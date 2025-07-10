# Project Structure

This document provides a comprehensive overview of the Measure.js project structure, explaining the purpose and organization of each component.

## 📁 Root Directory Structure

```
measure-js/
├── 📁 src/                    # Source code
│   ├── 📁 api/               # API layer
│   ├── 📁 config/            # Configuration
│   ├── 📁 services/          # Business logic
│   ├── 📁 types/             # TypeScript types
│   └── 📁 utils/             # Utility functions
├── 📁 data/                  # Data pipeline
│   └── 📁 dbt/              # dbt analytics
├── 📁 docs/                  # Documentation
├── 📁 infrastructure/        # Deployment configs
├── 📁 static/               # Static assets
├── 📁 tests/                # Test suite
├── 📄 package.json          # Dependencies & scripts
├── 📄 tsconfig.json         # TypeScript config
├── 📄 Dockerfile            # Container config
└── 📄 example.env           # Environment template
```

## 🔧 Source Code (`src/`)

### API Layer (`src/api/`)

The API layer handles HTTP requests and responses using the Hono framework.

```
src/api/
├── 📄 index.ts              # Main API entry point
├── 📁 middleware/           # Request/response middleware
│   ├── 📄 cors.ts          # CORS configuration
│   └── 📄 rateLimit.ts     # Rate limiting
└── 📁 routes/              # API route handlers
    ├── 📄 events.ts        # Event tracking endpoints
    └── 📄 health.ts        # Health check endpoint
```

**Key Components:**

- **`index.ts`**: Main application entry point, configures middleware and routes
- **`middleware/cors.ts`**: Cross-Origin Resource Sharing configuration
- **`middleware/rateLimit.ts`**: Rate limiting to prevent abuse
- **`routes/events.ts`**: Event tracking API endpoints
- **`routes/health.ts`**: Health monitoring endpoint

### Configuration (`src/config/`)

Application configuration and environment management.

```
src/config/
└── 📄 environment.ts        # Environment variables & config
```

**Features:**
- Environment variable management
- Type-safe configuration
- Default values for development
- Security settings (CORS, rate limiting)

### Services (`src/services/`)

Business logic and external service integrations.

```
src/services/
├── 📁 analytics/            # Analytics processing
│   └── 📄 geoLocation.ts   # Geographic data processing
├── 📁 storage/             # Data storage
│   └── 📄 bigQueryService.ts # BigQuery integration
└── 📁 tracking/            # Event tracking
    └── 📄 eventProcessor.ts # Event processing logic
```

**Key Services:**

- **`analytics/geoLocation.ts`**: IP geolocation using MaxMind
- **`storage/bigQueryService.ts`**: Google BigQuery data storage
- **`tracking/eventProcessor.ts`**: Event processing and enrichment

### Types (`src/types/`)

TypeScript type definitions for the application.

```
src/types/
├── 📄 events.ts            # Event data types
└── 📄 user.ts             # User-related types
```

**Type Definitions:**
- `TrackingEvent`: Raw event data structure
- `ProcessedEvent`: Enriched event data
- `ConsentSettings`: User consent preferences
- `ApiResponse`: API response formats

### Utils (`src/utils/`)

Utility functions and helpers.

```
src/utils/
├── 📁 crypto/              # Cryptographic utilities
│   └── 📄 hashing.ts      # Hash generation
├── 📁 helpers/             # Helper functions
│   └── 📄 ipUtils.ts      # IP address utilities
└── 📁 validation/          # Data validation
```

**Utilities:**
- **`crypto/hashing.ts`**: Privacy-preserving hash generation
- **`helpers/ipUtils.ts`**: IP address detection and sanitization
- **`validation/`**: Data validation schemas

## 📊 Data Pipeline (`data/`)

### dbt Analytics (`data/dbt/measure_js/`)

Data transformation and analytics pipeline.

```
data/dbt/measure_js/
├── 📁 models/              # Data transformation models
│   ├── 📁 core/           # Core business logic
│   ├── 📁 mart/           # Analytics-ready tables
│   └── 📁 staging/        # Data cleaning & preparation
├── 📁 macros/             # Reusable SQL macros
├── 📁 tests/              # Data quality tests
├── 📁 seeds/              # Reference data
├── 📄 dbt_project.yml     # dbt configuration
└── 📄 README.md           # Pipeline documentation
```

**Model Categories:**

- **`staging/`**: Raw data cleaning and preparation
- **`core/`**: Business logic and user/session identification
- **`mart/`**: Analytics-ready aggregated tables

## 🧪 Testing (`tests/`)

