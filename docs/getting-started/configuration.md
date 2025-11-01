# Configuration Guide

This guide covers all configuration options in `deploy/config.source`. After making changes, re-run the deployment as described in the [Quick Start Guide](./quick-start.md).

## Essential Configuration

These are the **minimum required settings** covered in the [Quick Start Guide](./quick-start.md):

```bash
# REQUIRED: Your Google Cloud Project ID
GCP_PROJECT_ID="your-project-id"

# REQUIRED: Your website domain for cookies  
COOKIE_DOMAIN="yourdomain.com"

# REQUIRED: Allowed origins (your website URLs)
CORS_ORIGIN="https://yourdomain.com,https://www.yourdomain.com"
```

## Custom Tracking Domain

To use your own domain instead of the default Cloud Run URL:

```bash
# Set your custom tracking domain
TRACKER_DOMAIN="tracking.yourdomain.com"

# Optional: Override service URL if auto-detection fails
SERVICE_URL="https://tracking.yourdomain.com"
```

**Note**: You must follow [Google Cloud's custom domain mapping guide](https://cloud.google.com/run/docs/mapping-custom-domains#run) to set up the domain mapping.

**Note**: Not all regions allow cloud run domain mapping. make sure to chose a region that supports it (see link above) using:

```
REGION="europe-west1"               # GCP region for all resources
```

## Geolocation Configuration

Enable IP-based geolocation using MaxMind GeoIP2:

```bash
# Get account from https://www.maxmind.com/en/geolite-free-ip-geolocation-data
GEO_ACCOUNT="your-account-id"
GEO_KEY="your-license-key"
```

Without these credentials, geolocation data will not be collected.

## Deployment Configuration

### Cloud Run Settings

```bash
# Resource allocation
MEMORY="512Mi"          # Memory per instance
CPU="1"                 # CPU allocation
MAX_INSTANCES="10"      # Maximum concurrent instances
MIN_INSTANCES="0"       # Minimum instances (set to 1 for always-warm)
TIMEOUT="300"           # Request timeout in seconds
REGION="europe-west1"   # GCP region for all resources
```

## BigQuery Configuration

```bash
# BigQuery dataset and table settings
GCP_DATASET_ID="measure_js"         # BigQuery dataset name
GCP_TABLE_ID="events"               # Events table name
```

## Advanced Configuration

### Cookie Settings

```bash
# Cookie configuration
CLIENT_ID_COOKIE_NAME="_ms_cid"     # Client ID cookie name
HASH_COOKIE_NAME="_ms_h"            # Hash cookie name
```


### Service Configuration

```bash
# Application service name
SERVICE_NAME="measure-app"

# Firestore database (usually keep as default)
GCP_FIRESTORE_DATABASE="(default)"
```

### DBT Data Pipeline

```bash
# DBT job configuration
DBT_JOB_NAME="measure-dbt-job"      # Cloud Run job name
DBT_SA_NAME="measure-dbt-sa"        # Service account name
DBT_MEMORY="2Gi"                    # Memory for DBT processing
DBT_CPU="1"                         # CPU for DBT processing
DBT_MAX_RETRIES="3"                 # Job retry attempts
DBT_TIMEOUT="1800s"                 # Job timeout (30 minutes)
DBT_SCHEDULE="0 6 * * *"            # Daily at 6 AM UTC
DBT_TARGET="prod"                   # DBT target environment
```

## After Configuration Changes

After modifying `deploy/config.source`, redeploy the application:

```bash
# Redeploy the application
./deploy/deploy_app.sh

# If you changed DBT settings, also redeploy the data pipeline
./deploy/deploy_dbt.sh
```
