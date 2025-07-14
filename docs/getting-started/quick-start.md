# Quick Start Guide

Get Measure.js deployed to production in under 10 minutes! This guide will walk you through deploying your analytics tracking system to Google Cloud Platform.

## Prerequisites

- Google Cloud Platform account with billing enabled
- Google Cloud CLI (`gcloud`) installed and authenticated
- MaxMind GeoIP2 account (for geolocation)
- Domain name (optional, for custom domain)

## 1. Clone and Setup

```bash
git clone https://github.com/your-repo/measure-js.git
cd measure-js
```

## 2. Environment Configuration

Copy the example environment file and configure your production settings:

```bash
cp example.env .env
```

Edit `.env` with your production configuration:

```env
# Google Cloud Platform
GCP_PROJECT_ID=your-production-project-id
GCP_DATASET_ID=measure_js_analytics
GCP_TABLE_ID=events

# MaxMind GeoIP2
GEO_ACCOUNT=your-maxmind-account
GEO_KEY=your-maxmind-license-key

# Security
DAILY_SALT=your-secure-production-salt

# CORS (your domains)
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com

# Rate Limiting
RATE_LIMIT_WINDOW_MS=60000
RATE_LIMIT_MAX_REQUESTS=100

# Environment
NODE_ENV=production
REGION=europe-west3
```

## 3. Deploy to Production

Run the automated deployment script:

```bash
./deploy.sh
```

This script will:
- ✅ Check prerequisites (gcloud, authentication, environment)
- ✅ Validate your configuration
- ✅ Deploy the application to Cloud Run
- ✅ Set up BigQuery dataset and tables
- ✅ Configure CORS and security settings

### Deployment Options

The `deploy.sh` script supports different deployment options:

```bash
# Deploy everything (recommended)
./deploy.sh

# Deploy only the main application
./deploy.sh --app-only

# Deploy only the dbt data pipeline
./deploy.sh --dbt-only

# Get help
./deploy.sh --help
```

## 4. Deploy Data Pipeline (Optional)

If you didn't deploy the dbt pipeline in step 3, you can deploy it separately:

```bash
./deploy.sh --dbt-only
```

This creates:
- ✅ Cloud Run job for dbt processing
- ✅ Cloud Scheduler for automated runs
- ✅ Data transformation pipeline

## 5. Integrate the Tracking Script

Add the Measure.js tracking script to your website:

```html
<script>
  // Replace with your actual Cloud Run endpoint
  var _measure = (function() {
    var endpoint = "https://your-app-name-xyz123-ez.a.run.app/events";

    function sendData(data) {
      var xhr = new XMLHttpRequest();
      xhr.open('POST', endpoint, true);
      xhr.withCredentials = true;
      xhr.setRequestHeader('Content-Type', 'application/json');
      xhr.send(JSON.stringify(data));
    }

    return {
      event: function(eventName, parameters) {
        var data = {
          en: eventName,
          url: window.location.href,
          r: document.referrer,
          p: parameters
        };
        sendData(data);
      },

      pageview: function(parameters) {
        this.event('pageview', parameters);
      },

      consent: function(consent) {
        this.event('consent', consent);
      }
    };
  })();
</script>
```

## 6. Start Tracking

Track your first events:

```javascript
// Track a pageview
_measure.pageview();

// Track a custom event
_measure.event('button_click', {
  button_id: 'signup',
  page: 'homepage'
});

// Handle user consent
_measure.consent({
  id: true,           // Enable client ID tracking
  analytics: true,    // Enable analytics tracking
  marketing: false    // Disable marketing tracking
});
```

## 7. Verify Deployment

Check that your deployment is working:

```bash
# Check the health endpoint
curl https://your-app-name-xyz123-ez.a.run.app/health

# View Cloud Run logs
gcloud run services logs read measure-js-app --region=europe-west3 --limit=50
```

## 8. View Your Data

Access your BigQuery dataset to see the collected data:

```sql
SELECT * FROM `your-project-id.measure_js_analytics.events`
ORDER BY timestamp DESC
LIMIT 10;
```

## Next Steps

- 📖 Read the [Production Deployment Guide](../deployment/production.md) for advanced configuration
- 📊 Set up the [dbt Data Pipeline](../analytics/dbt-pipeline.md) for analytics
- 🔧 Configure [Advanced Settings](./configuration.md)
- 🚀 Set up [Custom Domain](../deployment/production.md#custom-domain)

## Troubleshooting

### Common Issues

**Deployment fails with permission errors?**
```bash
# Check your GCP authentication
gcloud auth list

# Ensure you have the required roles
gcloud projects get-iam-policy your-project-id \
  --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"
```

**Deploy script fails?**
```bash
# Check deployment logs
tail -f deploy.log

# Verify prerequisites
./deploy.sh --help

# Try manual deployment
./infrastructure/scripts/deploy_app.sh
```

**Events not appearing in BigQuery?**
- Check your GCP credentials and permissions
- Verify the BigQuery dataset and table exist
- Check Cloud Run logs for errors

**CORS errors in browser?**
- Ensure your domain is in the CORS origins list
- Check that the endpoint URL is correct
- Verify Cloud Run service is accessible

**Geolocation not working?**
- Verify your MaxMind credentials
- Check that the GeoIP2 service is accessible
- Review Cloud Run logs for geolocation errors

### Getting Help

- 📖 Check the [API Documentation](../api/events.md)
- 🐛 Report issues on [GitHub](https://github.com/your-repo/measure-js/issues)
- 💬 Join our [Discussions](https://github.com/your-repo/measure-js/discussions)

## Production Checklist

Before going live, ensure:

- ✅ [ ] Environment variables are properly configured
- ✅ [ ] CORS origins include your production domains
- ✅ [ ] Rate limiting is appropriate for your traffic
- ✅ [ ] MaxMind GeoIP2 credentials are valid
- ✅ [ ] BigQuery dataset and tables are created
- ✅ [ ] Cloud Run service is accessible
- ✅ [ ] Tracking script is integrated on your website
- ✅ [ ] Consent management is implemented
- ✅ [ ] Data pipeline is deployed (optional)

---

**Need more help?** Check out the [full documentation](../README.md) or [contact support](mailto:support@9fwr.com).
