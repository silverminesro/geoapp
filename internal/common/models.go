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
	ID        uuid.UUID `json:"id" gorm:"type:uuid;default:gen_random_uuid();primaryKey"`
	CreatedAt time.Time `json:"created_at" gorm:"autoCreateTime"`
	UpdatedAt time.Time `json:"updated_at" gorm:"autoUpdateTime"`
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

// ✅ OPRAVENÝ User model - bez LastLocation (pridáme neskôr)
type User struct {
	BaseModel
	Username     string `json:"username" gorm:"uniqueIndex;not null;size:50"`
	Email        string `json:"email" gorm:"uniqueIndex;not null;size:100"`
	PasswordHash string `json:"-" gorm:"not null;size:255"`
	Tier         int    `json:"tier" gorm:"default:1"`
	IsActive     bool   `json:"is_active" gorm:"default:true"`

	// Relationships
	Inventory []InventoryItem `json:"inventory,omitempty" gorm:"foreignKey:UserID"`
}

// Zone model
type Zone struct {
	BaseModel
	Name         string   `json:"name" gorm:"not null;size:100"`
	Description  string   `json:"description,omitempty" gorm:"type:text"`
	TierRequired int      `json:"tier_required" gorm:"not null"`
	Location     Location `json:"location" gorm:"embedded;embeddedPrefix:location_"`
	RadiusMeters int      `json:"radius_meters" gorm:"not null"`
	IsActive     bool     `json:"is_active" gorm:"default:true"`
	ZoneType     string   `json:"zone_type" gorm:"not null;default:'static'"`
	Properties   JSONB    `json:"properties,omitempty" gorm:"type:jsonb"`

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
	Properties JSONB     `json:"properties,omitempty" gorm:"type:jsonb"`
	Quantity   int       `json:"quantity" gorm:"default:1"`
	AcquiredAt time.Time `json:"acquired_at" gorm:"autoCreateTime"`

	// Relationships
	User *User `json:"user,omitempty" gorm:"foreignKey:UserID"`
}

// Artifact model
type Artifact struct {
	BaseModel
	ZoneID     uuid.UUID `json:"zone_id" gorm:"not null;index"`
	Name       string    `json:"name" gorm:"not null;size:100"`
	Type       string    `json:"type" gorm:"not null;size:50"`
	Rarity     string    `json:"rarity" gorm:"not null;size:20"` // common, rare, epic, legendary
	Location   Location  `json:"location" gorm:"embedded;embeddedPrefix:location_"`
	Properties JSONB     `json:"properties,omitempty" gorm:"type:jsonb"`
	IsActive   bool      `json:"is_active" gorm:"default:true"`
	SpawnedAt  time.Time `json:"spawned_at" gorm:"autoCreateTime"`

	// Relationships
	Zone *Zone `json:"zone,omitempty" gorm:"foreignKey:ZoneID"`
}

// Gear model
type Gear struct {
	BaseModel
	ZoneID     uuid.UUID `json:"zone_id" gorm:"not null;index"`
	Name       string    `json:"name" gorm:"not null;size:100"`
	Type       string    `json:"type" gorm:"not null;size:50"` // weapon, armor, tool
	Level      int       `json:"level" gorm:"default:1"`
	Location   Location  `json:"location" gorm:"embedded;embeddedPrefix:location_"`
	Properties JSONB     `json:"properties,omitempty" gorm:"type:jsonb"`
	IsActive   bool      `json:"is_active" gorm:"default:true"`
	SpawnedAt  time.Time `json:"spawned_at" gorm:"autoCreateTime"`

	// Relationships
	Zone *Zone `json:"zone,omitempty" gorm:"foreignKey:ZoneID"`
}

// ✅ OPRAVENÉ: Player Session s LocationWithAccuracy pre last_location
type PlayerSession struct {
	BaseModel
	UserID      uuid.UUID  `json:"user_id" gorm:"not null;index"`
	LastSeen    time.Time  `json:"last_seen" gorm:"autoUpdateTime"`
	IsOnline    bool       `json:"is_online" gorm:"default:true"`
	CurrentZone *uuid.UUID `json:"current_zone,omitempty" gorm:"index"`

	// ✅ OPRAVENÉ: Use individual fields instead of embedded struct for last_location
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
