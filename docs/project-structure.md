# Project Structure

This document provides an overview of the MeasureStack project structure. The project follows a **simplicity-first** architecture - prioritizing ease of understanding over comprehensive features.

## 📁 Root Directory Structure

```
measure-stack/
├── 📁 src/                    # Source code (5 files)
│   ├── 📄 api/index.ts       # Main API server
│   └── 📁 services/          # Core services
│       ├── 📄 firestore.ts   # Firestore initialization
│       ├── 📄 salt.ts        # Daily salt & hashing
│       ├── 📄 geoip.ts       # GeoIP lookup
│       └── 📄 enrichment.ts  # Event enrichment & BigQuery
├── 📁 data/                   # Data pipeline
│   └── 📁 dbt/               # dbt analytics
├── 📁 deploy/                 # Deployment (5 files)
│   ├── 📄 config.source      # Main configuration
│   ├── 📄 deploy_app.sh      # App deployment
│   ├── 📄 deploy_dbt.sh      # DBT deployment
│   ├── 📄 quick_test.sh      # API testing
│   └── 📄 bq_table_schema.json # BigQuery schema
├── 📁 docs/                   # Documentation
├── 📁 static/                 # Static assets
│   └── 📄 measure.js         # Browser SDK
├── 📁 tests/                  # Test suite
├── 📄 package.json           # Dependencies & scripts
├── 📄 tsconfig.json          # TypeScript config
├── 📄 Dockerfile             # Container config
├── 📄 .env                   # Local environment
└── 📄 example.env            # Environment template
```

## 🔧 Source Code (`src/`)

The entire application consists of **just 5 TypeScript files** (~488 total lines):

### Main API Server (`src/api/index.ts`) - 145 lines

The main entry point that combines everything:

**Features:**
- Hono web server (port 3000)
- Inline CORS middleware
- Event handler (GET/POST endpoints)
- Cookie-based consent management
- Background processing with `setImmediate()`
- Supports JSON, form data, and query parameters

**Key Endpoints:**
- `GET /` - Root endpoint
- `GET /measure.js` - Serves tracking script
- `GET/POST /events` - Event tracking

### Firestore Service (`src/services/firestore.ts`) - 16 lines

Centralized Firestore initialization:

**Features:**
- Singleton instance pattern
- Configurable database ID
- Used by salt and GeoIP services

### Salt & Hashing (`src/services/salt.ts`) - 66 lines

Privacy-preserving hash generation with daily rotating salts:

**Features:**
- Atomic daily salt generation (Firestore transactions)
- In-memory caching
- Automatic cleanup of old salts (>24 hours)
- SHA256 hash generation

**Functions:**
- `getDailySalt()` - Get or create today's salt
- `getHash(ip, userAgent)` - Generate privacy hash
- `generateHash(data)` - Simple SHA256 hash

### GeoIP Service (`src/services/geoip.ts`) - 83 lines

Pluggable IP geolocation lookup:

**Features:**
- MaxMind GeoIP2 integration
- Firestore caching to reduce API calls
- Gracefully disabled if credentials not provided
- Returns continent, country, country_code, city

**Function:**
- `getGeoIPData(ipAddress)` - Lookup and cache geo data

### Enrichment Service (`src/services/enrichment.ts`) - 178 lines

Event enrichment and BigQuery storage:

**Features:**
- IP utilities: `truncateIP()`, `getClientIP()`, `sanitizeIP()`
- User-agent parsing (device, browser, OS)
- Event enrichment with geo and device data
- BigQuery storage with explicit project ID

**Functions:**
- `getClientIP()` - Extract IP from headers
- `truncateIP()` - Privacy-preserving IP truncation
- `enrichAndProcessEvent()` - Enrich event with device/geo data
- `storeEvent()` - Store in BigQuery

## 📊 Data Pipeline (`data/dbt/`)

dbt analytics pipeline for data transformation:

```
data/dbt/measure_js/
├── 📁 models/              # Data transformation models
│   ├── 📁 core/           # Core business logic
│   ├── 📁 mart/           # Analytics-ready tables
│   └── 📁 staging/        # Data cleaning
├── 📁 macros/             # Reusable SQL macros
├── 📄 dbt_project.yml     # dbt configuration
└── 📄 README.md           # Pipeline documentation
```

**Model Categories:**
- **`staging/`**: Raw data cleaning and preparation
- **`core/`**: Business logic and user/session identification
- **`mart/`**: Analytics-ready aggregated tables

## 🚀 Deployment (`deploy/`)

Simple flat structure with all deployment files:

### Configuration (`deploy/config.source`)

Main configuration file with all GCP settings, service config, and deployment settings.

**Required settings:**
- `GCP_PROJECT_ID` - Your GCP project
- `COOKIE_DOMAIN` - Your website domain
- `CORS_ORIGIN` - Allowed origins

