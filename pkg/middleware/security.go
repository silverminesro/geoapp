package middleware

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/redis/go-redis/v9"
)

type SecurityMiddleware struct {
	client *redis.Client
}

// Blacklisted IPs from recent attacks
var blacklistedIPs = map[string]bool{
	"35.193.149.100": true,
	"185.91.127.107": true,
	"185.169.4.150":  true,
	"204.76.203.193": true,
}

// Suspicious paths that indicate attacks
var suspiciousPaths = []string{
	"/boaform/", "/admin/", "/.env", "/wp-admin/",
	"/.git/", "/config", "/json", "/api/v1/",
	"/phpmyadmin/", "/.well-known/", "/xmlrpc.php",
	"/wp-content/", "/cgi-bin/", "/vendor/",
	"/backup/", "/db/", "/database/", "/sql/",
	"/config.php", "/wp-config.php", "/.htaccess",
	"/robots.txt", "/sitemap.xml", "/feed",
}

// 🛡️ HLAVNÁ FUNKCIA: Security middleware s Redis
func Security(client *redis.Client) gin.HandlerFunc {
	sm := &SecurityMiddleware{client: client}
	return sm.securityCheck()
}

// 🛡️ NOVÁ FUNKCIA: Basic security bez Redis
func BasicSecurity() gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := c.ClientIP()
		method := c.Request.Method
		path := c.Request.URL.Path
		userAgent := c.Request.UserAgent()

		// 1. 🚨 CONNECT method blocking (najdôležitejšie!)
		if method == "CONNECT" {
			log.Printf("🚨 [SECURITY] CONNECT ATTACK from: %s - BLOCKED (no Redis)", clientIP)
			blacklistedIPs[clientIP] = true // Pridaj do in-memory blacklistu
			c.JSON(http.StatusMethodNotAllowed, gin.H{
				"error": "Method not allowed",
				"code":  "CONNECT_BLOCKED",
			})
			c.Abort()
			return
		}

		// 2. 🚫 Basic blacklist check (in-memory only)
		if blacklistedIPs[clientIP] {
			log.Printf("🚫 [SECURITY] BLOCKED blacklisted IP: %s %s %s", clientIP, method, path)
			c.JSON(http.StatusForbidden, gin.H{
				"error": "Access denied",
				"code":  "IP_BLACKLISTED",
			})
			c.Abort()
			return
		}

		// 3. ⚠️ Basic suspicious path detection
		for _, suspPath := range suspiciousPaths {
			if strings.Contains(path, suspPath) {
				log.Printf("⚠️ [SECURITY] SUSPICIOUS PATH from %s: %s %s", clientIP, method, path)
				// Auto-blacklist after suspicious path attempt
				blacklistedIPs[clientIP] = true
				c.JSON(http.StatusNotFound, gin.H{
					"error": "Not found",
				})
				c.Abort()
				return
			}
		}

		// 4. 🤖 Basic bot detection
		if isSuspiciousBot(userAgent) {
			log.Printf("🤖 [SECURITY] SUSPICIOUS BOT from %s: %s", clientIP, userAgent)
			// Don't auto-blacklist bots immediately in basic mode
		}

		// 5. ✅ Log legitimate traffic (except health checks)
		if path != "/health" && path != "/api/v1/health" && path != "/api/v1/system/health" {
			log.Printf("✅ [SECURITY] ALLOWED: %s %s %s", clientIP, method, path)
		}

		c.Next()
	}
}

