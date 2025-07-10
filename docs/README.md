# Measure.js Documentation

Welcome to the Measure.js documentation! This is a comprehensive web analytics tracking system built with TypeScript, Bun, and Hono, designed to provide privacy-compliant analytics for web applications.

## 📚 Documentation Sections

### 🚀 Getting Started
- [Quick Start Guide](./getting-started/quick-start.md) - Get up and running in minutes
- [Installation Guide](./getting-started/installation.md) - Detailed setup instructions
- [Configuration](./getting-started/configuration.md) - Environment and application configuration

### 📖 API Reference
- [Events API](./api/events.md) - Track user events and pageviews with rate limiting
- [Health API](./api/health.md) - System health monitoring
- [Data Models](./api/data-models.md) - Event data structure and types

### 🔧 Development
- [Project Structure](./project-structure.md) - Comprehensive codebase organization guide
- [Testing Guide](./development/testing.md) - Running tests and writing new ones
- [Contributing](./development/contributing.md) - How to contribute to the project

### 📊 Analytics & Data
- [dbt Data Pipeline](./analytics/dbt-pipeline.md) - Data transformation and analytics
- [Data Schema](./analytics/data-schema.md) - Database schema and data models
- [Analytics Dashboard](./analytics/dashboard.md) - Understanding your analytics data

### 🚀 Deployment
- [Production Deployment](./deployment/production.md) - Complete production deployment guide
- [Docker Deployment](./deployment/docker.md) - Containerized deployment
- [Cloud Deployment](./deployment/cloud.md) - Deploy to cloud platforms
- [Environment Management](./deployment/environments.md) - Managing different environments

### 🔒 Security & Privacy
- [Privacy Features](./security/privacy.md) - GDPR compliance and privacy controls
- [Security Best Practices](./security/best-practices.md) - Security considerations
- [Data Retention](./security/data-retention.md) - Data lifecycle management

### 📱 Client Integration
- [JavaScript SDK](./integration/javascript-sdk.md) - Browser integration guide
- [API Integration](./integration/api-integration.md) - Server-side integration
- [Event Tracking](./integration/event-tracking.md) - Tracking user interactions

## 🎯 Quick Overview

Measure.js is a privacy-focused web analytics solution that provides:

- **Privacy Compliant**: Built with GDPR compliance in mind
- **Real-time Tracking**: Track user events and pageviews in real-time
- **Geographic Analytics**: IP-based location tracking
- **Device Detection**: Automatic device and browser detection
- **Consent Management**: Built-in consent tracking and cookie management
- **Data Pipeline**: dbt-powered data transformation and analytics
- **Rate Limiting**: Configurable rate limiting to prevent abuse
- **High Performance**: Built with Bun runtime for speed

## 🛠 Tech Stack

