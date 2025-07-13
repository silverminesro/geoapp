package zones

import (
	"fmt"
	"log"
	"math"
	"math/rand"
	"time"

	"geoanomaly/internal/common"
	// ❌ VYMAZANÉ: "geoanomaly/internal/game"

	"github.com/google/uuid"
)

// ✅ PRIDANÉ: Konstanty priamo do spawning.go
const (
	// Biome constants
	BiomeForest      = "forest"
	BiomeMountain    = "mountain"
	BiomeIndustrial  = "industrial"
	BiomeUrban       = "urban"
	BiomeWater       = "water"
	BiomeRadioactive = "radioactive"
	BiomeChemical    = "chemical"

	// Danger level constants
	DangerLow     = "low"
	DangerMedium  = "medium"
	DangerHigh    = "high"
	DangerExtreme = "extreme"

	// Zone constants
	AreaScanRadius     = 7000.0 // 7km radius
	ZoneMinExpiryHours = 10     // minimum 10 hours
	ZoneMaxExpiryHours = 24     // maximum 24 hours
)

// ✅ PRIDANÉ: Zone template type
type ZoneTemplate struct {
	Names                []string               `json:"names"`
	Biome                string                 `json:"biome"`
	DangerLevel          string                 `json:"danger_level"`
	MinTierRequired      int                    `json:"min_tier_required"`
	AllowedArtifacts     []string               `json:"allowed_artifacts"`
	ExclusiveArtifacts   []string               `json:"exclusive_artifacts"`
	ArtifactSpawnRates   map[string]float64     `json:"artifact_spawn_rates"`
	GearSpawnRates       map[string]float64     `json:"gear_spawn_rates"`
	EnvironmentalEffects map[string]interface{} `json:"environmental_effects"`
}

