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

// ✅ NOVÉ: Count len dynamic zóny v spawn area
func (h *Handler) countDynamicZonesInSpawnArea(lat, lng, radiusMeters float64) int {
	zones := h.getExistingZonesInArea(lat, lng, radiusMeters)
	count := 0
	for _, zone := range zones {
		if zone.ZoneType == "dynamic" {
			count++
		}
	}
	log.Printf("📊 Found %d dynamic zones in spawn area (%.0fm radius)", count, radiusMeters)
	return count
}

// ✅ AKTUALIZOVANÉ: Spawn s distance-based tier spawning
func (h *Handler) spawnDynamicZonesInRadius(lat, lng float64, playerTier int, count int, spawnRadius float64, existingZones []common.Zone) []common.Zone {
	var newZones []common.Zone

	log.Printf("🏗️ Spawning %d zones for player tier %d (spawn radius: %.0fm, collision check: %d zones)",
		count, playerTier, spawnRadius, len(existingZones))

	for i := 0; i < count; i++ {
		biome := h.selectBiome(playerTier)
		zoneTier := h.generateZoneTier(playerTier, biome)

		// ✅ NOVÉ: Distance-based tier spawning - nižšie tier blízko, vyššie ďalej
		tierSpawnRadius := h.calculateTierSpawnRadius(zoneTier, spawnRadius)

		// ✅ KĽÚČOVÁ ZMENA: Použiť tier-specific radius namiesto full spawn radius
		zoneLat, zoneLng, positionValid := h.generateValidZonePositionInRadius(lat, lng, zoneTier, tierSpawnRadius, existingZones)
		if !positionValid {
			log.Printf("⚠️ Using fallback position for zone %d (collision detection failed)", i+1)
		}

		// Random TTL between min-max hours (konfigurovateľné)
		minTTL := time.Duration(ZoneMinExpiryHours) * time.Hour
		maxTTL := time.Duration(ZoneMaxExpiryHours) * time.Hour
		ttlRange := maxTTL - minTTL
		randomTTL := minTTL + time.Duration(rand.Float64()*float64(ttlRange))
		expiresAt := time.Now().Add(randomTTL)

		zone := common.Zone{
			BaseModel: common.BaseModel{ID: uuid.New()},
			Name:      h.generateZoneName(biome),
			Location: common.Location{
				Latitude:  zoneLat,
				Longitude: zoneLng,
				Timestamp: time.Now(),
			},
			TierRequired: zoneTier,
			RadiusMeters: h.calculateZoneRadius(zoneTier),
			IsActive:     true,
			ZoneType:     "dynamic",
			Biome:        biome,
			DangerLevel:  GetZoneTemplate(biome).DangerLevel,

			// TTL fields
			ExpiresAt:    &expiresAt,
			LastActivity: time.Now(),
			AutoCleanup:  true,

			Properties: common.JSONB{
				"spawned_by":            "scan_area",
				"ttl_hours":             randomTTL.Hours(),
				"biome":                 biome,
				"danger_level":          GetZoneTemplate(biome).DangerLevel,
				"environmental_effects": GetZoneTemplate(biome).EnvironmentalEffects,
				"zone_template":         "biome_based",
				"collision_detected":    !positionValid,
				"min_distance_enforced": h.getMinZoneDistanceForZoneTier(zoneTier),
				"zone_tier":             zoneTier,
				"player_tier":           playerTier,
				"radius_range":          fmt.Sprintf("%d-%dm", h.getBaseRadiusForTier(zoneTier)-h.getRadiusVarianceForTier(zoneTier), h.getBaseRadiusForTier(zoneTier)+h.getRadiusVarianceForTier(zoneTier)),
				// ✅ NOVÉ: Distance-based spawning info
				"spawn_radius":         spawnRadius,
				"tier_spawn_radius":    tierSpawnRadius,
				"distance_based_tier":  true,
				"tier_distance_system": "close_low_far_high",
				"scan_radius":          AreaScanRadius,
				"spawn_vs_scan_system": true,
			},
		}

		if err := h.db.Create(&zone).Error; err == nil {
			h.spawnItemsInZone(zone.ID, zoneTier, zone.Biome, zone.Location, zone.RadiusMeters)
			newZones = append(newZones, zone)
			existingZones = append(existingZones, zone)

			distanceFromCenter := CalculateDistance(lat, lng, zoneLat, zoneLng)
			log.Printf("🏰 Zone spawned: %s (Tier: %d, Distance: %.0fm/%.0fm, Biome: %s, Radius: %dm)",
				zone.Name, zoneTier, distanceFromCenter, tierSpawnRadius, biome, zone.RadiusMeters)
		} else {
			log.Printf("❌ Failed to create zone: %v", err)
		}
	}

	log.Printf("✅ Zone spawning complete: %d/%d zones created with distance-based tiers (spawn radius: %.0fm)",
		len(newZones), count, spawnRadius)
	return newZones
}

