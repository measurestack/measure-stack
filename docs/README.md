# Measure.js Documentation

Welcome to the Measure.js documentation! This is a comprehensive web analytics tracking system built with TypeScript, Bun, and Hono, designed to provide privacy-compliant analytics for web applications.

## 📚 Documentation Sections

### 🚀 Getting Started
- [Production Deployment](./deployment/production.md) - Complete production deployment guide
- [dbt Cloud Run Deployment](./deployment/dbt-cloud-run.md) - Data pipeline deployment
- [Configuration](./getting-started/configuration.md) - Environment and application configuration

### 📖 API Reference
- [Events API](./api/events.md) - Track user events and pageviews with rate limiting
- [Health API](./api/health.md) - System health monitoring
- [Data Models](./api/data-models.md) - Event data structure and types

### 📊 Analytics & Data
- [dbt Data Pipeline](./analytics/dbt-pipeline.md) - Data transformation and analytics
- [Data Schema](./analytics/data-schema.md) - Database schema and data models
- [Analytics Dashboard](./analytics/dashboard.md) - Understanding your analytics data

### 🚀 Deployment
- [Production Deployment](./deployment/production.md) - Complete production deployment guide
- [Docker Deployment](./deployment/docker.md) - Containerized deployment
- [dbt Cloud Run Deployment](./deployment/dbt-cloud-run.md) - Data pipeline deployment

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
- **Deployment**: Google Cloud Platform, Cloud Run, Docker

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Client Side   │    │   Server Side   │    │   Data Layer    │
│                 │    │                 │    │                 │
│ measure.js SDK  │───▶│  Hono API       │───▶│  BigQuery       │
│ (Browser)       │    │  (Cloud Run)    │    │  (Raw Events)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │  Data Pipeline  │    │  Analytics      │
                       │                 │    │                 │
                       │  dbt Models     │───▶│  Dashboards     │
                       │  (Cloud Run)    │    │  (Insights)     │
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
- **Auto-scaling**: Cloud Run automatic scaling capabilities
- **Load Balancing**: Built-in load balancing capabilities
- **Global Distribution**: Multi-region deployment support

### Data & Analytics
- **Geographic Analytics**: IP-based location tracking
- **Device Detection**: Automatic device and browser identification
- **Session Tracking**: User session identification and management
- **Custom Events**: Flexible event tracking system
- **Data Pipeline**: dbt-powered data transformation

## 🚀 Production Deployment

### Google Cloud Platform (Recommended)

The recommended deployment approach uses Google Cloud Platform services:

1. **Cloud Run** - Serverless container deployment
2. **BigQuery** - Data warehouse for analytics
3. **Cloud Scheduler** - Automated dbt pipeline execution
4. **Cloud Build** - Automated container builds

### Quick Deployment

```bash
# Clone the repository
git clone https://github.com/your-repo/measure-js.git
cd measure-js

# Configure environment
cp example.env .env
# Edit .env with your production settings

# Deploy to production
./infrastructure/scripts/deploy_app.sh
```

### Deployment Options

1. **Google Cloud Platform** - Full cloud-native deployment
2. **Docker** - Containerized deployment
3. **Kubernetes** - Production orchestration

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

# Configure environment
cp example.env .env
# Edit .env with your production settings

# Deploy to Google Cloud
./deploy.sh
```

## 📋 Recent Updates

### v1.0.0 (December 2024)
- ✅ Complete API implementation with rate limiting
- ✅ Privacy-focused design with GDPR compliance
- ✅ Google Cloud Platform deployment automation
- ✅ Production deployment guides
- ✅ Enhanced documentation
- ✅ Security hardening
- ✅ Performance optimizations

## 🙏 Acknowledgments

- [Bun](https://bun.sh) for the fast JavaScript runtime
- [Hono](https://hono.dev) for the lightweight web framework
- [dbt](https://www.getdbt.com/) for data transformation
- [MaxMind](https://www.maxmind.com/) for geolocation services
- [Google Cloud Platform](https://cloud.google.com/) for cloud infrastructure

---

**Made with ❤️ for privacy-conscious developers**

**Version**: 1.0.0
**Last Updated**: July 2025
