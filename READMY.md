# 🎮 GeoApp Backend - Location-Based AR Game

**Created by: silverminesro**  
**Last Updated: 2025-07-08 16:18:19 UTC**  
**Status: ✅ Production Ready**

## 🌟 **Project Overview**

GeoApp is a revolutionary location-based augmented reality game where players explore real-world locations to discover zones, collect artifacts, and gather gear. The backend system manages dynamic zone creation, item spawning, player progression, and real-time multiplayer features.

### 🎯 **Core Features**
- 🗺️ **Dynamic Zone System** - Creates game zones at real GPS locations
- 💎 **Item Collection** - Artifacts and gear spawn dynamically in zones  
- 👥 **Multiplayer Support** - Real-time player tracking and interaction
- 🏆 **Tier System** - 5-tier subscription model (Tier 0-4)
- 📊 **Player Progression** - XP, levels, and achievement tracking
- 🔐 **Secure Authentication** - JWT-based user management

### 🛠️ **Technology Stack**
- **Backend**: Go 1.21+ with Gin framework
- **Database**: PostgreSQL 15+ with PostGIS extension
- **Cache**: Redis for real-time features
- **Authentication**: JWT tokens with bcrypt
- **API**: RESTful endpoints with JSON responses

---

## 🏗️ **System Architecture**

```
geoapp/
├── cmd/server/          # Application entry point
│   ├── main.go         # Server startup and configuration
│   └── router.go       # API route definitions
├── internal/           # Core business logic
│   ├── auth/           # Authentication handlers
│   ├── user/           # User management
│   ├── game/           # Game mechanics and zone system
│   ├── location/       # Real-time location tracking
│   ├── admin/          # Administrative functions
│   └── common/         # Shared models and utilities
├── pkg/                # Reusable packages
│   ├── database/       # Database connection and migrations
│   ├── middleware/     # HTTP middleware (auth, CORS, rate limiting)
│   └── redis/          # Redis client configuration
├── docker-compose.yml  # Development environment
├── Dockerfile         # Container configuration
└── go.mod/go.sum      # Go module dependencies
```

---

## 🚀 **Getting Started**

### 📋 **Prerequisites**
- Go 1.21 or higher
- PostgreSQL 15+ with PostGIS extension
- Redis 7+ (optional, for real-time features)
- Git

### ⚙️ **Installation**

1. **Clone Repository**
```bash
git clone https://github.com/silverminesro/geoapp.git
cd geoapp
```

2. **Install Dependencies**
```bash
go mod download
```

3. **Database Setup**
```sql
-- Create database
CREATE DATABASE geoapp_db;

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Run schema creation (see Database Schema section)
```

4. **Environment Configuration**
Create `.env` file:
```env
# Server Configuration
PORT=8080
HOST=localhost
GIN_MODE=debug

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=your_password
DB_NAME=geoapp_db
DB_SSLMODE=disable
DB_TIMEZONE=UTC

# JWT Configuration
JWT_SECRET=your-super-secret-jwt-key-minimum-32-characters
JWT_EXPIRES_IN=24h

# Redis Configuration (Optional)
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# Application Settings
APP_ENV=development
API_VERSION=v1
DEBUG=true
LOG_LEVEL=info
```

5. **Run Server**
```bash
go run cmd/server/main.go cmd/server/router.go
```

Server starts on: `http://localhost:8080`

---

## 📊 **Database Schema**

### 👤 **Users Table**
```sql
CREATE TABLE users (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at              TIMESTAMP,
    username                VARCHAR(50) UNIQUE NOT NULL,
    email                   VARCHAR(100) UNIQUE NOT NULL,
    password_hash           VARCHAR(255) NOT NULL,
    tier                    INTEGER DEFAULT 0,
    tier_expires            TIMESTAMP,
    tier_auto_renew         BOOLEAN DEFAULT false,
    xp                      INTEGER DEFAULT 0,
    level                   INTEGER DEFAULT 1,
    total_artifacts         INTEGER DEFAULT 0,
    total_gear              INTEGER DEFAULT 0,
    zones_discovered        INTEGER DEFAULT 0,
    is_active               BOOLEAN DEFAULT true,
    is_banned               BOOLEAN DEFAULT false,
    last_login              TIMESTAMP,
    profile_data            JSONB DEFAULT '{}'::jsonb
);
```

### 🏰 **Zones Table**
```sql
CREATE TABLE zones (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at              TIMESTAMP,
    name                    VARCHAR(100) NOT NULL,
    description             TEXT,
    location_latitude       DECIMAL(10, 8) NOT NULL,
    location_longitude      DECIMAL(11, 8) NOT NULL,
    location_timestamp      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    radius_meters           INTEGER NOT NULL,
    tier_required           INTEGER NOT NULL,
    zone_type               VARCHAR(20) NOT NULL DEFAULT 'static',
    properties              JSONB DEFAULT '{}'::jsonb,
    is_active               BOOLEAN DEFAULT true
);
```

