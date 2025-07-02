# JavaScript SDK

The Measure.js JavaScript SDK provides a simple and powerful way to track user interactions on your website. It's designed to be lightweight, privacy-compliant, and easy to integrate.

## Quick Start

### 1. Include the Script

Add the Measure.js script to your HTML:

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

### 2. Start Tracking

```javascript
// Track pageview
_measure.pageview();

// Track custom event
_measure.event('button_click', {
  button_id: 'signup',
  page: 'homepage'
});
```

## API Reference

### Core Methods

#### `_measure.event(eventName, parameters)`

Track a custom event.

**Parameters:**
- `eventName` (string, required): Name of the event
- `parameters` (object, optional): Additional event data

**Example:**
```javascript
_measure.event('form_submit', {
  form_id: 'contact_form',
  form_type: 'contact',
  user_type: 'new'
});
```

#### `_measure.pageview(parameters)`

Track a pageview event.

**Parameters:**
- `parameters` (object, optional): Additional pageview data

**Example:**
```javascript
_measure.pageview({
  page_title: 'Product Page',
  page_category: 'ecommerce',
  product_id: '12345'
});
```

#### `_measure.consent(consentSettings)`

Handle user consent for tracking.

**Parameters:**
- `consentSettings` (object, required): Consent preferences

**Example:**
```javascript
// Grant consent
_measure.consent({
  id: true,           // Enable client ID tracking
  analytics: true,    // Enable analytics tracking
  marketing: false    // Disable marketing tracking
});

// Revoke consent
_measure.consent({
  id: false,
  analytics: false,
  marketing: false
});
```

## Advanced Configuration

### Custom Endpoint

You can customize the endpoint URL based on your environment:

```javascript
var _measure = (function() {
  // Dynamic endpoint based on environment
  var endpoint = window.location.hostname === 'localhost'
    ? 'http://localhost:3000/events'
    : 'https://your-domain.com/events';

  // ... rest of the implementation
})();
```

### Enhanced Error Handling

```javascript
var _measure = (function() {
  var endpoint = "https://your-domain.com/events";

  function sendData(data) {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', endpoint, true);
    xhr.withCredentials = true;
    xhr.setRequestHeader('Content-Type', 'application/json');

    xhr.onload = function() {
      if (xhr.status === 200) {
        console.log('Event sent successfully');
      } else {
        console.error('Failed to send event:', xhr.status);
      }
    };

    xhr.onerror = function() {
      console.error('Network error sending event');
    };

    xhr.send(JSON.stringify(data));
  }

  return {
    event: function(eventName, parameters) {
      try {
        var data = {
          en: eventName,
          url: window.location.href,
          r: document.referrer,
          p: parameters || {}
        };
        sendData(data);
      } catch (error) {
        console.error('Error tracking event:', error);
      }
    },

    pageview: function(parameters) {
      this.event('pageview', parameters);
    },

    consent: function(consent) {
      this.event('consent', consent);
    }
  };
})();
```

### Retry Logic

```javascript
function sendDataWithRetry(data, maxRetries = 3) {
  var attempt = 0;

  function attemptSend() {
    var xhr = new XMLHttpRequest();
    xhr.open('POST', endpoint, true);
    xhr.withCredentials = true;
    xhr.setRequestHeader('Content-Type', 'application/json');

    xhr.onload = function() {
      if (xhr.status === 200) {
        console.log('Event sent successfully');
      } else if (attempt < maxRetries) {
        attempt++;
        setTimeout(attemptSend, 1000 * attempt); // Exponential backoff
      } else {
        console.error('Failed to send event after', maxRetries, 'attempts');
      }
    };

    xhr.onerror = function() {
      if (attempt < maxRetries) {
        attempt++;
        setTimeout(attemptSend, 1000 * attempt);
      } else {
        console.error('Network error after', maxRetries, 'attempts');
      }
    };

    xhr.send(JSON.stringify(data));
  }

  attemptSend();
}
```

