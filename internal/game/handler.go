package game

import (
	"context"
	"fmt"
	"math"
	"math/rand"
	"net/http"
	"strconv"
	"time"

	"geoapp/internal/common"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	redis_client "github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

type Handler struct {
	db    *gorm.DB
	redis *redis_client.Client
}

// Request/Response struktury
type ScanAreaRequest struct {
	Latitude  float64 `json:"latitude" binding:"required"`
	Longitude float64 `json:"longitude" binding:"required"`
}

type ScanAreaResponse struct {
	ZonesCreated      int               `json:"zones_created"`
	Zones             []ZoneWithDetails `json:"zones"`
	ScanAreaCenter    LocationPoint     `json:"scan_area_center"`
	NextScanAvailable int64             `json:"next_scan_available"`
	MaxZones          int               `json:"max_zones"`
	CurrentZoneCount  int               `json:"current_zone_count"`
	PlayerTier        int               `json:"player_tier"`
}

type ZoneWithDetails struct {
	Zone            common.Zone `json:"zone"`
	DistanceMeters  float64     `json:"distance_meters"`
	CanEnter        bool        `json:"can_enter"`
	ActiveArtifacts int         `json:"active_artifacts"`
	ActiveGear      int         `json:"active_gear"`
	ActivePlayers   int         `json:"active_players"`
	ExpiresAt       *int64      `json:"expires_at,omitempty"`
	TimeToExpiry    *string     `json:"time_to_expiry,omitempty"`
}

type LocationPoint struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type ScanZoneResponse struct {
	Zone      common.Zone       `json:"zone"`
	Artifacts []common.Artifact `json:"artifacts"`
	Gear      []common.Gear     `json:"gear"`
	Players   []PlayerInZone    `json:"players"`
	CanEnter  bool              `json:"can_enter"`
	Distance  float64           `json:"distance_meters"`
}

type PlayerInZone struct {
	Username string    `json:"username"`
	Tier     int       `json:"tier"`
	LastSeen time.Time `json:"last_seen"`
	Distance float64   `json:"distance_meters"`
}

type CollectItemRequest struct {
	ItemType  string    `json:"item_type" binding:"required"` // artifact, gear
	ItemID    uuid.UUID `json:"item_id" binding:"required"`
	Latitude  float64   `json:"latitude" binding:"required"`
	Longitude float64   `json:"longitude" binding:"required"`
}

type CollectItemResponse struct {
	Success     bool        `json:"success"`
	Item        interface{} `json:"item"`
	Message     string      `json:"message"`
	XPGained    int         `json:"xp_gained"`
	NewLevel    int         `json:"new_level,omitempty"`
	ZoneEmpty   bool        `json:"zone_empty,omitempty"`
	ZoneDespawn bool        `json:"zone_despawn,omitempty"`
}

// Konstanty
const (
	EarthRadiusKm      = 6371.0
	MaxScanRadius      = 100.0  // 100 metrov pre scanning
	MaxCollectRadius   = 50.0   // 50 metrov pre collecting
	AreaScanRadius     = 7000.0 // 7km pre area scan
	AreaScanCooldown   = 30     // 30 minút cooldown
	ZoneMinExpiryHours = 10     // minimálne 10 hodín expiry
	ZoneMaxExpiryHours = 24     // maximálne 24 hodín expiry
)

func NewHandler(db *gorm.DB, redisClient *redis_client.Client) *Handler {
	return &Handler{
		db:    db,
		redis: redisClient,
	}
}

// ScanArea - NOVÁ FUNKCIA - naskenuj oblasť a vytvor dynamic zones
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

	// Kontrola rate limit - 1 scan každých 30 minút
	scanKey := fmt.Sprintf("area_scan:%s", userID)
	if !h.checkAreaScanRateLimit(scanKey) {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"error":       "Area scan rate limit exceeded",
			"retry_after": AreaScanCooldown * 60,
			"message":     "You can scan area once every 30 minutes",
		})
		return
	}

	// Nájdi existujúce zóny v oblasti (dynamic + static)
	existingZones := h.getExistingZonesInArea(req.Latitude, req.Longitude, AreaScanRadius)

	// Vypočítaj koľko nových zón môžeme vytvoriť
	maxZones := h.calculateMaxZones(user.Tier)
	currentDynamicZones := h.countDynamicZonesInArea(req.Latitude, req.Longitude, AreaScanRadius)
	newZonesNeeded := maxZones - currentDynamicZones

	var newZones []common.Zone

	if newZonesNeeded > 0 {
		// Spawn nové dynamic zóny
		newZones = h.spawnDynamicZones(req.Latitude, req.Longitude, user.Tier, newZonesNeeded)
	}

	// Vytvor detailné informácie o zónách
	var zonesWithDetails []ZoneWithDetails
	allZones := append(existingZones, newZones...)

	for _, zone := range allZones {
		details := h.buildZoneDetails(zone, req.Latitude, req.Longitude, user.Tier)
		zonesWithDetails = append(zonesWithDetails, details)
	}

	// Nastav next scan time
	nextScanTime := time.Now().Add(AreaScanCooldown * time.Minute)

	response := ScanAreaResponse{
		ZonesCreated:      len(newZones),
		Zones:             zonesWithDetails,
		ScanAreaCenter:    LocationPoint{Latitude: req.Latitude, Longitude: req.Longitude},
		NextScanAvailable: nextScanTime.Unix(),
		MaxZones:          maxZones,
		CurrentZoneCount:  len(allZones),
		PlayerTier:        user.Tier,
	}

	c.JSON(http.StatusOK, response)
}

