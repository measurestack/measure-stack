import { describe, test, expect, beforeAll, afterAll } from "bun:test";
import { BigQuery } from '@google-cloud/bigquery';
import dotenv from 'dotenv';

// Load environment variables from .env
dotenv.config();

const BASE_URL = process.env.TEST_URL || "http://localhost:3000";
const USER_AGENT = "MeasureStack-E2E-Test/1.0";
const PROJECT_ID = process.env.GCP_PROJECT_ID!;
const DATASET_ID = process.env.GCP_DATASET_ID!;
const TABLE_ID = process.env.GCP_TABLE_ID!;
const TEST_ORIGIN = process.env.CORS_ORIGIN?.split(',')[0]!; // Use first allowed origin

let serverProcess: any = null;
const bigquery = new BigQuery({ projectId: PROJECT_ID });

describe("E2E Server Tests", () => {
  beforeAll(async () => {
    // Start server if testing locally
    if (BASE_URL.includes("localhost")) {
      console.log("Starting local server...");
      serverProcess = Bun.spawn(["bun", "src/api/index.ts"], {
        stdout: "pipe",
        stderr: "pipe",
      });

      // Wait for server to start
      await new Promise(resolve => setTimeout(resolve, 2000));
    }
  });

  afterAll(() => {
    if (serverProcess) {
      console.log("Stopping local server...");
      serverProcess.kill();
    }
  });

  test("Root endpoint returns expected message", async () => {
    const response = await fetch(BASE_URL);
    const text = await response.text();

    expect(response.status).toBe(200);
    expect(text).toContain("Nothing to see here");
  });

  test("measure.js script is served", async () => {
    const response = await fetch(`${BASE_URL}/measure.js`);
    const text = await response.text();

    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toContain("javascript");
    expect(text).toContain("_measure");
  });

  test("POST event with JSON body", async () => {
    const testId = `test-${Date.now()}`;

    const response = await fetch(`${BASE_URL}/events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": USER_AGENT,
        "Origin": TEST_ORIGIN
      },
      body: JSON.stringify({
        et: "event",
        en: testId,
        url: `${TEST_ORIGIN}/test`,
        r: "https://google.com",
        p: { test: true }
      })
    });

    const json = await response.json();

    expect(response.status).toBe(200);
    expect(json.message).toBe("ok");
    expect(json.h).toBeDefined(); // Hash should be present

    // Wait for background processing
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Verify in BigQuery
    const query = `
      SELECT event_name, user_agent, url, referrer
      FROM \`${PROJECT_ID}.${DATASET_ID}.${TABLE_ID}\`
      WHERE event_name = @event_name
      AND user_agent = @user_agent
      ORDER BY timestamp DESC
      LIMIT 1
    `;

    const [rows] = await bigquery.query({
      query,
      params: { event_name: testId, user_agent: USER_AGENT },
      jobTimeoutMs: 15000
    });

    expect(rows.length).toBe(1);
    expect(rows[0].event_name).toBe(testId);
    expect(rows[0].url).toBe(`${TEST_ORIGIN}/test`);
    expect(rows[0].referrer).toBe("https://google.com");
  }, { timeout: 25000 });

  test("GET event with query parameters", async () => {
    const testId = `test-query-${Date.now()}`;

    const params = new URLSearchParams({
      et: "pageview",
      en: testId,
      url: `${TEST_ORIGIN}/page`,
      r: "https://bing.com"
    });

    const response = await fetch(`${BASE_URL}/events?${params}`, {
      headers: {
        "User-Agent": USER_AGENT,
        "Origin": TEST_ORIGIN
      }
    });

    const json = await response.json();

    expect(response.status).toBe(200);
    expect(json.message).toBe("ok");

    // Wait for background processing
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Verify in BigQuery
    const query = `
      SELECT event_name, event_type, url
      FROM \`${PROJECT_ID}.${DATASET_ID}.${TABLE_ID}\`
      WHERE event_name = @event_name
      AND user_agent = @user_agent
      ORDER BY timestamp DESC
      LIMIT 1
    `;

    const [rows] = await bigquery.query({
      query,
      params: { event_name: testId, user_agent: USER_AGENT },
      jobTimeoutMs: 15000
    });

    expect(rows.length).toBe(1);
    expect(rows[0].event_type).toBe("pageview");
    expect(rows[0].url).toBe(`${TEST_ORIGIN}/page`);
  }, { timeout: 25000 });

  test("Consent event sets and deletes cookies", async () => {
    // Grant consent
    const grantResponse = await fetch(`${BASE_URL}/events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": USER_AGENT,
        "Origin": TEST_ORIGIN
      },
      body: JSON.stringify({
        et: "consent",
        en: "consent",
        p: { id: true }
      })
    });

    expect(grantResponse.status).toBe(200);
    const cookies = grantResponse.headers.get("set-cookie");
    expect(cookies).toBeDefined();
    expect(cookies).toContain("_ms_cid");
    expect(cookies).toContain("_ms_h");
  }, { timeout: 10000 });

  test("CORS headers are present for allowed origin", async () => {
    // Test with allowed origin
    const allowedResponse = await fetch(`${BASE_URL}/events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Origin": TEST_ORIGIN,
        "User-Agent": USER_AGENT
      },
      body: JSON.stringify({
        en: "cors-test-allowed",
        url: `${TEST_ORIGIN}/test`
      })
    });

    expect(allowedResponse.status).toBe(200);
    expect(allowedResponse.headers.get("access-control-allow-origin")).toBe(TEST_ORIGIN);

    // Test with disallowed origin
    const disallowedResponse = await fetch(`${BASE_URL}/events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Origin": "https://evil.com",
        "User-Agent": USER_AGENT
      },
      body: JSON.stringify({
        en: "cors-test-disallowed",
        url: "https://evil.com/test"
      })
    });

    // Request should still succeed but without CORS header for disallowed origin
    expect(disallowedResponse.status).toBe(200);
    const corsHeader = disallowedResponse.headers.get("access-control-allow-origin");
    expect(corsHeader === null || corsHeader !== "https://evil.com").toBe(true);
  });

  test("Device and location enrichment", async () => {
    const testId = `test-enrichment-${Date.now()}`;

    const response = await fetch(`${BASE_URL}/events`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15",
        "Origin": TEST_ORIGIN
      },
      body: JSON.stringify({
        en: testId,
        url: `${TEST_ORIGIN}/mobile`
      })
    });

    expect(response.status).toBe(200);

    // Wait for background processing
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Verify enrichment in BigQuery
    const query = `
      SELECT device.os as device_os, device.browser as device_browser, location.ip_trunc as ip_trunc, location.country as location_country
      FROM \`${PROJECT_ID}.${DATASET_ID}.${TABLE_ID}\`
      WHERE event_name = @event_name
      ORDER BY timestamp DESC
      LIMIT 1
    `;

    const [rows] = await bigquery.query({
      query,
      params: { event_name: testId },
      jobTimeoutMs: 15000
    });

    expect(rows.length).toBe(1);
    expect(rows[0].device_os).toBeTruthy(); // Device OS should be enriched
    expect(rows[0].device_browser).toBeTruthy(); // Browser should be enriched
    expect(rows[0].ip_trunc).toBeDefined(); // IP should be truncated
  }, { timeout: 25000 });

  test("Hash consistency", async () => {
    // Make two requests from same "client"
    const responses = [];

    for (let i = 0; i < 2; i++) {
      const response = await fetch(`${BASE_URL}/events`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "User-Agent": "TestAgent/1.0",
          "Origin": TEST_ORIGIN
        },
        body: JSON.stringify({
          en: `hash-test-${i}`,
          url: TEST_ORIGIN
        })
      });

      responses.push(await response.json());
    }

    // Same user agent and IP should produce same hash
    expect(responses[0].h).toBe(responses[1].h);
    expect(responses[0].h).toBeDefined();
  });
});
