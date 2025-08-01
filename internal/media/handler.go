// internal/media/handler.go
package media

import (
	"crypto/md5"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) GetImage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	filename := c.Param("filename")

	// 📊 Audit logging
	log.Printf("🖼️ [AUDIT] User %v accessing image: %s (R2 cost incurred)", userID, filename)

	h.serveImage(c, filename, userID)
}

func (h *Handler) GetArtifactImage(c *gin.Context) {
	userID, _ := c.Get("user_id")
	artifactType := c.Param("type")

	// 🔒 User ownership validation
	if !h.service.UserOwnsArtifact(userID, artifactType) {
		log.Printf("🚫 [SECURITY] User %v denied access to artifact: %s (not owned)", userID, artifactType)
		c.JSON(http.StatusForbidden, gin.H{"error": "Access denied - artifact not owned"})
		return
	}

	filename, exists := h.service.GetArtifactImage(artifactType)
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{"error": "Artifact type not found"})
		return
	}

	// 📊 Audit logging
	log.Printf("🎨 [AUDIT] User %v accessing artifact image: %s -> %s (R2 cost incurred)", userID, artifactType, filename)

	h.serveImage(c, filename, userID)
}

// Helper funkcia pre serving obrázkov
func (h *Handler) serveImage(c *gin.Context, filename string, userID interface{}) {
	obj, err := h.service.GetObject(c.Request.Context(), filename)
	if err != nil {
		log.Printf("❌ [ERROR] Failed to get image %s for user %v: %v", filename, userID, err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Image not found"})
		return
	}
	defer obj.Close()

	stat, err := obj.Stat()
	if err != nil {
		log.Printf("❌ [ERROR] Failed to read image metadata %s: %v", filename, err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Cannot read image metadata"})
		return
	}

	// 🏎️ Cache headers pre optimalizáciu
	etag := generateETag(filename, stat.LastModified)
	c.Header("Content-Type", stat.ContentType)
	c.Header("Content-Length", strconv.FormatInt(stat.Size, 10))
	c.Header("Cache-Control", "private, max-age=3600") // 1 hodina cache pre authenticated users
	c.Header("ETag", etag)
	c.Header("Last-Modified", stat.LastModified.Format(http.TimeFormat))

	// Check If-None-Match header (ETag validation)
	if match := c.GetHeader("If-None-Match"); match == etag {
		c.Status(http.StatusNotModified)
		return
	}

	// 📊 Success audit log
	log.Printf("✅ [AUDIT] Successfully served image %s to user %v (size: %d bytes)", filename, userID, stat.Size)

	io.Copy(c.Writer, obj)
}

// Generate ETag for caching
func generateETag(filename string, lastModified time.Time) string {
	data := fmt.Sprintf("%s-%d", filename, lastModified.Unix())
	hash := md5.Sum([]byte(data))
	return fmt.Sprintf(`"%x"`, hash)
}
