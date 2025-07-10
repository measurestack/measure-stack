# Events API

The Events API is the core endpoint for tracking user interactions and pageviews in Measure.js. It handles event processing, user identification, and data storage with built-in rate limiting and privacy protection.

## Endpoint

```
POST /events
GET /events
```

Both GET and POST methods are supported for maximum compatibility.

## Request Format

### Headers

| Header | Required | Description |
|--------|----------|-------------|
| `Content-Type` | No | `application/json` (for POST requests) |
| `User-Agent` | No | Browser user agent (auto-detected) |
| `Cookie` | No | Client ID and hash cookies |
| `Origin` | No | Origin for CORS validation |

### Request Body

The API accepts data in multiple formats:
- **JSON body** (POST requests)
- **Form data** (POST requests)
- **Query parameters** (GET requests)

### Event Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `en` | string | Yes | Event name (e.g., "pageview", "button_click") |
| `url` | string | No | Current page URL (auto-detected if not provided) |
| `r` | string | No | Referrer URL |
| `p` | object | No | Custom parameters/attributes |
| `ts` | string | No | Timestamp (ISO 8601 format) |
| `et` | string | No | Event type (defaults to "event") |
| `ua` | string | No | User agent string |
| `c` | string | No | Client ID (from cookie) |
| `h` | string | No | Hash for user identification |
| `h1` | string | No | Stored hash (from cookie) |
| `ch` | string | No | Client IP address |
| `u` | string | No | User ID (for authenticated users) |

## Response Format

### Success Response

```json
{
  "message": "ok",
  "c": "client-id-here",
  "h": "hash-here"
}
```

### Error Response

```json
{
  "error": "Error message",
  "code": "ERROR_CODE"
}
```

### Rate Limit Response

```json
{
  "error": "Too Many Requests",
  "message": "Rate limit exceeded. Please try again later.",
  "retryAfter": 60
}
```

## Rate Limiting

The API implements configurable rate limiting to prevent abuse:

### Default Limits

- **Window**: 1 minute (60,000ms)
- **Max Requests**: 100 requests per window
- **Burst Protection**: Configurable burst limits

### Rate Limit Headers

| Header | Description |
|--------|-------------|
| `X-RateLimit-Limit` | Maximum requests per window |
| `X-RateLimit-Remaining` | Remaining requests in current window |
| `X-RateLimit-Reset` | Time when the rate limit resets |

### Configuration

Rate limiting can be configured via environment variables:

```env
RATE_LIMIT_WINDOW_MS=60000      # Time window in milliseconds
RATE_LIMIT_MAX_REQUESTS=100     # Maximum requests per window
RATE_LIMIT_SKIP_SUCCESS=true    # Skip rate limiting for successful requests
RATE_LIMIT_SKIP_FAILED=false    # Skip rate limiting for failed requests
```

## Event Types

### 1. Pageview Events

Track page views automatically or manually:

```javascript
// Automatic pageview (recommended)
_measure.pageview();

// Pageview with custom parameters
_measure.pageview({
  page_title: "Homepage",
  page_category: "marketing"
});
```

**Equivalent API call:**
```bash
curl -X POST https://your-domain.com/events \
  -H "Content-Type: application/json" \
  -d '{
    "en": "pageview",
    "url": "https://example.com/homepage",
    "p": {
      "page_title": "Homepage",
      "page_category": "marketing"
    }
  }'
```

### 2. Custom Events

Track specific user interactions:

```javascript
// Button click
_measure.event('button_click', {
  button_id: 'signup',
  button_text: 'Sign Up',
  page: 'homepage'
});

// Form submission
_measure.event('form_submit', {
  form_id: 'contact_form',
  form_type: 'contact'
});
```

**Equivalent API call:**
```bash
curl -X POST https://your-domain.com/events \
  -H "Content-Type: application/json" \
  -d '{
    "en": "button_click",
    "url": "https://example.com/homepage",
    "p": {
      "button_id": "signup",
      "button_text": "Sign Up",
      "page": "homepage"
    }
  }'
```

### 3. Consent Events

Handle user consent for tracking:

```javascript
// User grants consent
_measure.consent({
  id: true,           // Enable client ID tracking
  analytics: true,    // Enable analytics tracking
  marketing: false    // Disable marketing tracking
});

// User revokes consent
_measure.consent({
  id: false,
  analytics: false,
  marketing: false
});
```

**Equivalent API call:**
```bash
curl -X POST https://your-domain.com/events \
  -H "Content-Type: application/json" \
  -d '{
    "en": "consent",
    "p": {
      "id": true,
      "analytics": true,
      "marketing": false
    }
  }'
```

## Data Processing

### Automatic Data Enrichment

The API automatically enriches events with:

1. **Device Information**
   - Device type, brand, model
   - Browser and version
   - Operating system and version
   - Bot detection

2. **Geographic Information**
   - IP address (truncated for privacy)
   - Country, region, city
   - Continent

3. **Session Information**
   - Client ID (from cookie)
   - Hash for user identification
   - Timestamp

### Privacy Features

- **IP Truncation**: IP addresses are truncated to protect user privacy
- **Consent Management**: Respects user consent preferences
- **Cookie Control**: Manages tracking cookies based on consent
- **Data Minimization**: Only collects necessary data

