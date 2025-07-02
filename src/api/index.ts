import dotenv from 'dotenv';
import { Hono } from 'hono';
import { corsMiddleware } from './middleware/cors';
import { rateLimitMiddleware } from './middleware/rateLimit';
import eventsRouter from './routes/events';
import healthRouter from './routes/health';

// Load environment variables
dotenv.config();

// Initialize the App
const app = new Hono();

// Apply CORS middleware
app.use('*', corsMiddleware);

// Apply rate limiting to events endpoint
app.use('/events/*', rateLimitMiddleware);

// Routes
app.get("/", (c) => c.text("{Nothing to see here}"));

// Mount route handlers
app.route('/events', eventsRouter);
app.route('/health', healthRouter);

export default {
  port: 3000,
  fetch: app.fetch,
};
