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

# Enable services
gcloud services enable run.googleapis.com cloudbuild.googleapis.com bigquery.googleapis.com firestore.googleapis.com --project="$GCP_PROJECT_ID"

# Create Firestore database if it doesn't exist
if ! gcloud firestore databases describe --database="$GCP_FIRESTORE_DATABASE" --project="$GCP_PROJECT_ID" &>/dev/null; then
    { set +x; echo "🔥 Creating Firestore database..."; set -x; }
    gcloud firestore databases create --database="$GCP_FIRESTORE_DATABASE" --location="$REGION" --type=firestore-native --project="$GCP_PROJECT_ID"
fi

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
if ! gcloud iam service-accounts describe "$SA_EMAIL" --project="$GCP_PROJECT_ID" &>/dev/null; then
    gcloud iam service-accounts create "$SERVICE_NAME" --display-name="Measure-JS SA" --project="$GCP_PROJECT_ID"
fi

# Grant permissions
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/datastore.owner"
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.dataEditor"
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" --member="serviceAccount:$SA_EMAIL" --role="roles/bigquery.jobUser"

# Build and deploy
{ set +x; echo "📦 Building Docker image..."; set -x; }
gcloud builds submit --tag "$IMAGE_NAME" --project="$GCP_PROJECT_ID" .

# Create environment variables file for Cloud Run
ENV_VARS_FILE="/tmp/env-vars.yaml"
cat > "$ENV_VARS_FILE" << EOF
GCP_PROJECT_ID: "$GCP_PROJECT_ID"
GCP_DATASET_ID: "$GCP_DATASET_ID"
GCP_TABLE_ID: "$GCP_TABLE_ID"
GCP_FIRESTORE_DATABASE: "$GCP_FIRESTORE_DATABASE"
CLIENT_ID_COOKIE_NAME: "$CLIENT_ID_COOKIE_NAME"
HASH_COOKIE_NAME: "$HASH_COOKIE_NAME"
COOKIE_DOMAIN: "$COOKIE_DOMAIN"
DAILY_SALT: "$DAILY_SALT"
GEO_ACCOUNT: "$GEO_ACCOUNT"
GEO_KEY: "$GEO_KEY"
CORS_ORIGIN: "$CORS_ORIGIN"
RATE_LIMIT_WINDOW_MS: "$RATE_LIMIT_WINDOW_MS"
RATE_LIMIT_MAX_REQUESTS: "$RATE_LIMIT_MAX_REQUESTS"
RATE_LIMIT_SKIP_SUCCESS: "$RATE_LIMIT_SKIP_SUCCESS"
RATE_LIMIT_SKIP_FAILED: "$RATE_LIMIT_SKIP_FAILED"
EOF

{ set +x; echo "🏗️ Deploying to Cloud Run..."; set -x; }
gcloud run deploy "$SERVICE_NAME" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --allow-unauthenticated \
    --port=3000 \
    --service-account="$SA_EMAIL" \
    --env-vars-file="$ENV_VARS_FILE" \
    --memory="$MEMORY" \
    --cpu="$CPU" \
    --execution-environment=gen2 \
    --project="$GCP_PROJECT_ID"

# Clean up temp file
rm "$ENV_VARS_FILE"

# Get the actual service URL after deployment
DEPLOYED_SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region="$REGION" --project="$GCP_PROJECT_ID" --format="value(status.url)")

# setup domain mapping if TRACKER_DOMAIN is set
if [ -n "$TRACKER_DOMAIN" ]; then
  if ! gcloud beta run domain-mappings describe --domain "$TRACKER_DOMAIN" --region "$REGION" --project="$GCP_PROJECT_ID" &>/dev/null; then
    echo "Creating domain mapping for $TRACKER_DOMAIN"
    gcloud beta run domain-mappings create \
      --domain "$TRACKER_DOMAIN" \
      --service "$SERVICE_NAME" \
      --platform managed \
      --region "$REGION" \
      --project="$GCP_PROJECT_ID"
  else
    echo "Domain mapping for $TRACKER_DOMAIN already exists."
  fi
fi


# Use tracker domain if set, otherwise use deployed service URL
if [ -n "$TRACKER_DOMAIN" ]; then
  TRACKING_URL="https://$TRACKER_DOMAIN"
else
  TRACKING_URL="$DEPLOYED_SERVICE_URL"
fi

set +x
echo "✅ Deployment complete!"
echo "Service URL: $TRACKING_URL" 
echo ""
echo "Add this tracking script to your website:"
echo "<script>"
echo "  (function() {"
echo "    var s = document.createElement('script');"
echo "    s.src = '$TRACKING_URL/measure.js';"
echo "    s.async = true;"
echo "    s.onload = function() {"
echo "      _measure.pageview();"
echo "    };"
echo "    var x = document.getElementsByTagName('script')[0];"
echo "    x.parentNode.insertBefore(s, x);"
echo "  })();"
echo "</script>"

