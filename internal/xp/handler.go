package xp

import (
	"geoanomaly/internal/common"
	"log"
	"time"

	"github.com/google/uuid"
	"gorm.io/gorm"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

// ✅ MAIN: Award XP for artifact collection
func (h *Handler) AwardArtifactXP(userID uuid.UUID, rarity, biome string, zoneTier int) (*XPResult, error) {
	// Get current user
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		return nil, err
	}

	// Calculate XP
	breakdown := h.calculateArtifactXP(rarity, biome, zoneTier)
	xpGained := breakdown.BaseXP + breakdown.RarityBonus + breakdown.BiomeBonus + breakdown.TierBonus

	oldLevel := user.Level
	oldXP := user.XP
	newXP := oldXP + xpGained

	// Update user XP
	if err := h.db.Model(&user).Update("xp", newXP).Error; err != nil {
		return nil, err
	}

	// Check for level up
	newLevel := h.getLevelFromXP(newXP)
	levelUp := newLevel > oldLevel

	var levelUpInfo *LevelUpInfo
	if levelUp {
		// Update user level
		if err := h.db.Model(&user).Update("level", newLevel).Error; err != nil {
			return nil, err
		}

		levelUpInfo = &LevelUpInfo{
			OldLevel:    oldLevel,
			NewLevel:    newLevel,
			Rewards:     []string{"Level progression unlocked"},
			LevelUpTime: time.Now().Unix(),
		}

		log.Printf("🎉 LEVEL UP! User %s: %d → %d (XP: %d → %d)", userID, oldLevel, newLevel, oldXP, newXP)
	}

	result := &XPResult{
		XPGained:     xpGained,
		TotalXP:      newXP,
		CurrentLevel: newLevel,
		LevelUp:      levelUp,
		Breakdown:    breakdown,
		LevelUpInfo:  levelUpInfo,
	}

	return result, nil
}

// Calculate XP for artifact
func (h *Handler) calculateArtifactXP(rarity, biome string, zoneTier int) XPBreakdown {
	breakdown := XPBreakdown{
		BaseXP: 10, // Base 10 XP per artifact
	}

	// Rarity bonus
	switch rarity {
	case "common":
		breakdown.RarityBonus = 0
	case "rare":
		breakdown.RarityBonus = 5
	case "epic":
		breakdown.RarityBonus = 15
	case "legendary":
		breakdown.RarityBonus = 30
	}

	// Biome danger bonus
	switch biome {
	case "forest":
		breakdown.BiomeBonus = 0
	case "mountain", "urban", "water":
		breakdown.BiomeBonus = 5
	case "industrial":
		breakdown.BiomeBonus = 10
	case "radioactive", "chemical":
		breakdown.BiomeBonus = 15
	}

	// Zone tier bonus
	breakdown.TierBonus = zoneTier * 3

	return breakdown
}

// Get level from XP using level_definitions table
func (h *Handler) getLevelFromXP(totalXP int) int {
	var levelDefs []struct {
		Level      int `json:"level"`
		XPRequired int `json:"xp_required"`
	}

	if err := h.db.Table("level_definitions").
		Order("level DESC").
		Find(&levelDefs).Error; err != nil {
		return 1 // Fallback
	}

	// Find highest level player qualifies for
	for _, levelDef := range levelDefs {
		if totalXP >= levelDef.XPRequired {
			return levelDef.Level
		}
	}

	return 1 // Fallback to level 1
}
