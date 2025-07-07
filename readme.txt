Detailné Vysvetlenie:
1. cmd/server/main.go
= Spúšťač aplikácie

Go
// Tu sa spúšťa celá aplikácia
// Pripojuje databázu, Redis, spúšťa server
func main() {
    // Start server na porte 8080
}
2. internal/ = Herná Logika
internal/auth/handler.go
= Prihlásenie/Registrácia

Go
POST /auth/register  // Vytvor účet
POST /auth/login     // Prihlás sa  
POST /auth/refresh   // Obnov token
internal/user/handler.go
= Profil Hráča

Go
GET /user/profile       // Moj profil
PUT /user/profile       // Zmeň username/email
GET /user/inventory     // Môj inventár
POST /user/location     // Aktualizuj GPS
internal/game/handler.go
= Hlavná Hra

Go
GET /game/zones/nearby     // Zóny v okolí
POST /game/zones/{id}/enter // Vstúp do zóny
GET /game/zones/{id}/scan   // Čo je v zóne?
POST /game/zones/{id}/collect // Zber artefakt
internal/location/handler.go
= Multiplayer Tracking

Go
POST /location/update        // Real-time GPS
GET /location/nearby         // Hráči v zóne
GET /location/zones/{id}/activity // Aktivita
internal/common/models.go
= Databázové Modely

Go
type User struct { ... }      // Hráč
type Zone struct { ... }      // Herná zóna
type Artifact struct { ... }  // Artefakt
type Gear struct { ... }      // Vybavenie
type Inventory struct { ... } // Inventár
3. pkg/ = Pomocné Nástroje
pkg/database/
connection.go = Pripojenie k PostgreSQL
migrations.go = Vytvorenie tabuliek
pkg/middleware/
auth.go = JWT token overenie
cors.go = Prístup z Flutter app
logger.go = Logovanie requestov
rate_limiter.go = Ochrana pred spam
pkg/redis/
client.go = Redis pripojenie (cache, real-time)
🔥 Ako to Funguje:
Flutter App → Go API:
Code
📱 Flutter                    🚀 Go Backend
│
├── Login Screen           → POST /auth/login
├── Map Screen             → GET /game/zones/nearby  
├── Profile Screen         → GET /user/profile
├── Inventory Screen       → GET /user/inventory
├── Scanning Screen        → GET /game/zones/{id}/scan
└── Collecting Screen      → POST /game/zones/{id}/collect
📊 Databáza:
SQL
PostgreSQL Tables:
├── users           (hráči)
├── zones           (herné zóny)  
├── artifacts       (artefakty)
├── gear           (vybavenie)
├── inventory_items (inventár)
└── player_sessions (real-time tracking)
⚡ Redis Cache:
Code
Redis Keys:
├── user_profile:{id}     (cache profilov)
├── rate_limit:{ip}       (ochrana)
├── player_session:{id}   (real-time GPS)
└── zone_players:{zone}   (multiplayer)
🎮 Herný Tok:
Registrácia → auth/handler.go
Prihlásenie → auth/handler.go
Nájdi zóny → game/handler.go
Vstúp do zóny → game/handler.go
Naskenuj → game/handler.go
Zber items → game/handler.go
Zobraz inventár → user/handler.go
Multiplayer → location/handler.go



------------------------------------
-------D  A  T  A  B  A  Z  A-------
------------------------------------

📊 CREATE TABLE Statements pre pgAdmin4:
🔧 1. Config Tables (Tier & Level System):
SQL
-- ============================================
-- TIER DEFINITIONS (Subscription System)
-- ============================================
CREATE TABLE tier_definitions (
    tier_level              INTEGER PRIMARY KEY,
    tier_name               VARCHAR(50) NOT NULL,
    price_monthly           DECIMAL(10,2),
    max_zones_per_scan      INTEGER NOT NULL,
    collect_cooldown_seconds INTEGER NOT NULL,
    scan_cooldown_minutes   INTEGER NOT NULL,
    inventory_slots         INTEGER NOT NULL,
    features                JSONB DEFAULT '{}'::jsonb,
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_tier_level CHECK (tier_level >= 0 AND tier_level <= 4),
    CONSTRAINT check_price CHECK (price_monthly >= 0)
);

