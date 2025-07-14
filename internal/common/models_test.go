package common

import (
	"testing"
)

func TestJSONB_MarshalUnmarshal(t *testing.T) {
	original := JSONB{"foo": "bar"}
	bytes, err := original.Value()
	if err != nil {
		t.Fatalf("marshal failed: %v", err)
	}
	var j JSONB
	if err := j.Scan(bytes); err != nil {
		t.Fatalf("unmarshal failed: %v", err)
	}
	if j["foo"] != "bar" {
		t.Errorf("got %v, want %v", j["foo"], "bar")
	}
}
func IsValidGPSCoordinate(lat, lng float64) bool {
	return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
}
func TestIsValidGPSCoordinate(t *testing.T) {
	tests := []struct {
		lat, lng float64
		valid    bool
	}{
		{0, 0, true},
		{90, 180, true},
		{-90, -180, true},
		{91, 0, false},
		{0, 181, false},
		{-91, 0, false},
		{0, -181, false},
	}
	for _, tt := range tests {
		got := IsValidGPSCoordinate(tt.lat, tt.lng)
		if got != tt.valid {
			t.Errorf("IsValidGPSCoordinate(%v, %v) = %v; want %v", tt.lat, tt.lng, got, tt.valid)
		}
	}
}
