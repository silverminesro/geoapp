package game

import (
	"log"
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

// CollectItem - zber artefakt/gear s biome awareness
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

	// Get zone info for biome context
	var zone common.Zone
	if err := h.db.First(&zone, "id = ? AND is_active = true", zoneID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Zone not found"})
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

	// ✅ UPDATED: Enhanced collection with biome context
	var collectedItem interface{}
	var itemName string
	var biome string

	switch req.ItemType {
	case "artifact":
		var artifact common.Artifact
		if err := h.db.First(&artifact, "id = ? AND zone_id = ? AND is_active = true", req.ItemID, zoneID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Artifact not found"})
			return
		}

		// ✅ TIER CHECK for artifact rarity - use zones package
		if !h.zones.CanCollectArtifact(artifact, user.Tier) {
			c.JSON(http.StatusForbidden, gin.H{
				"error":         "Cannot collect this artifact",
				"message":       "Upgrade your tier to collect higher rarity artifacts",
				"rarity":        artifact.Rarity,
				"required_tier": h.zones.GetRequiredTierForRarity(artifact.Rarity),
				"your_tier":     user.Tier,
				"biome":         artifact.Biome,
			})
			return
		}

		// ✅ BIOME CHECK: Special handling for biome-exclusive artifacts
		if h.zones.IsExclusiveArtifact(artifact.Type) {
			log.Printf("🎯 Player collected exclusive %s artifact from %s biome", artifact.Type, artifact.Biome)
		}

		// Deactivate artifact
		artifact.IsActive = false
		h.db.Save(&artifact)

		// ✅ ENHANCED: Add biome info to inventory
		inventory := common.InventoryItem{
			UserID:   user.ID,
			ItemType: "artifact",
			ItemID:   artifact.ID,
			Quantity: 1,
			Properties: common.JSONB{
				"name":           artifact.Name,
				"type":           artifact.Type,
				"rarity":         artifact.Rarity,
				"biome":          artifact.Biome,
				"collected_at":   time.Now().Unix(),
				"collected_from": zoneID,
				"zone_name":      zone.Name,
				"zone_biome":     zone.Biome,
				"danger_level":   zone.DangerLevel,
			},
		}
		h.db.Create(&inventory)

		collectedItem = artifact
		itemName = artifact.Name
		biome = artifact.Biome

		// Update user stats
		h.db.Model(&user).Update("total_artifacts", gorm.Expr("total_artifacts + ?", 1))

	case "gear":
		var gear common.Gear
		if err := h.db.First(&gear, "id = ? AND zone_id = ? AND is_active = true", req.ItemID, zoneID).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "Gear not found"})
			return
		}

		// ✅ TIER CHECK for gear level - use zones package
		if !h.zones.CanCollectGear(gear, user.Tier) {
			c.JSON(http.StatusForbidden, gin.H{
				"error":              "Cannot collect this gear",
				"message":            "Upgrade your tier to collect higher level gear",
				"level":              gear.Level,
				"max_level_for_tier": h.zones.GetMaxGearLevelForTier(user.Tier),
				"your_tier":          user.Tier,
				"biome":              gear.Biome,
			})
			return
		}

		// Deactivate gear
		gear.IsActive = false
		h.db.Save(&gear)

		// ✅ ENHANCED: Add biome info to inventory
		inventory := common.InventoryItem{
			UserID:   user.ID,
			ItemType: "gear",
			ItemID:   gear.ID,
			Quantity: 1,
			Properties: common.JSONB{
				"name":           gear.Name,
				"type":           gear.Type,
				"level":          gear.Level,
				"biome":          gear.Biome,
				"collected_at":   time.Now().Unix(),
				"collected_from": zoneID,
				"zone_name":      zone.Name,
				"zone_biome":     zone.Biome,
				"danger_level":   zone.DangerLevel,
			},
		}
		h.db.Create(&inventory)

		collectedItem = gear
		itemName = gear.Name
		biome = gear.Biome

		// Update user stats
		h.db.Model(&user).Update("total_gear", gorm.Expr("total_gear + ?", 1))

	default:
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid item type"})
		return
	}

	// ✅ ENHANCED: Response with biome context
	c.JSON(http.StatusOK, gin.H{
		"message":      "Item collected successfully",
		"item":         collectedItem,
		"item_name":    itemName,
		"item_type":    req.ItemType,
		"biome":        biome,
		"zone_name":    zone.Name,
		"danger_level": zone.DangerLevel,
		"collected_at": time.Now().Unix(),
		"new_total":    user.TotalArtifacts + user.TotalGear + 1,
	})
}

// ✅ ODSTRÁNENÉ: Všetky duplicitné filtering funkcie presunuté do zones/filtering.go

// ✅ PONECHANÉ: Legacy spawning functions for backward compatibility
func (h *Handler) spawnItemsForNewZone(zoneID uuid.UUID, tier int) {
	// Deprecated - now handled by zones package automatically
	log.Printf("⚠️ Legacy spawnItemsForNewZone called - items are now spawned automatically by zones package")
}

func getRaritiesForTier(tier int) []string {
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

func getGearNamesForTier(tier int) []string {
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
