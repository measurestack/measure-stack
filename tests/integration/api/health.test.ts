import { describe, it, expect } from 'bun:test';
import app from '../../../src/api';

describe('Health API Integration', () => {
  it('should return health status', async () => {
    const req = new Request('http://localhost/health');
    const res = await app.fetch(req);

    expect(res.status).toBe(200);

    const data = await res.json();
    expect(data.status).toBe('ok');
    expect(data.timestamp).toBeDefined();
    expect(data.service).toBe('measure-js');
  });

  it('should return valid timestamp', async () => {
    const req = new Request('http://localhost/health');
    const res = await app.fetch(req);

    const data = await res.json();
    const timestamp = new Date(data.timestamp);

    expect(timestamp.getTime()).toBeGreaterThan(0);
    expect(timestamp).toBeInstanceOf(Date);
  });
});