**Optional settings:**
- `GEO_ACCOUNT`, `GEO_KEY` - MaxMind credentials
- `TRACKER_DOMAIN` - Custom domain
- Resource allocation (MEMORY, CPU, etc.)

### Deployment Scripts

- **`deploy_app.sh`** - Deploy main app to Cloud Run
- **`deploy_dbt.sh`** - Deploy dbt pipeline
- **`quick_test.sh`** - Test all API endpoints

### BigQuery Schema (`deploy/bq_table_schema.json`)

Defines the BigQuery table structure for events:
- Event metadata (timestamp, event_type, event_name)
- User identification (client_id, user_id, hash)
- Device info (type, browser, OS)
- Location data (ip_trunc, country, city)
- Consent tracking

## 📦 Static Assets (`static/`)

Client-side JavaScript SDK:

```
static/
├── 📄 measure.js          # Generated tracking script
└── 📄 measure.js.template # Template with {{ endpoint }}
```

**Features:**
- Lightweight SDK
- Privacy-focused design
- Consent management
- Pageview and event tracking

## 🧪 Testing (`tests/`)

Test suite structure:

```
tests/
├── 📁 unit/               # Unit tests
├── 📁 integration/        # Integration tests
└── 📁 e2e/               # End-to-end tests
```

**Test Commands:**
```bash
bun test                  # Run all tests
bun test:unit            # Unit tests only
bun test:integration     # Integration tests only
bun test:e2e            # E2E tests only
bun test:watch          # Watch mode
```

## 🏗️ Architecture Overview

### Simplified Stack (5 Files)

```
┌──────────────────────────────────────┐
│   src/api/index.ts (145 lines)      │
│   • Hono server                      │
│   • CORS inline                      │
│   • Event handler                    │
│   • Cookie consent                   │
└─────────────┬────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│   src/services/ (4 files, 343 lines)   │
├─────────────────────────────────────────┤
│ firestore.ts    • Firestore singleton  │
│ salt.ts         • Daily salt & hashing │
│ geoip.ts        • GeoIP lookup         │
│ enrichment.ts   • Enrichment & BigQuery│
└─────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│   External Services                     │
├─────────────────────────────────────────┤
│ • Firestore (salt storage, geo cache)  │
│ • BigQuery (event storage)             │
│ • MaxMind (optional GeoIP)             │
└─────────────────────────────────────────┘
```

### Key Design Principles

1. **Simplicity First** - Only 5 core files, ~488 total lines
2. **Flat Structure** - No deep nesting, everything easy to find
3. **Privacy-Preserving** - Daily salt rotation, IP truncation, consent management
4. **Pluggable GeoIP** - Works without credentials, optional feature
5. **Background Processing** - Non-blocking with `setImmediate()`
6. **Explicit Configuration** - BigQuery project ID explicitly passed

## 🔒 Privacy & Security

### Privacy Protection
- **IP Truncation**: Last octet removed (IPv4), /64 for IPv6
- **Daily Salt Rotation**: Hashes change daily, stored in Firestore
- **Consent Management**: Cookie-based opt-in/opt-out
- **Data Minimization**: Only essential data collected

### Security Features
- **CORS Protection**: Origin validation
- **Cookie Security**: Domain-scoped, 1-year expiry
- **Environment Isolation**: Separate dev/prod configs
- **Service Accounts**: Least-privilege IAM roles

## 📈 Development Workflow

### Local Development
```bash
bun install          # Install dependencies
bun run dev         # Start dev server (with watch)
bun src/api/index.ts # Run directly
```

### Testing
```bash
bun test            # Run all tests
bun test:watch     # Watch mode
```

### Deployment
```bash
./deploy/deploy_app.sh   # Deploy to Cloud Run
./deploy/deploy_dbt.sh   # Deploy dbt pipeline
./deploy/quick_test.sh   # Test deployed API
```

## 📚 Documentation (`docs/`)

```
docs/
├── 📁 getting-started/    # Quick start & configuration
├── 📁 api/               # API documentation
├── 📁 integration/       # Client integration
├── 📁 analytics/         # Data pipeline docs
└── 📄 project-structure.md # This file
```

## 🔧 Configuration Files

### `package.json`
- Dependencies (Hono, Google Cloud SDKs, etc.)
- Scripts (dev, test, build)
- Bun engine requirement (>=1.3.1)

### `tsconfig.json`
- TypeScript compilation settings
- Module resolution (NodeNext)
- Strict type checking disabled for `noImplicitAny`

### `Dockerfile`
- Based on Bun 1.3.1
- NODE_ENV=production for proper timeouts
- Runs uncompiled TypeScript (compiled version has Firestore bug)

### `.env` / `example.env`
- Local development configuration
- Template for new installations
- No secrets committed to git

---

This simplified architecture prioritizes **understanding and extensibility through clarity**. With just 5 core files and ~488 lines of code, the entire analytics stack is easy to read, modify, and extend in any direction you need.
