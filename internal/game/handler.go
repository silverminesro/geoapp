package game

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"geoanomaly/internal/common"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ============================================
// MAIN GAME ENDPOINTS
// ============================================

// ScanArea - hlavný endpoint pre hľadanie zón
func (h *Handler) ScanArea(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	var req ScanAreaRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if !IsValidGPSCoordinate(req.Latitude, req.Longitude) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid GPS coordinates"})
		return
	}

	// Get user
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Rate limiting check
	rateLimitKey := fmt.Sprintf("scan_area:%s", userID)
	if !h.checkAreaScanRateLimit(rateLimitKey) {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"error":               "Rate limit exceeded",
			"next_scan_in_sec":    AreaScanCooldown * 60,
			"next_scan_available": time.Now().Add(AreaScanCooldown * time.Minute).Unix(),
		})
		return
	}

	// Get existing zones in area
	existingZones := h.getExistingZonesInArea(req.Latitude, req.Longitude, AreaScanRadius)

	// Calculate how many new zones can be created
	maxZones := h.calculateMaxZones(user.Tier)
	currentDynamicZones := h.countDynamicZonesInArea(req.Latitude, req.Longitude, AreaScanRadius)
	newZonesNeeded := maxZones - currentDynamicZones

	var newZones []common.Zone
	if newZonesNeeded > 0 {
		log.Printf("🏗️ Creating %d new zones for tier %d player", newZonesNeeded, user.Tier)
		newZones = h.spawnDynamicZones(req.Latitude, req.Longitude, user.Tier, newZonesNeeded)
	}

	// Combine all zones
	allZones := append(existingZones, newZones...)

	// Filter zones by tier
	visibleZones := h.filterZonesByTier(allZones, user.Tier)

	// Build detailed zone info
	var zoneDetails []ZoneWithDetails
	for _, zone := range visibleZones {
		details := h.buildZoneDetails(zone, req.Latitude, req.Longitude, user.Tier)
		zoneDetails = append(zoneDetails, details)
	}

	response := ScanAreaResponse{
		ZonesCreated:      len(newZones),
		Zones:             zoneDetails,
		ScanAreaCenter:    LocationPoint(req),
		NextScanAvailable: time.Now().Add(AreaScanCooldown * time.Minute).Unix(),
		MaxZones:          maxZones,
		CurrentZoneCount:  len(visibleZones),
		PlayerTier:        user.Tier,
	}

	c.JSON(http.StatusOK, response)
}

// GetNearbyZones - získanie zón v okolí
func (h *Handler) GetNearbyZones(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	lat, err := strconv.ParseFloat(c.Query("lat"), 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid latitude"})
		return
	}

	lng, err := strconv.ParseFloat(c.Query("lng"), 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid longitude"})
		return
	}

	radius, err := strconv.ParseFloat(c.DefaultQuery("radius", "5000"), 64)
	if err != nil || radius > 10000 {
		radius = 5000 // Default 5km
	}

	// Get user tier
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Get nearby zones
	zones := h.getExistingZonesInArea(lat, lng, radius)
	visibleZones := h.filterZonesByTier(zones, user.Tier)

	// Build detailed response
	var zoneDetails []ZoneWithDetails
	for _, zone := range visibleZones {
		details := h.buildZoneDetails(zone, lat, lng, user.Tier)
		zoneDetails = append(zoneDetails, details)
	}

	c.JSON(http.StatusOK, gin.H{
		"zones":       zoneDetails,
		"total_zones": len(zoneDetails),
		"scan_center": LocationPoint{Latitude: lat, Longitude: lng},
		"radius":      radius,
		"player_tier": user.Tier,
	})
}

// GetZoneDetails - detaily konkrétnej zóny
func (h *Handler) GetZoneDetails(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	zoneID := c.Param("id")
	if zoneID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Zone ID required"})
		return
	}

	// Get user
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Get zone
	var zone common.Zone
	if err := h.db.First(&zone, "id = ? AND is_active = true", zoneID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Zone not found"})
		return
	}

	// Tier check
	if zone.TierRequired > user.Tier {
		c.JSON(http.StatusForbidden, gin.H{
			"error":         "Zone not accessible",
			"message":       "Upgrade your tier to access this zone",
			"required_tier": zone.TierRequired,
			"your_tier":     user.Tier,
		})
		return
	}

	// Build detailed response
	details := h.buildZoneDetails(zone, 0, 0, user.Tier)

	// Get all items in zone (filtered by tier)
	var artifacts []common.Artifact
	var gear []common.Gear
	h.db.Where("zone_id = ? AND is_active = true", zone.ID).Find(&artifacts)
	h.db.Where("zone_id = ? AND is_active = true", zone.ID).Find(&gear)

	filteredArtifacts := h.filterArtifactsByTier(artifacts, user.Tier)
	filteredGear := h.filterGearByTier(gear, user.Tier)

	c.JSON(http.StatusOK, gin.H{
		"zone":      details,
		"artifacts": filteredArtifacts,
		"gear":      filteredGear,
		"can_enter": user.Tier >= zone.TierRequired,
		"message":   "Zone details retrieved successfully",
	})
}

