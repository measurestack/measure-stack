
# =========================== ENV VAR Definitions ==============================

export DAILY_SALT=123456789
export CLIENT_ID_COOKIE_NAME=_ms_cid
export HASH_COOKIE_NAME=_ms_h
export GCP_PROJECT_ID=internal-294410
export GCP_DATASET_ID=test_tracking
export GCP_TABLE_ID=events
export GEO_ACCOUNT=1136583
export GEO_KEY=
export SERVICE_NAME=measure-js-app
export REGION=europe-west1
export CORS_ORIGIN=https://9fwr.com
export SERVICE_NAME=measure-js-app

# =============================== Checks =======================================

# Check 1 - Is the User Logged In?
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

if [ -z "$ACTIVE_ACCOUNT" ]; then
  echo "❌ No active GCP account found. Please run 'gcloud auth login' first."
  exit 1
fi
echo "✅ Logged in as: $ACTIVE_ACCOUNT"


# Check 2 - Do the Project / Dataset / Table exist?
## 2.1 Check Project Existence
echo "🔍 Checking if GCP project exists..."
gcloud projects describe "$GCP_PROJECT_ID" > /dev/null 2>&1 || {
  read -p "❌ Project not found! Do you want to create the project? [y/n] " CREATE_PR
  if [ "$CREATE_PR" = "y" ]; then
    echo "Creating project..."
    gcloud projects create "$GCP_PROJECT_ID" \
        --name="$GCP_PROJECT_ID" \
        --set-as-default
  else
      echo "Exiting..."
      exit 1
  fi
  }

## 2.2 Check Dataset Existence
echo "🔍 Checking if GCP Dataset '$GCP_DATASET_ID' exists in project '$GCP_PROJECT_ID'..."

bq ls --format=sparse "$GCP_PROJECT_ID:$GCP_DATASET_ID" >/dev/null 2>&1 || {
    read -p "❌ Dataset not found! Do you want to create the Dataset? [y/n] " CREATE_DS
    if [ "$CREATE_DS" = "y" ]; then
        echo "Creating dataset '$GCP_DATASET_ID' in project '$GCP_PROJECT_ID'..."
        bq mk --dataset "$GCP_PROJECT_ID:$GCP_DATASET_ID"
        echo "✅ Dataset '$GCP_DATASET_ID' created."
    else
        echo "Exiting..."
        exit 1
    fi
}

## 2.2 Check Table Existence
if bq show --format=prettyjson "$GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID" >/dev/null 2>&1; then
  echo "✅ Table '$GCP_TABLE_ID' exists in dataset '$GCP_DATASET_ID'."
else
  echo "❌ Table '$GCP_TABLE_ID' not found in dataset '$GCP_DATASET_ID'. It will be created during deployment"
  # Prompt user to create the table, or exit
fi

# Check 3 - Does the Service Account already exists / Does he have the correct permissions?
SA_NAME="${SERVICE_NAME}-sa"
SA_EMAIL="$SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"


EXISTING_SA=$(gcloud iam service-accounts list \
    --filter="email=$SA_EMAIL" \
    --format="value(email)")

if [ "$EXISTING_SA" = "$SA_EMAIL" ]; then
  echo "✅ Service account $SA_EMAIL already exists."

else
  echo "👤 Creating service account: $SA_NAME..."
  gcloud iam service-accounts create "$SA_NAME" --display-name "Measure-JS SA for $SERVICE_NAME" || echo "✅ Service account already exists."

  # Assign IAM roles (limited to the specific BigQuery Dataset and Firestore Database)
  echo "🔑 Assigning IAM roles to the service account..."
  gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
      --member="serviceAccount:$SA_EMAIL" \
      --role="roles/datastore.user"

  # Assign BigQuery dataset-level access for the service account
  echo "🔑 Assigning BigQuery dataset-level access to $SA_EMAIL on dataset $GCP_DATASET_ID..."

  # 1) Retrieve the existing dataset access into a temporary JSON file
  bq show --format=prettyjson "$GCP_PROJECT_ID:$GCP_DATASET_ID" > dataset_temp.json

  # 2) Use jq to append a new access rule for the service account
  #    - 'userByEmail': Use the service account's email
  #    - 'role': "WRITER" grants read/write. Use "READER" for read-only, or "OWNER" for full control.
  jq --arg SA_EMAIL "$SA_EMAIL" '.access += [{"userByEmail": $SA_EMAIL, "role": "WRITER"}]' dataset_temp.json > dataset_access.json

  # 3) Update the dataset with the modified access
  bq update --source dataset_access.json "$GCP_PROJECT_ID:$GCP_DATASET_ID"

  # 4) Clean up temporary files
  rm dataset_temp.json dataset_access.json
fi

# Build and push the Docker image
# Ensure Docker is open:
if ! docker info >/dev/null 2>&1; then
    echo "🐳 Docker does not seem to be running. Attempting to start Docker Desktop..."
    open /Applications/Docker.app || {
      echo "❌ Could not open Docker Desktop. Please start it manually."
      exit 1
    }

# Wait for Docker to be fully running
while ! docker info >/dev/null 2>&1; do
  echo "⏳ Waiting for Docker to start..."
  sleep 1
done
fi

IMAGE_NAME="gcr.io/$GCP_PROJECT_ID/$SERVICE_NAME"
gcloud builds submit --tag "$IMAGE_NAME" .

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."
gcloud run deploy "$SERVICE_NAME" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --allow-unauthenticated \
    --port 3000 \
    --set-env-vars "GCP_PROJECT_ID=$GCP_PROJECT_ID" \
    --set-env-vars "GCP_DATASET_ID=$GCP_DATASET_ID" \
    --set-env-vars "GCP_TABLE_ID=$GCP_TABLE_ID" \
    --set-env-vars "CLIENT_ID_COOKIE_NAME=$CLIENT_ID_COOKIE_NAME" \
    --set-env-vars "HASH_COOKIE_NAME=$HASH_COOKIE_NAME" \
    --set-env-vars "DAILY_SALT=$DAILY_SALT" \
    --set-env-vars "GEO_ACCOUNT=$GEO_ACCOUNT" \
    --set-env-vars "GEO_KEY=$GEO_KEY" \
    --set-env-vars "CORS_ORIGIN=$CORS_ORIGIN" \
    --service-account "$SA_EMAIL"


echo "✅ Deployment complete!"
echo "🌍 Your app is live at: $(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)')"
