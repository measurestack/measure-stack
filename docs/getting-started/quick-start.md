# Quick Start Guide

Deploy Measure.js analytics to production in minutes.

## Prerequisites

1. **Install Google Cloud CLI**: [Installation guide](https://cloud.google.com/sdk/docs/install)
2. **Authenticate with Google Cloud**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```
3. **Google Cloud Project**: You need a GCP project where you have Owner permissions

## 1. Clone and Configure

```bash
git clone https://github.com/your-repo/measure-js.git
cd measure-js
```

## 2. Essential Configuration

Edit `infrastructure/config.source` - **ONLY change these required settings**:

```bash
# REQUIRED: Your Google Cloud Project ID
GCP_PROJECT_ID="your-project-id"

# REQUIRED: Your website domain for cookies  
COOKIE_DOMAIN="yourdomain.com"

# REQUIRED: Allowed origins (your website URLs)
CORS_ORIGIN="https://yourdomain.com,https://www.yourdomain.com"
```

All other settings can remain as defaults for now.

## 3. Deploy Application

```bash
./infrastructure/scripts/deploy_app.sh
```

This deploys the tracking API and creates the BigQuery dataset. **Copy the tracking code printed at the end** - you'll need it for your website.

## 4. Deploy the Analytics Script

Add the generated tracking code to your website (e.g., via Google Tag Manager):

```html
<!-- The script will be displayed after deploy_app.sh completes -->
```

## 5. Deploy Data Pipeline

```bash
./infrastructure/scripts/deploy_dbt.sh
```

This sets up automated data processing that runs daily.

## 6. Start Tracking

```javascript
// Track pageviews
_measure.pageview();

// Track custom events  
_measure.event('button_click', { button_id: 'signup' });
```

## Verify

Check your BigQuery dataset to see incoming data:
```sql
SELECT * FROM `your-project-id.measure_js.events` 
ORDER BY timestamp DESC LIMIT 10;
```

---

**Need detailed configuration?** See the [full documentation](./configuration.md).
