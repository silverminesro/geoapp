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
)
