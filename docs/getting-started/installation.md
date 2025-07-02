# Installation Guide

This comprehensive guide will walk you through installing and configuring Measure.js for production use.

## System Requirements

### Minimum Requirements
- **Runtime**: Bun 1.0+ or Node.js 18+
- **Memory**: 512MB RAM
- **Storage**: 1GB free space
- **Network**: Internet access for external services

### Recommended Requirements
- **Runtime**: Bun 1.0+
- **Memory**: 2GB+ RAM
- **Storage**: 5GB+ free space
- **CPU**: 2+ cores

## Step 1: Environment Setup

### Install Bun (Recommended)

```bash
# macOS/Linux
curl -fsSL https://bun.sh/install | bash

# Windows (WSL)
curl -fsSL https://bun.sh/install | bash

# Verify installation
bun --version
```

### Alternative: Install Node.js

```bash
# Using nvm (recommended)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install 18
nvm use 18

# Or download from nodejs.org
```

## Step 2: Clone the Repository

```bash
git clone https://github.com/your-repo/measure-js.git
cd measure-js
```

## Step 3: Install Dependencies

```bash
# Using Bun (recommended)
bun install

# Using npm
npm install

# Using yarn
yarn install
```

## Step 4: Environment Configuration

### Create Environment File

```bash
cp example.env .env
```

### Configure Environment Variables

Edit `.env` with your specific configuration:

```env
# =============================================================================
# APPLICATION SETTINGS
# =============================================================================
NODE_ENV=development
PORT=3000
REGION=us-central1
SERVICE_NAME=measure-js-app

# =============================================================================
# SECURITY & PRIVACY
# =============================================================================
DAILY_SALT=your-super-secure-random-salt-here
CLIENT_ID_COOKIE_NAME=_ms_cid
HASH_COOKIE_NAME=_ms_h

# =============================================================================
# GOOGLE CLOUD PLATFORM
# =============================================================================
GCP_PROJECT_ID=your-gcp-project-id
GCP_DATASET_ID=analytics
GCP_TABLE_ID=events

# =============================================================================
# MAXMIND GEOIP2
# =============================================================================
GEO_ACCOUNT=your-maxmind-account-id
GEO_KEY=your-maxmind-license-key

# =============================================================================
# CORS SETTINGS
# =============================================================================
CORS_ORIGINS=https://yourdomain.com,https://www.yourdomain.com
CORS_METHODS=GET,POST,OPTIONS
CORS_CREDENTIALS=true
```

### Environment Variable Reference

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `NODE_ENV` | Environment mode | No | `development` |
| `PORT` | Server port | No | `3000` |
| `DAILY_SALT` | Salt for hashing | Yes | - |
| `GCP_PROJECT_ID` | Google Cloud Project ID | Yes | - |
| `GCP_DATASET_ID` | BigQuery dataset name | Yes | - |
| `GCP_TABLE_ID` | BigQuery table name | Yes | - |
| `GEO_ACCOUNT` | MaxMind account ID | Yes | - |
| `GEO_KEY` | MaxMind license key | Yes | - |

## Step 5: Google Cloud Platform Setup

### 1. Create a GCP Project

```bash
# Install Google Cloud CLI
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# Login to GCP
gcloud auth login

# Create project (if needed)
gcloud projects create your-project-id --name="Your Project Name"

# Set project
gcloud config set project your-project-id
```

### 2. Enable Required APIs

```bash
# Enable BigQuery API
gcloud services enable bigquery.googleapis.com

# Enable Cloud Functions API (if using)
gcloud services enable cloudfunctions.googleapis.com

# Enable Cloud Logging API
gcloud services enable logging.googleapis.com
```

### 3. Create Service Account

```bash
# Create service account
gcloud iam service-accounts create measure-js-sa \
  --display-name="Measure.js Service Account"

# Get service account email
SA_EMAIL=$(gcloud iam service-accounts list \
  --filter="displayName:Measure.js Service Account" \
  --format="value(email)")

# Grant BigQuery permissions
gcloud projects add-iam-policy-binding your-project-id \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/bigquery.dataEditor"

gcloud projects add-iam-policy-binding your-project-id \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/bigquery.jobUser"

# Create and download key
gcloud iam service-accounts keys create key.json \
  --iam-account=$SA_EMAIL

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="$(pwd)/key.json"
```

### 4. Create BigQuery Dataset and Table

```bash
# Create dataset
bq mk --dataset your-project-id:analytics

# Create events table
bq mk --table your-project-id:analytics.events \
  timestamp:TIMESTAMP,event_type:STRING,event_name:STRING,parameters:STRING,user_agent:STRING,url:STRING,referrer:STRING,client_id:STRING,hash:STRING,user_id:STRING,device:RECORD,location:RECORD
```

## Step 6: MaxMind GeoIP2 Setup

### 1. Create MaxMind Account

1. Visit [MaxMind.com](https://www.maxmind.com/)
2. Create a free account
3. Generate a license key

### 2. Configure GeoIP2

```bash
# Install MaxMind GeoIP2 database (optional for local development)
# The service will use MaxMind's web service by default
```

## Step 7: Verify Installation

### 1. Build the Application

```bash
# Build TypeScript
bun run build

# Or with npm
npm run build
```

### 2. Run Tests

```bash
# Run all tests
bun test

# Run specific test suites
bun test tests/unit/
bun test tests/integration/
bun test tests/e2e/
```

### 3. Start the Server

```bash
# Development mode
bun run dev

# Production mode
bun run start
```

### 4. Test Endpoints

```bash
# Health check
curl http://localhost:3000/health

# Test event tracking
curl -X POST http://localhost:3000/events \
  -H "Content-Type: application/json" \
  -d '{"en":"test_event","url":"http://example.com"}'
```

## Step 8: Production Considerations

### Security Checklist

- [ ] Use strong, unique `DAILY_SALT`
- [ ] Configure proper CORS origins
- [ ] Set up HTTPS in production
- [ ] Use environment-specific configurations
- [ ] Secure service account keys
- [ ] Enable audit logging

### Performance Optimization

- [ ] Configure proper memory limits
- [ ] Set up monitoring and alerting
- [ ] Optimize BigQuery table partitioning
- [ ] Configure proper caching strategies

### Monitoring Setup

```bash
# Install monitoring tools
bun add @google-cloud/monitoring

# Set up health checks
curl http://localhost:3000/health
```

## Troubleshooting

### Common Installation Issues

**Permission Denied Errors**
```bash
# Fix file permissions
chmod +x scripts/*.sh
chmod 600 key.json
```

**BigQuery Connection Issues**
```bash
# Verify credentials
gcloud auth application-default login

# Test BigQuery access
bq ls your-project-id:analytics
```

**MaxMind API Issues**
```bash
# Test MaxMind connection
curl "https://geoip.maxmind.com/geoip/v2.1/country/8.8.8.8" \
  -u "your-account:your-license-key"
```

### Getting Help

- 📖 Check the [Configuration Guide](./configuration.md)
- 🐛 Report issues on [GitHub](https://github.com/your-repo/measure-js/issues)
- 💬 Join our [Discussions](https://github.com/your-repo/measure-js/discussions)

## Next Steps

- 🚀 [Deploy to Production](../deployment/cloud.md)
- 📊 [Set up Analytics Pipeline](../analytics/dbt-pipeline.md)
- 🔧 [Configure Advanced Settings](./configuration.md)
- 📱 [Integrate with Your Website](../integration/javascript-sdk.md)

---

**Need assistance?** Contact our support team at [support@9fwr.com](mailto:support@9fwr.com).
