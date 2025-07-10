package game

import (
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"time"

	"geoanomaly/internal/common"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"gorm.io/gorm"
)

// ============================================
// ITEM COLLECTION ENDPOINT
// ============================================

// CollectItem - zber artefakt/gear
func (h *Handler) CollectItem(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	zoneID := c.Param("id")
	if zoneID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Zone ID required"})
		return
	}

	type CollectRequest struct {
		ItemType string `json:"item_type" binding:"required"` // artifact, gear
		ItemID   string `json:"item_id" binding:"required"`
	}

	var req CollectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Get user
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Check if player is in zone
	var session common.PlayerSession
	if err := h.db.Where("user_id = ? AND current_zone = ?", userID, zoneID).First(&session).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error":   "Not in zone",
			"message": "You must be in the zone to collect items",
		})
		return
	}

	// ✅ OPRAVENÉ: Tagged switch na req.ItemType
	var collectedItem interface{}
	var itemName string

	switch req.ItemType {
	case "artifact":
		var artifact common.Artifact
		if err := h.db.First(&artifact, "id = ? AND zone_id = ? AND is_active = true", req.ItemID, zoneID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artifact not found"})
			return
		}

		// ✅ TIER CHECK for artifact rarity
		if !h.canCollectArtifact(artifact, user.Tier) {
			c.JSON(http.StatusForbidden, gin.H{
				"error":         "Cannot collect this artifact",
				"message":       "Upgrade your tier to collect higher rarity artifacts",
				"rarity":        artifact.Rarity,
				"required_tier": h.getRequiredTierForRarity(artifact.Rarity),
				"your_tier":     user.Tier,
			})
			return
		}

		// Deactivate artifact
		artifact.IsActive = false
		h.db.Save(&artifact)

		// Add to inventory
		inventory := common.InventoryItem{
			UserID:   user.ID,
			ItemType: "artifact",
			ItemID:   artifact.ID,
			Quantity: 1,
			Properties: common.JSONB{
				"name":           artifact.Name,
				"type":           artifact.Type,
				"rarity":         artifact.Rarity,
				"collected_at":   time.Now().Unix(),
				"collected_from": zoneID,
				"zone_name":      "zone",
			},
		}
		h.db.Create(&inventory)

		collectedItem = artifact
		itemName = artifact.Name

		// Update user stats
		h.db.Model(&user).Update("total_artifacts", gorm.Expr("total_artifacts + ?", 1))

	case "gear":
		var gear common.Gear
		if err := h.db.First(&gear, "id = ? AND zone_id = ? AND is_active = true", req.ItemID, zoneID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Gear not found"})
			return
		}

		// ✅ TIER CHECK for gear level
		if !h.canCollectGear(gear, user.Tier) {
			c.JSON(http.StatusForbidden, gin.H{
				"error":              "Cannot collect this gear",
				"message":            "Upgrade your tier to collect higher level gear",
				"level":              gear.Level,
				"max_level_for_tier": h.getMaxGearLevelForTier(user.Tier),
				"your_tier":          user.Tier,
			})
			return
		}

		// Deactivate gear
		gear.IsActive = false
		h.db.Save(&gear)

		// Add to inventory
		inventory := common.InventoryItem{
			UserID:   user.ID,
			ItemType: "gear",
			ItemID:   gear.ID,
			Quantity: 1,
			Properties: common.JSONB{
				"name":           gear.Name,
				"type":           gear.Type,
				"level":          gear.Level,
				"collected_at":   time.Now().Unix(),
				"collected_from": zoneID,
				"zone_name":      "zone",
			},
		}
		h.db.Create(&inventory)

		collectedItem = gear
		itemName = gear.Name

		// Update user stats
		h.db.Model(&user).Update("total_gear", gorm.Expr("total_gear + ?", 1))

	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid item type"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":      "Item collected successfully",
		"item":         collectedItem,
		"item_name":    itemName,
		"item_type":    req.ItemType,
		"collected_at": time.Now().Unix(),
		"new_total":    user.TotalArtifacts + user.TotalGear + 1,
	})
}

// ============================================
// ITEM SPAWNING FUNCTIONS
// ============================================

func (h *Handler) spawnItemsForNewZone(zoneID uuid.UUID, tier int) {
	log.Printf("🎁 Spawning items for zone %s (tier %d)", zoneID, tier)

	// ✅ ADJUSTED: Fewer items for better balance
	artifactCount := 1 + tier   // Tier 0: 1, Tier 1: 2, Tier 2: 3, etc.
	gearCount := 1 + (tier / 2) // Tier 0: 1, Tier 1: 1, Tier 2: 2, etc.

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
	level := tier + rand.Intn(2) // Level can be tier or tier+1

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

// ============================================
// TIER FILTERING FUNCTIONS
// ============================================

// Helper functions pre tier filtering
func (h *Handler) filterArtifactsByTier(artifacts []common.Artifact, userTier int) []common.Artifact {
	var filtered []common.Artifact
	for _, artifact := range artifacts {
		if h.canCollectArtifact(artifact, userTier) {
			filtered = append(filtered, artifact)
		}
	}
	return filtered
}

func (h *Handler) filterGearByTier(gear []common.Gear, userTier int) []common.Gear {
	var filtered []common.Gear
	for _, g := range gear {
		if h.canCollectGear(g, userTier) {
			filtered = append(filtered, g)
		}
	}
	return filtered
}

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

func (h *Handler) getRaritiesForTier(tier int) []string {
	switch tier {
	case 0:
		return []string{"common"}
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
	case 0:
		return []string{"Basic", "Simple"}
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
