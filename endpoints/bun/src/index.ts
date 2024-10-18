import dotenv from 'dotenv';
// Load environment variables from the .env file
dotenv.config();
import handleEvent from './shared/handleEvent';
import { Hono } from 'hono'


const app = new Hono();

app.get("/", () => "Nothing to see here.");

app.get("/events", (c) => handleEvent(c));
app.post("/events", async (c) => await handleEvent(c));
//app.get("/store", handleStorage);

export default {  
  port: 3000, 
  fetch: app.fetch, 
} 
