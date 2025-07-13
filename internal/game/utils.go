package game

import (
	"context"
	"fmt"
	"math"
	"time"
)

// Rate limiting functions
func (h *Handler) checkAreaScanRateLimit(key string) bool {
	return h.checkRateLimit(key, 1, AreaScanCooldown*time.Minute)
}

func (h *Handler) checkRateLimit(key string, limit int, duration time.Duration) bool {
	if h.redis == nil {
		return true // Allow if Redis unavailable
	}

	count, err := h.redis.Get(context.Background(), key).Int()
	if err != nil {
		return true // Allow if Redis error
	}

	if count >= limit {
		return false
	}

	h.redis.Incr(context.Background(), key)
	h.redis.Expire(context.Background(), key, duration)
	return true
}

// ✅ EXPORTED: Utility functions for zones package
func CalculateDistance(lat1, lon1, lat2, lon2 float64) float64 {
	dlat := (lat2 - lat1) * (math.Pi / 180.0)
	dlon := (lon2 - lon1) * (math.Pi / 180.0)

	a := math.Sin(dlat/2)*math.Sin(dlat/2) + math.Cos(lat1*(math.Pi/180.0))*math.Cos(lat2*(math.Pi/180.0))*math.Sin(dlon/2)*math.Sin(dlon/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))

	return EarthRadiusKm * c * 1000
}

func IsValidGPSCoordinate(lat, lng float64) bool {
	return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
}

func FormatDuration(d time.Duration) string {
	if d < time.Hour {
		return fmt.Sprintf("%dm", int(d.Minutes()))
	}
	if d < 24*time.Hour {
		return fmt.Sprintf("%dh %dm", int(d.Hours()), int(d.Minutes())%60)
	}
	return fmt.Sprintf("%dd %dh", int(d.Hours()/24), int(d.Hours())%24)
}
