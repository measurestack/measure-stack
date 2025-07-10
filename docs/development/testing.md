# Testing Guide

This guide covers testing strategies, running tests, and best practices for the Measure.js application.

## 🧪 Test Structure

The test suite is organized into three main categories:

```
tests/
├── 📁 unit/               # Unit tests (isolated function testing)
│   ├── 📁 config/        # Configuration tests
│   ├── 📁 services/      # Service layer tests
│   └── 📁 utils/         # Utility function tests
├── 📁 integration/        # Integration tests (API endpoints)
│   └── 📁 api/           # API endpoint tests
├── 📁 e2e/               # End-to-end tests (complete flows)
├── 📄 README.md          # Test documentation
└── 📄 test-runner.ts     # Test runner configuration
```

## 🚀 Running Tests

### All Tests
```bash
bun test
```

### Specific Test Categories
```bash
# Unit tests only
bun test tests/unit/

# Integration tests only
bun test tests/integration/

# End-to-end tests only
bun test tests/e2e/
```

### Watch Mode
```bash
# Watch all tests
bun test --watch

# Watch specific test files
bun test --watch tests/unit/utils/
```

### Test Coverage
```bash
# Run with coverage (if available)
bun test --coverage
```

## 📊 Test Results Summary

### ✅ Passing Tests

#### Unit Tests (20/20)
- **IP Utilities** (10/10): IPv4/IPv6 truncation, client IP detection, IP sanitization
- **Crypto Utilities** (6/6): Hash generation, consistent hashing
- **Environment Configuration** (4/4): Config structure validation

#### Integration Tests (2/2)
- **Health Endpoint**: Basic health check functionality
- **Rate Limiting**: Rate limit middleware functionality

### ⚠️ Known Issues

#### Hono/Bun Adapter Issues
Some tests fail due to Hono/Bun adapter environment setup:

- **Event Processing Tests**: `getConnInfo` function expects specific Bun runtime environment
- **Integration Tests**: API endpoint tests affected by adapter issues
- **End-to-End Tests**: Complete flow tests impacted

#### Workarounds
1. **Mock Hono Context**: Create proper mocks for unit tests
2. **Test Environment Setup**: Configure proper Bun runtime simulation
3. **Separate Concerns**: Keep unit tests focused on business logic

## 🔧 Unit Tests

### Configuration Tests

Test environment configuration and validation:

```typescript
// tests/unit/config/environment.test.ts
import { describe, it, expect } from 'bun:test';
import { config } from '../../../src/config/environment';

describe('Environment Configuration', () => {
  it('should have required configuration structure', () => {
    expect(config).toHaveProperty('dailySalt');
    expect(config).toHaveProperty('gcp');
    expect(config).toHaveProperty('geo');
    expect(config).toHaveProperty('rateLimit');
  });

  it('should have valid rate limit configuration', () => {
    expect(config.rateLimit.windowMs).toBeGreaterThan(0);
    expect(config.rateLimit.maxRequests).toBeGreaterThan(0);
  });
});
```

### Utility Tests

Test utility functions in isolation:

```typescript
// tests/unit/utils/ipUtils.test.ts
import { describe, it, expect } from 'bun:test';
import { truncateIP, getClientIP } from '../../../src/utils/helpers/ipUtils';

describe('IP Utilities', () => {
  it('should truncate IPv4 addresses', () => {
    expect(truncateIP('192.168.1.1')).toBe('192.168.1.0');
    expect(truncateIP('10.0.0.1')).toBe('10.0.0.0');
  });

  it('should truncate IPv6 addresses', () => {
    expect(truncateIP('2001:db8::1')).toBe('2001:db8::');
  });

  it('should handle invalid IP addresses', () => {
    expect(truncateIP('invalid')).toBe('invalid');
    expect(truncateIP('')).toBe('');
  });
});
```

### Service Tests

Test business logic services:

```typescript
// tests/unit/services/tracking/eventProcessor.test.ts
import { describe, it, expect, mock } from 'bun:test';
import { processEvent } from '../../../src/services/tracking/eventProcessor';

describe('Event Processor', () => {
  it('should process basic event', () => {
    const event = {
      en: 'pageview',
      url: 'https://example.com',
      ts: new Date().toISOString()
    };

    const result = processEvent(event);
    expect(result).toHaveProperty('event_name', 'pageview');
    expect(result).toHaveProperty('url', 'https://example.com');
  });

  it('should enrich event with device information', () => {
    const event = {
      en: 'button_click',
      ua: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    };

    const result = processEvent(event);
    expect(result.device).toHaveProperty('browser');
    expect(result.device).toHaveProperty('os');
  });
});
```

## 🔗 Integration Tests

### API Endpoint Tests

Test API endpoints with real HTTP requests:

