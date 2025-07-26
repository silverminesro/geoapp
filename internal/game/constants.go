package game

// Biome constants
const (
	BiomeForest      = "forest"
	BiomeMountain    = "mountain"
	BiomeUrban       = "urban"
	BiomeWater       = "water"
	BiomeIndustrial  = "industrial"
	BiomeRadioactive = "radioactive"
	BiomeChemical    = "chemical"
)

// Danger level constants
const (
	DangerLow     = "low"
	DangerMedium  = "medium"
	DangerHigh    = "high"
	DangerExtreme = "extreme"
)

// Zone constants
const (
	EarthRadiusKm      = 6371.0
	MaxScanRadius      = 100.0
	MaxCollectRadius   = 50.0
	AreaScanRadius     = 7000.0
	AreaScanCooldown   = 30
	ZoneMinExpiryHours = 10
	ZoneMaxExpiryHours = 24

	// ✅ AKTUALIZOVANÉ: Zone tier based spacing (nie player tier)
	// Tier 0 zones
	ZoneTier0BaseRadius = 200
	ZoneTier0Variance   = 30 // 170-230m range
	ZoneTier0MinSpacing = 250.0

	// Tier 1 zones
	ZoneTier1BaseRadius = 250
	ZoneTier1Variance   = 40 // 210-290m range
	ZoneTier1MinSpacing = 300.0

	// Tier 2 zones
	ZoneTier2BaseRadius = 300
	ZoneTier2Variance   = 50 // 250-350m range
	ZoneTier2MinSpacing = 350.0

	// Tier 3 zones
	ZoneTier3BaseRadius = 350
	ZoneTier3Variance   = 60 // 290-410m range
	ZoneTier3MinSpacing = 400.0

	// Tier 4 zones
	ZoneTier4BaseRadius = 400
	ZoneTier4Variance   = 70 // 330-470m range
	ZoneTier4MinSpacing = 450.0

	// Maximum attempts pre nájdenie valid pozície
	MaxPositionAttempts = 50
)
