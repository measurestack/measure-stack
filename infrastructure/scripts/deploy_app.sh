#!/bin/bash
# Minimal Cloud Run deployment script
set -euxo pipefail

# Load unified configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config.source"

{ set +x; echo "🚀 Deploying $SERVICE_NAME to Cloud Run..."; set -x; }

# Change to project root for build context
cd "${SCRIPT_DIR}/../.."

# Generate SDK before build
{ set +x; echo "📝 Generating measure.js from template..."; set -x; }
sed "s|{{ endpoint }}|$SERVICE_URL|g" static/measure.js.template > static/measure.js

# Set project and enable services
gcloud config set project "$GCP_PROJECT_ID"
gcloud services enable run.googleapis.com cloudbuild.googleapis.com bigquery.googleapis.com firestore.googleapis.com

# Create dataset and table if needed
if ! bq ls --format=sparse "$GCP_PROJECT_ID:$GCP_DATASET_ID" &>/dev/null; then
    bq mk --dataset --location "$REGION" "$GCP_PROJECT_ID:$GCP_DATASET_ID"
fi

if ! bq show "$GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID" &>/dev/null; then
    bq mk --table \
        --location="$REGION" \
        --schema="${SCRIPT_DIR}/../schemas/bq_table_schema.json" \
        --time_partitioning_field=timestamp \
        --time_partitioning_type=DAY \
        "$GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID"
fi

# Create service account
if ! gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    gcloud iam service-accounts create "$SERVICE_NAME" --display-name="Measure-JS SA"
fi

# Grant permissions
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/datastore.user"
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.dataEditor"
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.jobUser"

# Build and deploy
{ set +x; echo "📦 Building Docker image..."; set -x; }
gcloud builds submit --tag "$IMAGE_NAME" .

{ set +x; echo "🏗️ Deploying to Cloud Run..."; set -x; }
gcloud run deploy "$SERVICE_NAME" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --allow-unauthenticated \
    --port=3000 \
    --service-account="$SA_EMAIL" \
    --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_DATASET_ID=$GCP_DATASET_ID,GCP_TABLE_ID=$GCP_TABLE_ID,CLIENT_ID_COOKIE_NAME=$CLIENT_ID_COOKIE_NAME,HASH_COOKIE_NAME=$HASH_COOKIE_NAME,COOKIE_DOMAIN=$COOKIE_DOMAIN,DAILY_SALT=$DAILY_SALT,GEO_ACCOUNT=$GEO_ACCOUNT,GEO_KEY=$GEO_KEY,CORS_ORIGIN=$CORS_ORIGIN,RATE_LIMIT_WINDOW_MS=$RATE_LIMIT_WINDOW_MS,RATE_LIMIT_MAX_REQUESTS=$RATE_LIMIT_MAX_REQUESTS,RATE_LIMIT_SKIP_SUCCESS=$RATE_LIMIT_SKIP_SUCCESS,RATE_LIMIT_SKIP_FAILED=$RATE_LIMIT_SKIP_FAILED" \
    --memory="$MEMORY" \
    --cpu="$CPU" \
    --execution-environment=gen2
set +x
echo "✅ Deployment complete!"
echo "Service URL: $SERVICE_URL"
echo "SDK URL: $SERVICE_URL/measure.js"