```typescript
// tests/integration/api/events.test.ts
import { describe, it, expect } from 'bun:test';

describe('Events API', () => {
  const baseUrl = 'http://localhost:3000';

  it('should accept POST requests', async () => {
    const response = await fetch(`${baseUrl}/events`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'test_event',
        url: 'https://example.com'
      })
    });

    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.message).toBe('ok');
  });

  it('should accept GET requests', async () => {
    const params = new URLSearchParams({
      en: 'test_event',
      url: 'https://example.com'
    });

    const response = await fetch(`${baseUrl}/events?${params}`);
    expect(response.status).toBe(200);
  });

  it('should handle rate limiting', async () => {
    const requests = Array.from({ length: 110 }, () =>
      fetch(`${baseUrl}/events`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ en: 'rate_test', url: 'https://example.com' })
      })
    );

    const responses = await Promise.all(requests);
    const rateLimited = responses.filter(r => r.status === 429);
    expect(rateLimited.length).toBeGreaterThan(0);
  });
});
```

### Health Check Tests

```typescript
// tests/integration/api/health.test.ts
import { describe, it, expect } from 'bun:test';

describe('Health API', () => {
  const baseUrl = 'http://localhost:3000';

  it('should return health status', async () => {
    const response = await fetch(`${baseUrl}/health`);
    expect(response.status).toBe(200);

    const data = await response.json();
    expect(data).toHaveProperty('status', 'ok');
    expect(data).toHaveProperty('timestamp');
  });
});
```

## 🎯 End-to-End Tests

### Complete User Flow Tests

```typescript
// tests/e2e/basic-flow.test.ts
import { describe, it, expect } from 'bun:test';

describe('Basic User Flow', () => {
  it('should track complete user journey', async () => {
    // 1. User visits homepage
    const pageviewResponse = await fetch('http://localhost:3000/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'pageview',
        url: 'https://example.com/homepage'
      })
    });
    expect(pageviewResponse.status).toBe(200);

    // 2. User clicks button
    const clickResponse = await fetch('http://localhost:3000/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'button_click',
        url: 'https://example.com/homepage',
        p: { button_id: 'signup' }
      })
    });
    expect(clickResponse.status).toBe(200);

    // 3. User submits form
    const formResponse = await fetch('http://localhost:3000/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'form_submit',
        url: 'https://example.com/signup',
        p: { form_id: 'signup_form' }
      })
    });
    expect(formResponse.status).toBe(200);
  });
});
```

## 🛠️ Manual Testing

### API Testing

#### Using curl

```bash
# Test basic event
curl -X POST http://localhost:3000/events \
  -H "Content-Type: application/json" \
  -d '{"en":"test_event","url":"https://example.com"}'

# Test with all parameters
curl -X POST http://localhost:3000/events \
  -H "Content-Type: application/json" \
  -d '{
    "en": "pageview",
    "url": "https://example.com/test",
    "r": "https://google.com",
    "p": {"page_title": "Test Page"},
    "ts": "2024-01-01T00:00:00Z"
  }'

# Test rate limiting
for i in {1..110}; do
  curl -X POST http://localhost:3000/events \
    -H "Content-Type: application/json" \
    -d "{\"en\":\"rate_test_$i\",\"url\":\"https://example.com\"}" &
done
wait
```

#### Using Postman

1. **Create Collection**: "Measure.js API Tests"
2. **Add Requests**:
   - POST `/events` - Basic event
   - POST `/events` - Pageview with parameters
   - POST `/events` - Custom event
   - GET `/health` - Health check
3. **Set Environment Variables**:
   - `baseUrl`: `http://localhost:3000`
   - `clientId`: (from response cookies)

### Browser Testing

#### Test HTML Page

Create `test.html`:

```html
<!DOCTYPE html>
<html>
<head>
    <title>Measure.js Test Page</title>
    <script src="http://localhost:3000/static/measure.js"></script>
</head>
<body>
    <h1>Test Page</h1>
    <button onclick="_measure.event('button_click', {button_id: 'test'})">
        Test Button
    </button>
    <form onsubmit="_measure.event('form_submit', {form_id: 'test_form'}); return false;">
        <input type="text" placeholder="Test input">
        <button type="submit">Submit</button>
    </form>

    <script>
        // Initialize tracking
        _measure.init('http://localhost:3000');

        // Test pageview
        _measure.pageview();

        // Test custom event
        setTimeout(() => {
            _measure.event('test_event', {test_param: 'test_value'});
        }, 1000);
    </script>
</body>
</html>
```

## 🔍 Debugging Tests

### Test Debugging

```bash
# Run specific test with debug output
bun test tests/unit/utils/ipUtils.test.ts --verbose

# Run with console.log output
bun test tests/integration/api/events.test.ts --reporter=verbose
```

### Application Debugging

```bash
# Start with debug logging
DEBUG=* bun run dev

# Check application logs
tail -f app.log

# Monitor BigQuery data
bq query --use_legacy_sql=false "
  SELECT * FROM \`your-project.analytics.events\`
  WHERE timestamp >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 1 HOUR)
  ORDER BY timestamp DESC
  LIMIT 10
"
```