- **Runtime**: [Bun](https://bun.sh) - Fast JavaScript runtime
- **Framework**: [Hono](https://hono.dev) - Lightweight web framework
- **Language**: [TypeScript](https://www.typescriptlang.org/) - Type safety
- **Database**: [Google BigQuery](https://cloud.google.com/bigquery) - Data warehouse
- **Analytics**: [dbt](https://www.getdbt.com/) - Data transformation
- **Geolocation**: [MaxMind GeoIP2](https://www.maxmind.com/en/geoip2-services-and-databases) - IP geolocation
- **Deployment**: Docker, Google Cloud Platform, Kubernetes

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client Side   │    │   Server Side   │    │   Data Layer    │
│                 │    │                 │    │                 │
│ measure.js SDK  │───▶│  Hono API       │───▶│  BigQuery       │
│ (Browser)       │    │  (Bun Runtime)  │    │  (Raw Events)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │  Data Pipeline  │    │  Analytics      │
                       │                 │    │                 │
                       │  dbt Models     │───▶│  Dashboards     │
                       │  (Transform)    │    │  (Insights)     │
                       └─────────────────┘    └─────────────────┘
```

## 🔧 Key Features

### Privacy & Security
- **GDPR Compliance**: Built-in consent management and data minimization
- **IP Truncation**: Protects user privacy by truncating IP addresses
- **Rate Limiting**: Configurable rate limiting to prevent abuse
- **CORS Protection**: Secure cross-origin request handling
- **First-Party Cookies**: No third-party tracking dependencies

### Performance & Scalability
- **High Performance**: Bun runtime for fast execution
- **Real-time Processing**: Immediate event processing and storage
- **Horizontal Scaling**: Support for multiple deployment strategies
- **Load Balancing**: Built-in load balancing capabilities
- **Caching**: Intelligent caching strategies

### Data & Analytics
- **Geographic Analytics**: IP-based location tracking
- **Device Detection**: Automatic device and browser identification
- **Session Tracking**: User session identification and management
- **Custom Events**: Flexible event tracking system
- **Data Pipeline**: dbt-powered data transformation

## 📊 Test Coverage

### Current Status
- **Unit Tests**: ✅ 20/20 passing (IP utilities, crypto, config)
- **Integration Tests**: ⚠️ 2/2 passing (health, rate limiting)
- **E2E Tests**: ⚠️ Known issues with Hono/Bun adapter

### Test Categories
- **Unit Tests**: Individual function testing in isolation
- **Integration Tests**: API endpoint and component interaction testing
- **End-to-End Tests**: Complete user flow testing
- **Performance Tests**: Load and stress testing

## 🚀 Deployment Options

### 1. Docker (Recommended)
- Containerized deployment with Docker Compose
- Easy scaling and management
- Production-ready configuration

### 2. Google Cloud Platform
- Cloud Run for serverless deployment
- Load balancer integration
- Custom domain support

### 3. Kubernetes
- Full Kubernetes deployment manifests
- Auto-scaling capabilities
- Production-grade orchestration

### 4. Traditional Server
- PM2 process management
- Nginx reverse proxy
- SSL/TLS configuration

## 📈 Monitoring & Observability

### Application Monitoring
- Health check endpoints
- Performance metrics
- Error tracking and alerting
- Log aggregation and analysis

### Data Pipeline Monitoring
- BigQuery data flow monitoring
- dbt pipeline status
- Data quality validation
- Analytics dashboard metrics

## 🔒 Security Features

### Privacy Protection
- IP address truncation
- Consent management
- Data minimization
- GDPR compliance

### Security Measures
- Rate limiting
- CORS protection
- Input validation
- Secure headers

## 📞 Support

- **[Documentation](docs/README.md)** - Comprehensive guides
- **[GitHub Issues](https://github.com/your-repo/measure-js/issues)** - Bug reports and feature requests
- **[Discussions](https://github.com/your-repo/measure-js/discussions)** - Community discussions
- **[Email Support](mailto:support@9fwr.com)** - Direct support

## 🎯 Quick Start

```bash
# Clone the repository
git clone https://github.com/your-repo/measure-js.git
cd measure-js

# Install dependencies
bun install

# Set up environment
cp example.env .env
# Edit .env with your configuration

# Start development server
bun run dev

# Run tests
bun test
```

## 📋 Recent Updates

### v1.0.0 (December 2024)
- ✅ Complete API implementation with rate limiting
- ✅ Privacy-focused design with GDPR compliance
- ✅ Comprehensive test suite
- ✅ Production deployment guides
- ✅ Enhanced documentation
- ✅ Security hardening
- ✅ Performance optimizations

## 🙏 Acknowledgments

- [Bun](https://bun.sh) for the fast JavaScript runtime
- [Hono](https://hono.dev) for the lightweight web framework
- [dbt](https://www.getdbt.com/) for data transformation
- [MaxMind](https://www.maxmind.com/) for geolocation services

---

**Made with ❤️ for privacy-conscious developers**

**Version**: 1.0.0
**Last Updated**: July 2025
