import dotenv from 'dotenv';
// Load environment variables from the .env file
dotenv.config();
import handleEvent from './shared/handleEvent';
import { Hono } from 'hono'
import { BigQuery } from "@google-cloud/bigquery";

const bigquery = new BigQuery({
  projectId: process.env.BIGQUERY_PROJECT_ID, // Ensures the correct project is used
});

const app = new Hono();

app.get("/", (c) => c.text("{Nothing to see here}"));

app.get("/events", (c) => handleEvent(c));
app.post("/events", async (c) => await handleEvent(c));
//app.get("/store", handleStorage);


// Testing:
app.get("/test", async (c) => {
  try {
      const query = `SELECT * FROM ${process.env.GCP_PROJECT_ID}.${process.env.GCP_DATASET_ID}.${process.env.GCP_TABLE_ID} LIMIT 10`;
      const [rows] = await bigquery.query(query);
      return c.json(rows);
  } catch (error) {
      console.error("BigQuery Error:", error);
      return c.text("Failed to fetch data", 500);
  }
});

export default {
  port: 3000,
  fetch: app.fetch,
}
