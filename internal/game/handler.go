package game

import (
	"fmt"
	"log"
	"math"
	"math/rand"
	"net/http"
	"strconv"
	"time"

	"geoanomaly/internal/common"
	"geoanomaly/internal/xp"

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

	// ✅ AKTUALIZOVANÉ: Rozdielne radiusy pre scan vs spawn
	// Scan 7km radius - vidí všetky zóny
	existingZonesInScanArea := h.getExistingZonesInArea(req.Latitude, req.Longitude, AreaScanRadius)

	// Count len v spawn radius - spawnovanie len v 2km
	currentDynamicZonesInSpawnArea := h.countDynamicZonesInSpawnArea(req.Latitude, req.Longitude, AreaSpawnRadius)

	// Calculate how many new zones can be created
	maxZones := h.calculateMaxZones(user.Tier)
	newZonesNeeded := maxZones - currentDynamicZonesInSpawnArea // ✅ ZMENA: používa spawn area count

	var newZones []common.Zone
	if newZonesNeeded > 0 {
		log.Printf("🏗️ Creating %d new zones in spawn radius (%.0fm) for tier %d player",
			newZonesNeeded, AreaSpawnRadius, user.Tier)

		// ✅ NOVÉ: Spawn len v 2km radius, ale collision check s celou 7km oblasťou
		newZones = h.spawnDynamicZonesInRadius(req.Latitude, req.Longitude, user.Tier, newZonesNeeded, AreaSpawnRadius, existingZonesInScanArea)
	}

	// Combine all zones v scan area (7km) - ✅ ZACHOVANÉ: vidí všetky zóny v 7km
	allZones := append(existingZonesInScanArea, newZones...)

	// Filter zones by tier - ✅ ZACHOVANÉ: tier filtering
	visibleZones := h.filterZonesByTier(allZones, user.Tier)

	// Build detailed zone info - ✅ ZACHOVANÉ: rovnaká logika
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

		// ✅ NOVÉ: Info o radiusoch
		ScanRadius:       AreaScanRadius,                 // 7km - čo vidíš
		SpawnRadius:      AreaSpawnRadius,                // 2km - kde spawnovať
		ZonesInSpawnArea: currentDynamicZonesInSpawnArea, // Počet zón v spawn area
	}

	c.JSON(http.StatusOK, response)
}

// ✅ AKTUALIZOVANÉ: spawnDynamicZones redirect na novú radius-controlled funkciu
func (h *Handler) spawnDynamicZones(lat, lng float64, playerTier int, count int) []common.Zone {
	// ✅ NOVÉ: Redirect na novú radius-controlled funkciu
	existingZones := h.getExistingZonesInArea(lat, lng, AreaScanRadius)
	log.Printf("🔄 [silverminesro] Redirecting to radius-controlled spawning (spawn radius: %.0fm, scan radius: %.0fm)",
		AreaSpawnRadius, AreaScanRadius)
	log.Printf("🏗️ Spawning %d zones for player tier %d with %d existing zones for collision check",
		count, playerTier, len(existingZones))

	return h.spawnDynamicZonesInRadius(lat, lng, playerTier, count, AreaSpawnRadius, existingZones)
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

// ✅ ENHANCED: EnterZone with activity tracking
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

	// Update zone activity
	h.updateZoneActivity(zone.ID)

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
		"ttl_status":           zone.TTLStatus(),
		"expires_in_seconds":   int64(zone.TimeUntilExpiry().Seconds()),
	})
}

// Helper function to update zone activity
func (h *Handler) updateZoneActivity(zoneID uuid.UUID) {
	h.db.Model(&common.Zone{}).Where("id = ?", zoneID).Update("last_activity", time.Now())
}

// ExitZone - jednoduchá implementácia
func (h *Handler) ExitZone(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	// Get player session
	var session common.PlayerSession
	if err := h.db.Where("user_id = ?", userID).First(&session).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Player session not found"})
		return
	}

	if session.CurrentZone == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Not currently in any zone"})
		return
	}

	// Get zone name before clearing
	var zoneName string = "Unknown Zone"
	if session.CurrentZone != nil {
		var zone common.Zone
		if err := h.db.First(&zone, "id = ?", *session.CurrentZone).Error; err == nil {
			zoneName = zone.Name
		}
	}

	// Calculate basic time in zone
	timeInZone := time.Since(session.CreatedAt)

	// Clear current zone
	session.CurrentZone = nil
	session.LastSeen = time.Now()

	if err := h.db.Save(&session).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to exit zone"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":         "Successfully exited zone",
		"exited_at":       time.Now().Unix(),
		"zone_name":       zoneName,
		"time_in_zone":    fmt.Sprintf("%.0fm", timeInZone.Minutes()),
		"items_collected": 0, // TODO: Implement if needed
		"xp_gained":       0, // TODO: Implement if needed
		"total_xp_gained": 0, // TODO: Implement if needed
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

	// Update zone activity on scan
	h.updateZoneActivity(zone.ID)

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
		"ttl_status":      zone.TTLStatus(),
		"expires_in":      int64(zone.TimeUntilExpiry().Seconds()),
	})
}