// GetNearbyZones - AKTUALIZOVANÁ - nájdi zóny v okolí (pre kompatibilitu)
func (h *Handler) GetNearbyZones(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	// Získaj GPS súradnice z query parametrov
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
		radiusKm = 20 // max 20km
	}

	// Získaj tier používateľa
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Nájdi zóny v okolí
	zones := h.getExistingZonesInArea(lat, lng, radiusKm*1000)

	// Vytvor detailné informácie
	var result []ZoneWithDetails
	for _, zone := range zones {
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

// EnterZone - AKTUALIZOVANÁ - vstúp do zóny s lepšou validáciou
func (h *Handler) EnterZone(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	zoneID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid zone ID"})
		return
	}

	// Získaj GPS súradnice z body
	var req ScanAreaRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Nájdi zónu a používateľa
	var zone common.Zone
	var user common.User

	if err := h.db.First(&zone, "id = ? AND is_active = true", zoneID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Zone not found or inactive"})
		return
	}

	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Kontrola tier požiadavky
	if user.Tier < zone.TierRequired {
		c.JSON(http.StatusForbidden, gin.H{
			"error":         "Insufficient tier level",
			"required_tier": zone.TierRequired,
			"user_tier":     user.Tier,
		})
		return
	}

	// Kontrola vzdialenosti
	distance := calculateDistance(req.Latitude, req.Longitude, zone.Location.Latitude, zone.Location.Longitude)
	if distance > float64(zone.RadiusMeters) {
		c.JSON(http.StatusForbidden, gin.H{
			"error":           "Too far from zone",
			"distance_meters": distance,
			"max_distance":    zone.RadiusMeters,
		})
		return
	}

	// Aktualizuj player session - vstúpil do zóny
	h.updatePlayerSession(userID.(uuid.UUID), &zoneID, common.Location{
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
		Timestamp: time.Now(),
	})

	// Spawn nové items ak je potrebné (len pre dynamic zones)
	if zone.ZoneType == "dynamic" {
		h.spawnItemsInZone(zoneID)
	}

	c.JSON(http.StatusOK, gin.H{
		"message":  "Successfully entered zone",
		"zone":     zone,
		"distance": distance,
	})
}

