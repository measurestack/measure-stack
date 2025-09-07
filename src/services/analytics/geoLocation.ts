import { WebServiceClient } from '@maxmind/geoip2-node';
import { GeoLocationInfo } from '../../types/user';
import { config } from '../../config/environment';
import { getFirestore } from '../storage/firestoreService';
const geoClient = new WebServiceClient(
  config.geo.account,
  config.geo.key,
  { host: 'geolite.info' }
);

export async function getGeoIPData(ipAddress: string): Promise<GeoLocationInfo | null> {
  const firestore = getFirestore();
  const geoipCollection = firestore.collection('geoip');

  try {
    const doc = await geoipCollection.doc(ipAddress).get();

    if (doc.exists) {
      const data = doc.data();
      return {
        continent: data?.continent || null,
        country: data?.country || null,
        country_code: data?.country_code || null,
        city: data?.city || null,
      };
    } else {
      const response = await geoClient.city(ipAddress);
      const data = {
        ip_mask: ipAddress,
        continent: response.continent?.names?.en || null,
        country: response.country?.names?.en || null,
        country_code: response.country?.isoCode || null,
        city: response.city?.names?.en || null,
        updated_at: new Date()
      };

      await geoipCollection.doc(ipAddress).set(data);

      return {
        continent: data.continent,
        country: data.country,
        country_code: data.country_code,
        city: data.city,
      };
    }
  } catch (error) {
    console.error("GeoIP lookup failed:", error);
    return null;
  }
}
