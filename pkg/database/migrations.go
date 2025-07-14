package database

import (
	"geoanomaly/internal/common"

	"gorm.io/gorm"
)

func AutoMigrate(db *gorm.DB) error {
	// Enable PostGIS extension
	if err := db.Exec("CREATE EXTENSION IF NOT EXISTS postgis").Error; err != nil {
		return err
	}

	// Auto-migrate all models
	err := db.AutoMigrate(
		&common.User{},
		&common.Zone{},
		&common.InventoryItem{},
		&common.Artifact{},
		&common.Gear{},
		&common.PlayerSession{},
	)

	if err != nil {
		return err
	}

	// ✅ UPDATED: Enhanced spatial indexes with biome support
	if err := createSpatialIndexes(db); err != nil {
		return err
	}

	// ✅ PRIDANÉ: Create biome-specific indexes
	if err := createBiomeIndexes(db); err != nil {
		return err
	}

	return nil
}

func createSpatialIndexes(db *gorm.DB) error {
	// Index for zones location
	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_zones_location 
		ON zones USING GIST (ST_Point(location_longitude, location_latitude))
	`).Error; err != nil {
		return err
	}

	// Index for artifacts location
	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_artifacts_location 
		ON artifacts USING GIST (ST_Point(location_longitude, location_latitude))
	`).Error; err != nil {
		return err
	}

	// Index for gear location
	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_gear_location 
		ON gear USING GIST (ST_Point(location_longitude, location_latitude))
	`).Error; err != nil {
		return err
	}

	return nil
}

// ✅ SIMPLIFIED: Biome-specific database indexes (bez environmental_effects)
func createBiomeIndexes(db *gorm.DB) error {
	// Index for zones by biome
	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_zones_biome 
		ON zones (biome)
	`).Error; err != nil {
		return err
	}

	// Index for zones by danger level
	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_zones_danger_level 
		ON zones (danger_level)
	`).Error; err != nil {
		return err
	}

	// Index for artifacts by biome
	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_artifacts_biome 
		ON artifacts (biome)
	`).Error; err != nil {
		return err
	}

	// Index for gear by biome
	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_gear_biome 
		ON gear (biome)
	`).Error; err != nil {
		return err
	}

	// Index for exclusive biome items
	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_artifacts_exclusive_biome 
		ON artifacts (exclusive_to_biome, biome)
	`).Error; err != nil {
		return err
	}

	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_gear_exclusive_biome 
		ON gear (exclusive_to_biome, biome)
	`).Error; err != nil {
		return err
	}

	// Combined index for zone filtering
	if err := db.Exec(`
		CREATE INDEX IF NOT EXISTS idx_zones_tier_biome 
		ON zones (tier_required, biome, is_active)
	`).Error; err != nil {
		return err
	}

	return nil
}
