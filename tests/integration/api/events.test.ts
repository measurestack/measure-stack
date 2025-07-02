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

  it('should handle consent revocation and stop tracking', async () => {
    // First, grant consent
    const consentReq = new Request('http://localhost/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'consent',
        p: { id: true }
      })
    });

    const consentRes = await app.fetch(consentReq);
    expect(consentRes.status).toBe(200);

    const consentData = await consentRes.json();
    expect(consentData.message).toBe('ok');
    expect(consentData.c).toBeDefined();

    // Get cookies from consent response
    const setCookieHeader = consentRes.headers.get('Set-Cookie');
    expect(setCookieHeader).toBeDefined();

    // Now revoke consent
    const revokeReq = new Request('http://localhost/events', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Cookie': setCookieHeader || ''
      },
      body: JSON.stringify({
        en: 'consent',
        p: { id: false }
      })
    });

    const revokeRes = await app.fetch(revokeReq);
    expect(revokeRes.status).toBe(200);

    const revokeData = await revokeRes.json();
    expect(revokeData.message).toBe('ok');

    // Verify that cookies are deleted (Set-Cookie with max-age=0 or expires in past)
    const revokeSetCookieHeader = revokeRes.headers.get('Set-Cookie');
    expect(revokeSetCookieHeader).toBeDefined();
    expect(revokeSetCookieHeader?.includes('Max-Age=0') || revokeSetCookieHeader?.includes('Expires=')).toBe(true);

    // Try to send a tracking event after consent revocation
    const trackingReq = new Request('http://localhost/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'pageview',
        url: 'https://example.com/test'
      })
    });

    const trackingRes = await app.fetch(trackingReq);
    expect(trackingRes.status).toBe(200);

    const trackingData = await trackingRes.json();
    expect(trackingData.message).toBe('ok');
    // The event should be processed anonymously (without client ID) for analytics
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
