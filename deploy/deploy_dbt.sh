#!/bin/bash
# Minimal dbt Cloud Run deployment script
set -euo pipefail

# Load unified configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if config.source exists
if [ ! -f "${SCRIPT_DIR}/config.source" ]; then
    echo "❌ Error: config.source not found!"
    echo "Please create it from the template:"
    echo "  cd deploy"
    echo "  cp config.source.template config.source"
    echo "  # Then edit config.source with your settings"
    exit 1
fi

source "${SCRIPT_DIR}/config.source"

echo "🚀 Deploying dbt job to Cloud Run..."

# Set project and enable services
gcloud config set project "$GCP_PROJECT_ID"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com bigquery.googleapis.com cloudscheduler.googleapis.com

# Create service account
if ! gcloud iam service-accounts describe "$DBT_SA_EMAIL" &>/dev/null; then
    gcloud iam service-accounts create "$DBT_SA_NAME" --display-name="DBT Service Account"
fi

# Grant Cloud Run Invoker permission for the service account (needed for Cloud Scheduler)
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$DBT_SA_EMAIL" --role="roles/run.invoker"

# Grant BigQuery permissions
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$DBT_SA_EMAIL" --role="roles/bigquery.dataEditor"
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$DBT_SA_EMAIL" --role="roles/bigquery.jobUser"

# Grant dataset access
bq show --format=prettyjson "$GCP_PROJECT_ID:$GCP_DATASET_ID" > /tmp/dataset.json
jq --arg SA "$DBT_SA_EMAIL" '.access = (.access // []) + [{"userByEmail": $SA, "role": "WRITER"}]' /tmp/dataset.json > /tmp/dataset_updated.json
bq update --source /tmp/dataset_updated.json "$GCP_PROJECT_ID:$GCP_DATASET_ID"

# Build and deploy
echo "📦 Building Docker image..."
cd "${SCRIPT_DIR}/../data/dbt"
gcloud builds submit --tag "$DBT_IMAGE_NAME"

echo "🏗️ Creating Cloud Run job..."
if gcloud run jobs describe "$DBT_JOB_NAME" --region="$REGION" &>/dev/null; then
    gcloud run jobs update "$DBT_JOB_NAME" --image="$DBT_IMAGE_NAME" --region="$REGION" --service-account="$DBT_SA_EMAIL" \
        --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_DATASET_ID=$GCP_DATASET_ID,REGION=$REGION,DBT_TARGET=prod"
else
    gcloud run jobs create "$DBT_JOB_NAME" --image="$DBT_IMAGE_NAME" --region="$REGION" --service-account="$DBT_SA_EMAIL" \
        --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_DATASET_ID=$GCP_DATASET_ID,REGION=$REGION,DBT_TARGET=prod"
fi

# Setup scheduler
echo "⏰ Setting up scheduler..."
if gcloud scheduler jobs describe "$DBT_SCHEDULER_JOB_NAME" --location="$REGION" &>/dev/null; then
    gcloud scheduler jobs update http "$DBT_SCHEDULER_JOB_NAME" --schedule="$DBT_SCHEDULE" \
        --uri="https://$REGION-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$GCP_PROJECT_ID/jobs/$DBT_JOB_NAME:run" \
        --http-method="POST" --oauth-service-account-email="$DBT_SA_EMAIL" --location="$REGION"
else
    gcloud scheduler jobs create http "$DBT_SCHEDULER_JOB_NAME" --schedule="$DBT_SCHEDULE" \
        --uri="https://$REGION-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$GCP_PROJECT_ID/jobs/$DBT_JOB_NAME:run" \
        --http-method="POST" --oauth-service-account-email="$DBT_SA_EMAIL" --location="$REGION"
fi

echo "✅ Deployment complete!"
echo "to manually executed dbt the first time do: gcloud run jobs execute $DBT_JOB_NAME --region=$REGION"