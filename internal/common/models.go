package common

import (
	"database/sql/driver"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
)

// JSONB type for PostgreSQL
type JSONB map[string]interface{}

func (j JSONB) Value() (driver.Value, error) {
	return json.Marshal(j)
}

func (j *JSONB) Scan(value interface{}) error {
	if value == nil {
		*j = nil
		return nil
	}

	bytes, ok := value.([]byte)
	if !ok {
		return errors.New("type assertion to []byte failed")
	}

	return json.Unmarshal(bytes, j)
}

// Base model
type BaseModel struct {
	ID        uuid.UUID  `json:"id" gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CreatedAt time.Time  `json:"created_at" gorm:"autoCreateTime"`
	UpdatedAt time.Time  `json:"updated_at" gorm:"autoUpdateTime"`
	DeletedAt *time.Time `json:"deleted_at,omitempty" gorm:"index"` // ✅ PRIDANÉ: Soft delete support
}

// ✅ OPRAVENÉ: Location bez Accuracy (databáza ho nemá)
type Location struct {
	Latitude  float64 `json:"latitude" gorm:"type:decimal(10,8)"`
	Longitude float64 `json:"longitude" gorm:"type:decimal(11,8)"`
	// ❌ REMOVED: Accuracy  float64   `json:"accuracy,omitempty"` // Database doesn't have this column
	Timestamp time.Time `json:"timestamp" gorm:"autoUpdateTime"`
}

// ✅ PRIDANÉ: LocationWithAccuracy pre user tracking kde potrebujeme accuracy
type LocationWithAccuracy struct {
	Latitude  float64   `json:"latitude" gorm:"type:decimal(10,8)"`
	Longitude float64   `json:"longitude" gorm:"type:decimal(11,8)"`
	Accuracy  float64   `json:"accuracy,omitempty"`
	Timestamp time.Time `json:"timestamp" gorm:"autoUpdateTime"`
}

// ✅ OPRAVENÝ User model - match exact database structure
type User struct {
	BaseModel
	Username        string     `json:"username" gorm:"uniqueIndex;not null;size:50"`
	Email           string     `json:"email" gorm:"uniqueIndex;not null;size:100"`
	PasswordHash    string     `json:"-" gorm:"not null;size:255"`
	Tier            int        `json:"tier" gorm:"default:0"`                // ✅ OPRAVENÉ: default 0 (not 1)
	TierExpires     *time.Time `json:"tier_expires,omitempty"`               // ✅ PRIDANÉ
	TierAutoRenew   bool       `json:"tier_auto_renew" gorm:"default:false"` // ✅ PRIDANÉ
	XP              int        `json:"xp" gorm:"default:0"`                  // ✅ PRIDANÉ
	Level           int        `json:"level" gorm:"default:1"`               // ✅ PRIDANÉ
	TotalArtifacts  int        `json:"total_artifacts" gorm:"default:0"`     // ✅ PRIDANÉ
	TotalGear       int        `json:"total_gear" gorm:"default:0"`          // ✅ PRIDANÉ
	ZonesDiscovered int        `json:"zones_discovered" gorm:"default:0"`    // ✅ PRIDANÉ
	IsActive        bool       `json:"is_active" gorm:"default:true"`
	IsBanned        bool       `json:"is_banned" gorm:"default:false"`                               // ✅ PRIDANÉ
	LastLogin       *time.Time `json:"last_login,omitempty"`                                         // ✅ PRIDANÉ
	ProfileData     JSONB      `json:"profile_data,omitempty" gorm:"type:jsonb;default:'{}'::jsonb"` // ✅ PRIDANÉ

	// Relationships
	Inventory []InventoryItem `json:"inventory,omitempty" gorm:"foreignKey:UserID"`
}

// Zone model - match exact database structure
type Zone struct {
	BaseModel
	Name         string   `json:"name" gorm:"not null;size:100"`
	Description  string   `json:"description,omitempty" gorm:"type:text"`
	TierRequired int      `json:"tier_required" gorm:"not null"`
	Location     Location `json:"location" gorm:"embedded;embeddedPrefix:location_"`
	RadiusMeters int      `json:"radius_meters" gorm:"not null"`
	IsActive     bool     `json:"is_active" gorm:"default:true"`
	ZoneType     string   `json:"zone_type" gorm:"not null;default:'static'"`
	Properties   JSONB    `json:"properties,omitempty" gorm:"type:jsonb;default:'{}'::jsonb"`

	// Relationships
	Artifacts []Artifact `json:"artifacts,omitempty" gorm:"foreignKey:ZoneID"`
	Gear      []Gear     `json:"gear,omitempty" gorm:"foreignKey:ZoneID"`
}

// Inventory model
type InventoryItem struct {
	BaseModel
	UserID     uuid.UUID `json:"user_id" gorm:"not null;index"`
	ItemType   string    `json:"item_type" gorm:"not null;size:50"` // artifact, gear
	ItemID     uuid.UUID `json:"item_id" gorm:"not null"`
	Properties JSONB     `json:"properties,omitempty" gorm:"type:jsonb;default:'{}'::jsonb"`
	Quantity   int       `json:"quantity" gorm:"default:1"`
	AcquiredAt time.Time `json:"acquired_at" gorm:"autoCreateTime"`

	// Relationships
	User *User `json:"user,omitempty" gorm:"foreignKey:UserID"`
}

// ✅ OPRAVENÝ Artifact model - match exact database structure
type Artifact struct {
	BaseModel
	ZoneID     uuid.UUID `json:"zone_id" gorm:"not null;index"`
	Name       string    `json:"name" gorm:"not null;size:100"`
	Type       string    `json:"type" gorm:"not null;size:50"`
	Rarity     string    `json:"rarity" gorm:"not null;size:20"` // common, rare, epic, legendary
	Location   Location  `json:"location" gorm:"embedded;embeddedPrefix:location_"`
	Properties JSONB     `json:"properties,omitempty" gorm:"type:jsonb;default:'{}'::jsonb"`
	IsActive   bool      `json:"is_active" gorm:"default:true"`
	// ❌ VYMAZANÉ: SpawnedAt - stĺpec neexistuje v databáze!

	// Relationships
	Zone *Zone `json:"zone,omitempty" gorm:"foreignKey:ZoneID"`
}

// ✅ OPRAVENÝ Gear model - match exact database structure
type Gear struct {
	BaseModel
	ZoneID     uuid.UUID `json:"zone_id" gorm:"not null;index"`
	Name       string    `json:"name" gorm:"not null;size:100"`
	Type       string    `json:"type" gorm:"not null;size:50"` // weapon, armor, tool
	Level      int       `json:"level" gorm:"default:1"`
	Location   Location  `json:"location" gorm:"embedded;embeddedPrefix:location_"`
	Properties JSONB     `json:"properties,omitempty" gorm:"type:jsonb;default:'{}'::jsonb"`
	IsActive   bool      `json:"is_active" gorm:"default:true"`
	// ❌ VYMAZANÉ: SpawnedAt - stĺpec neexistuje v databáze!

	// Relationships
	Zone *Zone `json:"zone,omitempty" gorm:"foreignKey:ZoneID"`
}

// ✅ PRIDANÉ: TableName methods pre správne názvy
func (Artifact) TableName() string {
	return "artifacts" // ✅ Correct plural form
}

func (Gear) TableName() string {
	return "gear" // ✅ Correct singular form (matches database)
}

// ✅ OPRAVENÉ: PlayerSession - NO BaseModel embedding to avoid conflicts
type PlayerSession struct {
	ID        uuid.UUID `json:"id" gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CreatedAt time.Time `json:"created_at" gorm:"autoCreateTime"`
	UpdatedAt time.Time `json:"updated_at" gorm:"autoUpdateTime"`

	UserID      uuid.UUID  `json:"user_id" gorm:"not null;index"`
	LastSeen    time.Time  `json:"last_seen" gorm:"autoUpdateTime"`
	IsOnline    bool       `json:"is_online" gorm:"default:true"`
	CurrentZone *uuid.UUID `json:"current_zone,omitempty" gorm:"index"`

	// ✅ Individual location fields instead of embedded struct
	LastLocationLatitude  float64   `json:"last_location_latitude" gorm:"type:decimal(10,8)"`
	LastLocationLongitude float64   `json:"last_location_longitude" gorm:"type:decimal(11,8)"`
	LastLocationAccuracy  float64   `json:"last_location_accuracy"`
	LastLocationTimestamp time.Time `json:"last_location_timestamp"`

	// Relationships
	User *User `json:"user,omitempty" gorm:"foreignKey:UserID"`
	Zone *Zone `json:"zone,omitempty" gorm:"foreignKey:CurrentZone"`
}

// ✅ PRIDANÉ: Helper method pre PlayerSession to get LastLocation as struct
func (ps *PlayerSession) GetLastLocation() LocationWithAccuracy {
	return LocationWithAccuracy{
		Latitude:  ps.LastLocationLatitude,
		Longitude: ps.LastLocationLongitude,
		Accuracy:  ps.LastLocationAccuracy,
		Timestamp: ps.LastLocationTimestamp,
	}
}

// ✅ PRIDANÉ: Helper method pre PlayerSession to set LastLocation from struct
func (ps *PlayerSession) SetLastLocation(loc LocationWithAccuracy) {
	ps.LastLocationLatitude = loc.Latitude
	ps.LastLocationLongitude = loc.Longitude
	ps.LastLocationAccuracy = loc.Accuracy
	ps.LastLocationTimestamp = loc.Timestamp
}