// ScanZone - AKTUALIZOVANÁ - naskenuj zónu s multiplayer info
func (h *Handler) ScanZone(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	zoneID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid zone ID"})
		return
	}

	// Získaj GPS súradnice z query
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

	// Nájdi zónu
	var zone common.Zone
	if err := h.db.First(&zone, "id = ? AND is_active = true", zoneID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Zone not found"})
		return
	}

	// Kontrola vzdialenosti pre scanning
	distance := calculateDistance(lat, lng, zone.Location.Latitude, zone.Location.Longitude)
	if distance > MaxScanRadius {
		c.JSON(http.StatusForbidden, gin.H{
			"error":             "Too far to scan",
			"distance_meters":   distance,
			"max_scan_distance": MaxScanRadius,
		})
		return
	}

	// Kontrola rate limit pre scanning
	scanKey := fmt.Sprintf("scan:%s:%s", userID, zoneID)
	if !h.checkScanRateLimit(scanKey) {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"error":       "Scan rate limit exceeded",
			"retry_after": 30,
		})
		return
	}

	// Nájdi artefakty v zóne
	var artifacts []common.Artifact
	h.db.Where("zone_id = ? AND is_active = true", zoneID).Find(&artifacts)

	// Nájdi gear v zóne
	var gear []common.Gear
	h.db.Where("zone_id = ? AND is_active = true", zoneID).Find(&gear)

	// Nájdi hráčov v zóne (multiplayer)
	players := h.getPlayersInZone(zoneID, userID.(uuid.UUID))

	response := ScanZoneResponse{
		Zone:      zone,
		Artifacts: artifacts,
		Gear:      gear,
		Players:   players,
		CanEnter:  true,
		Distance:  distance,
	}

	c.JSON(http.StatusOK, response)
}

// CollectItem - AKTUALIZOVANÁ - zber s GPS validáciou a zone cleanup
func (h *Handler) CollectItem(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	zoneID, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid zone ID"})
		return
	}

	var req CollectItemRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Kontrola rate limit pre collecting
	collectKey := fmt.Sprintf("collect:%s:%s", userID, zoneID)
	if !h.checkCollectRateLimit(collectKey) {
		c.JSON(http.StatusTooManyRequests, gin.H{
			"error":       "Collect rate limit exceeded",
			"retry_after": 60,
		})
		return
	}

	// Kontrola vzdialenosti pre collecting
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Zone not found"})
		return
	}

	zoneDistance := calculateDistance(req.Latitude, req.Longitude, zone.Location.Latitude, zone.Location.Longitude)
	if zoneDistance > MaxCollectRadius {
		c.JSON(http.StatusForbidden, gin.H{
			"error":                "Too far to collect",
			"distance_meters":      zoneDistance,
			"max_collect_distance": MaxCollectRadius,
		})
		return
	}

	// Spracuj podľa typu item
	var response CollectItemResponse
	var err error

	switch req.ItemType {
	case "artifact":
		response, err = h.collectArtifact(userID.(uuid.UUID), zoneID, req.ItemID)
	case "gear":
		response, err = h.collectGear(userID.(uuid.UUID), zoneID, req.ItemID)
	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid item type"})
		return
	}

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	// Skontroluj či je zóna prázdna po collecting
	if response.Success {
		isEmpty := h.checkIfZoneEmpty(zoneID)
		if isEmpty && zone.ZoneType == "dynamic" {
			h.despawnZone(zoneID, "empty")
			response.ZoneEmpty = true
			response.ZoneDespawn = true
		}
	}

	c.JSON(http.StatusOK, response)
}

// ============================================
// HELPER FUNCTIONS - AKTUALIZOVANÉ
// ============================================

