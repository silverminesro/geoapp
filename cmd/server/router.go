package main

import (
	"time"

	"geoanomaly/internal/auth"
	"geoanomaly/internal/common"
	"geoanomaly/internal/game"
	"geoanomaly/internal/location"
	"geoanomaly/internal/user"
	"geoanomaly/pkg/middleware"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

// ✅ FIXED: Removed zones import - all functionality is now in game package
func setupRoutes(db *gorm.DB) *gin.Engine {
	gin.SetMode(gin.ReleaseMode)

	router := gin.New()

	// Global middleware
	router.Use(middleware.Logger())
	router.Use(middleware.Recovery())
	router.Use(middleware.CORS())

	// ✅ SIMPLIFIED: Only main handlers (zones functionality merged into game)
	authHandler := auth.NewHandler(db, nil)
	userHandler := user.NewHandler(db, nil)
	gameHandler := game.NewHandler(db, nil) // ✅ Contains all game + zones functionality
	locationHandler := location.NewHandler(db, nil)

	// Health check endpoint
	router.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":     "healthy",
			"timestamp":  time.Now().Format(time.RFC3339),
			"version":    "1.0.0",
			"service":    "geoanomaly-backend",
			"created_by": "silverminesro",
			"structure":  "unified", // ✅ UPDATED
		})
	})

	// Basic info endpoint
	router.GET("/info", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"name":        "GeoAnomaly Backend",
			"version":     "1.0.0",
			"environment": getEnvVar("APP_ENV", "development"),
			"uptime":      time.Since(startTime).String(),
			"developer":   "silverminesro",
			"database":    getEnvVar("DB_NAME", "geoanomaly") + "@" + getEnvVar("DB_HOST", "localhost"),
			"structure":   "unified", // ✅ UPDATED
		})
	})

	// API v1 group
	v1 := router.Group("/api/" + getEnvVar("API_VERSION", "v1"))
	{
		// Basic test endpoints
		v1.GET("/test", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"message":   "🎮 GeoAnomaly API is working perfectly!",
				"time":      time.Now().Format(time.RFC3339),
				"endpoint":  "/api/v1/test",
				"developer": "silverminesro",
				"status":    "operational",
				"version":   "unified-structure", // ✅ UPDATED
			})
		})

		// Database test endpoint
		v1.GET("/db-test", func(c *gin.Context) {
			var tierCount int64
			var levelCount int64
			var userCount int64
			var zoneCount int64

			db.Raw("SELECT COUNT(*) FROM tier_definitions").Scan(&tierCount)
			db.Raw("SELECT COUNT(*) FROM level_definitions").Scan(&levelCount)
			db.Model(&common.User{}).Count(&userCount)
			db.Model(&common.Zone{}).Count(&zoneCount)

			c.JSON(200, gin.H{
				"database": "connected",
				"status":   "operational",
				"stats": gin.H{
					"tiers":  tierCount,
					"levels": levelCount,
					"users":  userCount,
					"zones":  zoneCount,
				},
				"message":   "Database connection successful! 🎯",
				"timestamp": time.Now().Format(time.RFC3339),
			})
		})

		// User test endpoint
		v1.GET("/users", func(c *gin.Context) {
			var users []common.User
			result := db.Limit(10).Find(&users)

			if result.Error != nil {
				c.JSON(500, gin.H{
					"error":   "Failed to query users",
					"message": result.Error.Error(),
				})
				return
			}

			c.JSON(200, gin.H{
				"users":     users,
				"count":     len(users),
				"total":     result.RowsAffected,
				"message":   "Users retrieved successfully",
				"timestamp": time.Now().Format(time.RFC3339),
			})
		})

		// Zone test endpoint
		v1.GET("/zones", func(c *gin.Context) {
			var zones []common.Zone
			result := db.Limit(10).Find(&zones)

			if result.Error != nil {
				c.JSON(500, gin.H{
					"error":   "Failed to query zones",
					"message": result.Error.Error(),
				})
				return
			}

			c.JSON(200, gin.H{
				"zones":     zones,
				"count":     len(zones),
				"total":     result.RowsAffected,
				"message":   "Zones retrieved successfully",
				"timestamp": time.Now().Format(time.RFC3339),
			})
		})

		// Server status endpoint
		v1.GET("/status", func(c *gin.Context) {
			sqlDB, err := db.DB()
			var dbStatus string
			if err != nil {
				dbStatus = "error"
			} else {
				if err := sqlDB.Ping(); err != nil {
					dbStatus = "disconnected"
				} else {
					dbStatus = "connected"
				}
			}

			c.JSON(200, gin.H{
				"server": gin.H{
					"status":      "running",
					"uptime":      time.Since(startTime).String(),
					"environment": getEnvVar("APP_ENV", "development"),
					"version":     "1.0.0",
					"structure":   "unified", // ✅ UPDATED
				},
				"database": gin.H{
					"status": dbStatus,
					"host":   getEnvVar("DB_HOST", "localhost"),
					"name":   getEnvVar("DB_NAME", "geoanomaly"),
				},
				"developer": "silverminesro",
				"timestamp": time.Now().Format(time.RFC3339),
			})
		})
	}

	// ==========================================
	// 🔐 AUTH ROUTES (Public - no JWT required)
	// ==========================================
	authRoutes := v1.Group("/auth")
	{
		authRoutes.POST("/register", authHandler.Register)
		authRoutes.POST("/login", authHandler.Login)

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
		userRoutes.GET("/profile", userHandler.GetProfile)
		userRoutes.PUT("/profile", userHandler.UpdateProfile)
		userRoutes.GET("/inventory", userHandler.GetInventory)
		userRoutes.GET("/inventory/:type", userHandler.GetInventoryByType)
		userRoutes.POST("/location", userHandler.UpdateLocation)
		userRoutes.GET("/location/history", userHandler.GetLocationHistory)
		userRoutes.GET("/stats", userHandler.GetUserStats)
	}

	// ==========================================
	// 🎮 GAME ROUTES (Protected - JWT required)
	// ✅ ALL HANDLED BY SINGLE gameHandler
	// ==========================================
	gameRoutes := v1.Group("/game")
	gameRoutes.Use(middleware.JWTAuth())
	{
		// ✨ MAIN GAME ENDPOINTS
		gameRoutes.POST("/scan-area", gameHandler.ScanArea) // 🔥 PRIMARY ENDPOINT

		// ✅ UNIFIED: Zone management - all handled by gameHandler
		zoneRoutes := gameRoutes.Group("/zones")
		{
			// Zone discovery
			zoneRoutes.GET("/nearby", gameHandler.GetNearbyZones)

			// Zone interaction (previously in zones package, now in game)
			zoneRoutes.GET("/:id", gameHandler.GetZoneDetails)
			zoneRoutes.POST("/:id/enter", gameHandler.EnterZone)
			zoneRoutes.POST("/:id/exit", gameHandler.ExitZone)
			zoneRoutes.GET("/:id/scan", gameHandler.ScanZone)

			// Item collection
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

		// Game statistics
		gameRoutes.GET("/leaderboard", gameHandler.GetLeaderboard)
		gameRoutes.GET("/stats", gameHandler.GetGameStats)
	}

	// ==========================================
	// 📍 LOCATION ROUTES (Protected - JWT required)
	// ==========================================
	locationRoutes := v1.Group("/location")
	locationRoutes.Use(middleware.JWTAuth())
	{
		locationRoutes.POST("/update", locationHandler.UpdateLocation)
		locationRoutes.GET("/nearby", locationHandler.GetNearbyPlayers)
		locationRoutes.GET("/zones/:id/activity", locationHandler.GetZoneActivity)
		locationRoutes.GET("/zones/:id/players", locationHandler.GetPlayersInZone)
		locationRoutes.GET("/history", locationHandler.GetLocationHistory)
		locationRoutes.GET("/heatmap", locationHandler.GetLocationHeatmap)
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
		// Zone management
		adminRoutes.POST("/zones", gameHandler.CreateEventZone)
		adminRoutes.PUT("/zones/:id", gameHandler.UpdateZone)
		adminRoutes.DELETE("/zones/:id", gameHandler.DeleteZone)

		// Item spawning
		adminRoutes.POST("/zones/:id/spawn/artifact", gameHandler.SpawnArtifact)
		adminRoutes.POST("/zones/:id/spawn/gear", gameHandler.SpawnGear)

		// Zone maintenance
		adminRoutes.POST("/zones/cleanup", gameHandler.CleanupExpiredZones)
		adminRoutes.GET("/zones/expired", gameHandler.GetExpiredZones)

		// User management
		adminRoutes.GET("/users", userHandler.GetAllUsers)
		adminRoutes.PUT("/users/:id/tier", userHandler.UpdateUserTier)
		adminRoutes.POST("/users/:id/ban", userHandler.BanUser)
		adminRoutes.POST("/users/:id/unban", userHandler.UnbanUser)

		// Analytics
		adminRoutes.GET("/analytics/zones", gameHandler.GetZoneAnalytics)
		adminRoutes.GET("/analytics/players", userHandler.GetPlayerAnalytics)
		adminRoutes.GET("/analytics/items", gameHandler.GetItemAnalytics)
	}

	// ==========================================
	// 🛠️ SYSTEM ROUTES
	// ==========================================
	systemRoutes := v1.Group("/system")
	{
		systemRoutes.GET("/health", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"status":    "healthy",
				"timestamp": time.Now().Format(time.RFC3339),
				"database":  "connected",
				"redis":     "disabled",
				"version":   "1.0.0",
				"structure": "unified",
			})
		})

		systemRoutes.GET("/stats", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"active_players":  0,
				"total_zones":     0,
				"dynamic_zones":   0,
				"static_zones":    0,
				"total_artifacts": 0,
				"total_gear":      0,
				"server_uptime":   "0s",
				"last_cleanup":    "never",
			})
		})

		// ✅ UPDATED: API documentation with unified structure
		systemRoutes.GET("/endpoints", func(c *gin.Context) {
			c.JSON(200, gin.H{
				"message":   "GeoAnomaly API Endpoints",
				"version":   "1.0.0",
				"structure": "unified",
				"packages": gin.H{
					"game":     "🎮 All game logic (zones, items, artifacts, gear, biomes)",
					"auth":     "🔐 Authentication & authorization",
					"user":     "👤 User profiles & inventory management",
					"location": "📍 Real-time location tracking & multiplayer",
				},
				"file_structure": gin.H{
					"internal/game/": gin.H{
						"handler.go":   "Main game endpoints (scan, enter, collect)",
						"zones.go":     "Zone creation & management",
						"artifacts.go": "Artifact definitions & filtering",
						"gear.go":      "Gear definitions & filtering",
						"biomes.go":    "Biome templates & zone names",
						"constants.go": "All game constants",
						"types.go":     "Type definitions",
						"utils.go":     "Utility functions",
						"filtering.go": "Tier filtering logic",
					},
				},
				"endpoints": gin.H{
					"auth": gin.H{
						"POST /auth/register": "Register new user",
						"POST /auth/login":    "Login user",
						"POST /auth/refresh":  "Refresh JWT token",
						"POST /auth/logout":   "Logout user",
					},
					"game": gin.H{
						"POST /game/scan-area":          "🔥 Scan area for dynamic zones",
						"GET /game/zones/nearby":        "Get nearby zones",
						"GET /game/zones/{id}":          "Get zone details",
						"POST /game/zones/{id}/enter":   "Enter zone",
						"POST /game/zones/{id}/exit":    "Exit zone",
						"GET /game/zones/{id}/scan":     "Scan zone for items",
						"POST /game/zones/{id}/collect": "Collect item from zone",
						"GET /game/leaderboard":         "Get leaderboard",
						"GET /game/items/artifacts":     "Get available artifacts",
						"GET /game/items/gear":          "Get available gear",
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
	// 📊 METRICS ROUTES
	// ==========================================
	metricsRoutes := v1.Group("/metrics")
	{
		metricsRoutes.GET("/prometheus", func(c *gin.Context) {
			c.String(200, "# GeoAnomaly Metrics\n# Coming soon...")
		})
	}

	// ==========================================
	// 🚫 ERROR HANDLERS
	// ==========================================
	router.NoRoute(func(c *gin.Context) {
		c.JSON(404, gin.H{
			"error":     "Endpoint not found",
			"path":      c.Request.URL.Path,
			"method":    c.Request.Method,
			"message":   "The requested API endpoint does not exist",
			"hint":      "Visit /api/v1/system/endpoints for available endpoints",
			"structure": "unified",
		})
	})

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