### 💎 **Artifacts & Gear Tables**
```sql
CREATE TABLE artifacts (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at              TIMESTAMP,
    zone_id                 UUID NOT NULL REFERENCES zones(id),
    name                    VARCHAR(100) NOT NULL,
    type                    VARCHAR(50) NOT NULL,
    rarity                  VARCHAR(20) NOT NULL,
    location_latitude       DECIMAL(10, 8) NOT NULL,
    location_longitude      DECIMAL(11, 8) NOT NULL,
    location_timestamp      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    properties              JSONB DEFAULT '{}'::jsonb,
    is_active               BOOLEAN DEFAULT true
);

CREATE TABLE gear (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    created_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at              TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at              TIMESTAMP,
    zone_id                 UUID NOT NULL REFERENCES zones(id),
    name                    VARCHAR(100) NOT NULL,
    type                    VARCHAR(50) NOT NULL,
    level                   INTEGER NOT NULL,
    location_latitude       DECIMAL(10, 8) NOT NULL,
    location_longitude      DECIMAL(11, 8) NOT NULL,
    location_timestamp      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    properties              JSONB DEFAULT '{}'::jsonb,
    is_active               BOOLEAN DEFAULT true
);
```

---

## 🔌 **API Documentation**

### 🔐 **Authentication Endpoints**

#### Register User
```http
POST /api/v1/auth/register
Content-Type: application/json

{
    "username": "player123",
    "email": "player@example.com", 
    "password": "securepass123"
}
```

**Response:**
```json
{
    "message": "User registered successfully",
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "username": "player123",
        "email": "player@example.com",
        "tier": 0,
        "is_active": true
    }
}
```

#### Login User
```http
POST /api/v1/auth/login
Content-Type: application/json

{
    "username": "player123",
    "password": "securepass123"
}
```

### 🎮 **Game Mechanics Endpoints**

#### Scan Area for Zones
```http
POST /api/v1/game/scan-area
Authorization: Bearer <token>
Content-Type: application/json

{
    "latitude": 49.2000,
    "longitude": 18.5000
}
```

**Response:**
```json
{
    "zones_created": 3,
    "zones": [
        {
            "zone": {
                "id": "f97cd7e8-76a3-4fa9-8234-238410a084eb",
                "name": "Ancient Ruins",
                "tier_required": 1
            },
            "active_artifacts": 8,
            "active_gear": 4,
            "distance_meters": 1250.5,
            "can_enter": true
        }
    ],
    "player_tier": 1,
    "max_zones": 3
}
```

#### Get Nearby Zones
```http
GET /api/v1/game/zones/nearby?lat=49.2000&lng=18.5000&radius=5
Authorization: Bearer <token>
```

### 👤 **User Management Endpoints**

#### Get User Profile
```http
GET /api/v1/user/profile
Authorization: Bearer <token>
```

#### Get User Inventory
```http
GET /api/v1/user/inventory?page=1&limit=50&type=artifact
Authorization: Bearer <token>
```

#### Update Location
```http
POST /api/v1/user/location
Authorization: Bearer <token>
Content-Type: application/json

{
    "latitude": 49.2000,
    "longitude": 18.5000,
    "accuracy": 10.5
}
```

### 📍 **Location Tracking Endpoints**

#### Get Nearby Players
```http
GET /api/v1/location/nearby?lat=49.2000&lng=18.5000
Authorization: Bearer <token>
```

#### Get Zone Activity
```http
GET /api/v1/location/zones/{zone_id}/activity
Authorization: Bearer <token>
```

---

## 🧪 **Testing Examples**

### PowerShell Testing Script
```powershell
# 1. Register User
$registerData = @{
    username = "testuser"
    email = "test@example.com"
    password = "password123"
} | ConvertTo-Json

$response = irm "http://localhost:8080/api/v1/auth/register" -Method POST -Body $registerData -ContentType "application/json"

# 2. Set Authorization Header
$headers = @{
    "Authorization" = "Bearer $($response.token)"
    "Content-Type" = "application/json"
}

# 3. Scan Area for Zones
$scanData = @{
    latitude = 49.2000
    longitude = 18.5000
} | ConvertTo-Json

$zones = irm "http://localhost:8080/api/v1/game/scan-area" -Method POST -Headers $headers -Body $scanData

# 4. Display Results
Write-Host "Zones Created: $($zones.zones_created)"
$zones.zones | ForEach-Object {
    Write-Host "Zone: $($_.zone.name) - Artifacts: $($_.active_artifacts), Gear: $($_.active_gear)"
}
```

