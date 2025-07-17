package inventory

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

type Handler struct {
	db *gorm.DB
}

func NewHandler(db *gorm.DB) *Handler {
	return &Handler{db: db}
}

// GET /api/v1/inventory
func (h *Handler) GetInventory(c *gin.Context) {
	fmt.Println("🔍 GetInventory method called!")
	fmt.Printf("🔍 Request path: %s\n", c.Request.URL.Path)
	fmt.Printf("🔍 Request method: %s\n", c.Request.Method)

	userID, exists := c.Get("user_id")
	fmt.Printf("🔍 UserID from context: exists=%v, value=%v\n", exists, userID)

	if !exists {
		fmt.Println("❌ User ID not found in context!")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	fmt.Printf("✅ User ID found: %v\n", userID)

	// Get query parameters
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	itemType := c.Query("type") // "artifact" or "gear"

	fmt.Printf("🔍 Query params: page=%d, limit=%d, type=%s\n", page, limit, itemType)

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 50
	}

	offset := (page - 1) * limit

	// Build query - ✅ FIXED: Use table name explicitly
	query := h.db.Table("inventory_items").Where("user_id = ? AND deleted_at IS NULL", userID)

	if itemType != "" {
		query = query.Where("item_type = ?", itemType)
	}

	fmt.Printf("🔍 About to count items for user: %v\n", userID)

	// Get total count
	var totalCount int64
	if err := query.Count(&totalCount).Error; err != nil {
		fmt.Printf("❌ Failed to count items: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to count items",
			"details": err.Error(),
		})
		return
	}

	fmt.Printf("✅ Total items count: %d\n", totalCount)

	// Get items - ✅ FIXED: Select into slice of maps first
	var items []map[string]interface{}
	if err := query.Limit(limit).Offset(offset).Order("created_at DESC").Find(&items).Error; err != nil {
		fmt.Printf("❌ Failed to fetch inventory: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to fetch inventory",
			"details": err.Error(),
		})
		return
	}

	fmt.Printf("✅ Found %d items\n", len(items))

	// Calculate pagination
	totalPages := int64(0)
	if totalCount > 0 {
		totalPages = (totalCount + int64(limit) - 1) / int64(limit)
	}

	// ✅ FIXED: Convert to proper format
	var formattedItems []gin.H
	for _, item := range items {
		formattedItems = append(formattedItems, gin.H{
			"id":         item["id"],
			"user_id":    item["user_id"],
			"item_type":  item["item_type"],
			"item_id":    item["item_id"],
			"quantity":   item["quantity"],
			"properties": item["properties"],
			"created_at": item["created_at"],
		})
	}

	fmt.Printf("✅ Returning %d formatted items\n", len(formattedItems))

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"items":   formattedItems,
		"pagination": gin.H{
			"current_page": page,
			"total_pages":  totalPages,
			"total_items":  totalCount,
			"limit":        limit,
		},
		"filter": gin.H{
			"item_type": itemType,
		},
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// GET /api/v1/inventory/summary
func (h *Handler) GetInventorySummary(c *gin.Context) {
	fmt.Println("🔍 GetInventorySummary method called!")
	fmt.Printf("🔍 Request path: %s\n", c.Request.URL.Path)

	userID, exists := c.Get("user_id")
	fmt.Printf("🔍 UserID from context: exists=%v, value=%v\n", exists, userID)

	if !exists {
		fmt.Println("❌ User ID not found in context!")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	fmt.Printf("✅ User ID found: %v\n", userID)

	// Count by item type - ✅ FIXED: Use table name
	var artifactCount, gearCount int64
	h.db.Table("inventory_items").Where("user_id = ? AND item_type = ? AND deleted_at IS NULL", userID, "artifact").Count(&artifactCount)
	h.db.Table("inventory_items").Where("user_id = ? AND item_type = ? AND deleted_at IS NULL", userID, "gear").Count(&gearCount)

	fmt.Printf("✅ Summary counts: artifacts=%d, gear=%d\n", artifactCount, gearCount)

	// Count by rarity (from properties) - ✅ FIXED: Use raw SQL
	var rarityStats map[string]int64 = make(map[string]int64)

	rows, err := h.db.Raw(`
		SELECT 
			properties->>'rarity' as rarity,
			COUNT(*) as count
		FROM inventory_items 
		WHERE user_id = ? AND deleted_at IS NULL 
		AND properties->>'rarity' IS NOT NULL
		GROUP BY properties->>'rarity'
	`, userID).Rows()

	if err == nil {
		defer rows.Close()
		for rows.Next() {
			var rarity string
			var count int64
			if err := rows.Scan(&rarity, &count); err == nil {
				rarityStats[rarity] = count
			}
		}
	}

	fmt.Printf("✅ Rarity stats: %v\n", rarityStats)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"summary": gin.H{
			"total_items":     artifactCount + gearCount,
			"total_artifacts": artifactCount,
			"total_gear":      gearCount,
			"by_rarity":       rarityStats,
		},
		"timestamp": time.Now().Format(time.RFC3339),
	})
}

// DELETE /api/v1/inventory/:id
func (h *Handler) DeleteItem(c *gin.Context) {
	fmt.Println("🔍 DeleteItem method called!")
	fmt.Printf("🔍 Request path: %s\n", c.Request.URL.Path)

	userID, exists := c.Get("user_id")
	fmt.Printf("🔍 UserID from context: exists=%v, value=%v\n", exists, userID)

	if !exists {
		fmt.Println("❌ User ID not found in context!")
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	itemID := c.Param("id")
	fmt.Printf("🔍 Item ID from URL: %s\n", itemID)

	if itemID == "" {
		fmt.Println("❌ Item ID is empty!")
		c.JSON(http.StatusBadRequest, gin.H{"error": "Item ID required"})
		return
	}

	fmt.Printf("✅ About to delete item: %s for user: %v\n", itemID, userID)

	// Find item first - ✅ FIXED: Use raw query
	var item map[string]interface{}
	if err := h.db.Table("inventory_items").Where("id = ? AND user_id = ? AND deleted_at IS NULL", itemID, userID).First(&item).Error; err != nil {
		fmt.Printf("❌ Failed to find item: %v\n", err)
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "Item not found"})
		} else {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to find item"})
		}
		return
	}

	fmt.Printf("✅ Item found: %v\n", item["id"])

	// Soft delete - ✅ FIXED: Use raw update
	if err := h.db.Table("inventory_items").Where("id = ? AND user_id = ?", itemID, userID).Update("deleted_at", time.Now()).Error; err != nil {
		fmt.Printf("❌ Failed to delete item: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete item"})
		return
	}

	fmt.Printf("✅ Item deleted successfully: %s\n", itemID)

	// Get item name from properties
	var itemName string
	if properties, ok := item["properties"].(map[string]interface{}); ok {
		if name, exists := properties["name"]; exists {
			itemName = name.(string)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"message": "Item deleted successfully",
		"deleted_item": gin.H{
			"id":        item["id"],
			"item_type": item["item_type"],
			"name":      itemName,
		},
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