Comprehensive test suite covering all application layers.

```
tests/
├── 📁 unit/               # Unit tests
│   ├── 📁 config/        # Configuration tests
│   ├── 📁 services/      # Service layer tests
│   └── 📁 utils/         # Utility function tests
├── 📁 integration/        # Integration tests
│   └── 📁 api/           # API endpoint tests
├── 📁 e2e/               # End-to-end tests
├── 📄 README.md          # Test documentation
└── 📄 test-runner.ts     # Test runner configuration
```

**Test Coverage:**

- **Unit Tests**: Individual function testing
- **Integration Tests**: API endpoint testing
- **E2E Tests**: Complete user flow testing

## 📚 Documentation (`docs/`)

Comprehensive documentation for users and developers.

```
docs/
├── 📁 getting-started/    # Quick start guides
├── 📁 api/               # API documentation
├── 📁 integration/       # Client integration guides
├── 📁 analytics/         # Data pipeline docs
├── 📁 deployment/        # Deployment guides
├── 📁 development/       # Development guides
└── 📄 README.md         # Documentation index
```

## 🚀 Infrastructure (`infrastructure/`)

Deployment and infrastructure configuration.

```
infrastructure/
├── 📁 docker/            # Docker configuration
│   └── 📄 Dockerfile     # Container definition
└── 📁 scripts/           # Deployment scripts
    └── 📄 deploy_app.sh  # Deployment automation
```

## 📦 Static Assets (`static/`)

Client-side JavaScript SDK.

```
static/
└── 📄 measure.js         # Browser tracking SDK
```

**Features:**
- Lightweight (~2KB minified)
- Privacy-focused design
- Cross-browser compatibility
- Consent management

## 🔧 Configuration Files

### `package.json`
- Dependencies and scripts
- Build configuration
- Test commands

### `tsconfig.json`
- TypeScript compilation settings
- Module resolution
- Strict type checking

### `Dockerfile`
- Multi-stage build
- Production optimization
- Security hardening

### `example.env`
- Environment variable template
- Configuration examples
- Security best practices

## 🏗️ Architecture Patterns

### 1. **Layered Architecture**
```
┌─────────────────┐
│   API Layer     │ ← HTTP requests/responses
├─────────────────┤
│  Service Layer  │ ← Business logic
├─────────────────┤
│  Storage Layer  │ ← Data persistence
└─────────────────┘
```

### 2. **Middleware Pattern**
- CORS handling
- Rate limiting
- Request validation
- Error handling

### 3. **Service Pattern**
- Event processing
- Data enrichment
- External integrations
- Caching strategies

### 4. **Repository Pattern**
- BigQuery integration
- Data access abstraction
- Query optimization

## 🔒 Security Considerations

### 1. **Privacy Protection**
- IP address truncation
- Consent management
- Data minimization
- GDPR compliance

### 2. **Rate Limiting**
- Per-IP request limits
- Burst protection
- Configurable thresholds

### 3. **CORS Security**
- Origin validation
- Credential handling
- Preflight requests

### 4. **Data Validation**
- Input sanitization
- Type checking
- Schema validation

## 📈 Performance Optimizations

### 1. **Runtime Performance**
- Bun JavaScript runtime
- TypeScript compilation
- Memory management

### 2. **API Performance**
- Async processing
- Connection pooling
- Response caching

### 3. **Data Pipeline**
- Incremental processing
- Partitioning strategies
- Query optimization

## 🧪 Testing Strategy

### 1. **Unit Testing**
- Individual function testing
- Mock external dependencies
- Edge case coverage

### 2. **Integration Testing**
- API endpoint testing
- Service interaction testing
- Database integration testing

### 3. **End-to-End Testing**
- Complete user flows
- Browser automation
- Real-world scenarios

## 🔄 Development Workflow

### 1. **Local Development**
```bash
bun install          # Install dependencies
bun run dev         # Start development server
bun test           # Run tests
```

### 2. **Code Quality**
- TypeScript strict mode
- ESLint configuration
- Pre-commit hooks

### 3. **Deployment Pipeline**
- Automated testing
- Build optimization
- Environment management

## 📊 Monitoring & Observability

### 1. **Application Metrics**
- Request/response times
- Error rates
- Resource usage

### 2. **Data Quality**
- Schema validation
- Data completeness
- Transformation accuracy

### 3. **Business Metrics**
- Event processing rates
- User engagement
- Geographic distribution

This structure provides a solid foundation for a scalable, maintainable, and privacy-focused analytics platform. Each component has a clear responsibility and well-defined interfaces, making the codebase easy to understand and extend.