// ✅ ENHANCED CollectItem - zber artefakt/gear s XP systémom + zone activity tracking
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

	// Update zone activity on collection
	h.updateZoneActivity(zone.ID)

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
	var xpResult *xp.XPResult

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

		// Award XP for artifact
		xpHandler := xp.NewHandler(h.db)
		var err error
		xpResult, err = xpHandler.AwardArtifactXP(user.ID, artifact.Rarity, artifact.Biome, zone.TierRequired)
		if err != nil {
			log.Printf("❌ Failed to award XP: %v", err)
		}

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

	// Check if zone should be marked for empty cleanup
	zoneUUID, _ := uuid.Parse(zoneID)
	go h.checkAndCleanupEmptyZone(zoneUUID)

	// Enhanced response s XP systémom
	response := gin.H{
		"message":      "Item collected successfully",
		"item":         collectedItem,
		"item_name":    itemName,
		"item_type":    req.ItemType,
		"biome":        biome,
		"zone_name":    zone.Name,
		"danger_level": zone.DangerLevel,
		"collected_at": time.Now().Unix(),
		"new_total":    user.TotalArtifacts + user.TotalGear + 1,
	}

	// Add XP data if successful (len pre artifacts)
	if req.ItemType == "artifact" && xpResult != nil {
		response["xp_gained"] = xpResult.XPGained
		response["total_xp"] = xpResult.TotalXP
		response["current_level"] = xpResult.CurrentLevel
		response["xp_breakdown"] = xpResult.Breakdown

		if xpResult.LevelUp {
			response["level_up"] = true
			response["level_up_info"] = xpResult.LevelUpInfo
			response["congratulations"] = fmt.Sprintf("🎉 Level Up! You are now level %d!", xpResult.CurrentLevel)
		}
	}

	c.JSON(http.StatusOK, response)
}

// Check and cleanup empty zone
func (h *Handler) checkAndCleanupEmptyZone(zoneID uuid.UUID) {
	// Wait a bit to allow for multiple rapid collections
	time.Sleep(30 * time.Second)

	var activeArtifacts int64
	h.db.Model(&common.Artifact{}).Where("zone_id = ? AND is_active = true", zoneID).Count(&activeArtifacts)

	if activeArtifacts == 0 {
		// Zone is empty, mark for cleanup soon
		h.db.Model(&common.Zone{}).Where("id = ?", zoneID).Update("last_activity", time.Now().Add(-10*time.Minute))
		log.Printf("🏰 Zone %s marked for empty cleanup", zoneID)
	}
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

func (h *Handler) GetItemAnalytics(c *gin.Context) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":  "Get item analytics not implemented yet",
		"status": "planned",
	})
}

func (h *Handler) GetAllUsers(c *gin.Context) {
	// Get all users (Super Admin only)
	var users []common.User
	if err := h.db.Find(&users).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to fetch users",
		})
		return
	}

	// Remove password hashes for security
	for i := range users {
		users[i].PasswordHash = ""
	}

	c.JSON(http.StatusOK, gin.H{
		"users":        users,
		"total_users":  len(users),
		"message":      "Users retrieved successfully",
		"timestamp":    time.Now().Format(time.RFC3339),
		"requested_by": c.GetString("username"),
	})
}

// ============================================
// ✅ REFAKTOROVANÉ HELPER FUNCTIONS
// ============================================

// ✅ NOVÉ: selectBiome používa getAvailableBiomes z zones.go
func (h *Handler) selectBiome(tier int) string {
	availableBiomes := h.getAvailableBiomes(tier)
	if len(availableBiomes) == 0 {
		return BiomeForest // fallback
	}
	return availableBiomes[rand.Intn(len(availableBiomes))]
}

// ✅ NOVÉ: generateZoneName používa GetZoneTemplate z biomes.go
func (h *Handler) generateZoneName(biome string) string {
	template := GetZoneTemplate(biome)
	if len(template.Names) == 0 {
		return fmt.Sprintf("Unknown %s Zone", biome)
	}
	return template.Names[rand.Intn(len(template.Names))]
}

