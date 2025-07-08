package middleware

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// AdminOnly middleware - requires tier >= 4 for admin access
func AdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get tier from JWT context (set by JWTAuth middleware)
		tier, exists := c.Get("tier")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error":   "Authentication required",
				"message": "Please login first",
			})
			c.Abort()
			return
		}

		// Check if user has admin tier (4 or higher)
		userTier, ok := tier.(int)
		if !ok || userTier < 4 {
			c.JSON(http.StatusForbidden, gin.H{
				"error":         "Admin access required",
				"message":       "You need admin privileges to access this resource",
				"required_tier": 4,
				"your_tier":     userTier,
			})
			c.Abort()
			return
		}

		// User is admin, continue to next handler
		c.Next()
	}
}

// SuperAdminOnly middleware - requires tier >= 5 for super admin access
func SuperAdminOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		tier, exists := c.Get("tier")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Authentication required",
			})
			c.Abort()
			return
		}

		userTier, ok := tier.(int)
		if !ok || userTier < 5 {
			c.JSON(http.StatusForbidden, gin.H{
				"error":         "Super admin access required",
				"required_tier": 5,
				"your_tier":     userTier,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}

// ModeratorOnly middleware - requires tier >= 3 for moderator access
func ModeratorOnly() gin.HandlerFunc {
	return func(c *gin.Context) {
		tier, exists := c.Get("tier")
		if !exists {
			c.JSON(http.StatusUnauthorized, gin.H{
				"error": "Authentication required",
			})
			c.Abort()
			return
		}

		userTier, ok := tier.(int)
		if !ok || userTier < 3 {
			c.JSON(http.StatusForbidden, gin.H{
				"error":         "Moderator access required",
				"required_tier": 3,
				"your_tier":     userTier,
			})
			c.Abort()
			return
		}

		c.Next()
	}
}