// EnterZone - vstup do zóny
func (h *Handler) EnterZone(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	zoneID := c.Param("id")
	if zoneID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Zone ID required"})
		return
	}

	// Get user
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Get zone
	var zone common.Zone
	if err := h.db.First(&zone, "id = ? AND is_active = true", zoneID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Zone not found"})
		return
	}

	// Tier check
	if zone.TierRequired > user.Tier {
		c.JSON(http.StatusForbidden, gin.H{
			"error":         "Insufficient tier level",
			"message":       "Upgrade your tier to enter this zone",
			"required_tier": zone.TierRequired,
			"your_tier":     user.Tier,
		})
		return
	}

	// Update player session
	var session common.PlayerSession
	if err := h.db.Where("user_id = ?", userID).First(&session).Error; err != nil {
		// Create new session
		session = common.PlayerSession{
			UserID:   user.ID,
			IsOnline: true,
			LastSeen: time.Now(),
		}
	}

	// Parse zone UUID
	zoneUUID, err := uuid.Parse(zoneID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid zone ID format"})
		return
	}

	session.CurrentZone = &zoneUUID
	session.LastSeen = time.Now()
	session.IsOnline = true

	if err := h.db.Save(&session).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to enter zone"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":              "Successfully entered zone",
		"zone_name":            zone.Name,
		"biome":                zone.Biome,
		"danger_level":         zone.DangerLevel,
		"zone":                 zone,
		"entered_at":           time.Now().Unix(),
		"can_collect":          true,
		"player_tier":          user.Tier,
		"distance_from_center": 0,
	})
}

// ExitZone - výstup zo zóny
func (h *Handler) ExitZone(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	// Update player session - remove current zone
	var session common.PlayerSession
	if err := h.db.Where("user_id = ?", userID).First(&session).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Player session not found"})
		return
	}

	session.CurrentZone = nil
	session.LastSeen = time.Now()

	if err := h.db.Save(&session).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to exit zone"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":   "Successfully exited zone",
		"exited_at": time.Now().Unix(),
	})
}

// ScanZone - scan items v zóne
func (h *Handler) ScanZone(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	zoneID := c.Param("id")
	if zoneID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Zone ID required"})
		return
	}

	// Get user
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Get zone
	var zone common.Zone
	if err := h.db.First(&zone, "id = ? AND is_active = true", zoneID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Zone not found"})
		return
	}

	// Tier check
	if zone.TierRequired > user.Tier {
		c.JSON(http.StatusForbidden, gin.H{
			"error":         "Insufficient tier level",
			"required_tier": zone.TierRequired,
			"your_tier":     user.Tier,
		})
		return
	}

	// Check if player is in zone
	var session common.PlayerSession
	if err := h.db.Where("user_id = ? AND current_zone = ?", userID, zoneID).First(&session).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Not in zone",
			"message": "You must enter the zone first",
		})
		return
	}

	// Get items in zone (filtered by tier)
	var artifacts []common.Artifact
	var gear []common.Gear

	h.db.Where("zone_id = ? AND is_active = true", zoneID).Find(&artifacts)
	h.db.Where("zone_id = ? AND is_active = true", zoneID).Find(&gear)

	filteredArtifacts := h.filterArtifactsByTier(artifacts, user.Tier)
	filteredGear := h.filterGearByTier(gear, user.Tier)

	c.JSON(http.StatusOK, gin.H{
		"zone_name":       zone.Name,
		"zone":            zone,
		"artifacts":       h.addDistanceToItems(filteredArtifacts, session.LastLocationLatitude, session.LastLocationLongitude),
		"gear":            h.addDistanceToGear(filteredGear, session.LastLocationLatitude, session.LastLocationLongitude),
		"total_artifacts": len(filteredArtifacts),
		"total_gear":      len(filteredGear),
		"scan_timestamp":  time.Now().Unix(),
		"message":         "Zone scanned successfully",
	})
}

