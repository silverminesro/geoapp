package redis

import (
	"context"
	"encoding/json"
	"time"

	"github.com/redis/go-redis/v9"
)

// ✅ OPRAVENÉ: Removed duplicate ctx declaration
// Using context.Background() directly instead

// SetWithExpiration - helper pre setting s TTL
func SetWithExpiration(client *redis.Client, key string, value interface{}, ttl time.Duration) error {
	if client == nil {
		return nil // Skip if Redis unavailable
	}

	jsonValue, err := json.Marshal(value)
	if err != nil {
		return err
	}

	// ✅ Using context.Background() directly
	return client.Set(context.Background(), key, jsonValue, ttl).Err()
}

// Delete - helper pre deleting keys
func Delete(client *redis.Client, key string) error {
	if client == nil {
		return nil // Skip if Redis unavailable
	}

	// ✅ Using context.Background() directly
	return client.Del(context.Background(), key).Err()
}

// Get - helper pre getting values
func Get(client *redis.Client, key string) (string, error) {
	if client == nil {
		return "", nil // Skip if Redis unavailable
	}

	// ✅ Using context.Background() directly
	return client.Get(context.Background(), key).Result()
}

// Exists - helper pre checking if key exists
func Exists(client *redis.Client, key string) (bool, error) {
	if client == nil {
		return false, nil // Skip if Redis unavailable
	}

	// ✅ Using context.Background() directly
	count, err := client.Exists(context.Background(), key).Result()
	return count > 0, err
}

// SetExpire - helper pre setting expiry on existing key
func SetExpire(client *redis.Client, key string, ttl time.Duration) error {
	if client == nil {
		return nil // Skip if Redis unavailable
	}

	// ✅ Using context.Background() directly
	return client.Expire(context.Background(), key, ttl).Err()
}

// Increment - helper pre incrementing numeric values
func Increment(client *redis.Client, key string) (int64, error) {
	if client == nil {
		return 0, nil // Skip if Redis unavailable
	}

	// ✅ Using context.Background() directly
	return client.Incr(context.Background(), key).Result()
}

// GetJSON - helper pre getting JSON values and unmarshaling
func GetJSON(client *redis.Client, key string, dest interface{}) error {
	if client == nil {
		return nil // Skip if Redis unavailable
	}

	// ✅ Using context.Background() directly
	val, err := client.Get(context.Background(), key).Result()
	if err != nil {
		return err
	}

	return json.Unmarshal([]byte(val), dest)
}

// SetJSON - helper pre marshaling and setting JSON values
func SetJSON(client *redis.Client, key string, value interface{}, ttl time.Duration) error {
	if client == nil {
		return nil // Skip if Redis unavailable
	}

	jsonValue, err := json.Marshal(value)
	if err != nil {
		return err
	}

	// ✅ Using context.Background() directly
	return client.Set(context.Background(), key, jsonValue, ttl).Err()
}

// DeleteMultiple - helper pre deleting multiple keys at once
func DeleteMultiple(client *redis.Client, keys ...string) error {
	if client == nil || len(keys) == 0 {
		return nil // Skip if Redis unavailable or no keys
	}

	// ✅ Using context.Background() directly
	return client.Del(context.Background(), keys...).Err()
}

// GetTTL - helper pre getting time to live of a key
func GetTTL(client *redis.Client, key string) (time.Duration, error) {
	if client == nil {
		return 0, nil // Skip if Redis unavailable
	}

	// ✅ Using context.Background() directly
	return client.TTL(context.Background(), key).Result()
}
