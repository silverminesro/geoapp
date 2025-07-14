package xp

// XP calculation result
type XPResult struct {
	XPGained     int          `json:"xp_gained"`
	TotalXP      int          `json:"total_xp"`
	CurrentLevel int          `json:"current_level"`
	LevelUp      bool         `json:"level_up"`
	Breakdown    XPBreakdown  `json:"xp_breakdown"`
	LevelUpInfo  *LevelUpInfo `json:"level_up_info,omitempty"`
}

type XPBreakdown struct {
	BaseXP      int `json:"base_xp"`
	RarityBonus int `json:"rarity_bonus"`
	BiomeBonus  int `json:"biome_bonus"`
	TierBonus   int `json:"tier_bonus"`
}

type LevelUpInfo struct {
	OldLevel    int      `json:"old_level"`
	NewLevel    int      `json:"new_level"`
	Rewards     []string `json:"rewards"`
	LevelUpTime int64    `json:"level_up_time"`
}
