package game

import (
	"fmt"
	"log"
	"math"
	"math/rand"
	"net/http"
	"time"

	"geoanomaly/internal/common"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ============================================
// ZONE INTERACTION ENDPOINTS
// ============================================

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

	// Get user tier for visibility check
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

	// ✅ TIER CHECK: Only show zone if user can see it
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
	details := h.buildZoneDetails(zone, 0, 0, user.Tier) // No distance calculation

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

	// ✅ TIER CHECK
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
		"message":     "Successfully entered zone",
		"zone":        zone,
		"entered_at":  time.Now().Unix(),
		"can_collect": true,
		"player_tier": user.Tier,
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

	// ✅ TIER CHECK
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
		"zone":            zone,
		"artifacts":       filteredArtifacts,
		"gear":            filteredGear,
		"total_artifacts": len(filteredArtifacts),
		"total_gear":      len(filteredGear),
		"scan_timestamp":  time.Now().Unix(),
		"message":         "Zone scanned successfully",
	})
}

// ============================================
// ZONE MANAGEMENT FUNCTIONS
// ============================================

// Zone creation functions
func (h *Handler) spawnDynamicZones(centerLat, centerLng float64, playerTier, count int) []common.Zone {
	var zones []common.Zone

	log.Printf("🏗️ Starting zone creation: lat=%.6f, lng=%.6f, tier=%d, count=%d", centerLat, centerLng, playerTier, count)

	zoneNames := []string{
		"Mysterious Forest", "Ancient Ruins", "Crystal Cave", "Forgotten Temple",
		"Enchanted Grove", "Shadow Valley", "Golden Hills", "Mystic Lake",
		"Dragon's Lair", "Wizard Tower", "Haunted Castle", "Sacred Grove",
	}

	for i := 0; i < count; i++ {
		// Random pozícia v rámci 7km
		lat, lng := h.generateRandomPosition(centerLat, centerLng, AreaScanRadius)
		zoneTier := h.calculateZoneTier(playerTier)

		// Expiry time
		expiryHours := ZoneMinExpiryHours + rand.Intn(ZoneMaxExpiryHours-ZoneMinExpiryHours+1)
		expiryTime := time.Now().Add(time.Duration(expiryHours) * time.Hour)

		zone := common.Zone{
			BaseModel:    common.BaseModel{ID: uuid.New()},
			Name:         fmt.Sprintf("%s (T%d)", zoneNames[rand.Intn(len(zoneNames))], zoneTier),
			Description:  fmt.Sprintf("Dynamic zone spawned for tier %d players", zoneTier),
			RadiusMeters: h.calculateZoneRadius(zoneTier),
			TierRequired: zoneTier,
			Location: common.Location{
				Latitude:  lat,
				Longitude: lng,
				Timestamp: time.Now(),
			},
			ZoneType: "dynamic",
			Properties: common.JSONB{
				"spawned_by":     "player_scan",
				"expires_at":     expiryTime.Unix(),
				"spawn_tier":     playerTier,
				"despawn_reason": "timer",
				"created_at":     time.Now().Unix(),
				"zone_type":      "dynamic",
				"zone_category":  h.getZoneCategory(zoneTier),
			},
			IsActive: true,
		}

		log.Printf("💾 Creating zone %d: %s at [%.6f, %.6f]", i+1, zone.Name, lat, lng)

		if err := h.db.Create(&zone).Error; err != nil {
			log.Printf("❌ Failed to create zone %s: %v", zone.Name, err)
			continue
		}

		log.Printf("✅ Zone created successfully: %s (ID: %s)", zone.Name, zone.ID)

		// Spawn items v zóne
		h.spawnItemsForNewZone(zone.ID, zoneTier)

		zones = append(zones, zone)
	}

	log.Printf("🎯 Zone creation completed: %d/%d zones created successfully", len(zones), count)
	return zones
}

func (h *Handler) getExistingZonesInArea(lat, lng, radiusMeters float64) []common.Zone {
	var zones []common.Zone

	if err := h.db.Where("is_active = true").Find(&zones).Error; err != nil {
		log.Printf("❌ Failed to query zones: %v", err)
		return []common.Zone{}
	}

	// Manual distance filtering
	var filteredZones []common.Zone
	for _, zone := range zones {
		distance := calculateDistance(lat, lng, zone.Location.Latitude, zone.Location.Longitude)
		if distance <= radiusMeters {
			filteredZones = append(filteredZones, zone)
		}
	}

	log.Printf("📍 Found %d zones in area (radius: %.0fm)", len(filteredZones), radiusMeters)
	return filteredZones
}

