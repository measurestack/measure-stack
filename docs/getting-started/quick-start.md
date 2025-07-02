# Quick Start Guide

Get Measure.js up and running in under 5 minutes! This guide will walk you through the essential setup to start tracking analytics on your website.

## Prerequisites

- Node.js 18+ or Bun runtime
- Google Cloud Platform account (for BigQuery)
- MaxMind GeoIP2 account (for geolocation)

## 1. Clone and Install

```bash
git clone https://github.com/your-repo/measure-js.git
cd measure-js
bun install
```

## 2. Environment Setup

Copy the example environment file and configure your settings:

```bash
cp example.env .env
```

Edit `.env` with your configuration:

```env
# Google Cloud Platform
GCP_PROJECT_ID=your-project-id
GCP_DATASET_ID=analytics
GCP_TABLE_ID=events

# MaxMind GeoIP2
GEO_ACCOUNT=your-maxmind-account
GEO_KEY=your-maxmind-license-key

# Application Settings
DAILY_SALT=your-secure-salt
CLIENT_ID_COOKIE_NAME=_ms_cid
HASH_COOKIE_NAME=_ms_h
```

## 3. Start the Server

```bash
# Development mode
bun run dev

# Production mode
bun run build
bun run start
```

Your server will be running at `http://localhost:3000`

## 4. Integrate the Tracking Script

Add the Measure.js tracking script to your website:

```html
<script>
  // Replace with your actual endpoint
  var _measure = (function() {
    var endpoint = "https://your-domain.com/events";

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

## 5. Start Tracking

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
  id: true  // Enable tracking for this user
});
```

## 6. Verify Installation

Check that events are being received:

```bash
# Check the health endpoint
curl http://localhost:3000/health

# Check server logs for incoming events
```

## 7. View Your Data

Access your BigQuery dataset to see the collected data:

```sql
SELECT * FROM `your-project.analytics.events`
ORDER BY timestamp DESC
LIMIT 10;
```

## Next Steps

- 📖 Read the [Installation Guide](./installation.md) for detailed setup
- 🔧 Configure [Advanced Settings](./configuration.md)
- 📊 Set up the [dbt Data Pipeline](../analytics/dbt-pipeline.md)
- 🚀 Deploy to [Production](../deployment/cloud.md)

## Troubleshooting

### Common Issues

**Events not appearing in BigQuery?**
- Check your GCP credentials and permissions
- Verify the BigQuery dataset and table exist
- Check server logs for errors

**CORS errors in browser?**
- Ensure your domain is in the CORS origins list
- Check that the endpoint URL is correct

**Geolocation not working?**
- Verify your MaxMind credentials
- Check that the GeoIP2 database is accessible

### Getting Help

- 📖 Check the [API Documentation](../api/events.md)
- 🐛 Report issues on [GitHub](https://github.com/your-repo/measure-js/issues)
- 💬 Join our [Discussions](https://github.com/your-repo/measure-js/discussions)

---

**Need more help?** Check out the [full documentation](../README.md) or [contact support](mailto:support@9fwr.com).
