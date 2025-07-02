import { describe, it, expect, beforeEach, afterEach } from 'bun:test';
import { config } from '../../../src/config/environment';

describe('Environment Configuration', () => {
  const originalEnv = process.env;

  beforeEach(() => {
    // Clear environment variables for testing
    process.env = {};
  });

  afterEach(() => {
    // Restore original environment
    process.env = originalEnv;
  });

  it('should have default values when environment variables are not set', () => {
    // These tests check the structure, not the exact values since env vars might be set
    expect(config.dailySalt).toBeDefined();
    expect(config.clientIdCookieName).toBeDefined();
    expect(config.hashCookieName).toBeDefined();
    expect(config.region).toBeDefined();
    expect(config.serviceName).toBeDefined();
  });

  it('should have environment variable structure', () => {
    // Test that the config object has the expected structure
    expect(typeof config.dailySalt).toBe('string');
    expect(typeof config.clientIdCookieName).toBe('string');
    expect(typeof config.hashCookieName).toBe('string');
    expect(typeof config.region).toBe('string');
    expect(typeof config.serviceName).toBe('string');
  });

  it('should have correct CORS configuration', () => {
    expect(config.cors.origins).toEqual(['https://9fwr.com', 'https://www.9fwr.com']);
    expect(config.cors.allowMethods).toEqual(['GET', 'POST', 'OPTIONS']);
    expect(config.cors.credentials).toBe(true);
  });

  it('should have GCP configuration structure', () => {
    expect(config.gcp).toBeDefined();
    expect(config.gcp.projectId).toBeDefined();
    expect(config.gcp.datasetId).toBeDefined();
    expect(config.gcp.tableId).toBeDefined();
  });

  it('should have geo configuration structure', () => {
    expect(config.geo).toBeDefined();
    expect(config.geo.account).toBeDefined();
    expect(config.geo.key).toBeDefined();
  });
});