func (h *Handler) spawnDynamicZones(centerLat, centerLng float64, playerTier, count int) []common.Zone {
	var zones []common.Zone

	zoneNames := []string{
		"Mysterious Forest", "Ancient Ruins", "Crystal Cave", "Forgotten Temple",
		"Enchanted Grove", "Shadow Valley", "Golden Hills", "Mystic Lake",
		"Dragon's Lair", "Wizard Tower", "Haunted Castle", "Sacred Grove",
		"Emerald Glade", "Phantom Peak", "Celestial Garden", "Dwarven Mine",
	}

	for i := 0; i < count; i++ {
		// Random pozícia v rámci 7km
		lat, lng := h.generateRandomPosition(centerLat, centerLng, AreaScanRadius)

		// Tier zóny basovaný na player tier ± 1
		zoneTier := h.calculateZoneTier(playerTier)

		// Expiry time - 10-24 hodín
		expiryHours := ZoneMinExpiryHours + rand.Intn(ZoneMaxExpiryHours-ZoneMinExpiryHours+1)
		expiryTime := time.Now().Add(time.Duration(expiryHours) * time.Hour)

		zone := common.Zone{
			BaseModel:   common.BaseModel{ID: uuid.New()},
			Name:        fmt.Sprintf("%s (T%d)", zoneNames[rand.Intn(len(zoneNames))], zoneTier),
			Description: fmt.Sprintf("Dynamic zone spawned for tier %d players", zoneTier),
			Location: common.Location{
				Latitude:  lat,
				Longitude: lng,
				Timestamp: time.Now(),
			},
			RadiusMeters: h.calculateZoneRadius(zoneTier),
			TierRequired: zoneTier,
			ZoneType:     "dynamic",
			Properties: common.JSONB{
				"spawned_by":     "player_scan",
				"expires_at":     expiryTime.Unix(),
				"spawn_tier":     playerTier,
				"despawn_reason": "timer",
				"created_at":     time.Now().Unix(),
			},
			IsActive: true,
		}

		// Uložiť do databázy
		if err := h.db.Create(&zone).Error; err != nil {
			continue // Skip ak sa nepodarilo vytvoriť
		}

		// Spawn artefakty a gear do zóny
		h.spawnItemsForNewZone(zone.ID, zoneTier)

		zones = append(zones, zone)
	}

	return zones
}

