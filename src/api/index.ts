import dotenv from 'dotenv';
import { Hono } from 'hono';
import { serveStatic } from 'hono/bun';
import { cors } from 'hono/cors';
import { getCookie, setCookie, deleteCookie } from 'hono/cookie';
import { getConnInfo } from 'hono/bun';
import { v4 as uuidv4 } from 'uuid';
import type { Context } from 'hono';
import { getHash } from '../services/salt';
import { getClientIP, enrichAndProcessEvent, storeEvent } from '../services/enrichment';
import type { TrackingEvent } from '../services/enrichment';

// Load environment variables
dotenv.config();

// Configuration
const config = {
  clientIdCookieName: process.env.CLIENT_ID_COOKIE_NAME || '_ms_cid',
  hashCookieName: process.env.HASH_COOKIE_NAME || '_ms_h',
  cookieDomain: process.env.COOKIE_DOMAIN || '',
  corsOrigins: process.env.CORS_ORIGIN ?
    process.env.CORS_ORIGIN.split(',').map(origin => origin.trim()) :
    ['', ''],
};

// Initialize Hono app
const app = new Hono();

// ============================================================================
// MIDDLEWARE
// ============================================================================

// Apply CORS middleware
app.use('*', cors({
  origin: config.corsOrigins,
  allowMethods: ['GET', 'POST', 'OPTIONS'],
  credentials: true
}));

// ============================================================================
// ROUTES
// ============================================================================

app.get("/", (c) => c.text("{Nothing to see here}"));

// Serve measure.js script
app.get('/measure.js', serveStatic({
  path: './static/measure.js',
  mimes: { 'js': 'application/javascript' }
}));

// ============================================================================
// EVENT HANDLER
// ============================================================================

async function handleEvent(context: Context): Promise<Response> {
  try {
    const req = context.req;

    // Extract tracking data from JSON, form, and query params
    const json = await req.json().catch(() => ({}));
    const form = await req.parseBody().catch(() => ({}));
    const query = req.query();

    // Merge JSON, form, and query params into a single object
    const trackingData: TrackingEvent = { ...query, ...form, ...json };

    const now = new Date().toISOString();
    const ip = getClientIP(req.header(), getConnInfo(context).remote?.address);

    // Set defaults
    trackingData.ts = trackingData.ts || now;
    trackingData.et = trackingData.et || "event";
    trackingData.ua = trackingData.ua || req.header('user-agent');
    trackingData.c = trackingData.c || getCookie(context, config.clientIdCookieName);
    trackingData.h = trackingData.h || await getHash(ip || '', trackingData.ua || '');
    trackingData.h1 = trackingData.h1 || getCookie(context, config.hashCookieName) || trackingData.h;
    trackingData.ch = ip;

    // Handle consent events
    if (trackingData.en === 'consent') {
      if (trackingData.p?.id === true) {
        // User gave consent - set cookies
        trackingData.c = trackingData.c || uuidv4();
        setCookie(context, config.clientIdCookieName, trackingData.c!, {
          maxAge: 31536000, // 1 year
          domain: config.cookieDomain
        });
        setCookie(context, config.hashCookieName, trackingData.h1!, {
          maxAge: 31536000, // 1 year
          domain: config.cookieDomain
        });
      } else if (trackingData.p?.id === false) {
        // User revoked consent - delete cookies
        deleteCookie(context, config.clientIdCookieName);
        deleteCookie(context, config.hashCookieName);
      }
    }

    // Background processing - don't await
    setImmediate(() => {
      processAndStoreEvent(trackingData).catch((error) => {
        console.error("Background event processing failed:", error);
      });
    });

    // Return immediate response
    return context.json({
      message: "ok",
      c: trackingData.c,
      h: trackingData.h
    });
  } catch (error) {
    console.error('Error processing event:', error);
    return context.json({ error: 'Internal server error' }, 500);
  }
}

/**
 * Process and store event in background
 */
async function processAndStoreEvent(trackingData: TrackingEvent): Promise<void> {
  try {
    const processedEvent = await enrichAndProcessEvent(trackingData);
    await storeEvent(processedEvent);
  } catch (error) {
    console.error("Failed to process and store event:", error);
  }
}

// Mount event handlers
app.get('/events', handleEvent);
app.post('/events', handleEvent);

// ============================================================================
// EXPORT
// ============================================================================

export default {
  port: 3000,
  fetch: app.fetch,
  // Increase timeout for local debugging (0 = indefinite)
  // In production, Cloud Run handles timeouts
  idleTimeout: process.env.NODE_ENV === 'production' ? 10 : 0,
};
