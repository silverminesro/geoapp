package game

import "geoanomaly/internal/common"

// Artifact display names
func GetArtifactDisplayName(artifactType string) string {
	displayNames := map[string]string{
		// Forest artifacts
		"mushroom_sample": "Mutant Mushroom Sample",
		"tree_resin":      "Amber Tree Resin",
		"animal_bones":    "Predator Bones",
		"herbal_extract":  "Healing Herb Extract",
		"dewdrop_pearl":   "Dewdrop Pearl",

		// Mountain artifacts
		"mineral_ore":   "Rare Mineral Ore",
		"crystal_shard": "Energy Crystal Shard",
		"stone_tablet":  "Ancient Stone Tablet",
		"mountain_herb": "Alpine Medicinal Herb",
		"ice_crystal":   "Frozen Ice Crystal",

		// Industrial artifacts
		"rusty_gear":           "Rusty Gear Relic",
		"chemical_sample":      "Unknown Chemical Sample",
		"machinery_parts":      "Industrial Machinery Parts",
		"electronic_component": "Advanced Electronic Component",
		"toxic_waste":          "Toxic Waste Container",

		// Urban artifacts
		"old_documents":    "Pre-War Documents",
		"medical_supplies": "Medical Emergency Kit",
		"electronics":      "Salvaged Electronics",
		"urban_artifact":   "City Historical Artifact",
		"pocket_radio":     "Pocket Radio Receiver",

		// Water artifacts
		"water_sample":   "Contaminated Water Sample",
		"aquatic_plant":  "Mutant Aquatic Plant",
		"filtered_water": "Purified Water Container",
		"abyss_pearl":    "Abyss Pearl",
		"algae_biomass":  "Toxic Algae Biomass",

		// Radioactive artifacts
		"uranium_ore":        "Uranium Ore Fragment",
		"radiation_detector": "Geiger Counter Device",
		"contaminated_soil":  "Radioactive Soil Sample",
		"atomic_battery":     "Nuclear Battery Cell",
		"nuclear_fuel":       "Spent Nuclear Fuel",

		// Radioactive exclusive
		"plutonium_core":   "Plutonium Reactor Core",
		"reactor_fragment": "Reactor Core Fragment",
		"control_rod":      "Nuclear Control Rod",

		// Chemical artifacts
		"chemical_compound": "Experimental Chemical Compound",
		"lab_equipment":     "Laboratory Equipment",
		"toxic_sample":      "Hazardous Toxic Sample",
		"hazmat_suit":       "Professional Hazmat Suit",
		"catalyst":          "Chemical Catalyst",

		// Chemical exclusive
		"pure_toxin":         "Pure Concentrated Toxin",
		"experimental_serum": "Experimental Bio-Serum",
		"bio_weapon":         "Biological Weapon Sample",

		// Night biome artifacts
		//"moon_shard":     "Moon Shard",
		//"night_bloom":    "Night Bloom",
		//"shadow_essence": "Shadow Essence",
		//"owl_feather":    "Owl Feather",
		//"midnight_berry": "Midnight Berry",
	}

	if name, exists := displayNames[artifactType]; exists {
		return name
	}
	return artifactType
}

// Get artifact rarity based on type and tier
func GetArtifactRarity(artifactType string, tier int) string {
	// Exclusive artifacts are always legendary
	exclusiveArtifacts := []string{
		"plutonium_core", "reactor_fragment", "control_rod",
		"pure_toxin", "experimental_serum", "bio_weapon", //"shadow_essence",
	}
	for _, exclusive := range exclusiveArtifacts {
		if artifactType == exclusive {
			return "legendary"
		}
	}

	// High-tier artifacts
	highTierArtifacts := []string{
		"uranium_ore", "chemical_compound", "atomic_battery",
		"nuclear_fuel", "lab_equipment", "electronic_component", //"moon_shard",
	}
	for _, highTier := range highTierArtifacts {
		if artifactType == highTier {
			if tier >= 3 {
				return "epic"
			}
			return "rare"
		}
	}

	// Medium-tier artifacts
	mediumTierArtifacts := []string{
		"crystal_shard", "steel_ingot", "electronics",
		"machinery_parts", "toxic_waste", "contaminated_soil", //"owl_feather",
		//"midnight_berry",
	}
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

// Artifact filtering functions
func (h *Handler) canCollectArtifact(artifact common.Artifact, userTier int) bool {
	switch userTier {
	case 0, 1:
		return artifact.Rarity == "common" || artifact.Rarity == "rare"
	case 2, 3:
		return artifact.Rarity != "legendary"
	case 4:
		return true // Elite tier can collect all
	default:
		return artifact.Rarity == "common"
	}
}

func (h *Handler) getRequiredTierForRarity(rarity string) int {
	switch rarity {
	case "common":
		return 0
	case "rare":
		return 1
	case "epic":
		return 2
	case "legendary":
		return 4
	default:
		return 0
	}
}

func (h *Handler) canAccessBiome(biome string, userTier int) bool {
	biomeRequirements := map[string]int{
		BiomeForest:      0,
		BiomeMountain:    1,
		BiomeUrban:       1,
		BiomeWater:       1,
		BiomeIndustrial:  2,
		BiomeRadioactive: 3,
		BiomeChemical:    4,
		//BiomeNight:       2, // ← pridané pre nočný biome
	}

	requiredTier, exists := biomeRequirements[biome]
	if !exists {
		return true // Unknown biome, allow access
	}

	return userTier >= requiredTier
}

func (h *Handler) filterArtifactsByTier(artifacts []common.Artifact, userTier int) []common.Artifact {
	var filtered []common.Artifact
	for _, artifact := range artifacts {
		// Check tier requirements
		if !h.canCollectArtifact(artifact, userTier) {
			continue
		}

		// Check biome access
		if artifact.Biome != "" {
			if !h.canAccessBiome(artifact.Biome, userTier) {
				continue
			}
		}

		filtered = append(filtered, artifact)
	}
	return filtered
}

// ✅ BUDÚCE ROZŠÍRENIA: Nové artefakty môžeš pridávať sem
/*
Plánované artefakty:

FOREST BIOME:
- "rare_flower", "enchanted_bark", "wolf_fang", "bear_claw"
- "druid_stone", "forest_essence", "nature_rune"

MOUNTAIN BIOME:
- "dragon_scale", "mountain_crystal", "cave_painting", "fossil_bone"
- "glacier_water", "summit_flag", "avalanche_debris"

INDUSTRIAL BIOME:
- "robot_part", "conveyor_belt", "industrial_diamond", "oil_sample"
- "factory_blueprint", "steam_engine", "mechanical_gear"

URBAN BIOME:
- "street_sign", "manhole_cover", "traffic_light", "subway_token"
- "city_map", "newspaper", "phone_booth", "fire_hydrant"

WATER BIOME:
- "sea_shell", "coral_fragment", "message_bottle", "anchor_chain"
- "lighthouse_lens", "ship_wheel", "treasure_chest", "pearl"

RADIOACTIVE BIOME:
- "geiger_tube", "radiation_badge", "hazmat_glove", "lead_shield"
- "reactor_coolant", "uranium_glass", "radioactive_ore"

CHEMICAL BIOME:
- "test_tube", "beaker", "chemical_formula", "periodic_table"
- "safety_shower", "fume_hood", "lab_coat", "chemical_spill"
*/
