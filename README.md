# MeasureStack v0.3.0

Privacy-first web analytics platform. Self-hosted, simple, and extensible.

## Quick Install

```bash
cd deploy && cp config.source.template deploy/config.source
# Then edit with your settings; bring your own Google Cloud Project
./deploy_app.sh      # Deploy tracking API
./deploy_dbt.sh      # Deploy analytics pipeline
```

## Documentation

- [Quick Start](./docs/getting-started/quick-start.md) - Full setup guide
- [Configuration](./docs/getting-started/configuration.md) - Configuration options

### 📖 More Documentation
- [Events API](./docs/api/events.md) - Track user events and pageviews
- [dbt Data Pipeline](./docs/analytics/dbt-pipeline.md) - Data transformation
- [Privacy Features](./docs/privacy.md) - GDPR compliance
- [JavaScript SDK](./docs/integration/javascript-sdk.md) - Browser integration


## Features

- **Privacy-first**: privacy friendly cookieless tracking with daily salt rotation, 
- **Self-hosted**: Deploy in your own cloud environment, fully own your data
- **Simple**: 5 core files (~500 lines), easy to understand and extend
- **Real-time tracking**: Events, pageviews, and custom parameters
- **Device & location enrichment**: User-agent parsing and IP geolocation
- **Consent management**: Cookie-based opt-in/opt-out and/or flexible cookieless tracking
- **Data pipeline**: dbt-powered transformation and analytics
- **Scalable**: Serverless architecture on Google Cloud Run

## Tech Stack

- **Runtime**: Bun
- **Framework**: Hono
- **Database**: BigQuery + Firestore
- **Analytics**: dbt
- **Deployment**: Google Cloud Run

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


## Development

```bash
bun install          # Install dependencies
bun run dev          # Start dev server with hot reload
bun test             # Run end-to-end tests
```

## License

MIT
