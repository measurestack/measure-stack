export const config = {
  dailySalt: process.env.DAILY_SALT || '123456789',
  clientIdCookieName: process.env.CLIENT_ID_COOKIE_NAME || '_ms_cid',
  hashCookieName: process.env.HASH_COOKIE_NAME || '_ms_h',
  gcp: {
    projectId: process.env.GCP_PROJECT_ID || '',
    datasetId: process.env.GCP_DATASET_ID || '',
    tableId: process.env.GCP_TABLE_ID || '',
  },
  geo: {
    account: process.env.GEO_ACCOUNT || '',
    key: process.env.GEO_KEY || '',
  },
  region: process.env.REGION || 'us-central1',
  serviceName: process.env.SERVICE_NAME || 'measure-js-app',
  cors: {
    origins: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',').map(origin => origin.trim()) : ['https://9fwr.com', 'https://www.9fwr.com'],
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    credentials: true,
  }
};