### cURL Testing Examples
```bash
# Register User
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"password123"}'

# Scan Area (replace TOKEN with actual JWT)
curl -X POST http://localhost:8080/api/v1/game/scan-area \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"latitude":49.2000,"longitude":18.5000}'
```

---

## 🎮 **Game Mechanics**

### 🏆 **Tier System**
| Tier | Name | Max Zones | Collect Cooldown | Scan Cooldown | Features |
|------|------|-----------|------------------|---------------|-----------|
| 0 | Free | 1 | 300s | 30min | Basic gameplay |
| 1 | Bronze | 3 | 240s | 25min | More zones |
| 2 | Silver | 5 | 180s | 20min | Premium items |
| 3 | Gold | 8 | 120s | 15min | Rare artifacts |
| 4 | Platinum | 12 | 60s | 10min | Legendary items |

### 🗺️ **Zone Types**
- **Static**: Permanent zones at fixed locations
- **Dynamic**: Temporary zones created by player scanning
- **Event**: Special time-limited zones with unique rewards

### 💎 **Item Spawning Formula**
- **Artifacts per zone**: `2 + (tier * 2)`
- **Gear per zone**: `1 + tier`
- **Higher tiers**: Better rarity distribution

### 📈 **Player Progression**
- **XP System**: Gain XP from collecting items and discovering zones
- **Levels**: 1-200, unlock cosmetics and features
- **Achievements**: Track various gameplay milestones

---

## 🚦 **Health Checks**

```http
GET /health
```
```json
{
    "status": "healthy",
    "timestamp": "2025-07-08T16:18:19Z",
    "version": "1.0.0",
    "service": "geoapp-backend"
}
```

```http
GET /api/v1/system/stats
```
```json
{
    "active_players": 15,
    "total_zones": 250,
    "dynamic_zones": 180,
    "static_zones": 70,
    "server_uptime": "2h30m15s"
}
```

---

## 🐳 **Docker Deployment**

```bash
# Development Environment
docker-compose up -d

# Production Build
docker build -t geoapp-backend .
docker run -p 8080:8080 geoapp-backend
```

---

## 📈 **Current Status (2025-07-08)**

### ✅ **Implemented Features**
- ✅ User authentication (register/login/JWT)
- ✅ Dynamic zone creation and management
- ✅ Item spawning system (artifacts & gear)
- ✅ Real-time location tracking
- ✅ Player sessions and multiplayer support
- ✅ Tier-based progression system
- ✅ Admin endpoints for zone management
- ✅ Comprehensive API with 50+ endpoints

### 🧪 **Latest Test Results**
**User: K44Test (Tier 1)**  
**Location: [49.3000, 18.6000]**
- Zones Created: 3 (1x T1, 2x T2)
- Total Items: 32 artifacts, 16 gear
- Database: 4 users, 9 zones total
- All endpoints functional ✅

### 🚀 **Ready for Production**
The system is fully functional and ready for Flutter mobile app integration.

---

## 👨‍💻 **Development**

### 🔄 **Adding New Features**
1. Create handler in appropriate `internal/` package
2. Add routes in `cmd/server/router.go`
3. Update models in `internal/common/models.go`
4. Add tests and documentation

### 🗄️ **Database Migrations**
```go
// Auto-migrate in main.go
db.AutoMigrate(&common.User{}, &common.Zone{}, &common.Artifact{}, &common.Gear{})
```

### 📝 **Logging**
Server logs all requests, database operations, and game events with structured logging.

---

## 🤝 **Contributing**

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

---

## 📞 **Support**

**Created by**: silverminesro  
**Repository**: https://github.com/silverminesro/geoapp  
**Issues**: https://github.com/silverminesro/geoapp/issues

---

## 📜 **License & Ownership**

**GeoApp Backend** is **PROPRIETARY SOFTWARE** exclusively owned and operated by **silverminesro**.

### 🔒 **EXCLUSIVE OWNERSHIP**
- **Owner & Operator:** silverminesro
- **Status:** All Rights Reserved
- **Date:** 2025-07-08 16:27:22 UTC

### 🚫 **STRICTLY PROHIBITED:**
- ❌ Any commercial use or distribution
- ❌ Third-party hosting or operation  
- ❌ Creating competing services
- ❌ SaaS or cloud deployment
- ❌ Mobile app integration without permission

### 🎯 **OFFICIAL SERVICE:**
**GeoApp** services are available EXCLUSIVELY through **silverminesro**.

For business inquiries: **silverminesro@email.com**

---

**⚠️ UNAUTHORIZED USE IS STRICTLY PROHIBITED AND WILL RESULT IN LEGAL ACTION.**

**© 2025 silverminesro - All Rights Reserved**

---

**🎮 Ready to explore? Start your GeoApp adventure today!** ✨