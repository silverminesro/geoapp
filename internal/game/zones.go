package game

import (
	"fmt"
	"log"
	"math"
	"math/rand"
	"time"

	"geoanomaly/internal/common"

	"github.com/google/uuid"
)

// Zone management functions
func (h *Handler) getExistingZonesInArea(lat, lng, radiusMeters float64) []common.Zone {
	var zones []common.Zone

	if err := h.db.Where("is_active = true").Find(&zones).Error; err != nil {
		log.Printf("❌ Failed to query zones: %v", err)
		return []common.Zone{}
	}

	// Manual distance filtering
	var filteredZones []common.Zone
	for _, zone := range zones {
		distance := CalculateDistance(lat, lng, zone.Location.Latitude, zone.Location.Longitude)
		if distance <= radiusMeters {
			filteredZones = append(filteredZones, zone)
		}
	}

	log.Printf("📍 Found %d zones in area (radius: %.0fm)", len(filteredZones), radiusMeters)
	return filteredZones
}

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

func (h *Handler) buildZoneDetails(zone common.Zone, playerLat, playerLng float64, playerTier int) ZoneWithDetails {
	distance := CalculateDistance(playerLat, playerLng, zone.Location.Latitude, zone.Location.Longitude)

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
		Biome:           zone.Biome,
		DangerLevel:     zone.DangerLevel,
	}

	// Expiry info pre dynamic zones
	if zone.ZoneType == "dynamic" {
		if expiryTime, exists := zone.Properties["expires_at"]; exists {
			if expiryTimestamp, ok := expiryTime.(float64); ok {
				expiry := int64(expiryTimestamp)
				details.ExpiresAt = &expiry

				timeLeft := time.Until(time.Unix(expiry, 0))
				if timeLeft > 0 {
					timeLeftStr := FormatDuration(timeLeft)
					details.TimeToExpiry = &timeLeftStr
				}
			}
		}
	}

	return details
}

// Zone spawning functions
func (h *Handler) spawnDynamicZones(centerLat, centerLng float64, playerTier, count int) []common.Zone {
	var zones []common.Zone

	log.Printf("🏗️ Starting zone creation: lat=%.6f, lng=%.6f, tier=%d, count=%d", centerLat, centerLng, playerTier, count)

	// Get available biomes for player tier
	availableBiomes := h.getAvailableBiomes(playerTier)
	log.Printf("🎯 Available biomes for tier %d: %v", playerTier, availableBiomes)

	for i := 0; i < count; i++ {
		// Select random biome
		biome := availableBiomes[rand.Intn(len(availableBiomes))]
		template := GetZoneTemplate(biome)

		// Select random name from template
		zoneName := template.Names[rand.Intn(len(template.Names))]

		// Random pozícia v rámci 7km
		lat, lng := h.generateRandomPosition(centerLat, centerLng, AreaScanRadius)
		zoneTier := h.calculateZoneTier(playerTier, template.MinTierRequired)

		// Expiry time
		expiryHours := ZoneMinExpiryHours + rand.Intn(ZoneMaxExpiryHours-ZoneMinExpiryHours+1)
		expiryTime := time.Now().Add(time.Duration(expiryHours) * time.Hour)

		zone := common.Zone{
			BaseModel:    common.BaseModel{ID: uuid.New()},
			Name:         fmt.Sprintf("%s (T%d)", zoneName, zoneTier),
			Description:  fmt.Sprintf("%s zone - %s danger level", template.Biome, template.DangerLevel),
			RadiusMeters: h.calculateZoneRadius(zoneTier),
			TierRequired: zoneTier,
			Location: common.Location{
				Latitude:  lat,
				Longitude: lng,
				Timestamp: time.Now(),
			},
			ZoneType:    "dynamic",
			Biome:       biome,
			DangerLevel: template.DangerLevel,
			Properties: common.JSONB{
				"spawned_by":            "player_scan",
				"expires_at":            expiryTime.Unix(),
				"spawn_tier":            playerTier,
				"despawn_reason":        "timer",
				"created_at":            time.Now().Unix(),
				"zone_type":             "dynamic",
				"zone_category":         h.getZoneCategory(zoneTier),
				"biome":                 biome,
				"danger_level":          template.DangerLevel,
				"environmental_effects": template.EnvironmentalEffects,
			},
			IsActive: true,
		}

		log.Printf("💾 Creating %s zone %d: %s at [%.6f, %.6f]", biome, i+1, zone.Name, lat, lng)

		if err := h.db.Create(&zone).Error; err != nil {
			log.Printf("❌ Failed to create zone %s: %v", zone.Name, err)
			continue
		}

		log.Printf("✅ Zone created successfully: %s (ID: %s)", zone.Name, zone.ID)

		// Spawn biome-specific items
		h.spawnBiomeSpecificItems(zone.ID, biome, zoneTier)

		zones = append(zones, zone)
	}

	log.Printf("🎯 Zone creation completed: %d/%d zones created successfully", len(zones), count)
	return zones
}

