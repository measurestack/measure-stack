#!/bin/bash

# Shared variables, Note: use `source /dev/stdin` on command line and copy those variables in to have them defined on commandline to execute statements individually 
NAME=tracker
TRACKER_FUNCTION="${NAME}"
PROJECT_ID=measure-js
LOCATION=europe-west1

# 0. Allow secret manager access of default service account
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:${PROJECT_ID}@appspot.gserviceaccount.com" --role='roles/secretmanager.secretAccessor'

# 1. Deploy the Cloud Functions
gcloud functions deploy $TRACKER_FUNCTION \
    --runtime python310 \
    --trigger-http \
    --allow-unauthenticated \
    --memory 256MB \
    --project $PROJECT_ID \
    --entry-point main \
    --source ./ \
    --region $LOCATION \
    --set-env-vars GEOIP_ACCOUNT_ID=871440 \
    --set-secrets GEOIP_API_KEY=geoip_api_key:latest 

gcloud functions describe $TRACKER_FUNCTION --format='get(httpsTrigger.url)' --project $PROJECT_ID --region $LOCATION 

# Check if Firestore database exists in the project
if gcloud firestore databases describe --project="$PROJECT_ID" 2>/dev/null; then
    echo "Firestore database already exists in project $PROJECT_ID."
else
    gcloud firestore databases create --project=$PROJECT_ID --location=$LOCATION #optional --database=measure
fi