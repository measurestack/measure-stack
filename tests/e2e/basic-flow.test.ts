import { describe, it, expect, beforeAll, afterAll } from 'bun:test';
import app from '../../src/api';

describe('End-to-End Basic Flow', () => {
  let server: any;

  beforeAll(async () => {
    // Start the server for E2E tests
    server = app;
  });

  afterAll(async () => {
    // Cleanup if needed
  });

  it('should handle complete event tracking flow', async () => {
    // Step 1: Send a pageview event
    const pageviewReq = new Request('http://localhost/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'pageview',
        url: 'https://example.com/test-page',
        r: 'https://google.com',
        p: { page_title: 'Test Page' }
      })
    });

    const pageviewRes = await server.fetch(pageviewReq);
    expect(pageviewRes.status).toBe(200);

    const pageviewData = await pageviewRes.json();
    expect(pageviewData.message).toBe('ok');
    expect(pageviewData.c).toBeDefined();
    expect(pageviewData.h).toBeDefined();

    // Step 2: Send a consent event
    const consentReq = new Request('http://localhost/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'consent',
        p: { id: true }
      })
    });

    const consentRes = await server.fetch(consentReq);
    expect(consentRes.status).toBe(200);

    const consentData = await consentRes.json();
    expect(consentData.message).toBe('ok');
    expect(consentData.c).toBeDefined();

    // Step 3: Send a custom event
    const customReq = new Request('http://localhost/events', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        en: 'button_click',
        url: 'https://example.com/test-page',
        p: { button_id: 'submit', section: 'form' }
      })
    });

    const customRes = await server.fetch(customReq);
    expect(customRes.status).toBe(200);

    const customData = await customRes.json();
    expect(customData.message).toBe('ok');
  });

  it('should handle health check endpoint', async () => {
    const healthReq = new Request('http://localhost/health');
    const healthRes = await server.fetch(healthReq);

    expect(healthRes.status).toBe(200);

    const healthData = await healthRes.json();
    expect(healthData.status).toBe('ok');
    expect(healthData.service).toBe('measure-js');
  });

  it('should handle root endpoint', async () => {
    const rootReq = new Request('http://localhost/');
    const rootRes = await server.fetch(rootReq);

    expect(rootRes.status).toBe(200);

    const text = await rootRes.text();
    expect(text).toBe('{Nothing to see here}');
  });
});
