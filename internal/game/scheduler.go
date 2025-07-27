package game

import (
	"context"
	"log"
	"time"

	"gorm.io/gorm"
)

type Scheduler struct {
	db             *gorm.DB
	cleanupService *CleanupService
	ticker         *time.Ticker
	ctx            context.Context
	cancel         context.CancelFunc
	isRunning      bool
}

type SchedulerStats struct {
	IsRunning       bool      `json:"is_running"`
	LastCleanup     time.Time `json:"last_cleanup"`
	NextCleanup     time.Time `json:"next_cleanup"`
	TotalCleanups   int       `json:"total_cleanups"`
	CleanupInterval string    `json:"cleanup_interval"`
	ZonesCleaned    int       `json:"zones_cleaned"`
	ItemsRemoved    int       `json:"items_removed"`
	PlayersAffected int       `json:"players_affected"`
}

func NewScheduler(db *gorm.DB) *Scheduler {
	cleanupService := NewCleanupService(db)
	ctx, cancel := context.WithCancel(context.Background())

	return &Scheduler{
		db:             db,
		cleanupService: cleanupService,
		ctx:            ctx,
		cancel:         cancel,
		isRunning:      false,
	}
}

// ✅ Start background cleanup scheduler
func (s *Scheduler) Start() {
	if s.isRunning {
		log.Printf("⚠️ Scheduler already running")
		return
	}

	s.isRunning = true
	s.ticker = time.NewTicker(5 * time.Minute) // Every 5 minutes

	log.Printf("🕐 Zone cleanup scheduler started (5min interval)")

	// Run initial cleanup
	go func() {
		log.Printf("🧹 Running initial cleanup...")
		result := s.cleanupService.CleanupExpiredZones()
		s.logCleanupResult(result)
	}()

	// Start scheduled cleanup
	go s.run()
}

// ✅ Stop scheduler
func (s *Scheduler) Stop() {
	if !s.isRunning {
		log.Printf("⚠️ Scheduler not running")
		return
	}

	s.cancel()
	if s.ticker != nil {
		s.ticker.Stop()
	}
	s.isRunning = false

	log.Printf("🛑 Zone cleanup scheduler stopped")
}

// ✅ Main scheduler loop
func (s *Scheduler) run() {
	defer func() {
		s.isRunning = false
		if s.ticker != nil {
			s.ticker.Stop()
		}
	}()

	for {
		select {
		case <-s.ctx.Done():
			log.Printf("🛑 Scheduler context cancelled")
			return

		case <-s.ticker.C:
			log.Printf("⏰ Scheduled cleanup triggered at %s", time.Now().Format("15:04:05"))

			// Run cleanup
			result := s.cleanupService.CleanupExpiredZones()
			s.logCleanupResult(result)

			// Check for zones about to expire (30min warning)
			s.checkExpiringZones()
		}
	}
}

// ✅ Log cleanup results
func (s *Scheduler) logCleanupResult(result CleanupResult) {
	if result.CleanedCount > 0 {
		log.Printf("🎯 CLEANUP COMPLETED: %d zones cleaned, %d items removed, %d players affected",
			result.CleanedCount, result.ItemsRemoved, result.PlayersAffected)

		// Log each cleaned zone
		for _, zone := range result.ExpiredZones {
			timeExpired := time.Since(*zone.ExpiresAt)
			log.Printf("   🗑️ Cleaned: %s (expired %s ago)", zone.Name, timeExpired.Round(time.Minute))
		}
	} else {
		log.Printf("✅ No expired zones found")
	}
}

// ✅ Check for zones about to expire
func (s *Scheduler) checkExpiringZones() {
	expiringZones := s.cleanupService.GetExpiringZones(30) // 30min warning

	if len(expiringZones) > 0 {
		log.Printf("⚠️ WARNING: %d zones expiring in next 30 minutes:", len(expiringZones))
		for _, zone := range expiringZones {
			timeLeft := time.Until(*zone.ExpiresAt)
			log.Printf("   ⏰ %s expires in %s", zone.Name, timeLeft.Round(time.Minute))
		}
	}
}

// ✅ Get scheduler status
func (s *Scheduler) GetStatus() SchedulerStats {
	stats := s.cleanupService.GetCleanupStats()

	return SchedulerStats{
		IsRunning:       s.isRunning,
		LastCleanup:     time.Now(), // TODO: Track actual last cleanup time
		NextCleanup:     time.Now().Add(5 * time.Minute),
		CleanupInterval: "5 minutes",
		ZonesCleaned:    int(stats["cleaned_zones"].(int64)),
		// TODO: Track cumulative stats
	}
}

// ✅ Force immediate cleanup
func (s *Scheduler) ForceCleanup() CleanupResult {
	log.Printf("🔧 Force cleanup triggered manually")
	return s.cleanupService.CleanupExpiredZones()
}

// ✅ Health check
func (s *Scheduler) IsHealthy() bool {
	return s.isRunning
}
