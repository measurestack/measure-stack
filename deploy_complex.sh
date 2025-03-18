# Script to deploy the app to Cloud Run

read -p "Please specify the target environment: 'prod' or 'dev': " ENVIRON
export ENVIRON

# Ensure the user is logged in:
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

if [ -z "$ACTIVE_ACCOUNT" ]; then
  echo "❌ No active GCP account found. Please run 'gcloud auth login' first."
  exit 1
fi
echo "✅ Logged in as: $ACTIVE_ACCOUNT"


# ==================== Environment Variable Definitions ========================

read -p "Enter your GCP Project ID: " GCP_PROJECT_ID
export GCP_PROJECT_ID

# Check if the Project exists / allow creation it if it doesnt
echo "🔍 Checking if GCP project exists..."
gcloud projects describe "$GCP_PROJECT_ID" > /dev/null 2>&1 || {
    read -p "❌ Project not found! Do you want to create the project? [y/n] " CREATE_PR
    if [ "$CREATE_PR" = "y" ]; then
        echo "Creating project..."
        gcloud projects create "$GCP_PROJECT_ID" \
            --name="Your Project Name" \
            --set-as-default
        # Add any additional config steps here (e.g. setting billing)
    else
        echo "Exiting..."
        exit 1
    fi
}

read -p "Enter BigQuery Dataset ID: " GCP_DATASET_ID
export GCP_DATASET_ID
# Check if the GCP BigQuery Dataset exists
# Use bq to list the dataset in sparse format
# Redirect output to /dev/null to suppress it
# If it fails (|| block), we prompt to create the dataset
echo "🔍 Checking if GCP Dataset '$GCP_DATASET_ID' exists in project '$GCP_PROJECT_ID'..."

bq ls --format=sparse "$GCP_PROJECT_ID:$GCP_DATASET_ID" >/dev/null 2>&1 || {
    read -p "❌ Dataset not found! Do you want to create the Dataset? [y/n] " CREATE_DS
    if [ "$CREATE_DS" = "y" ]; then
        read -p "Provide a Name for the Dataset " GCP_DATASET_ID
        echo "Creating dataset '$GCP_DATASET_ID' in project '$GCP_PROJECT_ID'..."
        bq mk --dataset "$GCP_PROJECT_ID:$GCP_DATASET_ID"
        echo "✅ Dataset '$GCP_DATASET_ID' created."
    else
        echo "Exiting..."
        exit 1
    fi
}
export GCP_DATASET_ID

read -p "Enter BigQuery Table ID: " GCP_TABLE_ID
# Check if the GCP BigQuery Dataset exists
# Use bq to list the dataset in sparse format
# Redirect output to /dev/null to suppress it
# If it fails (|| block), we prompt to create the dataset
echo "🔍 Checking if GCP Dataset '$GCP_TABLE_ID' exists in dataset '$GCP_DATASET_ID'..."
#TODO -> Implement Check
export GCP_TABLE_ID

read -p "Enter the GeoLite API Key: " GEO_KEY
export GEO_KEY


read -p "Enter GCP region (default: europe-west1): " REGION
REGION=${REGION:-europe-west1}
export REGION

# Export other env variables
export CLIENT_ID_COOKIE_NAME=_ms_cid
export HASH_COOKIE_NAME=_ms_h
export DAILY_SALT=123456789
# DELETE BEFORE DEPLOY
export GEO_ACCOUNT=XXX


case $ENVIRON in
  dev)
    # In case we are in a development environment, we aim to create a service account before building the docker image, which is run locally
    read -p "Enter Service Account name (default: measure-js-app): " SERVICE_NAME
    SERVICE_NAME=${SERVICE_NAME:-measure-js-app}

    # Check if the Service Account already exists:


    # Create a service account
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

    KEY_FILE_PATH=".config/service-account.json"

    if [ -f "$KEY_FILE_PATH" ]; then
      echo "✅ Key file already exists at $KEY_FILE_PATH. Skipping key creation."
    else
      echo "🔑 Creating new key for service account: $SA_EMAIL..."
      gcloud iam service-accounts keys create "$KEY_FILE_PATH" \
        --iam-account="$SA_EMAIL"
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

    IMAGE_NAME="$GCP_PROJECT_ID/$SERVICE_NAME-dev"
    echo "🐳 Building Docker Image..."
    docker build -t "$IMAGE_NAME" .
    docker run -p 3000:3000  -e SERVICE_NAME=$SERVICE_NAME \
                      -e GCP_PROJECT_ID=$GCP_PROJECT_ID \
                      -e GCP_DATASET_ID=$GCP_DATASET_ID \
                      -e GCP_TABLE_ID=$GCP_TABLE_ID \
                      -e CLIENT_ID_COOKIE_NAME=$CLIENT_ID_COOKIE_NAME \
                      -e HASH_COOKIE_NAME=$HASH_COOKIE_NAME \
                      -e DAILY_SALT=$DAILY_SALT \
                      -e GEO_ACCOUNT=$GEO_ACCOUNT \
                      -e GEO_KEY=$GEO_KEY \
                      -e GCP_TABLE_ID=$GCP_TABLE_ID \
                      "$IMAGE_NAME"
                      --name "measure-js-$IMAGE_NAME"

  ;;
  prod)
    # To deploy to google cloud run
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
    echo "🐳 Building Docker Image..."
    docker build -t "$IMAGE_NAME" .
    docker run -p 3000:3000  -e SERVICE_NAME=$SERVICE_NAME \
                      -e GCP_PROJECT_ID=$GCP_PROJECT_ID \
                      -e GCP_DATASET_ID=$GCP_DATASET_ID \
                      -e GCP_TABLE_ID=$GCP_TABLE_ID \
                      -e CLIENT_ID_COOKIE_NAME=$CLIENT_ID_COOKIE_NAME \
                      -e HASH_COOKIE_NAME=$HASH_COOKIE_NAME \
                      -e DAILY_SALT=$DAILY_SALT \
                      -e GEO_ACCOUNT=$GEO_ACCOUNT \
                      -e GEO_KEY=$GEO_KEY \
                      -e GCP_TABLE_ID=$GCP_TABLE_ID \
                      "$IMAGE_NAME"
                      --name "measure-js-$IMAGE_NAME"


    # Deploy to Cloud Run
    echo "🚀 Deploying to Cloud Run..."
    gcloud run deploy "$SERVICE_NAME" \
        --image="$IMAGE_NAME" \
        --region="$REGION" \
        --platform=managed \
        --allow-unauthenticated \
        --set-env-vars "GCP_DATASET_ID=$GCP_DATASET_ID,GCP_TABLE_ID=$GCP_TABLE_ID,GCP_PROJECT_ID=$GCP_PROJECT_ID"




    echo "✅ Deployment complete!"
    echo "🌍 Your app is live at: $(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)')"