-- ============================================
-- LEVEL DEFINITIONS (XP System)
-- ============================================
CREATE TABLE level_definitions (
    level                   INTEGER PRIMARY KEY,
    xp_required             INTEGER NOT NULL,
    level_name              VARCHAR(50),
    features_unlocked       JSONB DEFAULT '{}'::jsonb,
    cosmetic_unlocks        JSONB DEFAULT '{}'::jsonb,
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT check_level CHECK (level >= 1 AND level <= 200),
    CONSTRAINT check_xp CHECK (xp_required >= 0)
);
👤 2. Users Table:
SQL
-- ============================================
-- USERS (Main Players)
-- ============================================
CREATE TABLE users (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at              TIMESTAMP,
    
    -- Authentication
    username                VARCHAR(50) UNIQUE NOT NULL,
    email                   VARCHAR(100) UNIQUE NOT NULL,
    password_hash           VARCHAR(255) NOT NULL,
    
    -- Subscription (Payment)
    tier                    INTEGER DEFAULT 0,
    tier_expires            TIMESTAMP,
    tier_auto_renew         BOOLEAN DEFAULT false,
    
    -- Progression (Skill)
    xp                      INTEGER DEFAULT 0,
    level                   INTEGER DEFAULT 1,
    total_artifacts         INTEGER DEFAULT 0,
    total_gear              INTEGER DEFAULT 0,
    zones_discovered        INTEGER DEFAULT 0,
    
    -- Status
    is_active               BOOLEAN DEFAULT true,
    is_banned               BOOLEAN DEFAULT false,
    last_login              TIMESTAMP,
    
    -- Profile
    profile_data            JSONB DEFAULT '{}'::jsonb,
    
    -- Constraints
    CONSTRAINT check_tier CHECK (tier >= 0 AND tier <= 4),
    CONSTRAINT check_level CHECK (level >= 1 AND level <= 200),
    CONSTRAINT check_xp CHECK (xp >= 0),
    CONSTRAINT check_username_length CHECK (LENGTH(username) >= 3),
    CONSTRAINT check_email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);