// ✅ STALKER-STYLE BIOME TEMPLATES (updated to use local constants)
var zoneTemplates = map[string]ZoneTemplate{
	BiomeForest: {
		Names: []string{
			"Whispering Woods", "Dark Pine Forest", "Birch Grove", "Old Growth Forest",
			"Misty Woodland", "Silent Thicket", "Abandoned Logging Camp", "Hunter's Rest",
			"Tainted Grove", "Cursed Forest", "Dead Tree Valley", "Wolf's Den",
			"Moss-Covered Ruins", "Fungal Forest", "Rotten Swamp", "Beast Territory",
		},
		Biome:            BiomeForest,
		DangerLevel:      DangerLow,
		MinTierRequired:  0,
		AllowedArtifacts: []string{"mushroom_sample", "tree_resin", "animal_bones", "herbal_extract", "old_coin"},
		ArtifactSpawnRates: map[string]float64{
			"mushroom_sample": 0.8,
			"tree_resin":      0.6,
			"animal_bones":    0.4,
			"herbal_extract":  0.5,
			"old_coin":        0.3,
		},
		GearSpawnRates: map[string]float64{
			"hunting_knife": 0.4,
			"leather_boots": 0.5,
			"wooden_bow":    0.3,
		},
		EnvironmentalEffects: map[string]interface{}{
			"fog":          true,
			"wild_animals": true,
			"thick_canopy": true,
		},
	},

	BiomeMountain: {
		Names: []string{
			"Rocky Peaks", "Abandoned Mine", "Mountain Pass", "Highland Plateau",
			"Glacier Valley", "Stone Quarry", "Alpine Meadow", "Cave System",
			"Frozen Peak", "Avalanche Zone", "Mining Shaft", "Crystal Cave",
			"Cliff Face", "Ice Fields", "Boulder Field", "Echo Chamber",
		},
		Biome:            BiomeMountain,
		DangerLevel:      DangerMedium,
		MinTierRequired:  1,
		AllowedArtifacts: []string{"mineral_ore", "crystal_shard", "stone_tablet", "mountain_herb", "ice_crystal"},
		ArtifactSpawnRates: map[string]float64{
			"mineral_ore":   0.7,
			"crystal_shard": 0.5,
			"stone_tablet":  0.3,
			"mountain_herb": 0.4,
			"ice_crystal":   0.2,
		},
		GearSpawnRates: map[string]float64{
			"climbing_gear": 0.6,
			"winter_coat":   0.4,
			"pickaxe":       0.3,
		},
		EnvironmentalEffects: map[string]interface{}{
			"altitude_sickness": true,
			"cold_weather":      true,
			"unstable_terrain":  true,
		},
	},

	BiomeIndustrial: {
		Names: []string{
			"Abandoned Factory", "Chemical Plant", "Power Station", "Scrapyard",
			"Oil Refinery", "Steel Mill", "Warehouse District", "Train Depot",
			"Rust Zone", "Machinery Graveyard", "Toxic Facility", "Electrical Substation",
			"Assembly Line", "Cooling Tower", "Furnace Room", "Pipeline Junction",
		},
		Biome:            BiomeIndustrial,
		DangerLevel:      DangerHigh,
		MinTierRequired:  2,
		AllowedArtifacts: []string{"steel_ingot", "chemical_sample", "machinery_parts", "electronic_component", "toxic_waste"},
		ArtifactSpawnRates: map[string]float64{
			"steel_ingot":          0.6,
			"chemical_sample":      0.4,
			"machinery_parts":      0.5,
			"electronic_component": 0.3,
			"toxic_waste":          0.2,
		},
		GearSpawnRates: map[string]float64{
			"hard_hat":      0.5,
			"safety_gloves": 0.4,
			"welding_mask":  0.3,
		},
		EnvironmentalEffects: map[string]interface{}{
			"toxic_air":         true,
			"radiation_low":     true,
			"structural_damage": true,
		},
	},

	BiomeUrban: {
		Names: []string{
			"Ghost Town", "Subway Tunnels", "Ruined Hospital", "School Complex",
			"Shopping District", "Residential Block", "Office Building", "Police Station",
			"Empty Mall", "Parking Garage", "Abandoned Metro", "Rooftop Garden",
			"City Hall", "Library Ruins", "Apartment Complex", "Market Square",
		},
		Biome:            BiomeUrban,
		DangerLevel:      DangerMedium,
		MinTierRequired:  1,
		AllowedArtifacts: []string{"old_documents", "medical_supplies", "electronics", "urban_artifact", "cash_register"},
		ArtifactSpawnRates: map[string]float64{
			"old_documents":    0.5,
			"medical_supplies": 0.3,
			"electronics":      0.4,
			"urban_artifact":   0.2,
			"cash_register":    0.1,
		},
		GearSpawnRates: map[string]float64{
			"flashlight":    0.6,
			"first_aid_kit": 0.4,
			"crowbar":       0.3,
		},
		EnvironmentalEffects: map[string]interface{}{
			"unstable_buildings": true,
			"debris":             true,
			"darkness":           true,
		},
	},

	BiomeWater: {
		Names: []string{
			"Contaminated Lake", "Swamp Lands", "River Delta", "Flooded Quarry",
			"Toxic Pond", "Marsh Area", "Abandoned Pier", "Water Treatment Plant",
			"Algae Bloom", "Sunken Village", "Wetland Preserve", "Drainage Canal",
			"Boat Graveyard", "Muddy Banks", "Stagnant Pool", "Overflow Channel",
		},
		Biome:            BiomeWater,
		DangerLevel:      DangerMedium,
		MinTierRequired:  1,
		AllowedArtifacts: []string{"water_sample", "aquatic_plant", "filtered_water", "swamp_gas", "algae_biomass"},
		ArtifactSpawnRates: map[string]float64{
			"water_sample":   0.6,
			"aquatic_plant":  0.4,
			"filtered_water": 0.3,
			"swamp_gas":      0.2,
			"algae_biomass":  0.3,
		},
		GearSpawnRates: map[string]float64{
			"waders":         0.5,
			"fishing_gear":   0.4,
			"water_purifier": 0.2,
		},
		EnvironmentalEffects: map[string]interface{}{
			"contaminated_water": true,
			"slippery_terrain":   true,
			"methane_gas":        true,
		},
	},

	BiomeRadioactive: {
		Names: []string{
			"Nuclear Facility", "Reactor Core", "Contamination Zone", "Hot Zone",
			"Radiation Field", "Exclusion Zone", "Fallout Shelter", "Atomic Testing Ground",
			"Waste Storage", "Decontamination Site", "Geiger Memorial", "Uranium Mine",
			"Cooling Pool", "Control Room", "Ventilation Shaft", "Emergency Bunker",
		},
		Biome:              BiomeRadioactive,
		DangerLevel:        DangerExtreme,
		MinTierRequired:    3,
		AllowedArtifacts:   []string{"uranium_ore", "radiation_detector", "contaminated_soil", "atomic_battery", "nuclear_fuel"},
		ExclusiveArtifacts: []string{"plutonium_core", "reactor_fragment", "control_rod"},
		ArtifactSpawnRates: map[string]float64{
			"uranium_ore":        0.4,
			"radiation_detector": 0.3,
			"contaminated_soil":  0.5,
			"atomic_battery":     0.2,
			"plutonium_core":     0.1,
			"reactor_fragment":   0.05,
		},
		GearSpawnRates: map[string]float64{
			"hazmat_suit":     0.3,
			"geiger_counter":  0.4,
			"radiation_pills": 0.2,
		},
		EnvironmentalEffects: map[string]interface{}{
			"radiation_high":  true,
			"decontamination": true,
			"mutation_risk":   true,
		},
	},

	BiomeChemical: {
		Names: []string{
			"Chemical Spill Site", "Toxic Waste Dump", "Lab Complex", "Hazmat Zone",
			"Poison Gas Area", "Acid Rain Zone", "Mutant Laboratory", "Biohazard Facility",
			"Synthesis Plant", "Pesticide Factory", "Pharmaceutical Lab", "Cleanup Site",
			"Reaction Chamber", "Distillation Unit", "Storage Tank", "Ventilation System",
		},
		Biome:              BiomeChemical,
		DangerLevel:        DangerExtreme,
		MinTierRequired:    4,
		AllowedArtifacts:   []string{"chemical_compound", "lab_equipment", "toxic_sample", "hazmat_suit", "catalyst"},
		ExclusiveArtifacts: []string{"pure_toxin", "experimental_serum", "bio_weapon"},
		ArtifactSpawnRates: map[string]float64{
			"chemical_compound":  0.5,
			"lab_equipment":      0.3,
			"toxic_sample":       0.4,
			"pure_toxin":         0.05,
			"experimental_serum": 0.03,
			"bio_weapon":         0.01,
		},
		GearSpawnRates: map[string]float64{
			"gas_mask":      0.4,
			"chemical_suit": 0.3,
			"neutralizer":   0.2,
		},
		EnvironmentalEffects: map[string]interface{}{
			"toxic_gas":        true,
			"chemical_burns":   true,
			"corrosive_damage": true,
		},
	},
}

