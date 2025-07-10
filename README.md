# 👽 GeoAnomaly Backend - Reality's Hidden Mysteries

**Created by: silverminesro**  
**Last Updated: 2025-07-10 07:30:57 UTC**  
**Status: ✅ Production Ready**

## 🌟 **Project Overview**

GeoAnomaly is a revolutionary location-based augmented reality game where players use their mobile devices to detect and investigate mysterious anomalies scattered throughout the real world. These anomalies contain powerful artifacts and gear from unknown origins, challenging players to explore reality's hidden mysteries.

### 🔍 **Core Features**
- 👽 **Anomaly Detection** - Scan real locations for dimensional rifts and mysterious phenomena
- 💎 **Artifact Recovery** - Collect mysterious objects of unknown origin with unique properties
- ⚡ **Anomalous Gear** - Equipment that defies conventional physics and enhances detection
- 🌌 **Reality Glitches** - Zones where normal rules don't apply and strange things happen
- 👥 **Multiplayer Investigation** - Real-time collaboration with other anomaly hunters
- 🏆 **Tier System** - 5-tier subscription model (Tier 0-4) for advanced detection capabilities
- 📊 **Hunter Progression** - XP, levels, and achievement tracking for dedicated investigators
- 🔐 **Secure Operations** - JWT-based authentication for authorized personnel

### 🛠️ **Technology Stack**
- **Backend**: Go 1.21+ with Gin framework
- **Database**: PostgreSQL 15+ with PostGIS extension
- **Cache**: Redis for real-time anomaly tracking
- **Authentication**: JWT tokens with bcrypt encryption
- **API**: RESTful endpoints with JSON responses

---

## 🏗️ **System Architecture**

```
geoanomaly/
├── cmd/server/          # Application entry point
│   ├── main.go         # Server startup and configuration
│   └── router.go       # API route definitions
├── internal/           # Core anomaly detection logic
│   ├── auth/           # Authentication handlers
│   ├── user/           # User management (anomaly hunters)
│   ├── game/           # Anomaly detection and zone system
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
git clone https://github.com/silverminesro/GeoAnomaly.git
cd GeoAnomaly
```

2. **Install Dependencies**
```bash
go mod download
```

3. **Database Setup**
```sql
-- Create database
CREATE DATABASE geoanomaly_db;

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
DB_NAME=geoanomaly_db
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

### 👤 **Users Table (Anomaly Hunters)**
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

### 🌌 **Zones Table (Anomalous Areas)**
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

### 💎 **Artifacts & Gear Tables (Anomalous Objects)**
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

#### Register Anomaly Hunter
```http
POST /api/v1/auth/register
Content-Type: application/json

{
    "username": "hunter123",
    "email": "hunter@geoanomaly.com", 
    "password": "securepass123"
}
```

**Response:**
```json
{
    "message": "Anomaly hunter registered successfully",
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "username": "hunter123",
        "email": "hunter@geoanomaly.com",
        "tier": 0,
        "is_active": true
    }
}
```

#### Login Hunter
```http
POST /api/v1/auth/login
Content-Type: application/json

{
    "username": "hunter123",
    "password": "securepass123"
}
```

### 🌌 **Anomaly Detection Endpoints**

#### Scan Area for Anomalies
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
                "name": "Dimensional Rift Alpha",
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

#### Get Nearby Anomalous Zones
```http
GET /api/v1/game/zones/nearby?lat=49.2000&lng=18.5000&radius=5
Authorization: Bearer <token>
```

### 👤 **Hunter Management Endpoints**

#### Get Hunter Profile
```http
GET /api/v1/user/profile
Authorization: Bearer <token>
```

#### Get Collected Anomalies (Inventory)
```http
GET /api/v1/user/inventory?page=1&limit=50&type=artifact
Authorization: Bearer <token>
```

#### Update Hunter Location
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

### 📍 **Multi-Hunter Tracking Endpoints**

#### Get Nearby Hunters
```http
GET /api/v1/location/nearby?lat=49.2000&lng=18.5000
Authorization: Bearer <token>
```

#### Get Anomaly Zone Activity
```http
GET /api/v1/location/zones/{zone_id}/activity
Authorization: Bearer <token>
```

---

## 🧪 **Testing Examples**

### PowerShell Testing Script
```powershell
# 1. Register Anomaly Hunter
$registerData = @{
    username = "anomalyhunter"
    email = "hunter@geoanomaly.com"
    password = "password123"
} | ConvertTo-Json

$response = irm "http://localhost:8080/api/v1/auth/register" -Method POST -Body $registerData -ContentType "application/json"

# 2. Set Authorization Header
$headers = @{
    "Authorization" = "Bearer $($response.token)"
    "Content-Type" = "application/json"
}

# 3. Scan Area for Anomalies
$scanData = @{
    latitude = 49.2000
    longitude = 18.5000
} | ConvertTo-Json

$anomalies = irm "http://localhost:8080/api/v1/game/scan-area" -Method POST -Headers $headers -Body $scanData

# 4. Display Results
Write-Host "Anomalous Zones Created: $($anomalies.zones_created)"
$anomalies.zones | ForEach-Object {
    Write-Host "Zone: $($_.zone.name) - Artifacts: $($_.active_artifacts), Gear: $($_.active_gear)"
}
```

### cURL Testing Examples
```bash
# Register Anomaly Hunter
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"anomalyhunter","email":"hunter@geoanomaly.com","password":"password123"}'

