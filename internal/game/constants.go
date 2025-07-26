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

	// ✅ NOVÉ: Minimálne vzdialenosti medzi zónami
	MinZoneDistanceTier0 = 200.0 // Free tier - 200m minimum
	MinZoneDistanceTier1 = 250.0 // Basic tier - 250m minimum
	MinZoneDistanceTier2 = 300.0 // Premium tier - 300m minimum
	MinZoneDistanceTier3 = 350.0 // Pro tier - 350m minimum
	MinZoneDistanceTier4 = 400.0 // Elite tier - 400m minimum

	// Maximum attempts pre nájdenie valid pozície
	MaxPositionAttempts = 50
)
