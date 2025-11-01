import { WebServiceClient } from '@maxmind/geoip2-node';
import { getFirestore } from './firestore';

export interface GeoLocationInfo {
  continent: string | null;
  country: string | null;
  country_code: string | null;
  city: string | null;
}

let geoClient: WebServiceClient | null = null;

/**
 * Initialize GeoIP client (lazy initialization)
 * Only initializes if credentials are provided
 */
function getGeoClient(): WebServiceClient | null {
  if (geoClient) return geoClient;

  const account = process.env.GEO_ACCOUNT || '';
  const key = process.env.GEO_KEY || '';

  if (!account || !key) {
    return null; // GeoIP disabled
  }

  geoClient = new WebServiceClient(account, key, { host: 'geolite.info' });
  return geoClient;
}

/**
 * Get GeoIP data for an IP address
 * Uses Firestore cache to avoid depleting MaxMind API limits
 * Returns null if GeoIP is disabled (no credentials) or lookup fails
 */
export async function getGeoIPData(ipAddress: string): Promise<GeoLocationInfo | null> {
  const client = getGeoClient();
  if (!client) {
    return null; // GeoIP disabled
  }

  const firestore = getFirestore();
  const geoipCollection = firestore.collection('geoip');

  try {
    // Check Firestore cache first
    const doc = await geoipCollection.doc(ipAddress).get();

    if (doc.exists) {
      const data = doc.data();
      return {
        continent: data?.continent || null,
        country: data?.country || null,
        country_code: data?.country_code || null,
        city: data?.city || null,
      };
    }

    // Cache miss - lookup from MaxMind
    const response = await client.city(ipAddress);
    const data = {
      ip_mask: ipAddress,
      continent: response.continent?.names?.en || null,
      country: response.country?.names?.en || null,
      country_code: response.country?.isoCode || null,
      city: response.city?.names?.en || null,
      updated_at: new Date()
    };

    // Store in cache
    await geoipCollection.doc(ipAddress).set(data);

    return {
      continent: data.continent,
      country: data.country,
      country_code: data.country_code,
      city: data.city,
    };
  } catch (error) {
    console.error("GeoIP lookup failed:", error);
    return null;
  }
}