// 🛡️ REDIS SECURITY CHECK (plná funkcionalita)
func (sm *SecurityMiddleware) securityCheck() gin.HandlerFunc {
	return func(c *gin.Context) {
		clientIP := c.ClientIP()
		method := c.Request.Method
		path := c.Request.URL.Path
		userAgent := c.Request.UserAgent()

		// 1. 🚫 Blacklist check
		if blacklistedIPs[clientIP] {
			log.Printf("🚫 [SECURITY] BLOCKED blacklisted IP: %s %s %s", clientIP, method, path)
			c.JSON(http.StatusForbidden, gin.H{
				"error": "Access denied",
				"code":  "IP_BLACKLISTED",
			})
			c.Abort()
			return
		}

		// 2. 🚨 CONNECT method attack (KRITICKÉ!)
		if method == "CONNECT" {
			log.Printf("🚨 [SECURITY] CONNECT ATTACK from: %s - AUTO BLACKLISTING", clientIP)

			// Auto-blacklist CONNECT attackers
			blacklistedIPs[clientIP] = true
			sm.saveToRedisBlacklist(clientIP, "CONNECT_ATTACK")

			c.JSON(http.StatusMethodNotAllowed, gin.H{
				"error": "Method not allowed",
				"code":  "CONNECT_BLOCKED",
			})
			c.Abort()
			return
		}

		// 3. ⚠️ Suspicious path detection
		for _, suspPath := range suspiciousPaths {
			if strings.Contains(path, suspPath) {
				log.Printf("⚠️ [SECURITY] SUSPICIOUS PATH from %s: %s %s", clientIP, method, path)

				// Count suspicious attempts
				suspCount := sm.incrementSuspiciousCount(clientIP)

				if suspCount >= 3 {
					log.Printf("🚫 [SECURITY] AUTO-BLACKLISTED: %s (3+ suspicious attempts)", clientIP)
					blacklistedIPs[clientIP] = true
					sm.saveToRedisBlacklist(clientIP, "SUSPICIOUS_PATHS")
				}

				c.JSON(http.StatusNotFound, gin.H{
					"error": "Not found",
				})
				c.Abort()
				return
			}
		}

		// 4. 🤖 Bot detection (advanced)
		if sm.isSuspiciousBot(userAgent) {
			log.Printf("🤖 [SECURITY] SUSPICIOUS BOT from %s: %s", clientIP, userAgent)

			botCount := sm.incrementBotCount(clientIP)
			if botCount >= 5 {
				log.Printf("🚫 [SECURITY] AUTO-BLACKLISTED: %s (5+ bot attempts)", clientIP)
				blacklistedIPs[clientIP] = true
				sm.saveToRedisBlacklist(clientIP, "BOT_DETECTION")
			}
		}

		// 5. 📊 Enhanced rate limiting for unauthenticated users
		if _, exists := c.Get("user_id"); !exists {
			if !sm.checkUnauthenticatedRateLimit(clientIP) {
				log.Printf("🚫 [SECURITY] UNAUTHENTICATED RATE LIMIT: %s", clientIP)
				c.JSON(http.StatusTooManyRequests, gin.H{
					"error":       "Too many requests",
					"message":     "Please slow down or authenticate",
					"retry_after": 60,
				})
				c.Abort()
				return
			}
		}

		// 6. 🌐 Geographic IP filtering (bonus)
		if sm.isFromSuspiciousCountry(clientIP) {
			log.Printf("🌍 [SECURITY] SUSPICIOUS COUNTRY from %s", clientIP)
			// Don't block immediately, just log for now
		}

		// 7. ✅ Log legitimate traffic (except health checks)
		if !isHealthCheckPath(path) {
			log.Printf("✅ [SECURITY] ALLOWED: %s %s %s", clientIP, method, path)
		}

		c.Next()
	}
}

// 🛡️ HELPER FUNCTIONS

func (sm *SecurityMiddleware) incrementSuspiciousCount(ip string) int {
	if sm.client == nil {
		return 1 // Basic mode - immediate action
	}

	key := fmt.Sprintf("suspicious:%s", ip)
	val, err := sm.client.Incr(context.Background(), key).Result()
	if err != nil {
		log.Printf("Redis error in incrementSuspiciousCount: %v", err)
		return 1
	}
	sm.client.Expire(context.Background(), key, 10*time.Minute)
	return int(val)
}

func (sm *SecurityMiddleware) incrementBotCount(ip string) int {
	if sm.client == nil {
		return 1 // Basic mode
	}

	key := fmt.Sprintf("bot_count:%s", ip)
	val, err := sm.client.Incr(context.Background(), key).Result()
	if err != nil {
		log.Printf("Redis error in incrementBotCount: %v", err)
		return 1
	}
	sm.client.Expire(context.Background(), key, 30*time.Minute)
	return int(val)
}

func (sm *SecurityMiddleware) checkUnauthenticatedRateLimit(ip string) bool {
	if sm.client == nil {
		return true // Basic mode - no rate limiting
	}

	key := fmt.Sprintf("unauth_rate:%s", ip)
	val, err := sm.client.Get(context.Background(), key).Result()

	var count int
	if err == redis.Nil {
		count = 0
	} else if err != nil {
		log.Printf("Redis error in checkUnauthenticatedRateLimit: %v", err)
		return true // Allow on Redis error
	} else {
		count, _ = strconv.Atoi(val)
	}

	// 20 requests per minute for unauthenticated users
	if count >= 20 {
		return false
	}

	sm.client.Incr(context.Background(), key)
	sm.client.Expire(context.Background(), key, time.Minute)
	return true
}

func (sm *SecurityMiddleware) isSuspiciousBot(userAgent string) bool {
	return isSuspiciousBot(userAgent)
}

