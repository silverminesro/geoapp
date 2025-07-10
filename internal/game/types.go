package game

import (
	"geoanomaly/internal/common"
	"time"
)

// Request/Response struktury
type ScanAreaRequest struct {
	Latitude  float64 `json:"latitude" binding:"required"`
	Longitude float64 `json:"longitude" binding:"required"`
}

type ScanAreaResponse struct {
	ZonesCreated      int               `json:"zones_created"`
	Zones             []ZoneWithDetails `json:"zones"`
	ScanAreaCenter    LocationPoint     `json:"scan_area_center"`
	NextScanAvailable int64             `json:"next_scan_available"`
	MaxZones          int               `json:"max_zones"`
	CurrentZoneCount  int               `json:"current_zone_count"`
	PlayerTier        int               `json:"player_tier"`
}

type ZoneWithDetails struct {
	Zone            common.Zone `json:"zone"`
	DistanceMeters  float64     `json:"distance_meters"`
	CanEnter        bool        `json:"can_enter"`
	ActiveArtifacts int         `json:"active_artifacts"`
	ActiveGear      int         `json:"active_gear"`
	ActivePlayers   int         `json:"active_players"`
	ExpiresAt       *int64      `json:"expires_at,omitempty"`
	TimeToExpiry    *string     `json:"time_to_expiry,omitempty"`
}

type LocationPoint struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type PlayerInZone struct {
	Username string    `json:"username"`
	Tier     int       `json:"tier"`
	LastSeen time.Time `json:"last_seen"`
	Distance float64   `json:"distance_meters"`
}

// Konstanty
const (
	EarthRadiusKm      = 6371.0
	MaxScanRadius      = 100.0
	MaxCollectRadius   = 50.0
	AreaScanRadius     = 7000.0
	AreaScanCooldown   = 30
	ZoneMinExpiryHours = 10
	ZoneMaxExpiryHours = 24
)
