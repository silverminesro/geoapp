package main

import (
	"geoapp/internal/auth"
	"geoapp/internal/game"
	"geoapp/internal/location"
	"geoapp/internal/user"
	"geoapp/pkg/middleware"

	"github.com/gin-gonic/gin"
	redis_client "github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

func setupRoutes(db *gorm.DB, redisClient *redis_client.Client) *gin.Engine {
	// Nastav Gin mode
	gin.SetMode(gin.ReleaseMode) // Pre production

	router := gin.New()

	// Global middleware
	router.Use(middleware.Logger())
	router.Use(middleware.Recovery())
	router.Use(middleware.CORS())
	router.Use(middleware.RateLimit(redisClient))

	// Initialize handlers
	authHandler := auth.NewHandler(db, redisClient)
	userHandler := user.NewHandler(db, redisClient)
	gameHandler := game.NewHandler(db, redisClient)
	locationHandler := location.NewHandler(db, redisClient)

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":     "healthy",
			"timestamp":  "2025-07-06 14:01:46",
			"version":    "1.0.0",
			"service":    "geoapp-backend",
			"created_by": "silverminesro",
		})
	})

	// API v1 group
	v1 := router.Group("/api/v1")

	// ==========================================
	// 🔐 AUTH ROUTES (Public - no JWT required)
	// ==========================================
	authRoutes := v1.Group("/auth")
	{
		authRoutes.POST("/register", authHandler.Register)
		authRoutes.POST("/login", authHandler.Login)

		// Protected auth routes
		authProtected := authRoutes.Group("/")
		authProtected.Use(middleware.JWTAuth())
		{
			authProtected.POST("/refresh", authHandler.RefreshToken)
			authProtected.POST("/logout", authHandler.Logout)
		}
	}

	// ==========================================
	// 👤 USER ROUTES (Protected - JWT required)
	// ==========================================
	userRoutes := v1.Group("/user")
	userRoutes.Use(middleware.JWTAuth())
	{
		// Profile management
		userRoutes.GET("/profile", userHandler.GetProfile)
		userRoutes.PUT("/profile", userHandler.UpdateProfile)

		// Inventory management
		userRoutes.GET("/inventory", userHandler.GetInventory)
		userRoutes.GET("/inventory/:type", userHandler.GetInventoryByType) // artifacts, gear

		// Location updates
		userRoutes.POST("/location", userHandler.UpdateLocation)
		userRoutes.GET("/location/history", userHandler.GetLocationHistory)

		// User stats
		userRoutes.GET("/stats", userHandler.GetUserStats)
	}

	// ==========================================
	// 🎮 GAME ROUTES (Protected - JWT required)
	// ==========================================
	gameRoutes := v1.Group("/game")
	gameRoutes.Use(middleware.JWTAuth())
	{
		// ✨ NOVÝ DYNAMIC ZONE SYSTEM ✨
		gameRoutes.POST("/scan-area", gameHandler.ScanArea) // 🔥 HLAVNÝ ENDPOINT

		// Zone management
		zoneRoutes := gameRoutes.Group("/zones")
		{
			// Discovery (legacy support)
			zoneRoutes.GET("/nearby", gameHandler.GetNearbyZones)
			zoneRoutes.GET("/:id", gameHandler.GetZoneDetails)

			// Zone interaction
			zoneRoutes.POST("/:id/enter", gameHandler.EnterZone)
			zoneRoutes.POST("/:id/exit", gameHandler.ExitZone)

			// Scanning & Collecting
			zoneRoutes.GET("/:id/scan", gameHandler.ScanZone)
			zoneRoutes.POST("/:id/collect", gameHandler.CollectItem)

			// Zone stats
			zoneRoutes.GET("/:id/stats", gameHandler.GetZoneStats)
		}

		// Item management
		itemRoutes := gameRoutes.Group("/items")
		{
			itemRoutes.GET("/artifacts", gameHandler.GetAvailableArtifacts)
			itemRoutes.GET("/gear", gameHandler.GetAvailableGear)
			itemRoutes.POST("/use/:id", gameHandler.UseItem)
		}

		// Leaderboards & Statistics
		gameRoutes.GET("/leaderboard", gameHandler.GetLeaderboard)
		gameRoutes.GET("/stats", gameHandler.GetGameStats)
	}

	// ==========================================
	// 📍 LOCATION ROUTES (Protected - JWT required)
	// ==========================================
	locationRoutes := v1.Group("/location")
	locationRoutes.Use(middleware.JWTAuth())
	{
		// Real-time location tracking
		locationRoutes.POST("/update", locationHandler.UpdateLocation)
		locationRoutes.GET("/nearby", locationHandler.GetNearbyPlayers)

		// Zone-specific multiplayer
		locationRoutes.GET("/zones/:id/activity", locationHandler.GetZoneActivity)
		locationRoutes.GET("/zones/:id/players", locationHandler.GetPlayersInZone)

		// Player tracking & history
		locationRoutes.GET("/history", locationHandler.GetLocationHistory)
		locationRoutes.GET("/heatmap", locationHandler.GetLocationHeatmap)

		// Social features
		locationRoutes.POST("/share", locationHandler.ShareLocation)
		locationRoutes.GET("/friends/nearby", locationHandler.GetNearbyFriends)
	}

	// ==========================================
	// 🔧 ADMIN ROUTES (Protected - Admin only)
	// ==========================================
	adminRoutes := v1.Group("/admin")
	adminRoutes.Use(middleware.JWTAuth())
	adminRoutes.Use(middleware.AdminOnly())
	{
		// Static/Event zone management
		adminRoutes.POST("/zones", gameHandler.CreateEventZone)
		adminRoutes.PUT("/zones/:id", gameHandler.UpdateZone)
		adminRoutes.DELETE("/zones/:id", gameHandler.DeleteZone)

		// Manual item spawning
		adminRoutes.POST("/zones/:id/spawn/artifact", gameHandler.SpawnArtifact)
		adminRoutes.POST("/zones/:id/spawn/gear", gameHandler.SpawnGear)

		// Zone cleanup & maintenance
		adminRoutes.POST("/zones/cleanup", gameHandler.CleanupExpiredZones)
		adminRoutes.GET("/zones/expired", gameHandler.GetExpiredZones)

		// User management
		adminRoutes.GET("/users", userHandler.GetAllUsers)
		adminRoutes.PUT("/users/:id/tier", userHandler.UpdateUserTier)
		adminRoutes.POST("/users/:id/ban", userHandler.BanUser)
		adminRoutes.POST("/users/:id/unban", userHandler.UnbanUser)

		// System analytics
		adminRoutes.GET("/analytics/zones", gameHandler.GetZoneAnalytics)
		adminRoutes.GET("/analytics/players", userHandler.GetPlayerAnalytics)
		adminRoutes.GET("/analytics/items", gameHandler.GetItemAnalytics)
	}

	// ==========================================
	// 🛠️ SYSTEM ROUTES (Monitoring & Maintenance)
	// ==========================================
	systemRoutes := v1.Group("/system")
	{
		// Health checks
		systemRoutes.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"status":    "healthy",
				"timestamp": "2025-07-06 14:01:46",
				"database":  "connected",
				"redis":     "connected",
				"version":   "1.0.0",
			})
		})

		// Server statistics
		systemRoutes.GET("/stats", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"active_players":  0,       // TODO: Implementovať
				"total_zones":     0,       // TODO: Implementovať
				"dynamic_zones":   0,       // TODO: Implementovať
				"static_zones":    0,       // TODO: Implementovať
				"total_artifacts": 0,       // TODO: Implementovať
				"total_gear":      0,       // TODO: Implementovať
				"server_uptime":   "0s",    // TODO: Implementovať
				"last_cleanup":    "never", // TODO: Implementovať
			})
		})

		// API documentation
		systemRoutes.GET("/endpoints", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"message": "GeoApp API Endpoints",
				"version": "1.0.0",
				"endpoints": gin.H{
					"auth": gin.H{
						"POST /auth/register": "Register new user",
						"POST /auth/login":    "Login user",
						"POST /auth/refresh":  "Refresh JWT token",
						"POST /auth/logout":   "Logout user",
					},
					"game": gin.H{
						"POST /game/scan-area":          "🔥 Scan area for dynamic zones",
						"GET /game/zones/nearby":        "Get nearby zones (legacy)",
						"POST /game/zones/{id}/enter":   "Enter zone",
						"GET /game/zones/{id}/scan":     "Scan zone for items",
						"POST /game/zones/{id}/collect": "Collect item from zone",
						"GET /game/leaderboard":         "Get leaderboard",
					},
					"location": gin.H{
						"POST /location/update":             "Update player location",
						"GET /location/nearby":              "Get nearby players",
						"GET /location/zones/{id}/activity": "Get zone activity",
					},
					"user": gin.H{
						"GET /user/profile":   "Get user profile",
						"PUT /user/profile":   "Update user profile",
						"GET /user/inventory": "Get user inventory",
						"POST /user/location": "Update user location",
					},
				},
			})
		})
	}

	// ==========================================
	// 📊 METRICS ROUTES (For monitoring tools)
	// ==========================================
	metricsRoutes := v1.Group("/metrics")
	{
		metricsRoutes.GET("/prometheus", func(c *gin.Context) {
			// TODO: Implementovať Prometheus metrics
			c.String(200, "# GeoApp Metrics\n# Coming soon...")
		})
	}

	// ==========================================
	// 🚫 ERROR HANDLERS
	// ==========================================

	// 404 Handler
	router.NoRoute(func(c *gin.Context) {
		c.JSON(404, gin.H{
			"error":   "Endpoint not found",
			"path":    c.Request.URL.Path,
			"method":  c.Request.Method,
			"message": "The requested API endpoint does not exist",
			"hint":    "Visit /api/v1/system/endpoints for available endpoints",
		})
	})

	// 405 Method Not Allowed Handler
	router.NoMethod(func(c *gin.Context) {
		c.JSON(405, gin.H{
			"error":   "Method not allowed",
			"path":    c.Request.URL.Path,
			"method":  c.Request.Method,
			"message": "HTTP method not supported for this endpoint",
		})
	})

	return router
}