func (h *Handler) getExistingZonesInArea(lat, lng, radiusMeters float64) []common.Zone {
	var zones []common.Zone

	// Použiť PostGIS ak je dostupný, inak fallback na basic query
	query := `
		SELECT * FROM zones 
		WHERE is_active = true 
		AND (
			ST_DWithin(
				ST_Point(location_longitude, location_latitude)::geography,
				ST_Point(?, ?)::geography,
				?
			) 
			OR 
			(6371000 * acos(cos(radians(?)) * cos(radians(location_latitude)) * cos(radians(location_longitude) - radians(?)) + sin(radians(?)) * sin(radians(location_latitude)))) <= ?
		)
		ORDER BY (6371000 * acos(cos(radians(?)) * cos(radians(location_latitude)) * cos(radians(location_longitude) - radians(?)) + sin(radians(?)) * sin(radians(location_latitude))))
		LIMIT 50
	`

	if err := h.db.Raw(query, lng, lat, radiusMeters, lat, lng, lat, radiusMeters, lat, lng, lat).Scan(&zones).Error; err != nil {
		// Fallback bez PostGIS
		h.db.Where("is_active = true").Find(&zones)

		// Filter by distance manually
		var filteredZones []common.Zone
		for _, zone := range zones {
			distance := calculateDistance(lat, lng, zone.Location.Latitude, zone.Location.Longitude)
			if distance <= radiusMeters {
				filteredZones = append(filteredZones, zone)
			}
		}
		zones = filteredZones
	}

	return zones
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

func (h *Handler) getPlayersInZone(zoneID uuid.UUID, excludeUserID uuid.UUID) []PlayerInZone {
	var sessions []common.PlayerSession
	h.db.Preload("User").Where("current_zone = ? AND user_id != ? AND is_online = true AND last_seen > ?", zoneID, excludeUserID, time.Now().Add(-5*time.Minute)).Find(&sessions)

	var players []PlayerInZone
	for _, session := range sessions {
		if session.User == nil {
			continue
		}

		player := PlayerInZone{
			Username: session.User.Username,
			Tier:     session.User.Tier,
			LastSeen: session.LastSeen,
			Distance: 0, // Môžeme vypočítať ak chceme
		}
		players = append(players, player)
	}

	return players
}

func (h *Handler) calculateMaxZones(playerTier int) int {
	switch playerTier {
	case 1:
		return 3 // Začiatočník - 3 zóny
	case 2:
		return 5 // Pokročilý - 5 zón
	case 3:
		return 7 // Expert - 7 zón
	case 4:
		return 10 // Master - 10 zón
	default:
		return 2
	}
}

func (h *Handler) calculateZoneTier(playerTier int) int {
	// Zóny môžu byť ±1 tier od hráča
	minTier := int(math.Max(1, float64(playerTier-1)))
	maxTier := int(math.Min(4, float64(playerTier+1)))

	return minTier + rand.Intn(maxTier-minTier+1)
}

func (h *Handler) calculateZoneRadius(tier int) int {
	switch tier {
	case 1:
		return 150 // 150m
	case 2:
		return 200 // 200m
	case 3:
		return 250 // 250m
	case 4:
		return 300 // 300m
	default:
		return 100
	}
}

func (h *Handler) generateRandomPosition(centerLat, centerLng, radiusMeters float64) (float64, float64) {
	// Random angle
	angle := rand.Float64() * 2 * math.Pi

	// Random distance (0 to radiusMeters)
	distance := rand.Float64() * radiusMeters

	// Convert to lat/lng offset
	earthRadius := 6371000.0 // meters

	latOffset := (distance * math.Cos(angle)) / earthRadius * (180 / math.Pi)
	lngOffset := (distance * math.Sin(angle)) / earthRadius * (180 / math.Pi) / math.Cos(centerLat*math.Pi/180)

	return centerLat + latOffset, centerLng + lngOffset
}

func (h *Handler) spawnItemsForNewZone(zoneID uuid.UUID, tier int) {
	// Počet items podľa tier
	artifactCount := 2 + tier*2 // Tier 1: 4, Tier 2: 6, Tier 3: 8, Tier 4: 10
	gearCount := 1 + tier       // Tier 1: 2, Tier 2: 3, Tier 3: 4, Tier 4: 5

	// Spawn artefakty
	for i := 0; i < artifactCount; i++ {
		h.spawnRandomArtifactWithTier(zoneID, tier)
	}

	// Spawn gear
	for i := 0; i < gearCount; i++ {
		h.spawnRandomGearWithTier(zoneID, tier)
	}
}

func (h *Handler) spawnRandomArtifactWithTier(zoneID uuid.UUID, tier int) {
	// Získaj zónu pre lokáciu
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return
	}

	// Rarity based on tier
	rarities := h.getRaritiesForTier(tier)
	types := []string{"ancient_coin", "crystal", "rune", "scroll", "gem", "tablet", "orb"}

	rarity := rarities[rand.Intn(len(rarities))]
	artifactType := types[rand.Intn(len(types))]

	// Random pozícia v zóne
	lat, lng := h.generateRandomPosition(zone.Location.Latitude, zone.Location.Longitude, float64(zone.RadiusMeters))

	artifact := common.Artifact{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      fmt.Sprintf("%s %s", rarity, artifactType),
		Type:      artifactType,
		Rarity:    rarity,
		Location: common.Location{
			Latitude:  lat,
			Longitude: lng,
			Timestamp: time.Now(),
		},
		Properties: common.JSONB{
			"spawn_time":   time.Now().Unix(),
			"spawner":      "dynamic_zone",
			"zone_tier":    tier,
			"spawn_reason": "zone_creation",
		},
		IsActive: true,
	}

	h.db.Create(&artifact)
}