// ✅ Zone visibility filtering
func (h *Handler) filterZonesByTier(zones []common.Zone, userTier int) []common.Zone {
	var visibleZones []common.Zone
	for _, zone := range zones {
		if zone.TierRequired <= userTier {
			visibleZones = append(visibleZones, zone)
		}
	}
	log.Printf("🔍 Filtered zones: %d visible out of %d total (user tier: %d)", len(visibleZones), len(zones), userTier)
	return visibleZones
}

func (h *Handler) countDynamicZonesInArea(lat, lng, radiusMeters float64) int {
	zones := h.getExistingZonesInArea(lat, lng, radiusMeters)
	count := 0
	for _, zone := range zones {
		if zone.ZoneType == "dynamic" {
			count++
		}
	}
	return count
}

func (h *Handler) buildZoneDetails(zone common.Zone, playerLat, playerLng float64, playerTier int) ZoneWithDetails {
	distance := calculateDistance(playerLat, playerLng, zone.Location.Latitude, zone.Location.Longitude)

	// Počet aktívnych items
	var artifactCount, gearCount int64
	h.db.Model(&common.Artifact{}).Where("zone_id = ? AND is_active = true", zone.ID).Count(&artifactCount)
	h.db.Model(&common.Gear{}).Where("zone_id = ? AND is_active = true", zone.ID).Count(&gearCount)

	// Počet aktívnych hráčov
	var playerCount int64
	h.db.Model(&common.PlayerSession{}).Where("current_zone = ? AND is_online = true AND last_seen > ?", zone.ID, time.Now().Add(-5*time.Minute)).Count(&playerCount)

	details := ZoneWithDetails{
		Zone:            zone,
		DistanceMeters:  distance,
		CanEnter:        playerTier >= zone.TierRequired,
		ActiveArtifacts: int(artifactCount),
		ActiveGear:      int(gearCount),
		ActivePlayers:   int(playerCount),
	}

	// Expiry info pre dynamic zones
	if zone.ZoneType == "dynamic" {
		if expiryTime, exists := zone.Properties["expires_at"]; exists {
			if expiryTimestamp, ok := expiryTime.(float64); ok {
				expiry := int64(expiryTimestamp)
				details.ExpiresAt = &expiry

				timeLeft := time.Until(time.Unix(expiry, 0))
				if timeLeft > 0 {
					timeLeftStr := formatDuration(timeLeft)
					details.TimeToExpiry = &timeLeftStr
				}
			}
		}
	}

	return details
}

// ✅ Zone limits for freemium model
func (h *Handler) calculateMaxZones(playerTier int) int {
	switch playerTier {
	case 0:
		return 1 // Free - 1 zóna len
	case 1:
		return 2 // Basic - 2 zóny
	case 2:
		return 3 // Premium - 3 zóny
	case 3:
		return 5 // Pro - 5 zón
	case 4:
		return 7 // Elite - 7 zón
	default:
		return 1
	}
}

// ✅ Better zone tier assignment
func (h *Handler) calculateZoneTier(playerTier int) int {
	// 70% chance for player tier, 30% for +1 tier
	if rand.Float64() < 0.7 {
		return playerTier
	}
	// +1 tier but max 4
	return int(math.Min(4, float64(playerTier+1)))
}

// ✅ Zone categories
func (h *Handler) getZoneCategory(tier int) string {
	switch tier {
	case 0, 1:
		return "basic"
	case 2, 3:
		return "premium"
	case 4:
		return "elite"
	default:
		return "basic"
	}
}

func (h *Handler) calculateZoneRadius(tier int) int {
	switch tier {
	case 0:
		return 100 // Smaller for free
	case 1:
		return 150
	case 2:
		return 200
	case 3:
		return 250
	case 4:
		return 300
	default:
		return 100
	}
}

func (h *Handler) generateRandomPosition(centerLat, centerLng, radiusMeters float64) (float64, float64) {
	angle := rand.Float64() * 2 * math.Pi
	distance := rand.Float64() * radiusMeters
	earthRadius := 6371000.0

	latOffset := (distance * math.Cos(angle)) / earthRadius * (180 / math.Pi)
	lngOffset := (distance * math.Sin(angle)) / earthRadius * (180 / math.Pi) / math.Cos(centerLat*math.Pi/180)

	return centerLat + latOffset, centerLng + lngOffset
}
