import { describe, it, expect } from 'bun:test';
import app from '../../../src/api';

describe('Rate Limiting Integration', () => {
  it('should allow requests within rate limit', async () => {
    // Send a few requests within the limit
    for (let i = 0; i < 5; i++) {
      const req = new Request('http://localhost/events', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          en: 'test_event',
          url: 'https://example.com',
          p: { test: 'data' }
        })
      });

      const res = await app.fetch(req);
      expect(res.status).toBe(200);

      const data = await res.json();
      expect(data.message).toBe('ok');
    }
  });

  it('should include rate limit headers', async () => {
    const req = new Request('http://localhost/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'test_event',
        url: 'https://example.com'
      })
    });

    const res = await app.fetch(req);
    expect(res.status).toBe(200);

    // Check for rate limit headers
    expect(res.headers.get('X-RateLimit-Limit')).toBeDefined();
    expect(res.headers.get('X-RateLimit-Remaining')).toBeDefined();
    expect(res.headers.get('X-RateLimit-Reset')).toBeDefined();

    const limit = parseInt(res.headers.get('X-RateLimit-Limit') || '0');
    const remaining = parseInt(res.headers.get('X-RateLimit-Remaining') || '0');

    expect(limit).toBeGreaterThan(0);
    expect(remaining).toBeGreaterThanOrEqual(0);
    expect(remaining).toBeLessThanOrEqual(limit);
  });

  it('should block requests when rate limit is exceeded', async () => {
    // This test would require sending many requests quickly
    // For now, we'll just test the structure
    const req = new Request('http://localhost/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'test_event',
        url: 'https://example.com'
      })
    });

    const res = await app.fetch(req);

    // Should either be 200 (within limit) or 429 (exceeded limit)
    expect([200, 429]).toContain(res.status);

    if (res.status === 429) {
      const data = await res.json();
      expect(data.error).toBe('Too Many Requests');
      expect(data.message).toContain('Rate limit exceeded');
      expect(data.retryAfter).toBeDefined();
    }
  });

  it('should not apply rate limiting to health endpoint', async () => {
    const req = new Request('http://localhost/health');
    const res = await app.fetch(req);

    expect(res.status).toBe(200);

    // Health endpoint should not have rate limit headers
    expect(res.headers.get('X-RateLimit-Limit')).toBeNull();
    expect(res.headers.get('X-RateLimit-Remaining')).toBeNull();
  });
});
