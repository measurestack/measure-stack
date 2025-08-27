export const config = {
  dailySalt: process.env.DAILY_SALT || '123456789',
  clientIdCookieName: process.env.CLIENT_ID_COOKIE_NAME || '_ms_cid',
  hashCookieName: process.env.HASH_COOKIE_NAME || '_ms_h',
  cookieDomain: process.env.COOKIE_DOMAIN || '',
  gcp: {
    projectId: process.env.GCP_PROJECT_ID || '',
    datasetId: process.env.GCP_DATASET_ID || '',
    tableId: process.env.GCP_TABLE_ID || '',
    firestoreDatabase: process.env.GCP_FIRESTORE_DATABASE || '(default)',
  },
  geo: {
    account: process.env.GEO_ACCOUNT || '',
    key: process.env.GEO_KEY || '',
  },
  region: process.env.REGION || 'europe-west3',
  serviceName: process.env.SERVICE_NAME || 'measure-js-app',
  cors: {
    origins: process.env.CORS_ORIGIN ? process.env.CORS_ORIGIN.split(',').map(origin => origin.trim()) : ['', ''],
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    credentials: true,
  },
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS || '60000'), // 1 minute
    maxRequests: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS || '100'), // 100 requests per minute
    skipSuccessfulRequests: process.env.RATE_LIMIT_SKIP_SUCCESS === 'true',
    skipFailedRequests: process.env.RATE_LIMIT_SKIP_FAILED === 'true',
  }
};