func (h *Handler) spawnRandomGearWithTier(zoneID uuid.UUID, tier int) {
	// Získaj zónu pre lokáciu
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return
	}

	gearTypes := []string{"sword", "shield", "armor", "boots", "helmet", "ring", "amulet"}
	gearNames := h.getGearNamesForTier(tier)

	gearType := gearTypes[rand.Intn(len(gearTypes))]
	gearName := gearNames[rand.Intn(len(gearNames))]
	level := tier + rand.Intn(2) // tier ± 1

	lat, lng := h.generateRandomPosition(zone.Location.Latitude, zone.Location.Longitude, float64(zone.RadiusMeters))

	gear := common.Gear{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      fmt.Sprintf("%s %s", gearName, gearType),
		Type:      gearType,
		Level:     level,
		Location: common.Location{
			Latitude:  lat,
			Longitude: lng,
			Timestamp: time.Now(),
		},
		Properties: common.JSONB{
			"spawn_time":   time.Now().Unix(),
			"spawner":      "dynamic_zone",
			"zone_tier":    tier,
			"spawn_reason": "zone_creation",
		},
		IsActive: true,
	}

	h.db.Create(&gear)
}

func (h *Handler) getRaritiesForTier(tier int) []string {
	switch tier {
	case 1:
		return []string{"common", "common", "rare"} // 66% common, 33% rare
	case 2:
		return []string{"common", "rare", "rare", "epic"} // 25% common, 50% rare, 25% epic
	case 3:
		return []string{"rare", "rare", "epic", "legendary"} // 50% rare, 25% epic, 25% legendary
	case 4:
		return []string{"epic", "epic", "legendary", "legendary"} // 50% epic, 50% legendary
	default:
		return []string{"common"}
	}
}

func (h *Handler) getGearNamesForTier(tier int) []string {
	switch tier {
	case 1:
		return []string{"Iron", "Bronze", "Copper"}
	case 2:
		return []string{"Steel", "Silver", "Reinforced"}
	case 3:
		return []string{"Mithril", "Enchanted", "Masterwork"}
	case 4:
		return []string{"Dragon", "Legendary", "Mythical", "Divine"}
	default:
		return []string{"Basic"}
	}
}

func (h *Handler) checkIfZoneEmpty(zoneID uuid.UUID) bool {
	var artifactCount, gearCount int64
	h.db.Model(&common.Artifact{}).Where("zone_id = ? AND is_active = true", zoneID).Count(&artifactCount)
	h.db.Model(&common.Gear{}).Where("zone_id = ? AND is_active = true", zoneID).Count(&gearCount)

	return artifactCount == 0 && gearCount == 0
}

func (h *Handler) despawnZone(zoneID uuid.UUID, reason string) {
	// Deaktivuj zónu
	h.db.Model(&common.Zone{}).Where("id = ?", zoneID).Update("is_active", false)

	// Deaktivuj všetky items v zóne
	h.db.Model(&common.Artifact{}).Where("zone_id = ?", zoneID).Update("is_active", false)
	h.db.Model(&common.Gear{}).Where("zone_id = ?", zoneID).Update("is_active", false)

	// Vykick všetkých hráčov zo zóny
	h.db.Model(&common.PlayerSession{}).Where("current_zone = ?", zoneID).Update("current_zone", nil)

	// Log despawn
	fmt.Printf("🗑️ Despawned zone %s (reason: %s)\n", zoneID, reason)
}

func (h *Handler) checkAreaScanRateLimit(key string) bool {
	return h.checkRateLimit(key, 1, AreaScanCooldown*time.Minute)
}

// ============================================
// EXISTING FUNCTIONS - NEZMENENÉ
// ============================================

