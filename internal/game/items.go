package game

import (
	"fmt"
	"log"
	"math/rand"
	"time"

	"geoapp/internal/common"

	"github.com/google/uuid"
)

func (h *Handler) spawnItemsForNewZone(zoneID uuid.UUID, tier int) {
	log.Printf("🎁 Spawning items for zone %s (tier %d)", zoneID, tier)

	artifactCount := 2 + tier*2 // Tier 1: 4, Tier 2: 6, etc.
	gearCount := 1 + tier       // Tier 1: 2, Tier 2: 3, etc.

	// Spawn artefakty
	for i := 0; i < artifactCount; i++ {
		if err := h.spawnRandomArtifactWithTier(zoneID, tier); err != nil {
			log.Printf("⚠️ Failed to spawn artifact %d: %v", i+1, err)
		}
	}

	// Spawn gear
	for i := 0; i < gearCount; i++ {
		if err := h.spawnRandomGearWithTier(zoneID, tier); err != nil {
			log.Printf("⚠️ Failed to spawn gear %d: %v", i+1, err)
		}
	}

	log.Printf("✅ Items spawned: %d artifacts, %d gear", artifactCount, gearCount)
}

func (h *Handler) spawnRandomArtifactWithTier(zoneID uuid.UUID, tier int) error {
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return err
	}

	rarities := h.getRaritiesForTier(tier)
	types := []string{"ancient_coin", "crystal", "rune", "scroll", "gem", "tablet", "orb"}

	rarity := rarities[rand.Intn(len(rarities))]
	artifactType := types[rand.Intn(len(types))]

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

	return h.db.Create(&artifact).Error
}

func (h *Handler) spawnRandomGearWithTier(zoneID uuid.UUID, tier int) error {
	var zone common.Zone
	if err := h.db.First(&zone, "id = ?", zoneID).Error; err != nil {
		return err
	}

	gearTypes := []string{"sword", "shield", "armor", "boots", "helmet", "ring", "amulet"}
	gearNames := h.getGearNamesForTier(tier)

	gearType := gearTypes[rand.Intn(len(gearTypes))]
	gearName := gearNames[rand.Intn(len(gearNames))]
	level := tier + rand.Intn(2)

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

	return h.db.Create(&gear).Error
}

func (h *Handler) getRaritiesForTier(tier int) []string {
	switch tier {
	case 1:
		return []string{"common", "common", "rare"}
	case 2:
		return []string{"common", "rare", "rare", "epic"}
	case 3:
		return []string{"rare", "rare", "epic", "legendary"}
	case 4:
		return []string{"epic", "epic", "legendary", "legendary"}
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
