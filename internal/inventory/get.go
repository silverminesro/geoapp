package inventory

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// GET /api/v1/inventory/items
func (h *Handler) GetInventory(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found"})
		return
	}

	// Get query parameters
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	itemType := c.Query("type") // "artifact" or "gear"

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 50
	}

	offset := (page - 1) * limit

	// Build query
	query := h.db.Table("inventory_items").Where("user_id = ? AND deleted_at IS NULL", userID)

	if itemType != "" {
		query = query.Where("item_type = ?", itemType)
	}

	// Get total count
	var totalCount int64
	if err := query.Count(&totalCount).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to count items",
			"details": err.Error(),
		})
		return
	}

	// Get items as maps first (to handle JSONB properly)
	var rawItems []map[string]interface{}
	if err := query.Limit(limit).Offset(offset).Order("created_at DESC").Find(&rawItems).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":   "Failed to fetch inventory",
			"details": err.Error(),
		})
		return
	}

	// Calculate pagination
	totalPages := int64(0)
	if totalCount > 0 {
		totalPages = (totalCount + int64(limit) - 1) / int64(limit)
	}

	// Format items with image URLs
	var formattedItems []gin.H
	for _, rawItem := range rawItems {
		itemData := gin.H{
			"id":         rawItem["id"],
			"user_id":    rawItem["user_id"],
			"item_type":  rawItem["item_type"],
			"item_id":    rawItem["item_id"],
			"quantity":   rawItem["quantity"],
			"created_at": rawItem["created_at"],
		}

		// Handle properties as map
		if props, ok := rawItem["properties"].(map[string]interface{}); ok {
			itemData["properties"] = props

			// Extract common properties
			if name, ok := props["name"].(string); ok {
				itemData["name"] = name
			}
			if desc, ok := props["description"].(string); ok {
				itemData["description"] = desc
			}
			if rarity, ok := props["rarity"].(string); ok {
				itemData["rarity"] = rarity
			}
			if biome, ok := props["biome"].(string); ok {
				itemData["biome"] = biome
			}

			// Add image URL based on item type
			itemTypeStr, _ := rawItem["item_type"].(string)
			if itemTypeStr == "artifact" {
				if artifactType, exists := props["type"].(string); exists {
					itemData["image_url"] = fmt.Sprintf("/api/v1/media/artifact/%s", artifactType)
				}
			} else if itemTypeStr == "gear" {
				// For gear, we might use a different pattern
				if gearType, exists := props["type"].(string); exists {
					itemData["image_url"] = fmt.Sprintf("/api/v1/media/gear/%s", gearType)
				}

				// Add equipped status for gear
				if equipped, ok := props["equipped"].(bool); ok {
					itemData["equipped"] = equipped
				}
				if slot, ok := props["slot"].(string); ok {
					itemData["slot"] = slot
				}
			}

			// Add favorite status
			if favorite, ok := props["favorite"].(bool); ok {
				itemData["favorite"] = favorite
			}
		}

		formattedItems = append(formattedItems, itemData)
	}

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

	// Get item as map to handle JSONB
	var rawItem map[string]interface{}
	if err := h.db.Table("inventory_items").Where("id = ? AND user_id = ? AND deleted_at IS NULL", itemUUID, userID).First(&rawItem).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Item not found"})
		return
	}

	// Build response with all details
	response := gin.H{
		"id":         rawItem["id"],
		"user_id":    rawItem["user_id"],
		"item_type":  rawItem["item_type"],
		"item_id":    rawItem["item_id"],
		"quantity":   rawItem["quantity"],
		"created_at": rawItem["created_at"],
	}

	// Handle properties and add image URL
	if props, ok := rawItem["properties"].(map[string]interface{}); ok {
		response["properties"] = props

		// Extract common fields
		if name, ok := props["name"].(string); ok {
			response["name"] = name
		}
		if desc, ok := props["description"].(string); ok {
			response["description"] = desc
		}
		if rarity, ok := props["rarity"].(string); ok {
			response["rarity"] = rarity
		}

		// Add image URL
		itemTypeStr, _ := rawItem["item_type"].(string)
		if itemTypeStr == "artifact" {
			if artifactType, exists := props["type"].(string); exists {
				response["image_url"] = fmt.Sprintf("/api/v1/media/artifact/%s", artifactType)
			}
		} else if itemTypeStr == "gear" {
			if gearType, exists := props["type"].(string); exists {
				response["image_url"] = fmt.Sprintf("/api/v1/media/gear/%s", gearType)
			}
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"item":      response,
		"timestamp": time.Now().Format(time.RFC3339),
	})
}
