package game

import (
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

	// ✅ NEW: TTL info for zones with ExpiresAt
	if zone.ExpiresAt != nil {
		expiry := zone.ExpiresAt.Unix()
		details.ExpiresAt = &expiry

		timeLeft := zone.TimeUntilExpiry()
		if timeLeft > 0 {
			timeLeftStr := FormatDuration(timeLeft)
			details.TimeToExpiry = &timeLeftStr
		}
	}

	return details
}

// ✅ AKTUALIZOVANÉ: Zone radius podľa ZONE TIER, nie player tier
func (h *Handler) calculateZoneRadius(zoneTier int) int {
	// Base radius + random variance pre variety
	baseRadius := h.getBaseRadiusForTier(zoneTier)
	variance := h.getRadiusVarianceForTier(zoneTier)

	// Random radius v rámci range
	minRadius := baseRadius - variance
	maxRadius := baseRadius + variance

	radius := minRadius + rand.Intn(maxRadius-minRadius+1)

	log.Printf("📏 Zone tier %d: radius %dm (range: %d-%dm)", zoneTier, radius, minRadius, maxRadius)
	return radius
}

// ✅ NOVÉ: Base radius podľa zone tier
func (h *Handler) getBaseRadiusForTier(zoneTier int) int {
	switch zoneTier {
	case 0:
		return 200 // Tier 0 zones - 200m base
	case 1:
		return 250 // Tier 1 zones - 250m base
	case 2:
		return 300 // Tier 2 zones - 300m base
	case 3:
		return 350 // Tier 3 zones - 350m base
	case 4:
		return 400 // Tier 4 zones - 400m base
	default:
		return 200 // Default 200m
	}
}

// ✅ NOVÉ: Variance pre natural variety
func (h *Handler) getRadiusVarianceForTier(zoneTier int) int {
	switch zoneTier {
	case 0:
		return 30 // Tier 0: 170-230m range
	case 1:
		return 40 // Tier 1: 210-290m range
	case 2:
		return 50 // Tier 2: 250-350m range
	case 3:
		return 60 // Tier 3: 290-410m range
	case 4:
		return 70 // Tier 4: 330-470m range
	default:
		return 30 // Default variance
	}
}

// ✅ AKTUALIZOVANÉ: Min distance podľa ZONE TIER
func (h *Handler) getMinZoneDistanceForZoneTier(zoneTier int) float64 {
	switch zoneTier {
	case 0:
		return 250.0 // Tier 0 zones - 250m minimum spacing
	case 1:
		return 300.0 // Tier 1 zones - 300m minimum spacing
	case 2:
		return 350.0 // Tier 2 zones - 350m minimum spacing
	case 3:
		return 400.0 // Tier 3 zones - 400m minimum spacing
	case 4:
		return 450.0 // Tier 4 zones - 450m minimum spacing
	default:
		return 250.0 // Default 250m
	}
}

// ✅ AKTUALIZOVANÉ: Collision detection s zone tier
func (h *Handler) isValidZonePositionForTier(lat, lng float64, zoneTier int, existingZones []common.Zone) bool {
	minDistance := h.getMinZoneDistanceForZoneTier(zoneTier)

	for _, zone := range existingZones {
		distance := CalculateDistance(lat, lng, zone.Location.Latitude, zone.Location.Longitude)
		if distance < minDistance {
			log.Printf("🚫 Zone collision: distance %.1fm < minimum %.1fm (zone tier %d)", distance, minDistance, zoneTier)
			return false
		}
	}
	return true
}

// ✅ AKTUALIZOVANÉ: Generate position s zone tier
func (h *Handler) generateValidZonePositionForTier(centerLat, centerLng float64, zoneTier int, existingZones []common.Zone) (float64, float64, bool) {
	minDistance := h.getMinZoneDistanceForZoneTier(zoneTier)
	scanRadius := AreaScanRadius / 1000.0 // Convert to km for GPS calculations

	log.Printf("🎯 Generating zone position (zone tier %d, min distance: %.1fm)", zoneTier, minDistance)

	for attempt := 0; attempt < MaxPositionAttempts; attempt++ {
		// Generate random position within scan radius
		lat, lng := h.generateRandomPosition(centerLat, centerLng, scanRadius*1000) // Convert back to meters

		// Check if position is valid (no collisions)
		if h.isValidZonePositionForTier(lat, lng, zoneTier, existingZones) {
			log.Printf("✅ Valid position found on attempt %d: [%.6f, %.6f] (zone tier %d)", attempt+1, lat, lng, zoneTier)
			return lat, lng, true
		}

		if attempt%10 == 9 { // Log every 10 attempts
			log.Printf("⏳ Position attempt %d/%d failed for zone tier %d - trying again...", attempt+1, MaxPositionAttempts, zoneTier)
		}
	}

	log.Printf("❌ Failed to find valid position after %d attempts (zone tier %d, min distance: %.1fm)", MaxPositionAttempts, zoneTier, minDistance)
	return centerLat, centerLng, false // Fallback to center if no valid position found
}

// ✅ AKTUALIZOVANÉ: Univerzálna distribúcia pre všetkých hráčov
func (h *Handler) generateZoneTier(playerTier int, biome string) int {
	template := GetZoneTemplate(biome)
	minTierForBiome := template.MinTierRequired

	// ✅ UNIVERZÁLNA DISTRIBÚCIA - rovnaká pre všetkých hráčov
	// Zabezpečí dostupnosť zón pre všetky tier úrovne
	weights := map[int]int{
		0: 35, // 35% tier 0 zóny - základný content
		1: 30, // 30% tier 1 zóny - basic content
		2: 20, // 20% tier 2 zóny - intermediate content
		3: 10, // 10% tier 3 zóny - advanced content
		4: 5,  // 5% tier 4 zóny - elite content
	}

	// Filter len dostupné pre biome a player tier
	availableWeights := map[int]int{}
	for tier, weight := range weights {
		// Zóna sa môže spawnovať ak:
		// 1. Spĺňa biome requirements
		// 2. Nepresahuje player tier o viac ako +1
		if tier >= minTierForBiome && tier <= playerTier+1 {
			availableWeights[tier] = weight
		}
	}

	// Special case: Ak hráč nemôže spawnovať nič
	if len(availableWeights) == 0 {
		log.Printf("⚠️ No available zones for player tier %d in biome %s, using min tier %d",
			playerTier, biome, minTierForBiome)
		return minTierForBiome
	}

	// Weighted random selection
	totalWeight := 0
	for _, weight := range availableWeights {
		totalWeight += weight
	}

	roll := rand.Intn(totalWeight)
	current := 0

	for tier, weight := range availableWeights {
		current += weight
		if roll < current {
			log.Printf("🎲 Zone tier %d spawned by player tier %d in %s biome (universal distribution)",
				tier, playerTier, biome)
			return tier
		}
	}

	return minTierForBiome // Fallback
}

func (h *Handler) generateRandomPosition(centerLat, centerLng, radiusMeters float64) (float64, float64) {
	angle := rand.Float64() * 2 * math.Pi
	distance := rand.Float64() * radiusMeters
	earthRadius := 6371000.0

	latOffset := (distance * math.Cos(angle)) / earthRadius * (180 / math.Pi)
	lngOffset := (distance * math.Sin(angle)) / earthRadius * (180 / math.Pi) / math.Cos(centerLat*math.Pi/180)

	return centerLat + latOffset, centerLng + lngOffset
}

// ✅ SIMPLIFIED: Keep only essential functions, remove duplicates
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

// Keep existing biome-specific spawning functions
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
	level := tier + rand.Intn(2) + 1

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
