import { BigQuery } from '@google-cloud/bigquery';
import { ProcessedEvent } from '../../types/events';
import { config } from '../../config/environment';

export class BigQueryService {
  private bigquery: BigQuery;
  private datasetId: string;
  private tableId: string;

  constructor() {
    this.bigquery = new BigQuery();
    this.datasetId = config.gcp.datasetId;
    this.tableId = config.gcp.tableId;
  }

  async store(event: ProcessedEvent): Promise<void> {
    const dataset = this.bigquery.dataset(this.datasetId);
    const table = dataset.table(this.tableId);

    try {
      const [insertErrors] = await table.insert([event]);
      if (Array.isArray(insertErrors) && insertErrors.length > 0) {
        throw new Error(`Error inserting rows into BigQuery: ${JSON.stringify(insertErrors)}`);
      }
    } catch (error) {
      throw new Error(`Error inserting rows into BigQuery: ${error}`);
    }
  }
}
