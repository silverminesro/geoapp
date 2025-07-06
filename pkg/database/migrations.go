package database

import (
	"geoapp/internal/common"

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

	// Create spatial indexes for better performance
	if err := createSpatialIndexes(db); err != nil {
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
