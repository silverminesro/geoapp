package redis

import (
	"context"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/redis/go-redis/v9"
)

var ctx = context.Background()

func InitRedis() *redis.Client {
	// Get Redis configuration from environment
	host := getEnv("REDIS_HOST", "localhost")
	port := getEnv("REDIS_PORT", "6379")
	password := getEnv("REDIS_PASSWORD", "")
	dbStr := getEnv("REDIS_DB", "0")

	// Convert DB string to int
	db, err := strconv.Atoi(dbStr)
	if err != nil {
		log.Printf("⚠️  Invalid REDIS_DB value: %s, using default 0", dbStr)
		db = 0
	}

	// Create Redis client with compatible options
	client := redis.NewClient(&redis.Options{
		Addr:         host + ":" + port,
		Password:     password,
		DB:           db,
		DialTimeout:  10 * time.Second,
		ReadTimeout:  30 * time.Second,
		WriteTimeout: 30 * time.Second,
		PoolSize:     10,
		PoolTimeout:  30 * time.Second,
		// IdleTimeout removed - not supported in this version
		// MaxConnAge removed - not supported in this version
	})

	// Test connection
	_, err = client.Ping(ctx).Result()
	if err != nil {
		log.Printf("⚠️  Redis connection failed: %v", err)
		return nil // Return nil if Redis is not available
	}

	log.Printf("✅ Redis connected: %s:%s (DB: %d)", host, port, db)
	return client
}

func TestConnection(client *redis.Client) error {
	if client == nil {
		return nil // Skip test if client is nil
	}

	// Test basic operations
	testKey := "geoapp:test:connection"
	testValue := "connected"

	// Set test value
	err := client.Set(ctx, testKey, testValue, 10*time.Second).Err()
	if err != nil {
		return err
	}

	// Get test value
	val, err := client.Get(ctx, testKey).Result()
	if err != nil {
		return err
	}

	if val != testValue {
		return redis.Nil
	}

	// Clean up test key
	client.Del(ctx, testKey)

	log.Println("✅ Redis test operations successful")
	return nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