// Static function for both modes
func isSuspiciousBot(userAgent string) bool {
	suspiciousBots := []string{
		"curl", "wget", "python", "scanner", "bot",
		"crawler", "spider", "scraper", "httpclient",
		"masscan", "nmap", "nuclei", "sqlmap",
		"gobuster", "dirb", "nikto", "burp",
		"postman", "insomnia", "httpie",
	}

	userAgentLower := strings.ToLower(userAgent)

	// Empty user agent is suspicious
	if userAgent == "" {
		return true
	}

	for _, bot := range suspiciousBots {
		if strings.Contains(userAgentLower, bot) {
			return true
		}
	}
	return false
}

func (sm *SecurityMiddleware) isFromSuspiciousCountry(ip string) bool {
	// Basic implementation - can be enhanced with GeoIP
	// For now, just check for known VPN/proxy patterns
	return strings.HasPrefix(ip, "10.") ||
		strings.HasPrefix(ip, "172.") ||
		strings.HasPrefix(ip, "192.168.")
}

func isHealthCheckPath(path string) bool {
	healthPaths := []string{
		"/health", "/api/v1/health", "/api/v1/system/health",
		"/ping", "/status", "/api/v1/status",
	}

	for _, healthPath := range healthPaths {
		if path == healthPath {
			return true
		}
	}
	return false
}

func (sm *SecurityMiddleware) saveToRedisBlacklist(ip, reason string) {
	if sm.client == nil {
		log.Printf("🛡️ [SECURITY] Redis not available - IP %s blacklisted in memory only", ip)
		return
	}

	key := fmt.Sprintf("blacklist:%s", ip)
	data := fmt.Sprintf("%s:%d", reason, time.Now().Unix())
	err := sm.client.Set(context.Background(), key, data, 24*time.Hour).Err()
	if err != nil {
		log.Printf("Redis error in saveToRedisBlacklist: %v", err)
		return
	}

	// Also save to persistent blacklist log
	logKey := "security:blacklist_log"
	logEntry := fmt.Sprintf("%s|%s|%s", ip, reason, time.Now().Format("2006-01-02 15:04:05"))
	sm.client.LPush(context.Background(), logKey, logEntry)
	sm.client.LTrim(context.Background(), logKey, 0, 999) // Keep last 1000 entries

	log.Printf("🛡️ [SECURITY] IP %s saved to Redis blacklist with reason: %s", ip, reason)
}

// 🛡️ STARTUP FUNCTIONS

// Funkcia na načítanie blacklistu z Redis pri štarte
func LoadBlacklistFromRedis(client *redis.Client) {
	if client == nil {
		log.Printf("🛡️ [SECURITY] Redis not available - using in-memory blacklist only")
		log.Printf("🛡️ [SECURITY] Loaded %d pre-configured blacklisted IPs", len(blacklistedIPs))
		return
	}

	keys, err := client.Keys(context.Background(), "blacklist:*").Result()
	if err != nil {
		log.Printf("🛡️ [SECURITY] Redis error loading blacklist: %v", err)
		return
	}

	loadedCount := 0
	for _, key := range keys {
		ip := strings.TrimPrefix(key, "blacklist:")
		if ip != "" {
			blacklistedIPs[ip] = true
			loadedCount++
		}
	}

	total := len(blacklistedIPs)
	log.Printf("🛡️ [SECURITY] Loaded %d blacklisted IPs from Redis", loadedCount)
	log.Printf("🛡️ [SECURITY] Total blacklisted IPs: %d (Redis: %d, Pre-configured: %d)",
		total, loadedCount, total-loadedCount)
}

// 🛡️ ADMIN FUNCTIONS

// Get current blacklist (for admin endpoints)
func GetBlacklist() map[string]bool {
	// Return copy to prevent external modification
	result := make(map[string]bool)
	for ip, status := range blacklistedIPs {
		result[ip] = status
	}
	return result
}

// Add IP to blacklist manually (for admin endpoints)
func AddToBlacklist(ip, reason string) {
	blacklistedIPs[ip] = true
	log.Printf("🛡️ [SECURITY] Manually blacklisted IP: %s (reason: %s)", ip, reason)
}

// Remove IP from blacklist (for admin endpoints)
func RemoveFromBlacklist(ip string) bool {
	if _, exists := blacklistedIPs[ip]; exists {
		delete(blacklistedIPs, ip)
		log.Printf("🛡️ [SECURITY] Removed IP from blacklist: %s", ip)
		return true
	}
	return false
}

// Get security stats (for admin endpoints)
func GetSecurityStats() map[string]interface{} {
	return map[string]interface{}{
		"blacklisted_ips":  len(blacklistedIPs),
		"suspicious_paths": len(suspiciousPaths),
		"connect_blocking": "enabled",
		"rate_limiting":    "enabled",
		"bot_detection":    "enabled",
		"auto_blacklist":   "enabled",
		"last_updated":     time.Now().Format("2006-01-02 15:04:05"),
	}
}
