const { BigQuery } = require('@google-cloud/bigquery');
const bigQuery = new BigQuery({projectId: process.env.GCP_PROJECT_ID});
const { truncateIP, getGeoIPData } = require('./helpers');
const useragent = require('useragent');

// Function to create a table if it doesn't exist
async function createTableIfNotExists(datasetId, tableId) {
    const dataset = bigQuery.dataset(datasetId);
    const table = dataset.table(tableId);

    // Define schema based on your requirements
    const schema = [
        { name: "timestamp", type: "TIMESTAMP" },
        { name: "eventType", type: "STRING" },
        { name: "eventName", type: "STRING" },
        { name: "parameters", type: "STRING" }, // Use STRING to store JSON
        { name: "userAgent", type: "STRING" },
        { name: "url", type: "STRING" },
        { name: "referrer", type: "STRING" },
        { name: "clientId", type: "STRING" },
        { name: "hash", type: "STRING" },
        { name: "userId", type: "STRING" },
        {
            name: "device", type: "RECORD", fields: [
                { name: "type", type: "STRING" },
                { name: "brand", type: "STRING" },
                { name: "model", type: "STRING" },
                { name: "browser", type: "STRING" },
                { name: "browserVersion", type: "STRING" },
                { name: "os", type: "STRING" },
                { name: "osVersion", type: "STRING" },
                { name: "isBot", type: "BOOL" }
            ]
        },
        {
            name: "ab_test", type: "RECORD", mode: "REPEATED", fields: [
                { name: "name", type: "STRING" },
                { name: "variant", type: "STRING" },
                { name: "def", type: "STRING" }
            ]
        },
        {
            name: "location", type: "RECORD", fields: [
                { name: "ip_trunc", type: "STRING" },
                { name: "continent", type: "STRING" },
                { name: "country", type: "STRING" },
                { name: "country_code", type: "STRING" },
                { name: "city", type: "STRING" }
            ]
        }
    ];

    try {
        // Check if the table exists
        const [tableExists] = await table.exists();

        if (!tableExists) {
            console.log(`Table ${tableId} does not exist. Creating table...`);
            await dataset.createTable(tableId, {
                schema: schema,
                timePartitioning: {
                    type: 'DAY',
                    field: 'timestamp' // Partition by timestamp
                }
            });
            console.log(`Table ${tableId} created successfully.`);
        } else {
            console.log(`Table ${tableId} already exists.`);
        }
    } catch (err) {
        console.error(`Error in table creation: ${err.message}`);
        throw new Error(`Table creation failed: ${err.message}`);
    }
}

// create table if not exists:

createTableIfNotExists(process.env.GCP_DATASET_ID, process.env.GCP_TABLE_ID); // WARN: we don't await here to not create an async module, however this doens't ensure that table creation is finished before processing the first event. This should be a very limited problem though


async function loadToBigQuery(data) {

    const datasetId = process.env.GCP_DATASET_ID; // Replace with your dataset ID
    const tableId = process.env.GCP_TABLE_ID; // Replace with your table ID

    try {
        const dataset = bigQuery.dataset(datasetId);
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

    await loadToBigQuery(dataToBQ);
    //res.json({ message: "Tracking data processed" });
};
