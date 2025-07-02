import { Context, Next } from 'hono';
import { getClientIP } from '../../utils/helpers/ipUtils';
import { getConnInfo } from 'hono/bun';
import { config } from '../../config/environment';

interface RateLimitConfig {
  windowMs: number; // Time window in milliseconds
  maxRequests: number; // Maximum requests per window
  skipSuccessfulRequests?: boolean; // Skip rate limiting for successful requests
  skipFailedRequests?: boolean; // Skip rate limiting for failed requests
}

interface RateLimitStore {
  [key: string]: {
    count: number;
    resetTime: number;
  };
}

class RateLimiter {
  private store: RateLimitStore = {};
  private config: RateLimitConfig;

  constructor(config: RateLimitConfig) {
    this.config = config;
    // Clean up expired entries every 5 minutes
    setInterval(() => this.cleanup(), 5 * 60 * 1000);
  }

  private cleanup(): void {
    const now = Date.now();
    Object.keys(this.store).forEach(key => {
      if (this.store[key].resetTime < now) {
        delete this.store[key];
      }
    });
  }

  private getKey(context: Context): string {
    const ip = getClientIP(context.req.header(), getConnInfo(context).remote?.address);
    return `rate_limit:${ip}`;
  }

  async checkLimit(context: Context): Promise<{ allowed: boolean; remaining: number; resetTime: number }> {
    const key = this.getKey(context);
    const now = Date.now();

    if (!this.store[key] || this.store[key].resetTime < now) {
      // Reset or create new entry
      this.store[key] = {
        count: 1,
        resetTime: now + this.config.windowMs
      };
      return {
        allowed: true,
        remaining: this.config.maxRequests - 1,
        resetTime: this.store[key].resetTime
      };
    }

    if (this.store[key].count >= this.config.maxRequests) {
      return {
        allowed: false,
        remaining: 0,
        resetTime: this.store[key].resetTime
      };
    }

    this.store[key].count++;
    return {
      allowed: true,
      remaining: this.config.maxRequests - this.store[key].count,
      resetTime: this.store[key].resetTime
    };
  }
}

// Create rate limiter instance
const rateLimiter = new RateLimiter({
  windowMs: config.rateLimit.windowMs,
  maxRequests: config.rateLimit.maxRequests,
  skipSuccessfulRequests: config.rateLimit.skipSuccessfulRequests,
  skipFailedRequests: config.rateLimit.skipFailedRequests,
});

export const rateLimitMiddleware = async (c: Context, next: Next) => {
  const result = await rateLimiter.checkLimit(c);

  // Add rate limit headers
  c.header('X-RateLimit-Limit', config.rateLimit.maxRequests.toString());
  c.header('X-RateLimit-Remaining', result.remaining.toString());
  c.header('X-RateLimit-Reset', new Date(result.resetTime).toISOString());

  if (!result.allowed) {
    return c.json({
      error: 'Too Many Requests',
      message: 'Rate limit exceeded. Please try again later.',
      retryAfter: Math.ceil((result.resetTime - Date.now()) / 1000)
    }, 429);
  }

  await next();
};