## Integration Examples

### Single Page Application (SPA)

For SPAs, you'll want to track route changes:

```javascript
// React Router example
import { useEffect } from 'react';
import { useLocation } from 'react-router-dom';

function AnalyticsTracker() {
  const location = useLocation();

  useEffect(() => {
    // Track pageview on route change
    _measure.pageview({
      page_title: document.title,
      route: location.pathname
    });
  }, [location]);

  return null;
}

// Vue Router example
router.afterEach((to, from) => {
  _measure.pageview({
    page_title: document.title,
    route: to.path,
    from_route: from.path
  });
});
```

### E-commerce Integration

```javascript
// Product view tracking
function trackProductView(product) {
  _measure.event('product_view', {
    product_id: product.id,
    product_name: product.name,
    category: product.category,
    price: product.price,
    currency: 'USD'
  });
}

// Add to cart tracking
function trackAddToCart(product, quantity) {
  _measure.event('add_to_cart', {
    product_id: product.id,
    product_name: product.name,
    quantity: quantity,
    price: product.price,
    cart_value: product.price * quantity
  });
}

// Purchase tracking
function trackPurchase(order) {
  _measure.event('purchase', {
    order_id: order.id,
    total_value: order.total,
    currency: order.currency,
    payment_method: order.paymentMethod,
    items: order.items.length
  });
}
```

### Form Tracking

```javascript
// Form interaction tracking
function trackFormInteraction(formId, action) {
  _measure.event('form_interaction', {
    form_id: formId,
    action: action, // 'start', 'complete', 'abandon'
    form_type: document.getElementById(formId).dataset.type
  });
}

// Example usage
document.getElementById('contact-form').addEventListener('submit', function() {
  trackFormInteraction('contact-form', 'complete');
});
```

### Video Tracking

```javascript
// Video interaction tracking
function trackVideoEvent(videoId, event, currentTime, duration) {
  _measure.event('video_' + event, {
    video_id: videoId,
    video_title: document.title,
    current_time: currentTime,
    duration: duration,
    progress_percentage: Math.round((currentTime / duration) * 100)
  });
}

// Example usage with HTML5 video
const video = document.querySelector('video');
video.addEventListener('play', () => {
  trackVideoEvent('intro-video', 'play', video.currentTime, video.duration);
});

video.addEventListener('pause', () => {
  trackVideoEvent('intro-video', 'pause', video.currentTime, video.duration);
});
```

## Privacy and Consent

### GDPR Compliance

```javascript
// Consent management
function initializeConsent() {
  // Check for existing consent
  const consent = localStorage.getItem('measure_consent');

  if (consent) {
    const consentData = JSON.parse(consent);
    _measure.consent(consentData);
  } else {
    // Show consent banner
    showConsentBanner();
  }
}

function updateConsent(consentSettings) {
  // Store consent preferences
  localStorage.setItem('measure_consent', JSON.stringify(consentSettings));

  // Send consent event
  _measure.consent(consentSettings);

  // Hide consent banner
  hideConsentBanner();
}

// Consent banner example
function showConsentBanner() {
  const banner = document.createElement('div');
  banner.innerHTML = `
    <div style="position: fixed; bottom: 0; left: 0; right: 0; background: #f0f0f0; padding: 20px; border-top: 1px solid #ccc;">
      <p>We use cookies to analyze site traffic and optimize your site experience.</p>
      <button onclick="updateConsent({id: true, analytics: true, marketing: false})">Accept</button>
      <button onclick="updateConsent({id: false, analytics: false, marketing: false})">Decline</button>
    </div>
  `;
  document.body.appendChild(banner);
}
```

### Do Not Track Support

```javascript
// Check Do Not Track setting
function shouldTrack() {
  return !navigator.doNotTrack || navigator.doNotTrack === '0';
}

// Modified event function
function trackEvent(eventName, parameters) {
  if (shouldTrack()) {
    _measure.event(eventName, parameters);
  }
}
```