func (h *Handler) getAvailableBiomes(playerTier int) []string {
	biomes := []string{BiomeForest} // Forest always available

	if playerTier >= 1 {
		biomes = append(biomes, BiomeMountain, BiomeUrban, BiomeWater)
	}
	if playerTier >= 2 {
		biomes = append(biomes, BiomeIndustrial)
	}
	if playerTier >= 3 {
		biomes = append(biomes, BiomeRadioactive)
	}
	if playerTier >= 4 {
		biomes = append(biomes, BiomeChemical)
	}

	return biomes
}

func (h *Handler) calculateZoneTier(playerTier, biomeMinTier int) int {
	// Start with higher of player tier or biome minimum
	baseTier := int(math.Max(float64(playerTier), float64(biomeMinTier)))

	// 70% chance for base tier, 30% for +1 tier
	if rand.Float64() < 0.7 {
		return baseTier
	}
	// +1 tier but max 4
	return int(math.Min(4, float64(baseTier+1)))
}

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
		return 100
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

func (h *Handler) spawnBiomeSpecificItems(zoneID uuid.UUID, biome string, tier int) {
	template := GetZoneTemplate(biome)

	log.Printf("🎁 Spawning biome-specific items for %s zone %s (tier %d)", biome, zoneID, tier)

	// Spawn 2-4 artifacts
	minArtifacts := 2
	maxArtifacts := 4
	artifactCount := rand.Intn(maxArtifacts-minArtifacts+1) + minArtifacts

	availableArtifacts := make([]string, 0)
	for artifactType := range template.ArtifactSpawnRates {
		availableArtifacts = append(availableArtifacts, artifactType)
	}

	// Spawn guaranteed artifacts
	for i := 0; i < artifactCount && len(availableArtifacts) > 0; i++ {
		artifactType := availableArtifacts[rand.Intn(len(availableArtifacts))]
		if err := h.spawnSpecificArtifact(zoneID, artifactType, biome, tier); err != nil {
			log.Printf("⚠️ Failed to spawn %s artifact: %v", artifactType, err)
		}
	}

	// Spawn exclusive artifacts
	for _, exclusive := range template.ExclusiveArtifacts {
		if rand.Float64() < 0.3 {
			h.spawnSpecificArtifact(zoneID, exclusive, biome, tier)
		}
	}

	// Spawn gear
	gearCount := rand.Intn(4)
	availableGear := make([]string, 0)
	for gearType := range template.GearSpawnRates {
		availableGear = append(availableGear, gearType)
	}

	for i := 0; i < gearCount && len(availableGear) > 0; i++ {
		gearType := availableGear[rand.Intn(len(availableGear))]
		h.spawnSpecificGear(zoneID, gearType, biome, tier)
	}
}

func (h *Handler) spawnSpecificArtifact(zoneID uuid.UUID, artifactType, biome string, tier int) error {
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return err
	}

	displayName := GetArtifactDisplayName(artifactType)
	rarity := GetArtifactRarity(artifactType, tier)

	lat, lng := h.generateRandomPosition(zone.Location.Latitude, zone.Location.Longitude, float64(zone.RadiusMeters))

	artifact := common.Artifact{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      displayName,
		Type:      artifactType,
		Rarity:    rarity,
		Biome:     biome,
		Location: common.Location{
			Latitude:  lat,
			Longitude: lng,
			Timestamp: time.Now(),
		},
		Properties: common.JSONB{
			"spawn_time":   time.Now().Unix(),
			"spawner":      "biome_specific",
			"zone_tier":    tier,
			"biome":        biome,
			"spawn_reason": "zone_creation",
		},
		IsActive: true,
	}

	return h.db.Create(&artifact).Error
}

func (h *Handler) spawnSpecificGear(zoneID uuid.UUID, gearType, biome string, tier int) error {
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return err
	}

	displayName := GetGearDisplayName(gearType)
	level := tier + rand.Intn(2)

	lat, lng := h.generateRandomPosition(zone.Location.Latitude, zone.Location.Longitude, float64(zone.RadiusMeters))

	gear := common.Gear{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      displayName,
		Type:      gearType,
		Level:     level,
		Biome:     biome,
		Location: common.Location{
			Latitude:  lat,
			Longitude: lng,
			Timestamp: time.Now(),
		},
		Properties: common.JSONB{
			"spawn_time":   time.Now().Unix(),
			"spawner":      "biome_specific",
			"zone_tier":    tier,
			"biome":        biome,
			"spawn_reason": "zone_creation",
		},
		IsActive: true,
	}

	return h.db.Create(&gear).Error
}
