// Imports
import dotenv from 'dotenv';
import handleEvent from './shared/handleEvent';

import { Hono } from 'hono'
// Load environment variables from the .env file
dotenv.config();


const app = new Hono();

app.get("/", (c) => c.text("{Nothing to see here}"));

app.get("/events", (c) => handleEvent(c));
app.post("/events", async (c) => await handleEvent(c));
//app.get("/store", handleStorage);


export default {
  port: 3000,
  fetch: app.fetch,
}
