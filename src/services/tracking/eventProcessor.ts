import { Context } from 'hono';
import { v4 as uuidv4 } from 'uuid';
import { getCookie, setCookie, deleteCookie } from 'hono/cookie';
import { getConnInfo } from 'hono/bun';
import { TrackingEvent, ApiResponse } from '../../types/events';
import { getHashh } from '../../utils/crypto/hashing';
import { getClientIP, sanitizeIP } from '../../utils/helpers/ipUtils';
import { config } from '../../config/environment';
import { BigQueryService } from '../storage/bigQueryService';
import { getGeoIPData } from '../analytics/geoLocation';
import useragent from 'useragent';

export class EventProcessor {
  private bigQueryService: BigQueryService;

  constructor() {
    this.bigQueryService = new BigQueryService();
  }

  async handleEvent(context: Context): Promise<Response> {
    try {
      const req = context.req;

      // Extract tracking data from JSON, form, and query params
      const json = await req.json().catch(() => ({}));
      const form = await req.parseBody().catch(() => ({}));
      const query = req.query();

      // Merge JSON, form, and query params into a single object
      const trackingData: TrackingEvent = { ...query, ...form, ...json };

      // Capture Metadata (Time, User IP Address)
      const now = new Date().toISOString();
      const ip = getClientIP(req.header(), getConnInfo(context).remote?.address);

      trackingData.ts = trackingData.ts || now;
      trackingData.et = trackingData.et || "event";
      trackingData.ua = trackingData.ua || req.header('user-agent');
      trackingData.c = trackingData.c || getCookie(context, config.clientIdCookieName);
      trackingData.h = trackingData.h || getHashh(ip, trackingData.ua || '');
      trackingData.h1 = trackingData.h1 || getCookie(context, config.hashCookieName) || trackingData.h;
      trackingData.ch = ip;

      // Handle consent events
      if (trackingData.en === 'consent') {
        await this.handleConsent(trackingData, context);
      }

      // Process and store event data
      await this.processAndStoreEvent(trackingData);

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

  private async handleConsent(trackingData: TrackingEvent, context: Context): Promise<void> {
    if (trackingData.p?.id === true) {
      const parts = context.env.hostname.split('.');
      let domain;
      if (parts.length > 1) {
        domain = '.' + parts.slice(-2).join('.');
      } else {
        domain = parts[0];
      }

      trackingData.c = trackingData.c || uuidv4();

      setCookie(context, config.clientIdCookieName, trackingData.c, {
        maxAge: 31536000,
        domain: '.9fwr.com',
        sameSite: 'none',
        path: '/',
        secure: true
      });

      setCookie(context, config.hashCookieName, trackingData.h1 || '', {
        maxAge: 31536000,
        domain: '.9fwr.com',
        sameSite: 'none',
        path: '/',
        secure: true
      });
    } else if (trackingData.p?.id === false) {
      deleteCookie(context, config.clientIdCookieName);
      deleteCookie(context, config.hashCookieName);
    }
  }

  private async processAndStoreEvent(trackingData: TrackingEvent): Promise<void> {
    // Async processing to avoid blocking the response
    setImmediate(async () => {
      try {
        const sanitizedIP = sanitizeIP(trackingData.ch || '');
        const geoInfo = await getGeoIPData(sanitizedIP);
        const userAgentParsed = useragent.parse(trackingData.ua || '');

        const processedEvent = {
          timestamp: new Date().toISOString(),
          event_type: trackingData.et || 'event',
          event_name: trackingData.en || '',
          parameters: JSON.stringify(trackingData.p || {}),
          user_agent: trackingData.ua || '',
          url: trackingData.url || '',
          referrer: trackingData.r || '',
          client_id: trackingData.c || '',
          hash: trackingData.h || '',
          user_id: trackingData.u,
          device: {
            type: userAgentParsed.device.family,
            brand: userAgentParsed.device.brand,
            model: userAgentParsed.device.model,
            browser: userAgentParsed.family,
            browser_version: userAgentParsed.toVersion(),
            os: userAgentParsed.os.family,
            os_version: userAgentParsed.os.toVersion(),
            is_bot: userAgentParsed.device.isBot
          },
          location: {
            ip_trunc: sanitizedIP,
            continent: geoInfo?.continent || null,
            country: geoInfo?.country || null,
            country_code: geoInfo?.country_code || null,
            city: geoInfo?.city || null
          }
        };

        await this.bigQueryService.store(processedEvent);
      } catch (error) {
        console.error("store task failed:", error);
      }
    });
  }
}
