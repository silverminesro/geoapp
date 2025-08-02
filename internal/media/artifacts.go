package media

import "log"

// Mapuje artifactType na image filename
var ArtifactImages = map[string]string{

	// Forest artifacts - generovane: mysterious and atmospheric, highly detailed, inspired by S.T.A.L.K.E.R. games, no people
	"mushroom_sample": "mutant_mushroom_sample.jpg",
	"tree_resin":      "amber_tree_resin.jpg",
	"animal_bones":    "predator_bones.jpg",
	"herbal_extract":  "herbal_extract.jpg",
	"dewdrop_pearl":   "dewdrop_pearl.jpg",

	// Mountain artifacts - generovane: mysterious and atmospheric, highly detailed, inspired by S.T.A.L.K.E.R. games, no people
	"mineral_ore":   "rare_mineral_ore.jpg",
	"crystal_shard": "energy_crystal_shard.jpg",
	"stone_tablet":  "ancient_stone_tablet.jpg",
	"mountain_herb": "alpine_medicinal_herb.jpg",
	"ice_crystal":   "frozen_ice_crystal.jpg",

	// Industrial artifacts
	"rusty_gear":           "rusty_gear_relic.jpg",
	"chemical_sample":      "unknown_chemical_sample.jpg",
	"machinery_parts":      "industrial_machinery_parts.jpg",
	"electronic_component": "advanced_electronic_component.jpg",
	"toxic_waste":          "toxic_waste_container.jpg",

	// Urban artifacts
	"old_documents":    "pre_war_documents.jpg",
	"medical_supplies": "medical_emergency_kit.jpg",
	"electronics":      "salvaged_electronics.jpg",
	"urban_artifact":   "city_historical_artifact.jpg",
	"pocket_radio":     "pocket_radio_receiver.jpg",

	// Water artifacts
	"water_sample":   "contaminated_water_sample.jpg",
	"aquatic_plant":  "mutant_aquatic_plant.jpg",
	"filtered_water": "purified_water_container.jpg",
	"abyss_pearl":    "abyss_pearl.jpg",
	"algae_biomass":  "toxic_algae_biomass.jpg",
}

func (s *Service) GetArtifactImage(artifactType string) (string, bool) {
	filename, exists := ArtifactImages[artifactType]

	// ✅ PRIDANÉ: Debug logging
	log.Printf("🔍 GetArtifactImage: type='%s', filename='%s', exists=%v",
		artifactType, filename, exists)

	return filename, exists
}