func (h *Handler) spawnItemsInZone(zoneID uuid.UUID) {
	rand.Seed(time.Now().UnixNano())

	// 30% šanca na spawn nového artefaktu
	if rand.Float64() < 0.3 {
		h.spawnRandomArtifact(zoneID)
	}

	// 20% šanca na spawn nového gear
	if rand.Float64() < 0.2 {
		h.spawnRandomGear(zoneID)
	}
}

func (h *Handler) spawnRandomArtifact(zoneID uuid.UUID) {
	// Získaj zónu pre lokáciu
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return
	}

	rarities := []string{"common", "rare", "epic", "legendary"}
	types := []string{"ancient_coin", "crystal", "rune", "scroll"}

	rarity := rarities[rand.Intn(len(rarities))]
	artifactType := types[rand.Intn(len(types))]

	// Random pozícia v zóne
	lat := zone.Location.Latitude + (rand.Float64()-0.5)*0.001
	lng := zone.Location.Longitude + (rand.Float64()-0.5)*0.001

	artifact := common.Artifact{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      fmt.Sprintf("%s %s", rarity, artifactType),
		Type:      artifactType,
		Rarity:    rarity,
		Location: common.Location{
			Latitude:  lat,
			Longitude: lng,
			Timestamp: time.Now(),
		},
		Properties: common.JSONB{
			"spawn_time": time.Now().Unix(),
			"spawner":    "auto",
		},
		IsActive: true,
	}

	h.db.Create(&artifact)
}

func (h *Handler) spawnRandomGear(zoneID uuid.UUID) {
	// Podobná logika pre gear
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return
	}

	gearTypes := []string{"sword", "shield", "armor", "boots", "helmet"}
	gearNames := []string{"Iron", "Steel", "Mithril", "Dragon", "Legendary"}

	gearType := gearTypes[rand.Intn(len(gearTypes))]
	gearName := gearNames[rand.Intn(len(gearNames))]
	level := rand.Intn(5) + 1

	lat := zone.Location.Latitude + (rand.Float64()-0.5)*0.001
	lng := zone.Location.Longitude + (rand.Float64()-0.5)*0.001

	gear := common.Gear{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      fmt.Sprintf("%s %s", gearName, gearType),
		Type:      gearType,
		Level:     level,
		Location: common.Location{
			Latitude:  lat,
			Longitude: lng,
			Timestamp: time.Now(),
		},
		Properties: common.JSONB{
			"spawn_time": time.Now().Unix(),
			"spawner":    "auto",
		},
		IsActive: true,
	}

	h.db.Create(&gear)
}

func (h *Handler) collectArtifact(userID, zoneID, artifactID uuid.UUID) (CollectItemResponse, error) {
	// Nájdi artefakt
	var artifact common.Artifact
	if err := h.db.First(&artifact, "id = ? AND zone_id = ? AND is_active = true", artifactID, zoneID).Error; err != nil {
		return CollectItemResponse{}, fmt.Errorf("artifact not found")
	}

	// Šanca na úspešné zbieranie podľa rarity
	successChance := h.getCollectSuccessChance(artifact.Rarity)
	if rand.Float64() > successChance {
		return CollectItemResponse{
			Success: false,
			Message: "Failed to collect artifact - try again!",
		}, nil
	}

	// Pridaj do inventára
	inventoryItem := common.InventoryItem{
		BaseModel: common.BaseModel{ID: uuid.New()},
		UserID:    userID,
		ItemType:  "artifact",
		ItemID:    artifactID,
		Properties: common.JSONB{
			"name":    artifact.Name,
			"type":    artifact.Type,
			"rarity":  artifact.Rarity,
			"zone_id": zoneID,
		},
		Quantity: 1,
	}

	if err := h.db.Create(&inventoryItem).Error; err != nil {
		return CollectItemResponse{}, err
	}

	// Deaktivuj artefakt
	h.db.Model(&artifact).Update("is_active", false)

	// Vypočítaj XP
	xp := h.calculateXP(artifact.Rarity)

	return CollectItemResponse{
		Success:  true,
		Item:     artifact,
		Message:  fmt.Sprintf("Successfully collected %s %s!", artifact.Rarity, artifact.Name),
		XPGained: xp,
	}, nil
}