## Performance Optimization

### Batch Events

```javascript
// Simple event batching
var eventQueue = [];
var batchTimeout = null;

function queueEvent(eventName, parameters) {
  eventQueue.push({
    en: eventName,
    url: window.location.href,
    r: document.referrer,
    p: parameters
  });

  if (batchTimeout) clearTimeout(batchTimeout);

  batchTimeout = setTimeout(function() {
    if (eventQueue.length > 0) {
      sendBatchEvents(eventQueue);
      eventQueue = [];
    }
  }, 1000);
}

function sendBatchEvents(events) {
  var xhr = new XMLHttpRequest();
  xhr.open('POST', endpoint + '/batch', true);
  xhr.withCredentials = true;
  xhr.setRequestHeader('Content-Type', 'application/json');
  xhr.send(JSON.stringify({ events: events }));
}
```

### Lazy Loading

```javascript
// Load Measure.js only when needed
function loadMeasureJS() {
  if (window._measure) return Promise.resolve(window._measure);

  return new Promise((resolve, reject) => {
    var script = document.createElement('script');
    script.src = 'https://your-domain.com/measure.js';
    script.onload = () => resolve(window._measure);
    script.onerror = reject;
    document.head.appendChild(script);
  });
}

// Usage
loadMeasureJS().then(() => {
  _measure.pageview();
});
```

## Debugging

### Development Mode

```javascript
// Enable debug logging
var _measure = (function() {
  var debug = window.location.hostname === 'localhost';
  var endpoint = "https://your-domain.com/events";

  function log(message, data) {
    if (debug) {
      console.log('[Measure.js]', message, data);
    }
  }

  function sendData(data) {
    log('Sending event:', data);

    var xhr = new XMLHttpRequest();
    xhr.open('POST', endpoint, true);
    xhr.withCredentials = true;
    xhr.setRequestHeader('Content-Type', 'application/json');

    xhr.onload = function() {
      log('Response:', xhr.status, xhr.responseText);
    };

    xhr.send(JSON.stringify(data));
  }

  // ... rest of implementation
})();
```

### Event Validation

```javascript
function validateEvent(eventName, parameters) {
  var errors = [];

  if (!eventName || typeof eventName !== 'string') {
    errors.push('Event name must be a non-empty string');
  }

  if (parameters && typeof parameters !== 'object') {
    errors.push('Parameters must be an object');
  }

  if (errors.length > 0) {
    console.error('Event validation failed:', errors);
    return false;
  }

  return true;
}

// Modified event function
function trackEvent(eventName, parameters) {
  if (validateEvent(eventName, parameters)) {
    _measure.event(eventName, parameters);
  }
}
```

## Browser Compatibility

The SDK is compatible with:

- **Modern Browsers**: Chrome 60+, Firefox 55+, Safari 12+, Edge 79+
- **Mobile Browsers**: iOS Safari 12+, Chrome Mobile 60+
- **Legacy Support**: IE 11+ (with polyfills)

### Polyfills for Legacy Browsers

```html
<!-- For IE 11 support -->
<script src="https://polyfill.io/v3/polyfill.min.js?features=Promise,fetch"></script>
```

## Troubleshooting

### Common Issues

**Events not sending:**
- Check browser console for errors
- Verify endpoint URL is correct
- Ensure CORS is properly configured
- Check network connectivity

**CORS errors:**
- Verify your domain is in the allowed origins
- Check that credentials are properly set
- Ensure HTTPS is used in production

**Cookie issues:**
- Verify cookie domain settings
- Check browser cookie policies
- Ensure SameSite settings are correct

### Debug Commands

```javascript
// Check if SDK is loaded
console.log('Measure.js loaded:', typeof _measure !== 'undefined');

// Test event sending
_measure.event('debug_test', { test: true });

// Check cookies
console.log('Cookies:', document.cookie);
```

---

**Need help?** Check the [API Documentation](../api/events.md) or [contact support](mailto:support@9fwr.com).
