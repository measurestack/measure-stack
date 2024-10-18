

resource "google_bigquery_dataset" "events_dataset" {
  project                     = var.gcp_project_id
  dataset_id                  = var.bq_dataset_name
  location                    = var.gcp_region
}

resource "google_bigquery_table" "events_table" {
  dataset_id                  = google_bigquery_dataset.events_dataset.dataset_id
  table_id                    = var.bq_table_name
  time_partitioning {
    field = "timestamp"
    type = "DAY"
  }
  schema = <<EOF
[
  {
    "name": "timestamp",
    "type": "TIMESTAMP"
  },
  {
    "name": "event_type",
    "type": "STRING"
  },
  {
    "name": "event_name",
    "type": "STRING"
  },
  {
    "name": "parameters",
    "type": "JSON"
  },
  {
    "name": "user_agent",
    "type": "STRING"
  },
  {
    "name": "url",
    "type": "STRING"
  },
  {
    "name": "referrer",
    "type": "STRING"
  },
  {
    "name": "client_id",
    "type": "STRING"
  },
  {
    "name": "hash",
    "type": "STRING"
  },
  {
    "name": "user_id",
    "type": "STRING"
  },
  {
    "name": "device",
    "type": "RECORD",
    "fields": [
      {"name": "type", "type": "STRING"},
      {"name": "family", "type": "STRING"},
      {"name": "brand", "type": "STRING"},
      {"name": "model", "type": "STRING"},
      {"name": "browser", "type": "STRING"},
      {"name": "browser_version", "type": "STRING"},
      {"name": "os", "type": "STRING"},
      {"name": "os_version", "type": "STRING"},
      {"name": "is_bot", "type": "BOOL"}
    ]
  },
  {
    "name": "ab_test",
    "type": "RECORD",
    "mode": "REPEATED",
    "fields": [
      {"name": "name", "type": "STRING"},
      {"name": "variant", "type": "STRING"},
      {"name": "def", "type": "STRING"}
    ]
  },
  {
    "name": "location",
    "type": "RECORD",
    "fields": [
      {"name": "ip_trunc", "type": "STRING"},
      {"name": "continent", "type": "STRING"},
      {"name": "country", "type": "STRING"},
      {"name": "country_code", "type": "STRING"},
      {"name": "city", "type": "STRING"}
    ]
  }
]
EOF
}

variable "bq_dataset_name" {
  description = "The name of the BigQuery dataset"
}

variable "bq_table_name" {
  description = "The name of the BigQuery table"
}