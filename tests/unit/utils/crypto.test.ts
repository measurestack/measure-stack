import { describe, it, expect, beforeEach, afterEach } from 'bun:test';
import { getHashh, generateHash } from '../../../src/utils/crypto/hashing';

describe('Crypto Utils', () => {
  const originalEnv = process.env.DAILY_SALT;

  beforeEach(() => {
    // Set a known salt for testing
    process.env.DAILY_SALT = 'test-salt-123';
  });

  afterEach(() => {
    // Restore original environment
    if (originalEnv) {
      process.env.DAILY_SALT = originalEnv;
    } else {
      delete process.env.DAILY_SALT;
    }
  });

  describe('getHashh', () => {
    it('should generate consistent hash for same input', () => {
      const ip = '192.168.1.1';
      const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

      const hash1 = getHashh(ip, userAgent);
      const hash2 = getHashh(ip, userAgent);

      expect(hash1).toBe(hash2);
      expect(hash1).toHaveLength(64); // SHA-256 hash length
    });

    it('should generate different hashes for different inputs', () => {
      const ip1 = '192.168.1.1';
      const ip2 = '192.168.1.2';
      const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36';

      const hash1 = getHashh(ip1, userAgent);
      const hash2 = getHashh(ip2, userAgent);

      expect(hash1).not.toBe(hash2);
    });

    it('should handle empty strings', () => {
      const hash = getHashh('', '');
      expect(hash).toHaveLength(64);
      expect(typeof hash).toBe('string');
    });
  });

  describe('generateHash', () => {
    it('should generate SHA-256 hash', () => {
      const data = 'test data';
      const hash = generateHash(data);

      expect(hash).toHaveLength(64);
      expect(typeof hash).toBe('string');
    });

    it('should generate consistent hash for same input', () => {
      const data = 'test data';
      const hash1 = generateHash(data);
      const hash2 = generateHash(data);

      expect(hash1).toBe(hash2);
    });

    it('should generate different hashes for different inputs', () => {
      const hash1 = generateHash('data1');
      const hash2 = generateHash('data2');

      expect(hash1).not.toBe(hash2);
    });
  });
});
