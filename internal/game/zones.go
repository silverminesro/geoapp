package game

import (
	"fmt"
	"log"
	"math"
	"math/rand"
	"time"

	"geoapp/internal/common"

	"github.com/google/uuid"
)

// ✅ OPRAVENÉ: Zone creation with better error handling and debug
func (h *Handler) spawnDynamicZones(centerLat, centerLng float64, playerTier, count int) []common.Zone {
	var zones []common.Zone

	log.Printf("🏗️ Starting zone creation: lat=%.6f, lng=%.6f, tier=%d, count=%d", centerLat, centerLng, playerTier, count)

	zoneNames := []string{
		"Mysterious Forest", "Ancient Ruins", "Crystal Cave", "Forgotten Temple",
		"Enchanted Grove", "Shadow Valley", "Golden Hills", "Mystic Lake",
		"Dragon's Lair", "Wizard Tower", "Haunted Castle", "Sacred Grove",
	}

	for i := 0; i < count; i++ {
		// Random pozícia v rámci 7km
		lat, lng := h.generateRandomPosition(centerLat, centerLng, AreaScanRadius)
		zoneTier := h.calculateZoneTier(playerTier)

		// Expiry time
		expiryHours := ZoneMinExpiryHours + rand.Intn(ZoneMaxExpiryHours-ZoneMinExpiryHours+1)
		expiryTime := time.Now().Add(time.Duration(expiryHours) * time.Hour)

		// ✅ OPRAVENÉ: Location bez Accuracy field
		zone := common.Zone{
			BaseModel:    common.BaseModel{ID: uuid.New()},
			Name:         fmt.Sprintf("%s (T%d)", zoneNames[rand.Intn(len(zoneNames))], zoneTier),
			Description:  fmt.Sprintf("Dynamic zone spawned for tier %d players", zoneTier),
			RadiusMeters: h.calculateZoneRadius(zoneTier),
			TierRequired: zoneTier,
			Location: common.Location{
				Latitude:  lat,
				Longitude: lng,
				// ❌ REMOVED: Accuracy field (database doesn't have it)
				Timestamp: time.Now(),
			},
			ZoneType: "dynamic",
			Properties: common.JSONB{
				"spawned_by":     "player_scan",
				"expires_at":     expiryTime.Unix(),
				"spawn_tier":     playerTier,
				"despawn_reason": "timer",
				"created_at":     time.Now().Unix(),
				"zone_type":      "dynamic",
			},
			IsActive: true,
		}

		log.Printf("💾 Creating zone %d: %s at [%.6f, %.6f]", i+1, zone.Name, lat, lng)

		// ✅ OPRAVENÉ: Better error handling pre database insert
		if err := h.db.Create(&zone).Error; err != nil {
			log.Printf("❌ Failed to create zone %s: %v", zone.Name, err)
			continue
		}

		log.Printf("✅ Zone created successfully: %s (ID: %s)", zone.Name, zone.ID)

		// Spawn items v zóne
		h.spawnItemsForNewZone(zone.ID, zoneTier)

		zones = append(zones, zone)
	}

	log.Printf("🎯 Zone creation completed: %d/%d zones created successfully", len(zones), count)
	return zones
}

func (h *Handler) getExistingZonesInArea(lat, lng, radiusMeters float64) []common.Zone {
	var zones []common.Zone

	// ✅ OPRAVENÉ: Simplified query bez PostGIS dependency
	if err := h.db.Where("is_active = true").Find(&zones).Error; err != nil {
		log.Printf("❌ Failed to query zones: %v", err)
		return []common.Zone{}
	}

	// Manual distance filtering
	var filteredZones []common.Zone
	for _, zone := range zones {
		distance := calculateDistance(lat, lng, zone.Location.Latitude, zone.Location.Longitude)
		if distance <= radiusMeters {
			filteredZones = append(filteredZones, zone)
		}
	}

	log.Printf("📍 Found %d zones in area (radius: %.0fm)", len(filteredZones), radiusMeters)
	return filteredZones
}

func (h *Handler) countDynamicZonesInArea(lat, lng, radiusMeters float64) int {
	zones := h.getExistingZonesInArea(lat, lng, radiusMeters)
	count := 0
	for _, zone := range zones {
		if zone.ZoneType == "dynamic" {
			count++
		}
	}
	return count
}

func (h *Handler) buildZoneDetails(zone common.Zone, playerLat, playerLng float64, playerTier int) ZoneWithDetails {
	distance := calculateDistance(playerLat, playerLng, zone.Location.Latitude, zone.Location.Longitude)

	// Počet aktívnych items
	var artifactCount, gearCount int64
	h.db.Model(&common.Artifact{}).Where("zone_id = ? AND is_active = true", zone.ID).Count(&artifactCount)
	h.db.Model(&common.Gear{}).Where("zone_id = ? AND is_active = true", zone.ID).Count(&gearCount)

	// Počet aktívnych hráčov
	var playerCount int64
	h.db.Model(&common.PlayerSession{}).Where("current_zone = ? AND is_online = true AND last_seen > ?", zone.ID, time.Now().Add(-5*time.Minute)).Count(&playerCount)

	details := ZoneWithDetails{
		Zone:            zone,
		DistanceMeters:  distance,
		CanEnter:        playerTier >= zone.TierRequired,
		ActiveArtifacts: int(artifactCount),
		ActiveGear:      int(gearCount),
		ActivePlayers:   int(playerCount),
	}

	// Expiry info pre dynamic zones
	if zone.ZoneType == "dynamic" {
		if expiryTime, exists := zone.Properties["expires_at"]; exists {
			if expiryTimestamp, ok := expiryTime.(float64); ok {
				expiry := int64(expiryTimestamp)
				details.ExpiresAt = &expiry

				timeLeft := time.Until(time.Unix(expiry, 0))
				if timeLeft > 0 {
					timeLeftStr := formatDuration(timeLeft)
					details.TimeToExpiry = &timeLeftStr
				}
			}
		}
	}

	return details
}

// Helper functions
func (h *Handler) calculateMaxZones(playerTier int) int {
	switch playerTier {
	case 1:
		return 3
	case 2:
		return 5
	case 3:
		return 7
	case 4:
		return 10
	default:
		return 2
	}
}

func (h *Handler) calculateZoneTier(playerTier int) int {
	minTier := int(math.Max(1, float64(playerTier-1)))
	maxTier := int(math.Min(4, float64(playerTier+1)))
	return minTier + rand.Intn(maxTier-minTier+1)
}

func (h *Handler) calculateZoneRadius(tier int) int {
	switch tier {
	case 1:
		return 150
	case 2:
		return 200
	case 3:
		return 250
	case 4:
		return 300
	default:
		return 100
	}
}

func (h *Handler) generateRandomPosition(centerLat, centerLng, radiusMeters float64) (float64, float64) {
	angle := rand.Float64() * 2 * math.Pi
	distance := rand.Float64() * radiusMeters
	earthRadius := 6371000.0

	latOffset := (distance * math.Cos(angle)) / earthRadius * (180 / math.Pi)
	lngOffset := (distance * math.Sin(angle)) / earthRadius * (180 / math.Pi) / math.Cos(centerLat*math.Pi/180)

	return centerLat + latOffset, centerLng + lngOffset
}