// CollectItem - zber artefakt/gear
func (h *Handler) CollectItem(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	zoneID := c.Param("id")
	if zoneID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Zone ID required"})
		return
	}

	type CollectRequest struct {
		ItemType string `json:"item_type" binding:"required"` // artifact, gear
		ItemID   string `json:"item_id" binding:"required"`
	}

	var req CollectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Get zone info for biome context
	var zone common.Zone
	if err := h.db.First(&zone, "id = ? AND is_active = true", zoneID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Zone not found"})
		return
	}

	// Check if player is in zone
	var session common.PlayerSession
	if err := h.db.Where("user_id = ? AND current_zone = ?", userID, zoneID).First(&session).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Not in zone",
			"message": "You must be in the zone to collect items",
		})
		return
	}

	// Check if user can collect this item
	canCollect, reason := h.CheckUserCanCollectItem(user.Tier, req.ItemType, req.ItemID)
	if !canCollect {
		c.JSON(http.StatusForbidden, gin.H{
			"error":     "Cannot collect item",
			"reason":    reason,
			"your_tier": user.Tier,
			"item_type": req.ItemType,
		})
		return
	}

	// Process collection based on item type
	var collectedItem interface{}
	var itemName string
	var biome string

	switch req.ItemType {
	case "artifact":
		var artifact common.Artifact
		if err := h.db.First(&artifact, "id = ? AND zone_id = ? AND is_active = true", req.ItemID, zoneID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artifact not found"})
			return
		}

		// Deactivate artifact
		artifact.IsActive = false
		h.db.Save(&artifact)

		// Add to inventory
		inventory := common.InventoryItem{
			UserID:   user.ID,
			ItemType: "artifact",
			ItemID:   artifact.ID,
			Quantity: 1,
			Properties: common.JSONB{
				"name":           artifact.Name,
				"type":           artifact.Type,
				"rarity":         artifact.Rarity,
				"biome":          artifact.Biome,
				"collected_at":   time.Now().Unix(),
				"collected_from": zoneID,
				"zone_name":      zone.Name,
				"zone_biome":     zone.Biome,
				"danger_level":   zone.DangerLevel,
			},
		}
		h.db.Create(&inventory)

		collectedItem = artifact
		itemName = artifact.Name
		biome = artifact.Biome

		// Update user stats
		h.db.Model(&user).Update("total_artifacts", gorm.Expr("total_artifacts + ?", 1))

	case "gear":
		var gear common.Gear
		if err := h.db.First(&gear, "id = ? AND zone_id = ? AND is_active = true", req.ItemID, zoneID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Gear not found"})
			return
		}

		// Deactivate gear
		gear.IsActive = false
		h.db.Save(&gear)

		// Add to inventory
		inventory := common.InventoryItem{
			UserID:   user.ID,
			ItemType: "gear",
			ItemID:   gear.ID,
			Quantity: 1,
			Properties: common.JSONB{
				"name":           gear.Name,
				"type":           gear.Type,
				"level":          gear.Level,
				"biome":          gear.Biome,
				"collected_at":   time.Now().Unix(),
				"collected_from": zoneID,
				"zone_name":      zone.Name,
				"zone_biome":     zone.Biome,
				"danger_level":   zone.DangerLevel,
			},
		}
		h.db.Create(&inventory)

		collectedItem = gear
		itemName = gear.Name
		biome = gear.Biome

		// Update user stats
		h.db.Model(&user).Update("total_gear", gorm.Expr("total_gear + ?", 1))

	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid item type"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      "Item collected successfully",
		"item":         collectedItem,
		"item_name":    itemName,
		"item_type":    req.ItemType,
		"biome":        biome,
		"zone_name":    zone.Name,
		"danger_level": zone.DangerLevel,
		"collected_at": time.Now().Unix(),
		"new_total":    user.TotalArtifacts + user.TotalGear + 1,
	})
}

// ============================================
// STUB ENDPOINTS (TO BE IMPLEMENTED)
// ============================================

func (h *Handler) GetAvailableArtifacts(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Get available artifacts not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) GetAvailableGear(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Get available gear not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) UseItem(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Use item not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) GetLeaderboard(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Get leaderboard not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) GetGameStats(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Get game stats not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) GetZoneStats(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Get zone stats not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) CreateEventZone(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Create event zone not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) UpdateZone(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Update zone not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) DeleteZone(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Delete zone not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) SpawnArtifact(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Spawn artifact not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) SpawnGear(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Spawn gear not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) CleanupExpiredZones(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Cleanup expired zones not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) GetExpiredZones(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Get expired zones not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) GetZoneAnalytics(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Get zone analytics not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) GetItemAnalytics(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Get item analytics not implemented yet",
		"status": "planned",
	})
}