# Scan Area for Anomalies (replace TOKEN with actual JWT)
curl -X POST http://localhost:8080/api/v1/game/scan-area \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"latitude":49.2000,"longitude":18.5000}'
```

---

## 🎮 **Anomaly Detection Mechanics**

### 🏆 **Hunter Tier System**
| Tier | Name | Max Zones | Detection Cooldown | Scan Cooldown | Special Abilities |
|------|------|-----------|-------------------|---------------|-------------------|
| 0 | Novice | 1 | 300s | 30min | Basic detection |
| 1 | Apprentice | 3 | 240s | 25min | Enhanced sensitivity |
| 2 | Investigator | 5 | 180s | 20min | Rare anomaly access |
| 3 | Expert | 8 | 120s | 15min | Dimensional artifacts |
| 4 | Master | 12 | 60s | 10min | Legendary phenomena |

### 🌌 **Anomaly Zone Types**
- **Static**: Permanent dimensional rifts at fixed coordinates
- **Dynamic**: Temporary anomalies that appear during scanning
- **Event**: Special phenomena with unique temporal properties

### 💎 **Anomalous Object Spawning**
- **Artifacts per zone**: `2 + (tier * 2)` mysterious objects
- **Gear per zone**: `1 + tier` anomalous equipment
- **Higher tiers**: Access to rarer and more powerful anomalies

### 📈 **Hunter Progression**
- **XP System**: Gain experience from discovering anomalies and collecting artifacts
- **Levels**: 1-200, unlock advanced detection capabilities and equipment
- **Achievements**: Track investigation milestones and special discoveries

---

## 🚦 **Health Checks**

```http
GET /health
```
```json
{
    "status": "healthy",
    "timestamp": "2025-07-10T07:30:57Z",
    "version": "1.0.0",
    "service": "geoanomaly-backend"
}
```

```http
GET /api/v1/system/stats
```
```json
{
    "active_hunters": 15,
    "total_anomalies": 250,
    "dynamic_zones": 180,
    "static_rifts": 70,
    "server_uptime": "2h30m15s"
}
```

---

## 🐳 **Docker Deployment**

```bash
# Development Environment
docker-compose up -d

# Production Build
docker build -t geoanomaly-backend .
docker run -p 8080:8080 geoanomaly-backend
```

---

## 📈 **Current Status (2025-07-10)**

### ✅ **Implemented Features**
- ✅ Hunter authentication (register/login/JWT)
- ✅ Dynamic anomaly zone creation and management
- ✅ Anomalous object spawning system (artifacts & gear)
- ✅ Real-time hunter location tracking
- ✅ Multi-hunter sessions and collaboration support
- ✅ Tier-based progression system for advanced detection
- ✅ Admin endpoints for anomaly management
- ✅ Comprehensive API with 50+ endpoints

### 🧪 **Latest Test Results**
**Hunter: K44Test (Tier 1)**  
**Scan Location: [49.3000, 18.6000]**
- Anomalous Zones Created: 3 (1x T1, 2x T2)
- Total Anomalous Objects: 32 artifacts, 16 gear
- Database: 4 hunters, 9 anomaly zones total
- All detection systems functional ✅

### 🚀 **Ready for Investigation**
The system is fully operational and ready for mobile anomaly detection app integration.

---

## 👨‍💻 **Development**

### 🔄 **Adding New Anomaly Types**
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
Server logs all detection attempts, database operations, and anomaly events with structured logging.

---

## 🤝 **Contributing**

1. Fork the repository
2. Create feature branch (`git checkout -b feature/new-anomaly-type`)
3. Commit changes (`git commit -m 'Add new anomaly detection feature'`)
4. Push to branch (`git push origin feature/new-anomaly-type`)
5. Open Pull Request

---

## 📞 **Support**

**Created by**: silverminesro  
**Repository**: https://github.com/silverminesro/GeoAnomaly  
**Issues**: https://github.com/silverminesro/GeoAnomaly/issues

---

## 📜 **License & Ownership**

**GeoAnomaly Backend** is **PROPRIETARY SOFTWARE** exclusively owned and operated by **silverminesro**.

### 🔒 **EXCLUSIVE OWNERSHIP**
- **Owner & Operator:** silverminesro
- **Status:** All Rights Reserved
- **Date:** 2025-07-10 07:30:57 UTC

### 🚫 **STRICTLY PROHIBITED:**
- ❌ Any commercial use or distribution
- ❌ Third-party hosting or operation  
- ❌ Creating competing anomaly detection services
- ❌ SaaS or cloud deployment
- ❌ Mobile app integration without permission

### 🎯 **OFFICIAL SERVICE:**
**GeoAnomaly** detection services are available EXCLUSIVELY through **silverminesro**.

For business inquiries: **silverminesro@gmail.com**

---

**⚠️ UNAUTHORIZED USE IS STRICTLY PROHIBITED AND WILL RESULT IN LEGAL ACTION.**

**© 2025 silverminesro - All Rights Reserved**

---

**👽 Ready to investigate reality's mysteries? Start your GeoAnomaly hunt today!** ✨