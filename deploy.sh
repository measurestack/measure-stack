#!/bin/bash

# Target Environment Definition
if [ -z "$1" ]; then
    echo "Please specify the target environment: 'prod' or 'dev'"
    exit 1
fi

case $1 in
    dev)
      # In development mode, we use the .env file variables to build the docker image. In this case, the Image is not deployed to Google Cloud Run
      docker build -t measure-js-app-dev .
      docker run -p 3000:3000 --env-file .env measure-js-dev


case $1 in
    prod)
      # In production, we allow the user to define the gcp project, dataset and table to store the data:
      read -p "Enter your GCP Project ID: " GCP_PROJECT_ID
      read -p "Enter BigQuery Dataset name: " GCP_DATASET_ID
      read -p "Enter BigQuery Table name: " GCP_TABLE_ID
      read -p "Enter Cloud Run service name (default: measure-js-app): " SERVICE_NAME
      SERVICE_NAME=${SERVICE_NAME:-measure-js-app}
      read -p "Enter GCP region (default: us-central1): " REGION
      REGION=${REGION:-us-central1}
      read -p "Enter the Geolocation

      # Set the environment variables
      export GCP_PROJECT_ID
      export GCP_DATASET_ID
      export GCP_TABLE_ID
      export REGION

      # Ensure that the GCP Project exists:
      echo "🔍 Checking if GCP project exists..."
      gcloud projects describe "$GCP_PROJECT_ID" > /dev/null 2>&1 || { echo "❌ Project not found!"; exit 1; }

      # Create a service account
      SA_NAME="${SERVICE_NAME}-sa"
      SA_EMAIL="$SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"

      echo "👤 Creating service account: $SA_NAME..."
      gcloud iam service-accounts create "$SA_NAME" --display-name "Cloud Run SA for $SERVICE_NAME" || echo "✅ Service account already exists."

      # Assign IAM roles
      echo "🔑 Assigning IAM roles to the service account..."
      gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
          --member="serviceAccount:$SA_EMAIL" \
          --role="roles/bigquery.dataEditor"
      gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
          --member="serviceAccount:$SA_EMAIL" \
          --role="roles/run.invoker"

      # Build and push the Docker image
      IMAGE_NAME="gcr.io/$GCP_PROJECT_ID/$SERVICE_NAME"
      echo "🐳 Building and pushing Docker image to GCR..."
      docker build -t "$IMAGE_NAME" .
      gcloud auth configure-docker
      docker push "$IMAGE_NAME"

      # Deploy to Cloud Run
      echo "🚀 Deploying to Cloud Run..."
      gcloud run deploy "$SERVICE_NAME" \
          --image="$IMAGE_NAME" \
          --service-account="$SA_EMAIL" \
          --region="$REGION" \
          --platform=managed \
          --allow-unauthenticated \
          --set-env-vars "GCP_DATASET_ID=$GCP_DATASET_ID,GCP_TABLE_ID=$GCP_TABLE_ID,GCP_PROJECT_ID=$GCP_PROJECT_ID"

      echo "✅ Deployment complete!"
      echo "🌍 Your app is live at: $(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)')"












# Shared variables, Note: use `source /dev/stdin` on command line and copy those variables in to have them defined on commandline to execute statements individually
NAME=tracker
TRACKER_FUNCTION="${NAME}"
GCP_PROJECT_ID=measure-js
LOCATION=europe-west1

# 0. Allow secret manager access of default service account
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID --member="serviceAccount:${GCP_PROJECT_ID}@appspot.gserviceaccount.com" --role='roles/secretmanager.secretAccessor'

# 1. Deploy the Cloud Functions
gcloud functions deploy $TRACKER_FUNCTION \
    --runtime python310 \
    --trigger-http \
    --allow-unauthenticated \
    --memory 256MB \
    --project $GCP_PROJECT_ID \
    --entry-point main \
    --source ./ \
    --region $LOCATION \
    --set-env-vars GEOIP_ACCOUNT_ID=871440 \
    --set-secrets GEOIP_API_KEY=geoip_api_key:latest

gcloud functions describe $TRACKER_FUNCTION --format='get(httpsTrigger.url)' --project $GCP_PROJECT_ID --region $LOCATION

# Check if Firestore database exists in the project
if gcloud firestore databases describe --project="$GCP_PROJECT_ID" 2>/dev/null; then
    echo "Firestore database already exists in project $GCP_PROJECT_ID."
else
    gcloud firestore databases create --project=$GCP_PROJECT_ID --location=$LOCATION #optional --database=measure
fi
