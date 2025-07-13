package zones

import (
	"geoanomaly/internal/common"
	// ❌ VYMAZANÉ: "geoanomaly/internal/game"
)

// ============================================
// TIER FILTERING FUNCTIONS
// ============================================

// ✅ ENHANCED: Biome-aware artifact filtering
func (h *Handler) filterArtifactsByTier(artifacts []common.Artifact, userTier int) []common.Artifact {
	var filtered []common.Artifact
	for _, artifact := range artifacts {
		// Check tier requirements
		if !h.canCollectArtifact(artifact, userTier) {
			continue
		}

		// Check biome access (if biome system is active)
		if artifact.Biome != "" {
			if !h.canAccessBiome(artifact.Biome, userTier) {
				continue
			}
		}

		filtered = append(filtered, artifact)
	}
	return filtered
}

// ✅ ENHANCED: Biome-aware gear filtering
func (h *Handler) filterGearByTier(gear []common.Gear, userTier int) []common.Gear {
	var filtered []common.Gear
	for _, g := range gear {
		// Check tier requirements
		if !h.canCollectGear(g, userTier) {
			continue
		}

		// Check biome access (if biome system is active)
		if g.Biome != "" {
			if !h.canAccessBiome(g.Biome, userTier) {
				continue
			}
		}

		filtered = append(filtered, g)
	}
	return filtered
}

// ✅ NEW: Check if user can access biome (using local constants)
func (h *Handler) canAccessBiome(biome string, userTier int) bool {
	biomeRequirements := map[string]int{
		BiomeForest:      0,
		BiomeMountain:    1,
		BiomeUrban:       1,
		BiomeWater:       1,
		BiomeIndustrial:  2,
		BiomeRadioactive: 3,
		BiomeChemical:    4,
	}

	requiredTier, exists := biomeRequirements[biome]
	if !exists {
		return true // Unknown biome, allow access
	}

	return userTier >= requiredTier
}

// ✅ NEW: Check if artifact is exclusive to biome
func (h *Handler) isExclusiveArtifact(artifactType string) bool {
	exclusiveArtifacts := []string{
		"plutonium_core", "reactor_fragment", "control_rod",
		"pure_toxin", "experimental_serum", "bio_weapon",
	}

	for _, exclusive := range exclusiveArtifacts {
		if artifactType == exclusive {
			return true
		}
	}
	return false
}

// ✅ EXISTING: Artifact collection check
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

// ✅ EXISTING: Gear collection check
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

// ✅ EXPORT for items.go
func (h *Handler) CanCollectArtifact(artifact common.Artifact, userTier int) bool {
	return h.canCollectArtifact(artifact, userTier)
}

func (h *Handler) CanCollectGear(gear common.Gear, userTier int) bool {
	return h.canCollectGear(gear, userTier)
}

func (h *Handler) GetMaxGearLevelForTier(userTier int) int {
	return h.getMaxGearLevelForTier(userTier)
}

func (h *Handler) GetRequiredTierForRarity(rarity string) int {
	return h.getRequiredTierForRarity(rarity)
}

func (h *Handler) IsExclusiveArtifact(artifactType string) bool {
	return h.isExclusiveArtifact(artifactType)
}