## CORS Support

The API supports Cross-Origin Resource Sharing (CORS):

### Configuration

```typescript
cors: {
  origins: ['https://yourdomain.com', 'https://www.yourdomain.com'],
  allowMethods: ['GET', 'POST', 'OPTIONS'],
  credentials: true,
}
```

### Environment Variables

```env
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com
```

### Preflight Requests

The API automatically handles CORS preflight requests:

```bash
curl -X OPTIONS https://your-domain.com/events \
  -H "Origin: https://yourdomain.com" \
  -H "Access-Control-Request-Method: POST" \
  -H "Access-Control-Request-Headers: Content-Type"
```

## Error Handling

### Common Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| `400` | Bad Request | Check request format and parameters |
| `429` | Too Many Requests | Implement rate limiting in client |
| `500` | Internal Server Error | Check server logs and try again |

### Client-Side Error Handling

```javascript
function sendEvent(eventName, parameters) {
  const xhr = new XMLHttpRequest();
  xhr.open('POST', endpoint, true);
  xhr.withCredentials = true;
  xhr.setRequestHeader('Content-Type', 'application/json');

  xhr.onload = function() {
    if (xhr.status === 200) {
      console.log('Event sent successfully');
    } else if (xhr.status === 429) {
      const retryAfter = xhr.getResponseHeader('Retry-After');
      console.log(`Rate limited. Retry after ${retryAfter} seconds`);
    } else {
      console.error('Failed to send event:', xhr.status);
    }
  };

  xhr.onerror = function() {
    console.error('Network error sending event');
  };

  xhr.send(JSON.stringify({
    en: eventName,
    url: window.location.href,
    r: document.referrer,
    p: parameters
  }));
}
```

## Testing

### Test Event

```bash
# Simple test event
curl -X POST https://your-domain.com/events \
  -H "Content-Type: application/json" \
  -d '{"en":"test_event","url":"https://example.com"}'

# Test with all parameters
curl -X POST https://your-domain.com/events \
  -H "Content-Type: application/json" \
  -d '{
    "en": "test_event",
    "url": "https://example.com/test",
    "r": "https://google.com",
    "p": {
      "test_param": "test_value"
    },
    "ts": "2024-01-01T00:00:00Z",
    "et": "event"
  }'
```

### Test Rate Limiting

```bash
# Send multiple requests quickly to test rate limiting
for i in {1..110}; do
  curl -X POST https://your-domain.com/events \
    -H "Content-Type: application/json" \
    -d "{\"en\":\"rate_test_$i\",\"url\":\"https://example.com\"}" &
done
wait
```

### Verify Data Storage

```sql
-- Check recent events in BigQuery
SELECT
  timestamp,
  event_name,
  url,
  client_id,
  device.browser,
  location.country
FROM `your-project.analytics.events`
WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
ORDER BY timestamp DESC
LIMIT 10;
```

## Best Practices

### 1. Event Naming

- Use descriptive, consistent event names
- Follow a naming convention (e.g., `object_action`)
- Examples: `button_click`, `form_submit`, `video_play`

### 2. Parameter Usage

- Keep parameters relevant and meaningful
- Use consistent parameter names across events
- Avoid sensitive information in parameters

### 3. Performance

- Send events asynchronously
- Implement retry logic for failed requests
- Batch events when possible
- Respect rate limits

### 4. Privacy

- Always respect user consent
- Minimize data collection
- Document your tracking practices
- Use privacy-preserving techniques

## Examples

### E-commerce Tracking

```javascript
// Product view
_measure.event('product_view', {
  product_id: '12345',
  product_name: 'Blue T-Shirt',
  category: 'clothing',
  price: 29.99
});

// Add to cart
_measure.event('add_to_cart', {
  product_id: '12345',
  quantity: 2,
  cart_value: 59.98
});

// Purchase
_measure.event('purchase', {
  order_id: 'ORD-12345',
  total_value: 59.98,
  currency: 'USD',
  payment_method: 'credit_card'
});
```

### User Engagement

```javascript
// Video interaction
_measure.event('video_play', {
  video_id: 'intro-video',
  video_title: 'Product Introduction',
  video_duration: 120
});

// Scroll depth
_measure.event('scroll_depth', {
  depth_percentage: 75,
  page: 'homepage'
});

// Time on page
_measure.event('time_on_page', {
  duration_seconds: 180,
  page: 'product-page'
});
```

### Form Tracking

```javascript
// Form start
_measure.event('form_start', {
  form_id: 'contact_form',
  form_type: 'contact'
});

// Form completion
_measure.event('form_complete', {
  form_id: 'contact_form',
  form_type: 'contact',
  completion_time: 45
});
```

## Monitoring

### Health Checks

```bash
# Check API health
curl https://your-domain.com/health

# Check rate limit status
curl -I https://your-domain.com/events
```

### Logs

Monitor application logs for:
- Rate limit violations
- Error rates
- Performance metrics
- Data processing issues

---

**Need help?** Check the [JavaScript SDK](../integration/javascript-sdk.md) for client-side integration or [contact support](mailto:support@9fwr.com).
