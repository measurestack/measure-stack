import { describe, it, expect } from 'bun:test';
import { truncateIP, getClientIP, sanitizeIP } from '../../../src/utils/helpers/ipUtils';

describe('IP Utils', () => {
  describe('truncateIP', () => {
    it('should truncate IPv4 addresses', () => {
      expect(truncateIP('192.168.1.100')).toBe('192.168.1.0');
      expect(truncateIP('10.0.0.1')).toBe('10.0.0.0');
      expect(truncateIP('172.16.254.1')).toBe('172.16.254.0');
    });

    it('should truncate IPv6 addresses', () => {
      expect(truncateIP('2001:db8::1')).toBe('2001:db8::');
      expect(truncateIP('2001:db8:85a3::8a2e:370:7334')).toBe('2001:db8:85a3::');
    });

    it('should handle empty or invalid IPs', () => {
      expect(truncateIP('')).toBe('');
      expect(truncateIP('invalid')).toBe('invalid.0');
    });
  });

  describe('getClientIP', () => {
    it('should return X-Forwarded-For header', () => {
      const headers = { 'X-Forwarded-For': '192.168.1.1' };
      expect(getClientIP(headers)).toBe('192.168.1.1');
    });

    it('should return x-forwarded-for header (lowercase)', () => {
      const headers = { 'x-forwarded-for': '192.168.1.2' };
      expect(getClientIP(headers)).toBe('192.168.1.2');
    });

    it('should return remote address when no headers', () => {
      const headers = {};
      const remoteAddress = '192.168.1.3';
      expect(getClientIP(headers, remoteAddress)).toBe('192.168.1.3');
    });

    it('should return default IP when no headers or remote address', () => {
      const headers = {};
      expect(getClientIP(headers)).toBe('127.0.0.1');
    });
  });

  describe('sanitizeIP', () => {
    it('should replace localhost IPv4 with test IP', () => {
      expect(sanitizeIP('127.0.0.1')).toBe('141.20.2.3');
    });

    it('should replace IPv6 localhost with test IP', () => {
      expect(sanitizeIP('::1')).toBe('141.20.2.3');
    });

    it('should return original IP for non-localhost addresses', () => {
      expect(sanitizeIP('192.168.1.1')).toBe('192.168.1.1');
      expect(sanitizeIP('8.8.8.8')).toBe('8.8.8.8');
    });
  });
});
