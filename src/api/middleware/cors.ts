import { cors } from 'hono/cors';
import { config } from '../../config/environment';

export const corsMiddleware = cors({
  origin: config.cors.origins,
  allowMethods: config.cors.allowMethods,
  credentials: config.cors.credentials
});
