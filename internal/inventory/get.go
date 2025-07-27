package inventory

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"geoanomaly/internal/common"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// GET /api/v1/inventory/items
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

// GET /api/v1/inventory/items/:id
func (h *Handler) GetItemDetail(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	itemID := c.Param("id")
	if itemID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Item ID required"})
		return
	}

	// Parse UUID
	itemUUID, err := uuid.Parse(itemID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid item UUID"})
		return
	}

	var item common.InventoryItem
	if err := h.db.Where("id = ? AND user_id = ? AND deleted_at IS NULL", itemUUID, userID).First(&item).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Item not found"})
		return
	}

	// Doplníme image_url/icon ak chýbajú (ak máš utils, inak vynechaj)
	if item.Properties != nil {
		if item.Properties["image_url"] == nil {
			item.Properties["image_url"] = GenerateImageURL(item.ItemType, item.Properties)
		}
		if item.Properties["icon"] == nil {
			item.Properties["icon"] = GenerateIconKey(item.ItemType, item.Properties)
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"item":      item,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