🏰 3. Zones Table:
SQL
-- ============================================
-- ZONES (Game Areas)
-- ============================================
CREATE TABLE zones (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at              TIMESTAMP,
    
    -- Basic Info
    name                    VARCHAR(100) NOT NULL,
    description             TEXT,
    
    -- Location (GPS)
    location_latitude       DECIMAL(10, 8) NOT NULL,
    location_longitude      DECIMAL(11, 8) NOT NULL,
    location_timestamp      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Game Mechanics
    radius_meters           INTEGER NOT NULL,
    tier_required           INTEGER NOT NULL,
    zone_type               VARCHAR(20) NOT NULL DEFAULT 'static',
    
    -- Configuration
    properties              JSONB DEFAULT '{}'::jsonb,
    is_active               BOOLEAN DEFAULT true,
    
    -- Constraints
    CONSTRAINT check_latitude CHECK (location_latitude >= -90 AND location_latitude <= 90),
    CONSTRAINT check_longitude CHECK (location_longitude >= -180 AND location_longitude <= 180),
    CONSTRAINT check_radius CHECK (radius_meters >= 50 AND radius_meters <= 1000),
    CONSTRAINT check_tier_required CHECK (tier_required >= 0 AND tier_required <= 4),
    CONSTRAINT check_zone_type CHECK (zone_type IN ('static', 'dynamic', 'event'))
);
💎 4. Artifacts Table:
SQL
-- ============================================
-- ARTIFACTS (Collectible Items)
-- ============================================
CREATE TABLE artifacts (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at              TIMESTAMP,
    
    -- References
    zone_id                 UUID NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    
    -- Basic Info
    name                    VARCHAR(100) NOT NULL,
    type                    VARCHAR(50) NOT NULL,
    rarity                  VARCHAR(20) NOT NULL,
    
    -- Location (GPS)
    location_latitude       DECIMAL(10, 8) NOT NULL,
    location_longitude      DECIMAL(11, 8) NOT NULL,
    location_timestamp      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Configuration
    properties              JSONB DEFAULT '{}'::jsonb,
    is_active               BOOLEAN DEFAULT true,
    
    -- Constraints
    CONSTRAINT check_latitude CHECK (location_latitude >= -90 AND location_latitude <= 90),
    CONSTRAINT check_longitude CHECK (location_longitude >= -180 AND location_longitude <= 180),
    CONSTRAINT check_rarity CHECK (rarity IN ('common', 'rare', 'epic', 'legendary')),
    CONSTRAINT check_type CHECK (type IN ('ancient_coin', 'crystal', 'rune', 'scroll', 'gem', 'tablet', 'orb'))
);
⚔️ 5. Gear Table:
SQL
-- ============================================
-- GEAR (Equipment Items)
-- ============================================
CREATE TABLE gear (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at              TIMESTAMP,
    
    -- References
    zone_id                 UUID NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
    
    -- Basic Info
    name                    VARCHAR(100) NOT NULL,
    type                    VARCHAR(50) NOT NULL,
    level                   INTEGER NOT NULL,
    
    -- Location (GPS)
    location_latitude       DECIMAL(10, 8) NOT NULL,
    location_longitude      DECIMAL(11, 8) NOT NULL,
    location_timestamp      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Configuration
    properties              JSONB DEFAULT '{}'::jsonb,
    is_active               BOOLEAN DEFAULT true,
    
    -- Constraints
    CONSTRAINT check_latitude CHECK (location_latitude >= -90 AND location_latitude <= 90),
    CONSTRAINT check_longitude CHECK (location_longitude >= -180 AND location_longitude <= 180),
    CONSTRAINT check_level CHECK (level >= 1 AND level <= 10),
    CONSTRAINT check_gear_type CHECK (type IN ('sword', 'shield', 'armor', 'boots', 'helmet', 'ring', 'amulet'))
);
🎒 6. Inventory Table:
SQL
-- ============================================
-- INVENTORY ITEMS (Player Collections)
-- ============================================
CREATE TABLE inventory_items (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at              TIMESTAMP,
    
    -- References
    user_id                 UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Item Reference
    item_type               VARCHAR(20) NOT NULL,
    item_id                 UUID NOT NULL,
    
    -- Quantity & Properties
    quantity                INTEGER DEFAULT 1,
    properties              JSONB DEFAULT '{}'::jsonb,
    
    -- Constraints
    CONSTRAINT check_item_type CHECK (item_type IN ('artifact', 'gear')),
    CONSTRAINT check_quantity CHECK (quantity >= 0),
    
    -- Unique constraint pre duplicate items
    UNIQUE(user_id, item_type, item_id)
);
🕹️ 7. Player Sessions Table:
SQL
-- ============================================
-- PLAYER SESSIONS (Real-time Tracking)
-- ============================================
CREATE TABLE player_sessions (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Session Info
    last_seen                   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_online                   BOOLEAN DEFAULT true,
    
    -- Current Status
    current_zone                UUID REFERENCES zones(id) ON DELETE SET NULL,
    
    -- Last Location
    last_location_latitude      DECIMAL(10, 8),
    last_location_longitude     DECIMAL(11, 8),
    last_location_timestamp     TIMESTAMP,
    
    -- Session Data
    session_data                JSONB DEFAULT '{}'::jsonb,
    
    -- Constraints
    CONSTRAINT check_latitude CHECK (last_location_latitude IS NULL OR (last_location_latitude >= -90 AND last_location_latitude <= 90)),
    CONSTRAINT check_longitude CHECK (last_location_longitude IS NULL OR (last_location_longitude >= -180 AND last_location_longitude <= 180)),
    
    -- Unique constraint - jeden session per user
    UNIQUE(user_id)
);
📊 8. User Progression Table:
SQL
-- ============================================
-- USER PROGRESSION (Daily/Weekly Tracking)
-- ============================================
CREATE TABLE user_progression (
    id                          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id                     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at                  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Daily/Weekly Tracking
    last_daily_bonus            TIMESTAMP,
    daily_streak                INTEGER DEFAULT 0,
    weekly_streak               INTEGER DEFAULT 0,
    
    -- Activity Tracking
    zones_entered_today         INTEGER DEFAULT 0,
    items_collected_today       INTEGER DEFAULT 0,
    last_activity_reset         TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Achievements
    achievements                JSONB DEFAULT '[]'::jsonb,
    badges                      JSONB DEFAULT '[]'::jsonb,
    
    -- Constraints
    CONSTRAINT check_streaks CHECK (daily_streak >= 0 AND weekly_streak >= 0),
    CONSTRAINT check_daily_activity CHECK (zones_entered_today >= 0 AND items_collected_today >= 0),
    
    -- Unique constraint
    UNIQUE(user_id)
);





-----------------------
testy databazy
-----------------------

Test More Endpoints:
1. Database Test:

Code
GET http://localhost:8080/api/v1/db-test
Expected: Database stats (tiers: 5, levels: 200)

2. Server Status:

Code
GET http://localhost:8080/api/v1/status
Expected: Full server + database status

3. Health Check:

Code
GET http://localhost:8080/health
Expected: Overall system health

4. Users Endpoint:

Code
GET http://localhost:8080/api/v1/users
Expected: User list (currently 0 users)

5. Zones Endpoint:

Code
GET http://localhost:8080/api/v1/zones
Expected: Zone list (currently 0 zones)