// ✅ ENHANCED: spawnItemsInZone s konfigurovateľnými spawn rates
func (h *Handler) spawnItemsInZone(zoneID uuid.UUID, tier int, biome string, zoneCenter common.Location, zoneRadius int) {
	template := GetZoneTemplate(biome)

	// ✅ KONFIGUROVATEĽNÉ NASTAVENIA - zmeň tieto hodnoty podľa potreby
	const (
		// Základné spawn rates (0.0 = 0%, 1.0 = 100%)
		baseArtifactSpawnRate = 0.8  // 80% šanca na artifact spawn
		baseGearSpawnRate     = 0.7  // 70% šanca na gear spawn
		exclusiveSpawnRate    = 0.15 // 15% šanca na exclusive artifacts

		// Multiplikátory podľa tier (vyšší tier = viac items)
		tierMultiplier = 0.1 // +10% za každý tier

		// Minimum garantovaných items
		minArtifactsPerZone = 1
		minGearPerZone      = 1

		// Maximum items per zone
		maxArtifactsPerZone = 5
		maxGearPerZone      = 4
	)

	log.Printf("🏭 [DEBUG] Spawning items in %s zone (tier %d)", biome, tier)
	log.Printf("🔧 [DEBUG] Template: %d artifact types, %d gear types, %d exclusive",
		len(template.ArtifactSpawnRates), len(template.GearSpawnRates), len(template.ExclusiveArtifacts))

	// Výpočet tier bonus
	tierBonus := float64(tier) * tierMultiplier
	adjustedArtifactRate := baseArtifactSpawnRate + tierBonus
	adjustedGearRate := baseGearSpawnRate + tierBonus
	adjustedExclusiveRate := exclusiveSpawnRate + tierBonus

	log.Printf("📊 [DEBUG] Adjusted rates: artifacts=%.2f, gear=%.2f, exclusive=%.2f",
		adjustedArtifactRate, adjustedGearRate, adjustedExclusiveRate)

	// ✅ ARTIFACT SPAWNING s debug informáciami
	artifactsSpawned := 0
	artifactAttempts := 0

	for artifactType, templateRate := range template.ArtifactSpawnRates {
		// Kombinuj template rate s našou adjusted rate
		finalRate := templateRate * adjustedArtifactRate
		roll := rand.Float64()

		log.Printf("🎲 [DEBUG] %s: roll=%.3f vs rate=%.3f (template=%.2f * adjusted=%.2f)",
			artifactType, roll, finalRate, templateRate, adjustedArtifactRate)

		if roll < finalRate && artifactsSpawned < maxArtifactsPerZone {
			if err := h.spawnSpecificArtifact(zoneID, artifactType, biome, tier); err != nil {
				log.Printf("❌ [ERROR] Failed to spawn artifact %s: %v", artifactType, err)
			} else {
				artifactsSpawned++
				log.Printf("💎 [SUCCESS] Spawned artifact: %s (roll %.3f < %.3f)",
					GetArtifactDisplayName(artifactType), roll, finalRate)
			}
		} else if roll >= finalRate {
			log.Printf("⭕ [SKIP] %s - roll failed", artifactType)
		} else {
			log.Printf("🚫 [LIMIT] %s - max artifacts reached", artifactType)
		}
		artifactAttempts++
	}

	// ✅ GUARANTEED MINIMUM ARTIFACTS
	if artifactsSpawned < minArtifactsPerZone && len(template.ArtifactSpawnRates) > 0 {
		log.Printf("🔄 [GUARANTEE] Need %d more artifacts for minimum", minArtifactsPerZone-artifactsSpawned)

		// Vyber náhodné artifact types z template
		artifactTypes := make([]string, 0, len(template.ArtifactSpawnRates))
		for artifactType := range template.ArtifactSpawnRates {
			artifactTypes = append(artifactTypes, artifactType)
		}

		for artifactsSpawned < minArtifactsPerZone && len(artifactTypes) > 0 {
			randomIndex := rand.Intn(len(artifactTypes))
			artifactType := artifactTypes[randomIndex]

			if err := h.spawnSpecificArtifact(zoneID, artifactType, biome, tier); err != nil {
				log.Printf("❌ [GUARANTEE] Failed to spawn guaranteed %s: %v", artifactType, err)
			} else {
				artifactsSpawned++
				log.Printf("💎 [GUARANTEE] Spawned guaranteed: %s", GetArtifactDisplayName(artifactType))
			}

			// Odstráň z listu aby sa neopakoval
			artifactTypes = append(artifactTypes[:randomIndex], artifactTypes[randomIndex+1:]...)
		}
	}

	// ✅ EXCLUSIVE ARTIFACTS s debug
	exclusiveSpawned := 0
	for _, exclusiveType := range template.ExclusiveArtifacts {
		roll := rand.Float64()
		log.Printf("🌟 [DEBUG] Exclusive %s: roll=%.3f vs rate=%.3f",
			exclusiveType, roll, adjustedExclusiveRate)

		if roll < adjustedExclusiveRate && (artifactsSpawned+exclusiveSpawned) < maxArtifactsPerZone {
			if err := h.spawnSpecificArtifact(zoneID, exclusiveType, biome, tier); err != nil {
				log.Printf("❌ [ERROR] Failed to spawn exclusive %s: %v", exclusiveType, err)
			} else {
				exclusiveSpawned++
				log.Printf("🌟 [SUCCESS] Spawned EXCLUSIVE: %s", GetArtifactDisplayName(exclusiveType))
			}
		}
	}

	// ✅ GEAR SPAWNING s debug informáciami
	gearSpawned := 0
	for gearType, templateRate := range template.GearSpawnRates {
		finalRate := templateRate * adjustedGearRate
		roll := rand.Float64()

		log.Printf("⚔️ [DEBUG] %s: roll=%.3f vs rate=%.3f", gearType, roll, finalRate)

		if roll < finalRate && gearSpawned < maxGearPerZone {
			if err := h.spawnSpecificGear(zoneID, gearType, biome, tier); err != nil {
				log.Printf("❌ [ERROR] Failed to spawn gear %s: %v", gearType, err)
			} else {
				gearSpawned++
				log.Printf("⚔️ [SUCCESS] Spawned gear: %s", GetGearDisplayName(gearType))
			}
		}
	}

	// ✅ GUARANTEED MINIMUM GEAR
	if gearSpawned < minGearPerZone && len(template.GearSpawnRates) > 0 {
		log.Printf("🔄 [GUARANTEE] Need %d more gear for minimum", minGearPerZone-gearSpawned)

		gearTypes := make([]string, 0, len(template.GearSpawnRates))
		for gearType := range template.GearSpawnRates {
			gearTypes = append(gearTypes, gearType)
		}

		for gearSpawned < minGearPerZone && len(gearTypes) > 0 {
			randomIndex := rand.Intn(len(gearTypes))
			gearType := gearTypes[randomIndex]

			if err := h.spawnSpecificGear(zoneID, gearType, biome, tier); err != nil {
				log.Printf("❌ [GUARANTEE] Failed to spawn guaranteed %s: %v", gearType, err)
			} else {
				gearSpawned++
				log.Printf("⚔️ [GUARANTEE] Spawned guaranteed: %s", GetGearDisplayName(gearType))
			}

			gearTypes = append(gearTypes[:randomIndex], gearTypes[randomIndex+1:]...)
		}
	}

	totalArtifacts := artifactsSpawned + exclusiveSpawned
	log.Printf("✅ [FINAL] Zone spawning complete: %d artifacts (%d regular + %d exclusive), %d gear items",
		totalArtifacts, artifactsSpawned, exclusiveSpawned, gearSpawned)
	log.Printf("📊 [STATS] Success rate: artifacts=%d/%d, gear=%d/%d",
		totalArtifacts, artifactAttempts, gearSpawned, len(template.GearSpawnRates))
}

