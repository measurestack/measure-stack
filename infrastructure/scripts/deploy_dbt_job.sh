#!/bin/bash

# Deploy dbt as a Cloud Run job for scheduled execution
# This script deploys dbt as a Cloud Run job that can be triggered by Cloud Scheduler

set -e

# Load environment variables
source .env 2>/dev/null || true

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-ga4-9fwr}"
REGION="${REGION:-europe-west3}"
SERVICE_NAME="${SERVICE_NAME:-measure-app}"
DBT_JOB_NAME="${DBT_JOB_NAME:-measure-dbt-job}"
DBT_SA_NAME="${DBT_SA_NAME:-measure-dbt-sa}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check required environment variables
required_vars=(
    "GCP_PROJECT_ID"
    "GCP_DATASET_ID"
    "REGION"
)

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        error "Required environment variable $var is not set"
    fi
done

log "🚀 Deploying dbt as Cloud Run job..."

# Set project
gcloud config set project "$PROJECT_ID" || error "Failed to set project"

# Create service account for dbt job
log "🔑 Creating service account for dbt job..."
SA_EMAIL="$DBT_SA_NAME@$PROJECT_ID.iam.gserviceaccount.com"

if ! gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
    gcloud iam service-accounts create "$DBT_SA_NAME" \
        --display-name="DBT Service Account for Measure-JS" || \
        error "Failed to create service account"
    log "Created service account: $SA_EMAIL"
else
    log "Service account '$SA_EMAIL' already exists"
fi

# Grant BigQuery permissions
log "🔑 Granting BigQuery permissions..."
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/bigquery.dataEditor" || \
    error "Failed to grant BigQuery data editor role"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/bigquery.jobUser" || \
    error "Failed to grant BigQuery job user role"

# Build and deploy dbt job
log "🏗️ Building dbt Docker image..."
IMAGE_NAME="gcr.io/$PROJECT_ID/$DBT_JOB_NAME"

gcloud builds submit --tag "$IMAGE_NAME" \
    --file data/dbt/Dockerfile.dbt . || \
    error "Failed to build dbt image"

# Create Cloud Run job
log "🚀 Creating Cloud Run job..."
gcloud run jobs create "$DBT_JOB_NAME" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --service-account="$SA_EMAIL" \
    --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_DATASET_ID=$GCP_DATASET_ID,REGION=$REGION,DBT_TARGET=prod" \
    --memory="2Gi" \
    --cpu="1" \
    --max-retries="3" \
    --task-timeout="1800s" || \
    error "Failed to create Cloud Run job"

log "✅ dbt Cloud Run job created successfully!"

# Create Cloud Scheduler job (optional)
read -p "Create Cloud Scheduler job to run dbt every hour? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    log "⏰ Creating Cloud Scheduler job..."

    # Enable Cloud Scheduler API
    gcloud services enable cloudscheduler.googleapis.com || \
        warn "Failed to enable Cloud Scheduler API"

    # Create scheduler job
    SCHEDULER_JOB_NAME="measure-dbt-scheduler"

    gcloud scheduler jobs create http "$SCHEDULER_JOB_NAME" \
        --schedule="0 6 * * *" \
        --uri="https://$REGION-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$PROJECT_ID/jobs/$DBT_JOB_NAME:run" \
        --http-method="POST" \
        --oauth-service-account-email="$SA_EMAIL" \
        --location="$REGION" || \
        warn "Failed to create scheduler job"

    log "✅ Cloud Scheduler job created!"
    log "📅 dbt will run every hour at minute 0"
fi

log "🎉 dbt deployment completed!"
log "📊 Job name: $DBT_JOB_NAME"
log "🔗 Region: $REGION"
log "👤 Service account: $SA_EMAIL"
log ""
log "🚀 Manual execution:"
log "  gcloud run jobs execute $DBT_JOB_NAME --region=$REGION"
log ""
log "📋 View logs:"
log "  gcloud run jobs logs read $DBT_JOB_NAME --region=$REGION"
