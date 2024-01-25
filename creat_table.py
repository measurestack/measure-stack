from google.cloud import bigquery
import google.api_core
from consts import DATASET_ID, LOCATION, TABLE_ID
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--project', help='GCP project ID')
args = parser.parse_args()

if args.project:
    client = bigquery.Client(project=args.project)
else:
    client = bigquery.Client()


def create_dataset_and_table():
    dataset_ref = client.dataset(DATASET_ID)
    dataset = bigquery.Dataset(dataset_ref)
    dataset.location = LOCATION
    try:
        dataset = client.create_dataset(dataset, timeout=30)
        print(f"Created dataset: {dataset.dataset_id}")
    except Exception as e:
        pass
    
    existing_table = None
    try: 
        existing_table_ref = client.dataset(DATASET_ID).table(TABLE_ID)
        existing_table = client.get_table(existing_table_ref)
    except Exception as e:
        pass

    schema = [
        bigquery.SchemaField("timestamp", "TIMESTAMP"),
        bigquery.SchemaField("event_type", "STRING"),
        bigquery.SchemaField("event_name", "STRING"),
        bigquery.SchemaField("parameters", "JSON"),
        bigquery.SchemaField("user_agent", "STRING"),
        bigquery.SchemaField("url", "STRING"),
        bigquery.SchemaField("referrer", "STRING"),
        bigquery.SchemaField("client_id", "STRING"),
        bigquery.SchemaField("hash", "STRING"),
        bigquery.SchemaField("user_id", "STRING"),
        bigquery.SchemaField(
            "device", 
            "RECORD", 
            fields=[
                bigquery.SchemaField("type", "STRING"),
                bigquery.SchemaField("family", "STRING"),
                bigquery.SchemaField("brand", "STRING"),
                bigquery.SchemaField("model", "STRING"),
                bigquery.SchemaField("browser", "STRING"),
                bigquery.SchemaField("browser_version", "STRING"),
                bigquery.SchemaField("os", "STRING"),
                bigquery.SchemaField("os_version", "STRING"),
                bigquery.SchemaField("is_bot", "BOOL"),
            ]
        ),
        bigquery.SchemaField(
            "ab_test", 
            "RECORD", 
            mode="REPEATED",  # This indicates that the field is an array of records
            fields=[
                bigquery.SchemaField("name", "STRING"),
                bigquery.SchemaField("variant", "STRING"),
                bigquery.SchemaField("def", "STRING"),
            ]
        ),
        bigquery.SchemaField(
            "location", 
            "RECORD", 
            fields=[
                bigquery.SchemaField("ip_trunc", "STRING"),
                bigquery.SchemaField("continent", "STRING"),
                bigquery.SchemaField("country", "STRING"),
                bigquery.SchemaField("country_code", "STRING"),
                bigquery.SchemaField("city", "STRING"),
            ]
        ),        
    ]

    table_ref = dataset.table(TABLE_ID)
    table = bigquery.Table(table_ref, schema=schema)
    try:
        if existing_table:
            # Note, this will accept new columns in schema but not modified or deleted columns. This is inteded. Use DML like ALTER TABLE `ga3-api-370011.tracking.events` DROP COLUMN IF EXISTS `nonsense` to modify the table in BigQuery if necessary
            client.update_table(table, ["schema"])
            print(f"Updated table: {table.table_id}")
        else:
            table = client.create_table(table, timeout=30)
            print(f"Created table: {table.table_id}")
    except google.api_core.exceptions.NotFound as e:
        pass
    except Exception as e:
        raise e
    
create_dataset_and_table()
