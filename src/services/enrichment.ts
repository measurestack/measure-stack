import useragent from 'useragent';
import { getGeoIPData } from './geoip';

// ============================================================================
// IP UTILITIES
// ============================================================================

/**
 * Truncate IP address for privacy (remove last octet/segments)
 */
export function truncateIP(ip: string): string {
  if (!ip) return '';

  // Handle IPv6
  if (ip.includes(':')) {
    const parts = ip.split(':');
    // For IPv6, take first 4 segments and add ::
    if (ip.includes('::')) {
      const beforeDoubleColon = ip.split('::')[0];
      const segments = beforeDoubleColon.split(':').filter(Boolean);
      return segments.slice(0, 4).join(':') + '::';
    } else {
      return parts.slice(0, 4).join(':') + '::';
    }
  }

  // Handle IPv4
  const parts = ip.split('.');
  return parts.slice(0, 3).join('.') + '.0';
}

/**
 * Extract client IP from headers or remote address
 */
export function getClientIP(headers: Record<string, string | undefined>, remoteAddress?: string): string {
  return headers['X-Forwarded-For'] ||
         headers['x-forwarded-for'] ||
         remoteAddress ||
         '127.0.0.1';
}

/**
 * Sanitize IP address (convert localhost to test IP for development)
 */
export function sanitizeIP(ip: string): string {
  // For local testing, use a real IP
  if (ip.includes("127.0.0.1")) return "2a02:3100:1da8:1d00:d575:624d:f65a:e8ae";
  if (ip === "::1") return "2a02:3100:1da8:1d00:d575:624d:f65a:e8ae";
  return ip;
}

// ============================================================================
// EVENT PROCESSING
// ============================================================================

export interface TrackingEvent {
  en: string;           // event name
  url?: string;         // page URL
  r?: string;           // referrer
  p?: Record<string, any>; // parameters
  ts?: string;          // timestamp
  et?: string;          // event type
  ua?: string;          // user agent
  c?: string;           // client ID
  h?: string;           // hash
  h1?: string;          // stored hash
  ch?: string;          // client IP
  u?: string;           // user ID
}

export interface ProcessedEvent {
  timestamp: string;
  event_type: string;
  event_name: string;
  parameters: string;
  user_agent: string;
  url: string;
  referrer: string;
  client_id: string | null;
  hash: string | null;
  user_id?: string | null;
  consent_given: boolean;
  device: {
    type: string;
    brand: string;
    model: string;
    browser: string;
    browser_version: string;
    os: string;
    os_version: string;
    is_bot: boolean;
  };
  location: {
    ip_trunc: string;
    continent: string | null;
    country: string | null;
    country_code: string | null;
    city: string | null;
  };
}

/**
 * Enrich and process tracking event with device info and geolocation
 */
export async function enrichAndProcessEvent(trackingData: TrackingEvent): Promise<ProcessedEvent> {
  const sanitizedIP = sanitizeIP(trackingData.ch || '');
  const geoInfo = await getGeoIPData(sanitizedIP);
  const userAgentParsed = useragent.parse(trackingData.ua || '');

  return {
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
    consent_given: !!trackingData.c,
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
      ip_trunc: truncateIP(sanitizedIP),
      continent: geoInfo?.continent || null,
      country: geoInfo?.country || null,
      country_code: geoInfo?.country_code || null,
      city: geoInfo?.city || null
    }
  };
}
