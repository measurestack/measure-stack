const { Firestore } = require('@google-cloud/firestore');
const WebServiceClient = require('@maxmind/geoip2-node').WebServiceClient;
const crypto = require('crypto');
const { isIPv4, isIPv6 } = require('net');
const firestore = new Firestore();

// Initialize the MaxMind GeoIP2 WebServiceClient
// Replace '1234' and 'licenseKey' with your actual account ID and license key
const geoClient = new WebServiceClient(process.env.GEO_ACCOUNT, process.env.GEO_KEY, {host: 'geolite.info'});


async function getGeoIPData(ipAddress) {
    const geoipCollection = firestore.collection('geoip');
    try {
        const doc = await geoipCollection.doc(ipAddress).get();
        if (doc.exists) {
            //log.write(log.entry({ resource: { type: 'global' } }, `IP data found in Firestore for ${ipAddress}`));
            return doc.data();
        } else {
            //log.write(log.entry({ resource: { type: 'global' } }, `IP data not found in Firestore, querying geoip2 for ${ipAddress}`));
            const response = await geoClient.city(ipAddress);
            const data = {
                ip_mask: ipAddress,
                continent: response.continent.names.en,
                country: response.country.names.en,
                country_code: response.country.isoCode,
                city: response.city.names.en,
                updated_at: new Date()
            };
            await geoipCollection.doc(ipAddress).set(data);
            return data;
        }
    } catch (error) {
        //log.write(log.entry({ resource: { type: 'global' } }, `Error retrieving GeoIP data: ${error}`));
        return null;
    }
}

function getHashh(ip,ua) {
    const hashInput = `${ip}${ua}${process.env.DAILY_SALT}`;
    return crypto.createHash('sha256').update(hashInput).digest('hex');
}

function getHash(req) {
    const hashInput = `${req.ip}${req.headers['user-agent']}${process.env.DAILY_SALT}`;
    return crypto.createHash('sha256').update(hashInput).digest('hex');
}

function truncateIP(clientHost) {
    if (isIPv4(clientHost)) {
        // Anonymize IPv4 address
        const tmp = clientHost.split(".");
        tmp[tmp.length - 1] = '0';
        clientHost = tmp.join(".");
    } else if (isIPv6(clientHost)) {
        // Anonymize IPv6 address
        const ipSegments = clientHost.split(':').slice(0, 4);
        clientHost = ipSegments.join(':') + '::';
    }
    return clientHost;
}

module.exports = {
    getHash,
    getHashh,
    getGeoIPData,
    truncateIP
};
