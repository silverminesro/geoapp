package zones

import (
	"fmt"
	"log"
	"math"
	"net/http"
	"time"

	"geoanomaly/internal/common"
	// ❌ VYMAZANÉ: "geoanomaly/internal/game"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	redis_client "github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

type Handler struct {
	db    *gorm.DB
	redis *redis_client.Client
}

func NewHandler(db *gorm.DB, redisClient *redis_client.Client) *Handler {
	return &Handler{
		db:    db,
		redis: redisClient,
	}
}

// ✅ PRIDANÉ: ZoneWithDetails type (local copy to avoid import cycle)
type ZoneWithDetails struct {
	Zone            common.Zone `json:"zone"`
	DistanceMeters  float64     `json:"distance_meters"`
	CanEnter        bool        `json:"can_enter"`
	ActiveArtifacts int         `json:"active_artifacts"`
	ActiveGear      int         `json:"active_gear"`
	ActivePlayers   int         `json:"active_players"`
	ExpiresAt       *int64      `json:"expires_at,omitempty"`
	TimeToExpiry    *string     `json:"time_to_expiry,omitempty"`
	Biome           string      `json:"biome"`
	DangerLevel     string      `json:"danger_level"`
}

// ✅ PRIDANÉ: Utility functions (local copy to avoid import cycle)
func calculateDistance(lat1, lon1, lat2, lon2 float64) float64 {
	const earthRadiusKm = 6371.0
	dlat := (lat2 - lat1) * (math.Pi / 180.0)
	dlon := (lon2 - lon1) * (math.Pi / 180.0)

	a := math.Sin(dlat/2)*math.Sin(dlat/2) + math.Cos(lat1*(math.Pi/180.0))*math.Cos(lat2*(math.Pi/180.0))*math.Sin(dlon/2)*math.Sin(dlon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return earthRadiusKm * c * 1000
}

func formatDuration(d time.Duration) string {
	if d < time.Hour {
		return fmt.Sprintf("%dm", int(d.Minutes()))
	}
	if d < 24*time.Hour {
		return fmt.Sprintf("%dh %dm", int(d.Hours()), int(d.Minutes())%60)
	}
	return fmt.Sprintf("%dd %dh", int(d.Hours()/24), int(d.Hours())%24)
}

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
		"message":              "Successfully entered zone",
		"zone_name":            zone.Name,        // ✅ PRIDANÉ: zone name
		"biome":                zone.Biome,       // ✅ PRIDANÉ: biome
		"danger_level":         zone.DangerLevel, // ✅ PRIDANÉ: danger level
		"zone":                 zone,             // ✅ PONECHANÉ: full zone object
		"entered_at":           time.Now().Unix(),
		"can_collect":          true,
		"player_tier":          user.Tier,
		"distance_from_center": 0, // ✅ PRIDANÉ: placeholder distance
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

// ============================================
// ZONE MANAGEMENT FUNCTIONS
// ============================================

func (h *Handler) GetExistingZonesInArea(lat, lng, radiusMeters float64) []common.Zone {
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
func (h *Handler) FilterZonesByTier(zones []common.Zone, userTier int) []common.Zone {
	var visibleZones []common.Zone
	for _, zone := range zones {
		if zone.TierRequired <= userTier {
			visibleZones = append(visibleZones, zone)
		}
	}
	log.Printf("🔍 Filtered zones: %d visible out of %d total (user tier: %d)", len(visibleZones), len(zones), userTier)
	return visibleZones
}

// ✅ UPDATED: Enhanced zone details with biome info
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
		Biome:           zone.Biome,       // ✅ PRIDANÉ: Biome info
		DangerLevel:     zone.DangerLevel, // ✅ PRIDANÉ: Danger level
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

func (h *Handler) BuildZoneDetails(zone common.Zone, playerLat, playerLng float64, playerTier int) ZoneWithDetails {
	return h.buildZoneDetails(zone, playerLat, playerLng, playerTier)
}

func (h *Handler) addDistanceToItems(artifacts []common.Artifact, playerLat, playerLng float64) []map[string]interface{} {
	var result []map[string]interface{}

	for _, artifact := range artifacts {
		distance := calculateDistance(playerLat, playerLng, artifact.Location.Latitude, artifact.Location.Longitude)

		item := map[string]interface{}{
			"id":              artifact.ID,
			"name":            artifact.Name,
			"type":            artifact.Type,
			"rarity":          artifact.Rarity,
			"biome":           artifact.Biome,
			"location":        artifact.Location,
			"properties":      artifact.Properties,
			"is_active":       artifact.IsActive,
			"distance_meters": distance,
			"created_at":      artifact.CreatedAt,
		}
		result = append(result, item)
	}

	return result
}

func (h *Handler) addDistanceToGear(gear []common.Gear, playerLat, playerLng float64) []map[string]interface{} {
	var result []map[string]interface{}

	for _, g := range gear {
		distance := calculateDistance(playerLat, playerLng, g.Location.Latitude, g.Location.Longitude)

		item := map[string]interface{}{
			"id":              g.ID,
			"name":            g.Name,
			"type":            g.Type,
			"level":           g.Level,
			"biome":           g.Biome,
			"location":        g.Location,
			"properties":      g.Properties,
			"is_active":       g.IsActive,
			"distance_meters": distance,
			"created_at":      g.CreatedAt,
		}
		result = append(result, item)
	}

	return result
}
