package user

import (
	"net/http"
	"strconv"
	"time"

	"geoapp/internal/common"
	"geoapp/pkg/redis"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	redis_client "github.com/redis/go-redis/v9"
	"gorm.io/gorm"
)

type Handler struct {
	db    *gorm.DB
	redis *redis_client.Client
}

type UpdateProfileRequest struct {
	Username string `json:"username,omitempty" binding:"omitempty,min=3,max=50"`
	Email    string `json:"email,omitempty" binding:"omitempty,email"`
}

type UpdateLocationRequest struct {
	Latitude  float64 `json:"latitude" binding:"required,min=-90,max=90"`
	Longitude float64 `json:"longitude" binding:"required,min=-180,max=180"`
	Accuracy  float64 `json:"accuracy,omitempty"`
}

type UserProfileResponse struct {
	ID           uuid.UUID              `json:"id"`
	Username     string                 `json:"username"`
	Email        string                 `json:"email"`
	Tier         int                    `json:"tier"`
	IsActive     bool                   `json:"is_active"`
	CreatedAt    time.Time              `json:"created_at"`
	LastLocation *common.Location       `json:"last_location,omitempty"`
	Stats        UserStats              `json:"stats"`
	Inventory    []common.InventoryItem `json:"inventory,omitempty"`
}

type UserStats struct {
	TotalArtifacts int `json:"total_artifacts"`
	TotalGear      int `json:"total_gear"`
	ZonesVisited   int `json:"zones_visited"`
	Level          int `json:"level"`
}

func NewHandler(db *gorm.DB, redisClient *redis_client.Client) *Handler {
	return &Handler{
		db:    db,
		redis: redisClient,
	}
}

// GetProfile - získanie profilu používateľa
func (h *Handler) GetProfile(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found in context"})
		return
	}

	// Pokús sa najskôr z cache
	cacheKey := "user_profile:" + userID.(uuid.UUID).String()

	var user common.User
	if err := h.db.Preload("Inventory").First(&user, "id = ?", userID).Error; err != nil {
		if err == gorm.ErrRecordNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch user"})
		return
	}

	// Vypočítaj štatistiky
	stats := h.calculateUserStats(user.ID)

	response := UserProfileResponse{
		ID:           user.ID,
		Username:     user.Username,
		Email:        user.Email,
		Tier:         user.Tier,
		IsActive:     user.IsActive,
		CreatedAt:    user.CreatedAt,
		LastLocation: user.LastLocation,
		Stats:        stats,
		Inventory:    user.Inventory,
	}

	// Cachuj na 5 minút
	redis.SetWithExpiration(h.redis, cacheKey, response, 5*time.Minute)

	c.JSON(http.StatusOK, response)
}

// UpdateProfile - aktualizácia profilu
func (h *Handler) UpdateProfile(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found in context"})
		return
	}

	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Nájdi používateľa
	var user common.User
	if err := h.db.First(&user, "id = ?", userID).Error; err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Aktualizuj len poskytnuté polia
	updates := make(map[string]interface{})

	if req.Username != "" {
		// Skontroluj či username už neexistuje
		var existingUser common.User
		if err := h.db.Where("username = ? AND id != ?", req.Username, userID).First(&existingUser).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "Username already exists"})
			return
		}
		updates["username"] = req.Username
	}

	if req.Email != "" {
		// Skontroluj či email už neexistuje
		var existingUser common.User
		if err := h.db.Where("email = ? AND id != ?", req.Email, userID).First(&existingUser).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{"error": "Email already exists"})
			return
		}
		updates["email"] = req.Email
	}

	// Aktualizuj v databáze
	if len(updates) > 0 {
		if err := h.db.Model(&user).Updates(updates).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update profile"})
			return
		}

		// Vymaž cache
		cacheKey := "user_profile:" + userID.(uuid.UUID).String()
		redis.Delete(h.redis, cacheKey)
	}

	// Vráť aktualizovaný profil
	h.GetProfile(c)
}

