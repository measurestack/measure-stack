
const { BigQuery } = require('@google-cloud/bigquery');
const bigquery = new BigQuery();
const { truncateIP, getGeoIPData } = require('./helpers');
const useragent = require('useragent');


async function loadToBigQuery(data) {

    const datasetId = process.env.GCP_DATASET_ID; // Replace with your dataset ID
    const tableId = process.env.GCP_TABLE_ID; // Replace with your table ID

    try {
        const dataset = bigquery.dataset(datasetId);
        const table = dataset.table(tableId);

        const [apiResponse] = await table.insert([data]);
        if (apiResponse && apiResponse.insertErrors && apiResponse.insertErrors.length > 0) {
            throw new Error(`Error inserting rows into BigQuery: ${JSON.stringify(apiResponse.insertErrors)}`);
        } else {
            return "Data inserted successfully into BigQuery";
        }
    } catch (error) {
        throw new Error(`Error inserting rows into BigQuery: ${error}`);
    }
}

module.exports = async function store(trackingData) {

  await 1 // this will return an wait async for next execution cycle

  const userAgentParsed = useragent.parse(trackingData.ua);
    trackingData.ch = trackingData.ch.includes("127.0.0.1") ? "141.20.2.3" : trackingData.ch; // for local testing
    trackingData.ch = trackingData.ch==="::1" ? "141.20.2.3" : trackingData.ch; // for local testing

    const truncatedIP = truncateIP(trackingData.ch);
    geoInfo = await getGeoIPData(truncatedIP) // Get geolocation data

    const dataToBQ = {
        timestamp: new Date().toISOString(),
        event_type: trackingData.et,
        event_name: trackingData.en,
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

    await loadToBigQuery(dataToBQ);
    //res.json({ message: "Tracking data processed" });
};
