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

// ✅ ENHANCED: spawnDynamicZones with TTL system
func (h *Handler) spawnDynamicZones(lat, lng float64, tier int, count int) []common.Zone {
	var newZones []common.Zone

	for i := 0; i < count; i++ {
		// ✅ NEW: Random TTL between 6-24 hours
		minTTL := 6 * time.Hour
		maxTTL := 24 * time.Hour
		ttlRange := maxTTL - minTTL
		randomTTL := minTTL + time.Duration(rand.Float64()*float64(ttlRange))

		// Calculate expiry time
		expiresAt := time.Now().Add(randomTTL)

		// Generate biome for this tier
		biome := h.selectBiome(tier)

		zone := common.Zone{
			BaseModel: common.BaseModel{ID: uuid.New()},
			Name:      h.generateZoneName(tier),
			Location: common.Location{
				Latitude:  lat + (rand.Float64()-0.5)*0.01,
				Longitude: lng + (rand.Float64()-0.5)*0.01,
				Timestamp: time.Now(),
			},
			TierRequired: tier,
			RadiusMeters: h.calculateZoneRadius(tier),
			IsActive:     true,
			ZoneType:     "dynamic",
			Biome:        biome,
			DangerLevel:  h.calculateDangerLevel(tier),

			// ✅ NEW: TTL fields
			ExpiresAt:    &expiresAt,
			LastActivity: time.Now(),
			AutoCleanup:  true,

			Properties: common.JSONB{
				"spawned_by":   "scan_area",
				"ttl_hours":    randomTTL.Hours(),
				"biome":        biome,
				"danger_level": h.calculateDangerLevel(tier),
			},
		}

		if err := h.db.Create(&zone).Error; err == nil {
			// ✅ FIXED: Spawn items in new zone with zone location
			h.spawnItemsInZone(zone.ID, tier, zone.Biome, zone.Location, zone.RadiusMeters)
			newZones = append(newZones, zone)

			log.Printf("🏰 Zone spawned: %s (TTL: %.1fh, expires: %s)",
				zone.Name, randomTTL.Hours(), expiresAt.Format("15:04"))
		} else {
			log.Printf("❌ Failed to create zone: %v", err)
		}
	}

	return newZones
}

