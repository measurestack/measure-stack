const { getHash, loadToBigQuery, truncateIP, getGeoIPData } = require('./helpers');
const useragent = require('useragent');
const cookieParser = require('cookie-parser')();

module.exports = function handleStorage(req, res) {
    cookieParser(req, res, () => {
        const trackingData = { ...req.body, ...req.query };
        const userAgentParsed = useragent.parse(trackingData.ua);
        trackingData.ch = trackingData.ch.includes("127.0.0.1") ? "141.20.2.3" : trackingData.ch; // for local testing
        trackingData.ch = trackingData.ch==="::1" ? "141.20.2.3" : trackingData.ch; // for local testing
        const truncatedIP = truncateIP(trackingData.ch);
        getGeoIPData(truncatedIP).then(geoInfo => { // Get geolocation data
            const dataToBQ = {
                timestamp: new Date().toISOString(),
                eventType: trackingData.et,
                eventName: trackingData.en,
                parameters: JSON.stringify(trackingData.p),
                userAgent: trackingData.ua,
                url: trackingData.url,
                referrer: trackingData.r,
                clientId: trackingData.c,
                hash: trackingData.h,
                userId: trackingData.u,
                device: {
                    type: userAgentParsed.device.family,
                    brand: userAgentParsed.device.brand,
                    model: userAgentParsed.device.model,
                    browser: userAgentParsed.family,
                    browserVersion: userAgentParsed.toVersion(),
                    os: userAgentParsed.os.family,
                    osVersion: userAgentParsed.os.toVersion(),
                    isBot: userAgentParsed.device.isBot
                },
                location: {
                    ip_trunc: truncatedIP,
                    continent: geoInfo ? geoInfo.continent : null,
                    country: geoInfo ? geoInfo.country : null,
                    country_code: geoInfo ? geoInfo.country_code : null,
                    city: geoInfo ? geoInfo.city : null
                }
            };

            loadToBigQuery(dataToBQ);
        });
        res.json({ message: "Tracking data processed" });
    });
};
