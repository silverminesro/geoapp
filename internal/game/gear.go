package game

import "geoanomaly/internal/common"

// Gear display names
func GetGearDisplayName(gearType string) string {
	displayNames := map[string]string{
		// Forest gear
		"hunting_knife": "Survival Hunting Knife",
		"leather_boots": "Leather Combat Boots",
		"wooden_bow":    "Wooden Hunting Bow",

		// Mountain gear
		"climbing_gear": "Mountain Climbing Gear",
		"winter_coat":   "Insulated Winter Coat",
		"pickaxe":       "Mining Pickaxe",

		// Industrial gear
		"hard_hat":      "Industrial Hard Hat",
		"safety_gloves": "Chemical Safety Gloves",
		"welding_mask":  "Protective Welding Mask",

		// Urban gear
		"flashlight":    "Tactical Flashlight",
		"first_aid_kit": "Combat First Aid Kit",
		"crowbar":       "Steel Crowbar",

		// Water gear
		"waders":         "Waterproof Waders",
		"fishing_gear":   "Survival Fishing Kit",
		"water_purifier": "Portable Water Purifier",

		// Radioactive gear
		"hazmat_suit":     "Full Hazmat Suit",
		"geiger_counter":  "Radiation Detector",
		"radiation_pills": "Anti-Radiation Pills",

		// Chemical gear
		"gas_mask":      "Military Gas Mask",
		"chemical_suit": "Chemical Protection Suit",
		"neutralizer":   "Chemical Neutralizer",
	}

	if name, exists := displayNames[gearType]; exists {
		return name
	}
	return gearType
}

// Gear filtering functions
func (h *Handler) canCollectGear(gear common.Gear, userTier int) bool {
	maxLevel := h.getMaxGearLevelForTier(userTier)
	return gear.Level <= maxLevel
}

func (h *Handler) getMaxGearLevelForTier(userTier int) int {
	switch userTier {
	case 0:
		return 2 // Free tier: max level 2
	case 1:
		return 4 // Basic tier: max level 4
	case 2:
		return 6 // Premium tier: max level 6
	case 3:
		return 8 // Pro tier: max level 8
	case 4:
		return 10 // Elite tier: max level 10
	default:
		return 1
	}
}

func (h *Handler) filterGearByTier(gear []common.Gear, userTier int) []common.Gear {
	var filtered []common.Gear
	for _, g := range gear {
		// Check tier requirements
		if !h.canCollectGear(g, userTier) {
			continue
		}

		// Check biome access
		if g.Biome != "" {
			if !h.canAccessBiome(g.Biome, userTier) {
				continue
			}
		}

		filtered = append(filtered, g)
	}
	return filtered
}

// ✅ BUDÚCE ROZŠÍRENIA: Nové gear môžeš pridávať sem
/*
Plánované gear podľa biómov:

FOREST GEAR:
- "forest_cloak", "tree_climbing_boots", "hunting_trap", "nature_compass"
- "camping_tent", "survival_kit", "fire_starter", "animal_repellent"

MOUNTAIN GEAR:
- "mountain_boots", "ice_axe", "snow_goggles", "altitude_mask"
- "thermal_gloves", "rope_harness", "emergency_beacon", "avalanche_probe"

INDUSTRIAL GEAR:
- "steel_boots", "industrial_wrench", "machinery_scanner", "oil_detector"
- "factory_keycard", "conveyor_remote", "steam_gauge", "pressure_valve"

URBAN GEAR:
- "city_map", "lockpick_set", "urban_camouflage", "noise_dampener"
- "emergency_radio", "building_scanner", "street_light", "manhole_key"

WATER GEAR:
- "diving_suit", "oxygen_tank", "underwater_light", "pressure_gauge"
- "boat_motor", "fishing_net", "water_boots", "life_jacket"

RADIOACTIVE GEAR:
- "lead_apron", "dosimeter", "radiation_suit", "contamination_scanner"
- "decontamination_kit", "radiation_shield", "uranium_detector"

CHEMICAL GEAR:
- "chemical_analyzer", "ph_meter", "safety_goggles", "spill_kit"
- "fume_extractor", "chemical_resistant_suit", "neutralization_kit"
*/
