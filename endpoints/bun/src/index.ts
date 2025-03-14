// Imports
import dotenv from 'dotenv';
import handleEvent from './shared/handleEvent';
// Load environment variables from the .env file
dotenv.config();

import { Hono } from 'hono'
import { cors } from 'hono/cors'

// Initialise the App
const app = new Hono();

// Set the Middleware Configurations to allow HTTP requests to the app
app.use('*', async (c, next) => {
  const corsMiddlewareHandler = cors({
    origin: process.env.CORS_ORIGIN, // The Location where the script will be deployed
    allowMethods: ['GET', 'POST', 'OPTIONS'],
    credentials: true
    })
  return corsMiddlewareHandler(c, next)
  })

app.get("/", (c) => c.text("{Nothing to see here}"));

app.get("/events", (c) => handleEvent(c));
app.post("/events", async (c) => await handleEvent(c));

//app.get("/store", handleStorage);

export default {
  port: 3000,
  fetch: app.fetch,
}
