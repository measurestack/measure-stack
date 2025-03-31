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
                user_agent: trackingData.ua,
                url: trackingData.url,
                referrer: trackingData.r,
                client_id: trackingData.c,
                hash: trackingData.h,
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
