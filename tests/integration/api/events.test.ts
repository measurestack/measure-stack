import { describe, it, expect } from 'bun:test';
import app from '../../../src/api';

describe('Events API Integration', () => {
  it('should accept POST requests to /events', async () => {
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
    expect(data.c).toBeDefined();
    expect(data.h).toBeDefined();
  });

  it('should accept GET requests to /events', async () => {
    const req = new Request('http://localhost/events?en=test_event&url=https://example.com');
    const res = await app.fetch(req);

    expect(res.status).toBe(200);

    const data = await res.json();
    expect(data.message).toBe('ok');
  });

  it('should handle consent events', async () => {
    const req = new Request('http://localhost/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'consent',
        p: { id: true }
      })
    });

    const res = await app.fetch(req);
    expect(res.status).toBe(200);

    const data = await res.json();
    expect(data.message).toBe('ok');
    expect(data.c).toBeDefined();
  });

  it('should handle malformed JSON gracefully', async () => {
    const req = new Request('http://localhost/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: 'invalid json'
    });

    const res = await app.fetch(req);
    expect(res.status).toBe(200); // Should still return 200 as per current implementation
  });
});