// ✅ NOVÉ: Generate position v obmedzeném radius
func (h *Handler) generateValidZonePositionInRadius(centerLat, centerLng float64, zoneTier int, maxRadius float64, existingZones []common.Zone) (float64, float64, bool) {
	minDistance := h.getMinZoneDistanceForZoneTier(zoneTier)

	log.Printf("🎯 Generating zone position (zone tier %d, spawn radius: %.0fm, min distance: %.1fm)",
		zoneTier, maxRadius, minDistance)

	for attempt := 0; attempt < MaxPositionAttempts; attempt++ {
		// ✅ KĽÚČOVÁ ZMENA: Obmedz na spawn radius
		lat, lng := h.generateRandomPosition(centerLat, centerLng, maxRadius)

		if h.isValidZonePositionForTier(lat, lng, zoneTier, existingZones) {
			distanceFromCenter := CalculateDistance(centerLat, centerLng, lat, lng)
			log.Printf("✅ Valid position found on attempt %d: [%.6f, %.6f] (%.0fm from center)",
				attempt+1, lat, lng, distanceFromCenter)
			return lat, lng, true
		}

		if attempt%10 == 9 {
			log.Printf("⏳ Position attempt %d/%d failed in spawn radius - trying again...", attempt+1, MaxPositionAttempts)
		}
	}

	log.Printf("❌ Failed to find valid position in spawn radius (%.0fm) after %d attempts", maxRadius, MaxPositionAttempts)
	return centerLat, centerLng, false
}

// ✅ NOVÉ: Calculate tier-specific spawn radius (blízko = nízky tier, ďaleko = vysoký tier)
func (h *Handler) calculateTierSpawnRadius(zoneTier int, maxSpawnRadius float64) float64 {
	// ⚙️ KONFIGUROVATEĽNÉ NASTAVENIA - zmena týchto hodnôt ovplyvní spawn distances
	tierDistanceRanges := map[int][2]float64{
		// Format: tier: {min_percentage, max_percentage} z maxSpawnRadius
		0: {0.15, 0.35}, // Tier 0: 15-35% (300-700m z 2000m) - NAJBLIŽŠIE pre začiatočníkov
		1: {0.25, 0.50}, // Tier 1: 25-50% (500-1000m z 2000m) - BLÍZKO-STRED
		2: {0.40, 0.70}, // Tier 2: 40-70% (800-1400m z 2000m) - STRED
		3: {0.60, 0.85}, // Tier 3: 60-85% (1200-1700m z 2000m) - ĎALEKO
		4: {0.75, 1.00}, // Tier 4: 75-100% (1500-2000m z 2000m) - NAJĎALEJ pre elite
	}

	// 📝 POZNÁMKA: Ak chceš zmeniť vzdialenosti:
	// - Zmenš percentá = zóny bližšie k hráčovi
	// - Zväčši percentá = zóny ďalej od hráča
	// - Zmenš range = konzistentnejšie vzdialenosti
	// - Zväčši range = väčšia variety vo vzdialenostiach

	// Get range for this tier (fallback to tier 2 if unknown tier)
	distRange, exists := tierDistanceRanges[zoneTier]
	if !exists {
		distRange = tierDistanceRanges[2] // Default to tier 2 range
		log.Printf("⚠️ Unknown tier %d, using tier 2 distance range", zoneTier)
	}

	// Calculate actual distances in meters
	minDistance := distRange[0] * maxSpawnRadius
	maxDistance := distRange[1] * maxSpawnRadius

	// Random distance within tier range
	randomDistance := minDistance + rand.Float64()*(maxDistance-minDistance)

	log.Printf("🎯 Tier %d spawn distance: %.0fm (range: %.0f-%.0fm, %.1f%%-%.1f%% of max)",
		zoneTier, randomDistance, minDistance, maxDistance,
		distRange[0]*100, distRange[1]*100)

	return randomDistance
}