// ✅ NEW: Helper function for danger level calculation
func (h *Handler) calculateDangerLevel(tier int) string {
	switch tier {
	case 0, 1:
		return "low"
	case 2:
		return "medium"
	case 3:
		return "high"
	case 4:
		return "extreme"
	default:
		return "low"
	}
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

	// ✅ NEW: Update zone activity
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

// ✅ NEW: Helper function to update zone activity
func (h *Handler) updateZoneActivity(zoneID uuid.UUID) {
	h.db.Model(&common.Zone{}).Where("id = ?", zoneID).Update("last_activity", time.Now())
}

// ✅ ENHANCED ExitZone - výstup zo zóny s kompletným trackingom
func (h *Handler) ExitZone(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	// Get player session with zone info
	var session common.PlayerSession
	if err := h.db.Preload("Zone").Where("user_id = ?", userID).First(&session).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Player session not found"})
		return
	}

	// ✅ ENHANCED: Extract zone information before clearing
	zoneName, biome, dangerLevel, zoneTier := h.getZoneInfo(session.CurrentZone)

	// ✅ ENHANCED: Calculate session statistics
	timeInZone := time.Since(session.CreatedAt)
	itemsCollected := h.getSessionItemsCollected(userID.(uuid.UUID), session.CurrentZone, session.CreatedAt)
	xpGained := h.calculateXPGained(itemsCollected, zoneTier, biome)

	// ✅ ENHANCED: Build comprehensive session stats
	sessionStats := SessionStats{
		EnteredAt:           session.CreatedAt.Unix(),
		DurationSeconds:     int(timeInZone.Seconds()),
		AverageItemsPerHour: h.calculateItemsPerHour(itemsCollected, timeInZone),
		BiomeExplored:       biome,
		DangerLevelFaced:    dangerLevel,
	}

	// Clear current zone
	session.CurrentZone = nil
	session.LastSeen = time.Now()

	if err := h.db.Save(&session).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to exit zone"})
		return
	}

	// ✅ ENHANCED: Award XP to user (if we want to implement XP system)
	if xpGained > 0 {
		h.db.Model(&common.User{}).Where("id = ?", userID).Update("xp", gorm.Expr("xp + ?", xpGained))
	}

	// ✅ ENHANCED: Complete exit response
	response := ExitZoneResponse{
		Message:        "Successfully exited zone",
		ExitedAt:       time.Now().Unix(),
		ZoneName:       zoneName,
		TimeInZone:     h.formatDurationDetailed(timeInZone),
		ItemsCollected: itemsCollected,
		XPGained:       xpGained,
		TotalXPGained:  xpGained, // Could be lifetime total if we track it
		SessionStats:   sessionStats,
	}

	c.JSON(http.StatusOK, response)
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

	// ✅ NEW: Update zone activity on scan
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

	// ✅ NEW: Update zone activity on collection
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

		// ✅ NEW: Award XP for artifact (len pre artifacts!)
		xpHandler := xp.NewHandler(h.db)
		var err error
		xpResult, err = xpHandler.AwardArtifactXP(user.ID, artifact.Rarity, artifact.Biome, zone.TierRequired)
		if err != nil {
			log.Printf("❌ Failed to award XP: %v", err)
			// Continue anyway - don't fail the collection
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

	// ✅ NEW: Check if zone should be marked for empty cleanup
	zoneUUID, _ := uuid.Parse(zoneID)
	go h.checkAndCleanupEmptyZone(zoneUUID)

	// ✅ ENHANCED: Response s XP systémom
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

	// ✅ Add XP data if successful (len pre artifacts)
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

// ✅ NEW: Check and cleanup empty zone
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

// ============================================
// HELPER FUNCTIONS FOR ZONE CREATION
// ============================================

// ✅ NEW: Missing helper functions
func (h *Handler) selectBiome(tier int) string {
	biomes := map[int][]string{
		0: {"forest", "meadow", "grassland"},
		1: {"forest", "meadow", "hills", "riverside"},
		2: {"hills", "forest", "swamp", "rocky"},
		3: {"swamp", "rocky", "desert", "wasteland"},
		4: {"wasteland", "volcanic", "frozen", "abyss"},
	}

	if biomesForTier, exists := biomes[tier]; exists {
		return biomesForTier[rand.Intn(len(biomesForTier))]
	}
	return "forest" // Default fallback
}

func (h *Handler) generateZoneName(tier int) string {
	prefixes := map[int][]string{
		0: {"Peaceful", "Quiet", "Serene", "Gentle"},
		1: {"Silent", "Hidden", "Mystic", "Ancient"},
		2: {"Dark", "Shadowy", "Twisted", "Forgotten"},
		3: {"Cursed", "Rotten", "Haunted", "Corrupted"},
		4: {"Infernal", "Void", "Nightmare", "Apocalyptic"},
	}

	suffixes := map[int][]string{
		0: {"Grove", "Garden", "Clearing", "Haven"},
		1: {"Thicket", "Glen", "Hollow", "Sanctuary"},
		2: {"Woods", "Cavern", "Ruins", "Crypt"},
		3: {"Swamp", "Pit", "Graveyard", "Wasteland"},
		4: {"Abyss", "Inferno", "Vortex", "Realm"},
	}

	tierPrefixes := prefixes[0] // Default
	tierSuffixes := suffixes[0] // Default

	if p, exists := prefixes[tier]; exists {
		tierPrefixes = p
	}
	if s, exists := suffixes[tier]; exists {
		tierSuffixes = s
	}

	prefix := tierPrefixes[rand.Intn(len(tierPrefixes))]
	suffix := tierSuffixes[rand.Intn(len(tierSuffixes))]

	return fmt.Sprintf("%s %s (T%d)", prefix, suffix, tier)
}

// ✅ FIXED: spawnItemsInZone now gets zone location and radius
func (h *Handler) spawnItemsInZone(zoneID uuid.UUID, tier int, biome string, zoneCenter common.Location, zoneRadius int) {
	// ✅ FIXED: Spawn artifacts with zone location data
	artifactCount := rand.Intn(3) + 1 // 1-3 artifacts
	for i := 0; i < artifactCount; i++ {
		artifact := h.generateArtifact(zoneID, tier, biome, zoneCenter, zoneRadius)
		if err := h.db.Create(&artifact).Error; err != nil {
			log.Printf("❌ Failed to create artifact: %v", err)
		} else {
			log.Printf("💎 Artifact spawned: %s at [%.6f, %.6f]", artifact.Name, artifact.Location.Latitude, artifact.Location.Longitude)
		}
	}

	// ✅ FIXED: Spawn gear with zone location data
	gearCount := rand.Intn(2) + 1 // 1-2 gear items
	for i := 0; i < gearCount; i++ {
		gear := h.generateGear(zoneID, tier, biome, zoneCenter, zoneRadius)
		if err := h.db.Create(&gear).Error; err != nil {
			log.Printf("❌ Failed to create gear: %v", err)
		} else {
			log.Printf("⚔️ Gear spawned: %s at [%.6f, %.6f]", gear.Name, gear.Location.Latitude, gear.Location.Longitude)
		}
	}
}

// ✅ FIXED: generateArtifact with random position in zone
func (h *Handler) generateArtifact(zoneID uuid.UUID, tier int, biome string, zoneCenter common.Location, zoneRadius int) common.Artifact {
	artifactTypes := []string{"ancient_coin", "crystal", "rune", "scroll", "gem", "tablet", "orb"}
	rarities := map[int][]string{
		0: {"common", "common", "common", "rare"},
		1: {"common", "common", "rare", "rare"},
		2: {"common", "rare", "rare", "epic"},
		3: {"rare", "rare", "epic", "epic"},
		4: {"epic", "epic", "legendary", "legendary"},
	}

	tierRarities := rarities[0] // Default
	if r, exists := rarities[tier]; exists {
		tierRarities = r
	}

	artifactType := artifactTypes[rand.Intn(len(artifactTypes))]
	rarity := tierRarities[rand.Intn(len(tierRarities))]

	return common.Artifact{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      h.generateArtifactName(artifactType, rarity, biome),
		Type:      artifactType,
		Rarity:    rarity,
		Biome:     biome,
		Location:  h.generateRandomLocationInZone(zoneCenter, zoneRadius), // ✅ FIXED: Random position in zone
		IsActive:  true,
		Properties: common.JSONB{
			"biome":      biome,
			"spawned_at": time.Now().Unix(),
		},
	}
}

// ✅ FIXED: generateGear with random position in zone
func (h *Handler) generateGear(zoneID uuid.UUID, tier int, biome string, zoneCenter common.Location, zoneRadius int) common.Gear {
	gearTypes := []string{"sword", "shield", "armor", "boots", "helmet", "ring", "amulet"}

	gearType := gearTypes[rand.Intn(len(gearTypes))]
	level := tier + rand.Intn(3) + 1 // Tier + 1-3

	return common.Gear{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      h.generateGearName(gearType, level, biome),
		Type:      gearType,
		Level:     level,
		Biome:     biome,
		Location:  h.generateRandomLocationInZone(zoneCenter, zoneRadius), // ✅ FIXED: Random position in zone
		IsActive:  true,
		Properties: common.JSONB{
			"biome":      biome,
			"spawned_at": time.Now().Unix(),
		},
	}
}

// ✅ NEW: Generate random GPS coordinates within zone radius
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

func (h *Handler) generateArtifactName(artifactType, rarity, biome string) string {
	biomeAdjectives := map[string]string{
		"forest":    "Verdant",
		"meadow":    "Blooming",
		"hills":     "Rolling",
		"riverside": "Flowing",
		"swamp":     "Murky",
		"rocky":     "Stone",
		"desert":    "Scorched",
		"wasteland": "Corrupted",
		"volcanic":  "Molten",
		"frozen":    "Glacial",
		"abyss":     "Void",
	}

	rarityAdjectives := map[string]string{
		"common":    "Simple",
		"rare":      "Ancient",
		"epic":      "Legendary",
		"legendary": "Divine",
	}

	biomeAdj := biomeAdjectives[biome]
	if biomeAdj == "" {
		biomeAdj = "Mystic"
	}

	rarityAdj := rarityAdjectives[rarity]
	if rarityAdj == "" {
		rarityAdj = "Ancient"
	}

	return fmt.Sprintf("%s %s %s", biomeAdj, rarityAdj, artifactType)
}

func (h *Handler) generateGearName(gearType string, level int, biome string) string {
	biomeAdjectives := map[string]string{
		"forest":    "Wooden",
		"meadow":    "Leather",
		"hills":     "Stone",
		"riverside": "Silver",
		"swamp":     "Rusty",
		"rocky":     "Iron",
		"desert":    "Bronze",
		"wasteland": "Corrupted",
		"volcanic":  "Obsidian",
		"frozen":    "Ice",
		"abyss":     "Void",
	}

	biomeAdj := biomeAdjectives[biome]
	if biomeAdj == "" {
		biomeAdj = "Iron"
	}

	return fmt.Sprintf("%s %s +%d", biomeAdj, gearType, level)
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