// Generate random GPS coordinates within zone radius
func (h *Handler) generateRandomLocationInZone(center common.Location, radiusMeters int) common.Location {
	// Random angle (0-360 degrees)
	angle := rand.Float64() * 2 * math.Pi

	// Random distance (0 to radiusMeters)
	distance := rand.Float64() * float64(radiusMeters)

	// Convert to GPS coordinates
	// 1 degree ≈ 111,000 meters at equator
	latOffset := (distance * math.Cos(angle)) / 111000
	lngOffset := (distance * math.Sin(angle)) / (111000 * math.Cos(center.Latitude*math.Pi/180))

	return common.Location{
		Latitude:  center.Latitude + latOffset,
		Longitude: center.Longitude + lngOffset,
		Timestamp: time.Now(),
	}
}

// ============================================
// ZONE CLEANUP ENDPOINTS (REAL IMPLEMENTATIONS)
// ============================================

func (h *Handler) CleanupExpiredZones(c *gin.Context) {
	cleanupService := NewCleanupService(h.db)
	result := cleanupService.CleanupExpiredZones()

	c.JSON(http.StatusOK, gin.H{
		"message": "Zone cleanup completed",
		"result":  result,
		"status":  "success",
	})
}

func (h *Handler) GetExpiredZones(c *gin.Context) {
	var expiredZones []common.Zone
	h.db.Where("is_active = true AND expires_at < ?", time.Now()).Find(&expiredZones)

	c.JSON(http.StatusOK, gin.H{
		"expired_zones": expiredZones,
		"count":         len(expiredZones),
		"current_time":  time.Now().Format(time.RFC3339),
		"status":        "success",
	})
}

func (h *Handler) GetZoneAnalytics(c *gin.Context) {
	cleanupService := NewCleanupService(h.db)
	stats := cleanupService.GetCleanupStats()

	c.JSON(http.StatusOK, gin.H{
		"zone_analytics": stats,
		"timestamp":      time.Now().Format(time.RFC3339),
		"status":         "success",
	})
}