// ✅ UPDATED: Zone creation s biome system (using local constants)
func (h *Handler) SpawnDynamicZones(centerLat, centerLng float64, playerTier, count int) []common.Zone {
	var zones []common.Zone

	log.Printf("🏗️ Starting STALKER zone creation: lat=%.6f, lng=%.6f, tier=%d, count=%d", centerLat, centerLng, playerTier, count)

	// Get available biomes for player tier
	availableBiomes := h.getAvailableBiomes(playerTier)
	log.Printf("🎯 Available biomes for tier %d: %v", playerTier, availableBiomes)

	for i := 0; i < count; i++ {
		// Select random biome
		biome := availableBiomes[rand.Intn(len(availableBiomes))]
		template := zoneTemplates[biome]

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
			Description:  fmt.Sprintf("STALKER %s zone - %s danger level", template.Biome, template.DangerLevel),
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

	log.Printf("🎯 STALKER zone creation completed: %d/%d zones created successfully", len(zones), count)
	return zones
}

// ✅ NEW: Get available biomes based on player tier (using local constants)
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

// ✅ Zone limits for freemium model
func (h *Handler) CalculateMaxZones(playerTier int) int {
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

func (h *Handler) CountDynamicZonesInArea(lat, lng, radiusMeters float64) int {
	zones := h.GetExistingZonesInArea(lat, lng, radiusMeters)
	count := 0
	for _, zone := range zones {
		if zone.ZoneType == "dynamic" {
			count++
		}
	}
	return count
}

// ✅ UPDATED: Better zone tier assignment with biome minimum
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

// ✅ FIXED: Guaranteed artifact spawning with biome-specific items
func (h *Handler) spawnBiomeSpecificItems(zoneID uuid.UUID, biome string, tier int) {
	template := zoneTemplates[biome]

	log.Printf("🎁 Spawning biome-specific items for %s zone %s (tier %d)", biome, zoneID, tier)

	// ✅ GUARANTEED: Spawn 2-4 regular artifacts
	minArtifacts := 2
	maxArtifacts := 4
	artifactCount := rand.Intn(maxArtifacts-minArtifacts+1) + minArtifacts // 2-4 artifacts

	log.Printf("🎯 Planning to spawn %d artifacts (guaranteed minimum %d)", artifactCount, minArtifacts)

	// Get available artifact types
	availableArtifacts := make([]string, 0)
	for artifactType := range template.ArtifactSpawnRates {
		availableArtifacts = append(availableArtifacts, artifactType)
	}

	// ✅ SPAWN GUARANTEED ARTIFACTS with retry logic
	successfulArtifacts := 0
	for i := 0; i < artifactCount && len(availableArtifacts) > 0; i++ {
		// Pick random artifact type
		artifactType := availableArtifacts[rand.Intn(len(availableArtifacts))]

		if err := h.spawnSpecificArtifact(zoneID, artifactType, biome, tier); err != nil {
			log.Printf("⚠️ Failed to spawn %s artifact: %v", artifactType, err)

			// ✅ RETRY: Try different artifact if first fails
			for retry := 0; retry < 3 && len(availableArtifacts) > 0; retry++ {
				retryArtifact := availableArtifacts[rand.Intn(len(availableArtifacts))]
				if err := h.spawnSpecificArtifact(zoneID, retryArtifact, biome, tier); err == nil {
					successfulArtifacts++
					log.Printf("✅ Successfully spawned %s artifact (retry %d)", retryArtifact, retry+1)
					break
				}
			}
		} else {
			successfulArtifacts++
			log.Printf("✅ Successfully spawned %s artifact", artifactType)
		}
	}

	// ✅ ENSURE: At least 1 artifact spawned (fallback)
	if successfulArtifacts == 0 && len(availableArtifacts) > 0 {
		log.Printf("⚠️ No artifacts spawned, forcing spawn of basic artifact")
		basicArtifact := availableArtifacts[0] // Take first available artifact
		if err := h.spawnSpecificArtifact(zoneID, basicArtifact, biome, tier); err != nil {
			log.Printf("❌ Failed to force spawn basic artifact: %v", err)
		} else {
			log.Printf("✅ Force spawned basic %s artifact", basicArtifact)
		}
	}

	// ✅ EXCLUSIVE ARTIFACTS: Higher chance (30% instead of 10%)
	for _, exclusive := range template.ExclusiveArtifacts {
		if rand.Float64() < 0.3 { // ✅ INCREASED: 30% chance for exclusive
			if err := h.spawnSpecificArtifact(zoneID, exclusive, biome, tier); err != nil {
				log.Printf("⚠️ Failed to spawn exclusive %s artifact: %v", exclusive, err)
			} else {
				log.Printf("✅ Successfully spawned exclusive %s artifact", exclusive)
			}
		}
	}

	// ✅ GEAR SPAWNING: Optional (0-3 gear items)
	gearCount := rand.Intn(4) // 0-3 gear (can be 0)
	log.Printf("🎯 Planning to spawn %d gear items (can be 0)", gearCount)

	// Get available gear types
	availableGear := make([]string, 0)
	for gearType := range template.GearSpawnRates {
		availableGear = append(availableGear, gearType)
	}

	// Spawn gear with higher rates
	for i := 0; i < gearCount && len(availableGear) > 0; i++ {
		gearType := availableGear[rand.Intn(len(availableGear))]
		if err := h.spawnSpecificGear(zoneID, gearType, biome, tier); err != nil {
			log.Printf("⚠️ Failed to spawn %s gear: %v", gearType, err)
		} else {
			log.Printf("✅ Successfully spawned %s gear", gearType)
		}
	}
}

// ✅ NEW: Spawn specific artifact type
func (h *Handler) spawnSpecificArtifact(zoneID uuid.UUID, artifactType, biome string, tier int) error {
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return err
	}

	// Get display name and rarity for this artifact type
	displayName := h.getArtifactDisplayName(artifactType)
	rarity := h.getArtifactRarity(artifactType, tier)

	lat, lng := h.generateRandomPosition(zone.Location.Latitude, zone.Location.Longitude, float64(zone.RadiusMeters))

	artifact := common.Artifact{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      displayName,
		Type:      artifactType,
		Rarity:    rarity,
		Biome:     biome, // ✅ PRIDANÉ: Biome field
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

// ✅ NEW: Spawn specific gear type
func (h *Handler) spawnSpecificGear(zoneID uuid.UUID, gearType, biome string, tier int) error {
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return err
	}

	// Get display name for this gear type
	displayName := h.getGearDisplayName(gearType)
	level := tier + rand.Intn(2) // Level can be tier or tier+1

	lat, lng := h.generateRandomPosition(zone.Location.Latitude, zone.Location.Longitude, float64(zone.RadiusMeters))

	gear := common.Gear{
		BaseModel: common.BaseModel{ID: uuid.New()},
		ZoneID:    zoneID,
		Name:      displayName,
		Type:      gearType,
		Level:     level,
		Biome:     biome, // ✅ PRIDANÉ: Biome field
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

// ✅ NEW: Get artifact display name
func (h *Handler) getArtifactDisplayName(artifactType string) string {
	displayNames := map[string]string{
		"mushroom_sample":      "Mutant Mushroom Sample",
		"tree_resin":           "Amber Tree Resin",
		"animal_bones":         "Predator Bones",
		"herbal_extract":       "Healing Herb Extract",
		"mineral_ore":          "Rare Mineral Ore",
		"crystal_shard":        "Energy Crystal Shard",
		"stone_tablet":         "Ancient Stone Tablet",
		"mountain_herb":        "Alpine Medicinal Herb",
		"steel_ingot":          "Military Steel Ingot",
		"chemical_sample":      "Unknown Chemical Sample",
		"machinery_parts":      "Industrial Machinery Parts",
		"electronic_component": "Advanced Electronic Component",
		"old_documents":        "Pre-War Documents",
		"medical_supplies":     "Medical Emergency Kit",
		"electronics":          "Salvaged Electronics",
		"urban_artifact":       "City Historical Artifact",
		"water_sample":         "Contaminated Water Sample",
		"aquatic_plant":        "Mutant Aquatic Plant",
		"filtered_water":       "Purified Water Container",
		"swamp_gas":            "Methane Gas Canister",
		"uranium_ore":          "Uranium Ore Fragment",
		"radiation_detector":   "Geiger Counter Device",
		"contaminated_soil":    "Radioactive Soil Sample",
		"atomic_battery":       "Nuclear Battery Cell",
		"plutonium_core":       "Plutonium Reactor Core",
		"reactor_fragment":     "Reactor Core Fragment",
		"chemical_compound":    "Experimental Chemical Compound",
		"lab_equipment":        "Laboratory Equipment",
		"toxic_sample":         "Hazardous Toxic Sample",
		"pure_toxin":           "Pure Concentrated Toxin",
		"experimental_serum":   "Experimental Bio-Serum",
		"old_coin":             "Pre-War Coin",
	}

	if name, exists := displayNames[artifactType]; exists {
		return name
	}
	return artifactType
}

// ✅ NEW: Get gear display name
func (h *Handler) getGearDisplayName(gearType string) string {
	displayNames := map[string]string{
		"hunting_knife":   "Survival Hunting Knife",
		"leather_boots":   "Leather Combat Boots",
		"wooden_bow":      "Wooden Hunting Bow",
		"climbing_gear":   "Mountain Climbing Gear",
		"winter_coat":     "Insulated Winter Coat",
		"pickaxe":         "Mining Pickaxe",
		"hard_hat":        "Industrial Hard Hat",
		"safety_gloves":   "Chemical Safety Gloves",
		"welding_mask":    "Protective Welding Mask",
		"flashlight":      "Tactical Flashlight",
		"first_aid_kit":   "Combat First Aid Kit",
		"crowbar":         "Steel Crowbar",
		"waders":          "Waterproof Waders",
		"fishing_gear":    "Survival Fishing Kit",
		"water_purifier":  "Portable Water Purifier",
		"hazmat_suit":     "Full Hazmat Suit",
		"geiger_counter":  "Radiation Detector",
		"radiation_pills": "Anti-Radiation Pills",
		"gas_mask":        "Military Gas Mask",
		"chemical_suit":   "Chemical Protection Suit",
		"neutralizer":     "Chemical Neutralizer",
	}

	if name, exists := displayNames[gearType]; exists {
		return name
	}
	return gearType
}

// ✅ NEW: Get artifact rarity based on type and tier
func (h *Handler) getArtifactRarity(artifactType string, tier int) string {
	// Exclusive artifacts are always rare+
	exclusiveArtifacts := []string{"plutonium_core", "reactor_fragment", "pure_toxin", "experimental_serum", "bio_weapon"}
	for _, exclusive := range exclusiveArtifacts {
		if artifactType == exclusive {
			return "legendary"
		}
	}

	// High-tier artifacts
	highTierArtifacts := []string{"uranium_ore", "chemical_compound", "atomic_battery"}
	for _, highTier := range highTierArtifacts {
		if artifactType == highTier {
			if tier >= 3 {
				return "epic"
			}
			return "rare"
		}
	}

	// Medium-tier artifacts
	mediumTierArtifacts := []string{"crystal_shard", "steel_ingot", "electronics"}
	for _, mediumTier := range mediumTierArtifacts {
		if artifactType == mediumTier {
			if tier >= 2 {
				return "rare"
			}
			return "common"
		}
	}

	// Default to common
	return "common"
}