### Common Issues

#### 1. Hono Context Issues

**Problem**: Tests fail due to missing Bun runtime context

**Solution**: Mock the Hono context

```typescript
// Create mock context
const mockContext = {
  req: {
    header: (name: string) => headers[name],
    url: 'http://localhost:3000/events'
  },
  json: (data: any) => ({ status: 200, body: data }),
  text: (data: string) => ({ status: 200, body: data })
};
```

#### 2. Environment Variables

**Problem**: Tests fail due to missing environment variables

**Solution**: Set up test environment

```typescript
// tests/setup.ts
process.env.GCP_PROJECT_ID = 'test-project';
process.env.GCP_DATASET_ID = 'test_dataset';
process.env.GCP_TABLE_ID = 'test_events';
process.env.DAILY_SALT = 'test-salt';
```

#### 3. Rate Limiting in Tests

**Problem**: Tests are rate limited

**Solution**: Configure test-specific rate limits

```typescript
// tests/integration/api/rateLimit.test.ts
process.env.RATE_LIMIT_MAX_REQUESTS = '1000';
process.env.RATE_LIMIT_WINDOW_MS = '1000';
```

## 📈 Performance Testing

### Load Testing

```bash
# Install artillery (if not using Bun)
npm install -g artillery

# Create load test
cat > load-test.yml << EOF
config:
  target: 'http://localhost:3000'
  phases:
    - duration: 60
      arrivalRate: 10
scenarios:
  - name: "Event tracking"
    requests:
      - post:
          url: "/events"
          headers:
            Content-Type: "application/json"
          json:
            en: "pageview"
            url: "https://example.com"
EOF

# Run load test
artillery run load-test.yml
```

### Stress Testing

```bash
# Test rate limiting under load
for i in {1..1000}; do
  curl -X POST http://localhost:3000/events \
    -H "Content-Type: application/json" \
    -d "{\"en\":\"stress_test_$i\",\"url\":\"https://example.com\"}" &
done
wait
```

## 🔄 CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup Bun
      uses: oven-sh/setup-bun@v1
      with:
        bun-version: latest

    - name: Install dependencies
      run: bun install

    - name: Run unit tests
      run: bun test tests/unit/

    - name: Run integration tests
      run: bun test tests/integration/

    - name: Run e2e tests
      run: bun test tests/e2e/
```

### Local CI

```bash
#!/bin/bash
# scripts/test-ci.sh

echo "Running CI tests..."

# Install dependencies
bun install

# Run linting
bun run lint

# Run unit tests
bun test tests/unit/

# Run integration tests
bun test tests/integration/

# Run e2e tests
bun test tests/e2e/

echo "All tests completed!"
```

## 📊 Test Coverage

### Coverage Goals

- **Unit Tests**: 90%+ coverage
- **Integration Tests**: All API endpoints
- **E2E Tests**: Critical user flows

### Coverage Report

```bash
# Generate coverage report
bun test --coverage

# View coverage in browser
open coverage/lcov-report/index.html
```

## 🎯 Best Practices

### 1. Test Organization

- **Unit Tests**: Test individual functions in isolation
- **Integration Tests**: Test component interactions
- **E2E Tests**: Test complete user flows

### 2. Test Naming

```typescript
describe('UserService', () => {
  describe('createUser', () => {
    it('should create user with valid data', () => {
      // Test implementation
    });

    it('should reject invalid email', () => {
      // Test implementation
    });
  });
});
```

### 3. Test Data

```typescript
// Use factories for test data
const createTestEvent = (overrides = {}) => ({
  en: 'test_event',
  url: 'https://example.com',
  ts: new Date().toISOString(),
  ...overrides
});
```

### 4. Mocking

```typescript
// Mock external dependencies
const mockBigQuery = {
  insert: mock(() => Promise.resolve()),
  query: mock(() => Promise.resolve([]))
};
```

### 5. Async Testing

```typescript
it('should process event asynchronously', async () => {
  const event = createTestEvent();
  const result = await processEvent(event);
  expect(result).toBeDefined();
});
```

## 🚨 Troubleshooting

### Common Test Failures

1. **Environment Issues**
   - Check environment variables
   - Verify database connections
   - Ensure services are running

2. **Timing Issues**
   - Use proper async/await
   - Add timeouts for slow operations
   - Mock time-dependent operations

3. **Data Issues**
   - Clean up test data
   - Use isolated test databases
   - Reset state between tests

### Getting Help

- Check the [test logs](tests/README.md)
- Review [known issues](#known-issues)
- Create a [GitHub issue](https://github.com/your-repo/measure-js/issues)
- Contact [support](mailto:support@9fwr.com)

---

**Need help with testing?** Check the [test documentation](tests/README.md) or [contact support](mailto:support@9fwr.com).
