# Measure.js Documentation

Welcome to the Measure.js documentation! This is a comprehensive web analytics tracking system built with TypeScript, Bun/Hono and dbt, designed to provide lean, privacy-compliant, and fully under your control analytics for web applications.


### 🚀 Getting Started
- [Quick Start](./getting-started/quick-start.md) - Bring up analytics in minutes
- [Configuration](./getting-started/configuration.md) - Environment and application configuration

### 📖 API Reference
- [Events API](./api/events.md) - Track user events and pageviews with rate limiting

### 📊 Analytics & Data
- [dbt Data Pipeline](./analytics/dbt-pipeline.md) - Data transformation and analytics
- [Data Schema](./analytics/data-schema.md) - Database schema and data models
- [Analytics Dashboard](./analytics/dashboard.md) - Understanding your analytics data

### 🔒 Security & Privacy
- [Privacy Features](./privacy.md) - GDPR compliance and privacy controls
- [Security Best Practices](./security/best-practices.md) - Security considerations

### 📱 Client Integration
- [JavaScript SDK](./integration/javascript-sdk.md) - Browser integration guide


## 🎯 Quick Overview

Measure.js is a privacy-focused web analytics solution that provides:

- **Fully under your control**: Deploy in your own cloud environment, fully own your data, customize as needed
- **Privacy Compliant**: Built with GDPR compliance in mind, optional low privacy impact, time limited serverside hashing for session detection
- **Real-time Tracking**: Track user events and pageviews in real-time
- **Geographic Analytics**: IP-based location tracking
- **Device Detection**: Automatic device and browser detection
- **Consent Management**: Built-in consent tracking and cookie management
- **Data Pipeline**: dbt-powered data transformation and analytics
- **Rate Limiting**: Configurable rate limiting to prevent abuse
- **High Performance**: Built with Bun runtime for speed
- **Scalability**: Run on serverless archtecture (currently Google Cloud Run is supported)

## 🛠 Tech Stack

- **Runtime**: [Bun](https://bun.sh) - Fast JavaScript runtime
- **App Framework**: [Hono](https://hono.dev) - Lightweight web framework
- **Language**: [TypeScript](https://www.typescriptlang.org/) - Type safety
- **Database**: [Google BigQuery](https://cloud.google.com/bigquery) - Data warehouse
- **Analytics**: [dbt](https://www.getdbt.com/) - Data transformation
- **Geolocation**: [MaxMind GeoIP2](https://www.maxmind.com/en/geoip2-services-and-databases) - IP geolocation
- **Deployment**: Google Cloud Platform, Cloud Run, Docker

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌───────────────┐    ┌─────────────────┐
│   Client Side   │    │   Server Side │    │  Events Layer   │
│                 │    │               │    │                 │
│ measure.js SDK  │───▶│  Hono API     │───▶│  BigQuery       │
│ (Browser)       │    │  (Cloud Run)  │    │  (Raw Events)   │
└─────────────────┘    └───────────────┘    └─────────────────┘
                                                       │
                                                       ▼
                                            ┌─────────────────┐    ┌──────────────┐
                                            │  Data Pipeline  │    │  Analytics   │
                                            │                 │    │              │
                                            │  dbt Models     │───▶│  Dashboard   │
                                            │  (Cloud Run)    │    │  (Insights)  │
                                            └─────────────────┘    └──────────────┘
```


---


**Version**: 0.1.0
**Last Updated**: September 2025