// GetInventory - získanie inventára
func (h *Handler) GetInventory(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found in context"})
		return
	}

	// Parametre pre pagináciu
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	itemType := c.Query("type") // artifact, gear

	if page < 1 {
		page = 1
	}
	if limit < 1 || limit > 100 {
		limit = 50
	}

	offset := (page - 1) * limit

	// Query pre inventár
	query := h.db.Where("user_id = ?", userID)

	if itemType != "" {
		query = query.Where("item_type = ?", itemType)
	}

	var inventory []common.InventoryItem
	var totalCount int64

	// Spočítaj celkový počet
	query.Model(&common.InventoryItem{}).Count(&totalCount)

	// Získaj items s pagináciou
	if err := query.Limit(limit).Offset(offset).Order("acquired_at DESC").Find(&inventory).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory"})
		return
	}

	// Odpoveď s metadátami
	response := gin.H{
		"items": inventory,
		"pagination": gin.H{
			"current_page":   page,
			"total_pages":    (totalCount + int64(limit) - 1) / int64(limit),
			"total_items":    totalCount,
			"items_per_page": limit,
		},
	}

	c.JSON(http.StatusOK, response)
}

// UpdateLocation - aktualizácia GPS pozície
func (h *Handler) UpdateLocation(c *gin.Context) {
	userID, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not found in context"})
		return
	}

	var req UpdateLocationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Validácia GPS súradníc
	if !isValidGPSCoordinate(req.Latitude, req.Longitude) {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid GPS coordinates"})
		return
	}

	// Aktualizuj pozíciu v databáze
	location := common.Location{
		Latitude:  req.Latitude,
		Longitude: req.Longitude,
		Accuracy:  req.Accuracy,
		Timestamp: time.Now(),
	}

	updates := map[string]interface{}{
		"last_location_latitude":  location.Latitude,
		"last_location_longitude": location.Longitude,
		"last_location_accuracy":  location.Accuracy,
		"last_location_timestamp": location.Timestamp,
	}

	if err := h.db.Model(&common.User{}).Where("id = ?", userID).Updates(updates).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update location"})
		return
	}

	// Aktualizuj aj player session pre real-time tracking
	h.updatePlayerSession(userID.(uuid.UUID), location)

	// Vymaž cache
	cacheKey := "user_profile:" + userID.(uuid.UUID).String()
	redis.Delete(h.redis, cacheKey)

	c.JSON(http.StatusOK, gin.H{
		"message":  "Location updated successfully",
		"location": location,
	})
}

// Pomocné funkcie
func (h *Handler) calculateUserStats(userID uuid.UUID) UserStats {
	var stats UserStats

	// Spočítaj artefakty
	h.db.Model(&common.InventoryItem{}).Where("user_id = ? AND item_type = ?", userID, "artifact").Count(&stats.TotalArtifacts)

	// Spočítaj gear
	h.db.Model(&common.InventoryItem{}).Where("user_id = ? AND item_type = ?", userID, "gear").Count(&stats.TotalGear)

	// Zóny navštívené (zatiaľ 0, implementujeme neskôr)
	stats.ZonesVisited = 0

	// Level na základe celkového počtu items
	totalItems := stats.TotalArtifacts + stats.TotalGear
	stats.Level = calculateLevel(totalItems)

	return stats
}

func (h *Handler) updatePlayerSession(userID uuid.UUID, location common.Location) {
	session := common.PlayerSession{
		UserID:       userID,
		LastSeen:     time.Now(),
		IsOnline:     true,
		LastLocation: location,
	}

	// Upsert player session
	h.db.Where("user_id = ?", userID).Assign(session).FirstOrCreate(&session)
}

func isValidGPSCoordinate(lat, lng float64) bool {
	return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
}

func calculateLevel(totalItems int) int {
	// Jednoduchá formula pre level
	// Level 1: 0-9 items
	// Level 2: 10-24 items
	// Level 3: 25-49 items
	// atď.
	if totalItems < 10 {
		return 1
	} else if totalItems < 25 {
		return 2
	} else if totalItems < 50 {
		return 3
	} else if totalItems < 100 {
		return 4
	} else {
		return 5 + (totalItems-100)/50
	}
}
