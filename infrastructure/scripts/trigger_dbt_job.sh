#!/bin/bash

# Trigger dbt Cloud Run job manually
# This script can be used to manually trigger the dbt job

set -e

# Load environment variables
source .env 2>/dev/null || true

# Configuration
PROJECT_ID="${GCP_PROJECT_ID:-ga4-9fwr}"
REGION="${REGION:-europe-west3}"
DBT_JOB_NAME="${DBT_JOB_NAME:-measure-dbt-job}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

log "🚀 Triggering dbt job: $DBT_JOB_NAME"

# Execute the job
gcloud run jobs execute "$DBT_JOB_NAME" \
    --region="$REGION" \
    --wait || {
    warn "Job execution failed or timed out"
    exit 1
}

log "✅ dbt job completed successfully!"

# Show recent logs
log "📋 Recent logs:"
gcloud run jobs logs read "$DBT_JOB_NAME" \
    --region="$REGION" \
    --limit=50