func (h *Handler) collectGear(userID, zoneID, gearID uuid.UUID) (CollectItemResponse, error) {
	// Podobná logika ako pre artefakty
	var gear common.Gear
	if err := h.db.First(&gear, "id = ? AND zone_id = ? AND is_active = true", gearID, zoneID).Error; err != nil {
		return CollectItemResponse{}, fmt.Errorf("gear not found")
	}

	// Pridaj do inventára
	inventoryItem := common.InventoryItem{
		BaseModel: common.BaseModel{ID: uuid.New()},
		UserID:    userID,
		ItemType:  "gear",
		ItemID:    gearID,
		Properties: common.JSONB{
			"name":    gear.Name,
			"type":    gear.Type,
			"level":   gear.Level,
			"zone_id": zoneID,
		},
		Quantity: 1,
	}

	if err := h.db.Create(&inventoryItem).Error; err != nil {
		return CollectItemResponse{}, err
	}

	// Deaktivuj gear
	h.db.Model(&gear).Update("is_active", false)

	xp := gear.Level * 10 // XP na základe levelu gear

	return CollectItemResponse{
		Success:  true,
		Item:     gear,
		Message:  fmt.Sprintf("Successfully collected %s (Level %d)!", gear.Name, gear.Level),
		XPGained: xp,
	}, nil
}

func (h *Handler) updatePlayerSession(userID uuid.UUID, zoneID *uuid.UUID, location common.Location) {
	session := common.PlayerSession{
		UserID:       userID,
		LastSeen:     time.Now(),
		IsOnline:     true,
		CurrentZone:  zoneID,
		LastLocation: location,
	}

	h.db.Where("user_id = ?", userID).Assign(session).FirstOrCreate(&session)
}

func (h *Handler) checkScanRateLimit(key string) bool {
	// 1 scan každých 30 sekúnd
	return h.checkRateLimit(key, 1, 30*time.Second)
}

func (h *Handler) checkCollectRateLimit(key string) bool {
	// 1 collect každú minútu
	return h.checkRateLimit(key, 1, 60*time.Second)
}

func (h *Handler) checkRateLimit(key string, limit int, duration time.Duration) bool {
	count, err := h.redis.Get(context.Background(), key).Int()
	if err != nil {
		// Ak Redis nedostupný, povol akciu
		return true
	}

	if count >= limit {
		return false
	}

	// Increment a nastaviť expiry
	h.redis.Incr(context.Background(), key)
	h.redis.Expire(context.Background(), key, duration)
	return true
}

func (h *Handler) getCollectSuccessChance(rarity string) float64 {
	switch rarity {
	case "common":
		return 0.9 // 90%
	case "rare":
		return 0.7 // 70%
	case "epic":
		return 0.5 // 50%
	case "legendary":
		return 0.3 // 30%
	default:
		return 0.8
	}
}

func (h *Handler) calculateXP(rarity string) int {
	switch rarity {
	case "common":
		return 10
	case "rare":
		return 25
	case "epic":
		return 50
	case "legendary":
		return 100
	default:
		return 15
	}
}

// ============================================
// UTILITY FUNCTIONS
// ============================================

func calculateDistance(lat1, lon1, lat2, lon2 float64) float64 {
	// Haversine formula
	dlat := (lat2 - lat1) * (math.Pi / 180.0)
	dlon := (lon2 - lon1) * (math.Pi / 180.0)

	a := math.Sin(dlat/2)*math.Sin(dlat/2) + math.Cos(lat1*(math.Pi/180.0))*math.Cos(lat2*(math.Pi/180.0))*math.Sin(dlon/2)*math.Sin(dlon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return EarthRadiusKm * c * 1000 // vracia v metroch
}

func isValidGPSCoordinate(lat, lng float64) bool {
	return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
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

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
