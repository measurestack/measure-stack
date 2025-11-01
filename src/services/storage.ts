import { BigQuery } from '@google-cloud/bigquery';
import type { ProcessedEvent } from './enrichment';

let bigQueryInstance: BigQuery | null = null;

/**
 * Get or create BigQuery instance (lazy initialization)
 */
function getBigQuery(): BigQuery {
  if (!bigQueryInstance) {
    const projectId = process.env.GCP_PROJECT_ID;
    bigQueryInstance = new BigQuery({ projectId });
  }
  return bigQueryInstance;
}

/**
 * Store processed event in BigQuery
 */
export async function storeEvent(event: ProcessedEvent): Promise<void> {
  const datasetId = process.env.GCP_DATASET_ID || '';
  const tableId = process.env.GCP_TABLE_ID || '';

  const bigquery = getBigQuery();
  const dataset = bigquery.dataset(datasetId);
  const table = dataset.table(tableId);

  try {
    const [insertErrors] = await table.insert([event]);
    if (Array.isArray(insertErrors) && insertErrors.length > 0) {
      throw new Error(`Error inserting rows into BigQuery: ${JSON.stringify(insertErrors)}`);
    }
  } catch (error) {
    throw new Error(`Error inserting rows into BigQuery: ${error}`);
  }
}
