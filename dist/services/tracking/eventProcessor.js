import { v4 as uuidv4 } from 'uuid';
import { getCookie, setCookie, deleteCookie } from 'hono/cookie';
import { getConnInfo } from 'hono/bun';
import { getHashh } from '../../utils/crypto/hashing';
import { getClientIP, sanitizeIP } from '../../utils/helpers/ipUtils';
import { config } from '../../config/environment';
import { BigQueryService } from '../storage/bigQueryService';
import { getGeoIPData } from '../analytics/geoLocation';
import useragent from 'useragent';
export class EventProcessor {
    constructor() {
        this.bigQueryService = new BigQueryService();
    }
    async handleEvent(context) {
        try {
            const req = context.req;
            // Extract tracking data from JSON, form, and query params
            const json = await req.json().catch(() => ({}));
            const form = await req.parseBody().catch(() => ({}));
            const query = req.query();
            // Merge JSON, form, and query params into a single object
            const trackingData = { ...query, ...form, ...json };
            // Capture Metadata (Time, User IP Address)
            const now = new Date().toISOString();
            const ip = getClientIP(req.header(), getConnInfo(context).remote?.address);
            // Set Tracking parameter time, event type, and user-agent data
            trackingData.ts = trackingData.ts || now;
            trackingData.et = trackingData.et || "event";
            trackingData.ua = trackingData.ua || req.header('user-agent');
            trackingData.h = trackingData.h || getHashh(ip, trackingData.ua || '');
            trackingData.ch = ip;
            // Handle consent events first
            if (trackingData.en === 'consent') {
                const consentChanged = await this.handleConsent(trackingData, context);
                // Only process consent events if consent actually changed
                if (consentChanged) {
                    await this.processAndStoreEvent(trackingData);
                }
            }
            else {
                // For non-consent events, check if user has given consent
                const hasConsent = this.checkUserConsent(context);
                if (hasConsent) {
                    // Only set client ID if consent is given
                    trackingData.c = trackingData.c || getCookie(context, config.clientIdCookieName);
                    trackingData.h1 = trackingData.h1 || getCookie(context, config.hashCookieName) || trackingData.h;
                    // Process and store event data with full tracking (client ID)
                    await this.processAndStoreEvent(trackingData);
                }
                else {
                    // Process event anonymously (without client ID) for analytics
                    await this.processAndStoreEventAnonymously(trackingData);
                }
            }
            return context.json({
                message: "ok",
                c: trackingData.c,
                h: trackingData.h
            });
        }
        catch (error) {
            console.error('Error processing event:', error);
            return context.json({ error: 'Internal server error' }, 500);
        }
    }
    checkUserConsent(context) {
        // First check for consent cookie - this takes priority
        const consentCookie = getCookie(context, 'measure_consent');
        if (consentCookie) {
            try {
                const consentData = JSON.parse(consentCookie);
                // If any consent type is explicitly false, deny consent
                if (consentData.id === false || consentData.analytics === false) {
                    return false;
                }
                // If consent is explicitly granted, allow tracking
                if (consentData.id === true) {
                    return true;
                }
            }
            catch (error) {
                // If consent cookie is malformed, fall back to client ID check
                console.warn('Malformed consent cookie, falling back to client ID check');
            }
        }
        // Fallback: Check if client ID cookie exists (legacy behavior)
        const clientId = getCookie(context, config.clientIdCookieName);
        return !!clientId;
    }
    async handleConsent(trackingData, context) {
        // Check if consent has actually changed
        const existingConsent = getCookie(context, 'measure_consent');
        const newConsent = JSON.stringify(trackingData.p);
        // If consent hasn't changed, don't process the event
        if (existingConsent === newConsent) {
            console.log('Consent unchanged, skipping consent event');
            return false;
        }
        if (trackingData.p?.id === true) {
            trackingData.c = trackingData.c || uuidv4();
            setCookie(context, config.clientIdCookieName, trackingData.c, {
                maxAge: 31536000,
                domain: config.cookieDomain,
                sameSite: 'none',
                path: '/',
                secure: true
            });
            setCookie(context, config.hashCookieName, trackingData.h1 || '', {
                maxAge: 31536000,
                domain: config.cookieDomain,
                sameSite: 'none',
                path: '/',
                secure: true
            });
            // Store consent preferences
            setCookie(context, 'measure_consent', newConsent, {
                maxAge: 31536000,
                domain: config.cookieDomain,
                sameSite: 'none',
                path: '/',
                secure: true
            });
        }
        else if (trackingData.p?.id === false) {
            // Delete cookies with the same domain settings they were set with
            deleteCookie(context, config.clientIdCookieName, {
                domain: config.cookieDomain,
                path: '/'
            });
            deleteCookie(context, config.hashCookieName, {
                domain: config.cookieDomain,
                path: '/'
            });
            deleteCookie(context, 'measure_consent', {
                domain: config.cookieDomain,
                path: '/'
            });
        }
        return true; // Consent was changed
    }
    async processAndStoreEvent(trackingData) {
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
                        ip_trunc: sanitizedIP,
                        continent: geoInfo?.continent || null,
                        country: geoInfo?.country || null,
                        country_code: geoInfo?.country_code || null,
                        city: geoInfo?.city || null
                    }
                };
                await this.bigQueryService.store(processedEvent);
            }
            catch (error) {
                console.error("store task failed:", error);
            }
        });
    }
    async processAndStoreEventAnonymously(trackingData) {
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
                    client_id: null, // No client ID for anonymous tracking
                    hash: null, // No hash for anonymous tracking
                    user_id: null, // No user ID for anonymous tracking
                    consent_given: false,
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
            }
            catch (error) {
                console.error("store task failed:", error);
            }
        });
    }
}
