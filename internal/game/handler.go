package game

import (
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"geoanomaly/internal/common"

	"github.com/gin-gonic/gin"
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

// ============================================
// MAIN ENDPOINTS
// ============================================

// ScanArea - 🔥 HLAVNÝ ENDPOINT s tier filtering
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

	// Validácia GPS súradníc
	if !isValidGPSCoordinate(req.Latitude, req.Longitude) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid GPS coordinates"})
		return
	}

	// Získaj player info
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	log.Printf("🔍 Player %s (tier %d) scanning area at [%.6f, %.6f]", user.Username, user.Tier, req.Latitude, req.Longitude)

	// ✅ Rate limit check
	scanKey := fmt.Sprintf("area_scan:%s", userID)
	if h.redis != nil && !h.checkAreaScanRateLimit(scanKey) {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"error":       "Area scan rate limit exceeded",
			"retry_after": AreaScanCooldown * 60,
			"message":     "You can scan area once every 30 minutes",
		})
		return
	}

	// Nájdi existujúce zóny v oblasti
	existingZones := h.getExistingZonesInArea(req.Latitude, req.Longitude, AreaScanRadius)
	log.Printf("📍 Found %d existing zones in area", len(existingZones))

	// Vypočítaj koľko nových zón môžeme vytvoriť
	maxZones := h.calculateMaxZones(user.Tier)
	currentDynamicZones := h.countDynamicZonesInArea(req.Latitude, req.Longitude, AreaScanRadius)
	newZonesNeeded := maxZones - currentDynamicZones

	log.Printf("🎮 Zone calculation: maxZones=%d, currentDynamic=%d, newNeeded=%d", maxZones, currentDynamicZones, newZonesNeeded)

	var newZones []common.Zone

	// Vytvor nové zóny ak je potreba
	if newZonesNeeded > 0 {
		log.Printf("🏗️ Creating %d new dynamic zones...", newZonesNeeded)
		newZones = h.spawnDynamicZones(req.Latitude, req.Longitude, user.Tier, newZonesNeeded)
		log.Printf("✅ Successfully created %d zones", len(newZones))

		// Spawn items v nových zónách
		log.Printf("🎁 Starting item spawning for %d new zones...", len(newZones))
		for i, zone := range newZones {
			log.Printf("🎯 Processing zone %d/%d: %s (ID: %s)", i+1, len(newZones), zone.Name, zone.ID)
			h.spawnItemsForNewZone(zone.ID, zone.TierRequired)
			log.Printf("✅ Items spawned for zone: %s", zone.Name)
		}
		log.Printf("🎉 Item spawning completed for all zones")
	} else {
		log.Printf("⚠️ No new zones needed (already at max)")
	}

	// ✅ Filter zones by tier before building details
	allZones := append(existingZones, newZones...)
	visibleZones := h.filterZonesByTier(allZones, user.Tier)

	var zonesWithDetails []ZoneWithDetails

	log.Printf("📊 Building zone details for %d visible zones (filtered from %d total)...", len(visibleZones), len(allZones))
	for i, zone := range visibleZones {
		details := h.buildZoneDetails(zone, req.Latitude, req.Longitude, user.Tier)
		zonesWithDetails = append(zonesWithDetails, details)
		log.Printf("📋 Zone %d: %s - Artifacts: %d, Gear: %d, Can Enter: %v",
			i+1, zone.Name, details.ActiveArtifacts, details.ActiveGear, details.CanEnter)
	}

	// Nastav next scan time
	nextScanTime := time.Now().Add(AreaScanCooldown * time.Minute)

	// ✅ OPRAVENÉ: Convert ScanAreaRequest to LocationPoint properly
	scanCenter := LocationPoint(req)

	response := ScanAreaResponse{
		ZonesCreated:      len(newZones),
		Zones:             zonesWithDetails,
		ScanAreaCenter:    scanCenter, // ✅ Use proper conversion
		NextScanAvailable: nextScanTime.Unix(),
		MaxZones:          maxZones,
		CurrentZoneCount:  len(visibleZones),
		PlayerTier:        user.Tier,
	}

	log.Printf("📊 ScanArea response: created=%d, visible=%d, total=%d", len(newZones), len(visibleZones), len(allZones))
	c.JSON(http.StatusOK, response)
}

// GetNearbyZones - legacy endpoint s tier filtering
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

	radiusKm, _ := strconv.ParseFloat(c.DefaultQuery("radius", "5"), 64)
	if radiusKm > 20 {
		radiusKm = 20
	}

	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	zones := h.getExistingZonesInArea(lat, lng, radiusKm*1000)
	visibleZones := h.filterZonesByTier(zones, user.Tier)

	var result []ZoneWithDetails
	for _, zone := range visibleZones {
		details := h.buildZoneDetails(zone, lat, lng, user.Tier)
		result = append(result, details)
	}

	c.JSON(http.StatusOK, gin.H{
		"zones":     result,
		"total":     len(result),
		"user_tier": user.Tier,
		"message":   "Use /scan-area endpoint for dynamic zone generation",
	})
}

// ============================================
// STUB IMPLEMENTATIONS
// ============================================

func (h *Handler) GetZoneStats(c *gin.Context)          { h.notImplemented(c, "Zone stats") }
func (h *Handler) GetAvailableArtifacts(c *gin.Context) { h.notImplemented(c, "Available artifacts") }
func (h *Handler) GetAvailableGear(c *gin.Context)      { h.notImplemented(c, "Available gear") }
func (h *Handler) UseItem(c *gin.Context)               { h.notImplemented(c, "Use item") }
func (h *Handler) GetLeaderboard(c *gin.Context)        { h.notImplemented(c, "Leaderboard") }
func (h *Handler) GetGameStats(c *gin.Context)          { h.notImplemented(c, "Game stats") }
func (h *Handler) CreateEventZone(c *gin.Context)       { h.notImplemented(c, "Create event zone") }
func (h *Handler) UpdateZone(c *gin.Context)            { h.notImplemented(c, "Update zone") }
func (h *Handler) DeleteZone(c *gin.Context)            { h.notImplemented(c, "Delete zone") }
func (h *Handler) SpawnArtifact(c *gin.Context)         { h.notImplemented(c, "Spawn artifact") }
func (h *Handler) SpawnGear(c *gin.Context)             { h.notImplemented(c, "Spawn gear") }
func (h *Handler) CleanupExpiredZones(c *gin.Context)   { h.notImplemented(c, "Cleanup expired zones") }
func (h *Handler) GetExpiredZones(c *gin.Context)       { h.notImplemented(c, "Get expired zones") }
func (h *Handler) GetZoneAnalytics(c *gin.Context)      { h.notImplemented(c, "Zone analytics") }
func (h *Handler) GetItemAnalytics(c *gin.Context)      { h.notImplemented(c, "Item analytics") }

func (h *Handler) notImplemented(c *gin.Context, feature string) {
	c.JSON(http.StatusNotImplemented, gin.H{
		"error":     fmt.Sprintf("%s not implemented yet", feature),
		"status":    "planned",
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
