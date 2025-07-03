# =========================== ENV VAR Definitions ==============================

# Required environment variables - set these before running the script
# export GCP_PROJECT_ID="your-project-id"
# export REGION="us-central1"
# export GCP_DATASET_ID="measure_js"
# export GCP_TABLE_ID="events"
# export SERVICE_NAME="measure-js-api"
# export CLIENT_ID_COOKIE_NAME="measure_js_client_id"
# export HASH_COOKIE_NAME="measure_js_hash"
# export DAILY_SALT="your-daily-salt"
# export GEO_ACCOUNT="your-geo-account"
# export GEO_KEY="your-geo-key"
# export CORS_ORIGIN="https://yourdomain.com"

# Source environment variables from .env file if it exists
if [ -f .env ]; then
  echo "📄 Loading environment variables from .env file..."
  source .env
fi

# Check if required environment variables are set
required_vars=("GCP_PROJECT_ID" "REGION" "GCP_DATASET_ID" "GCP_TABLE_ID" "SERVICE_NAME" "CLIENT_ID_COOKIE_NAME" "HASH_COOKIE_NAME" "DAILY_SALT" "GEO_ACCOUNT" "GEO_KEY" "CORS_ORIGIN")

# Set default values for optional rate limiting variables
RATE_LIMIT_WINDOW_MS=${RATE_LIMIT_WINDOW_MS:-60000}
RATE_LIMIT_MAX_REQUESTS=${RATE_LIMIT_MAX_REQUESTS:-100}
RATE_LIMIT_SKIP_SUCCESS=${RATE_LIMIT_SKIP_SUCCESS:-false}
RATE_LIMIT_SKIP_FAILED=${RATE_LIMIT_SKIP_FAILED:-false}

for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "❌ Error: Environment variable $var is not set."
    echo "Please set all required environment variables before running this script."
    exit 1
  fi
done

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "❌ Error: jq is not installed. Please install jq to continue."
    echo "On macOS: brew install jq"
    echo "On Ubuntu: sudo apt-get install jq"
    exit 1
fi

# ============================ GCP Setup Checks ================================

set -e

## 1.1 - Check that the user is logged in and has the the correct permissions
ACTIVE_ACCOUNT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")

if [ -z "$ACTIVE_ACCOUNT" ]; then
  echo "❌ No active GCP account found. Please login first."
  gcloud auth login
  exit 1
fi
echo "✅ Logged in as: $ACTIVE_ACCOUNT"


# 1.2 - Ensure that the relevant APIs are enabled and the user has the required permissions
gcloud services enable run.googleapis.com \
                     cloudbuild.googleapis.com \
                     bigquery.googleapis.com \
                     firestore.googleapis.com

PERMISSION_CHECK=$(gcloud projects get-iam-policy "$GCP_PROJECT_ID" \
  --flatten="bindings[].members" \
  --format="value(bindings.role)" \
  --filter="bindings.members:user:$ACTIVE_ACCOUNT" | grep -E "roles/owner|roles/editor|roles/iam.admin" || true)

if [ -z "$PERMISSION_CHECK" ]; then
  echo "❌ User '$ACTIVE_ACCOUNT' does not have the required IAM permissions to create a service account."
  echo "🔑 Required roles: Owner (roles/owner), Editor (roles/editor), or IAM Admin (roles/iam.admin)."
  echo "Request an administrator to grant you the necessary permissions."
  exit 1
else
  echo "✅ User '$ACTIVE_ACCOUNT' has permissions to create a service account."
fi


# 1.3 - Check for the GCP Project
echo "🔍 Checking if GCP project exists..."
if gcloud projects describe "$GCP_PROJECT_ID" > /dev/null 2>&1; then
  echo "✅ Project '$GCP_PROJECT_ID' already exists."
else
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
fi

## If it exits, set the project as default, otherwise the GCP_PROJECT_ID is overwritten by the default project set via command line
gcloud config set project "$GCP_PROJECT_ID"

## 1.4 - Check if billing is enabled:
BILLING_ENABLED=$(gcloud beta billing projects describe "$GCP_PROJECT_ID" --format="value(billingEnabled)")

if [ "$BILLING_ENABLED" = "True" ]; then
  echo "✅ Billing is enabled for project '$GCP_PROJECT_ID'."
else
  echo "❌ Billing is NOT enabled for project '$GCP_PROJECT_ID'."
  read -p "Do you want to link the project to a billing account? [y/n] " LINK_BILLING
  if [ "$LINK_BILLING" = "y" ]; then
    echo "Please select a billing account from the list below and copy the ID:"
    gcloud beta billing accounts list

    read -p "Enter the Billing Account ID: " BILLING_ACCOUNT_ID
    echo "Linking project '$GCP_PROJECT_ID' to billing account '$BILLING_ACCOUNT_ID'..."
    gcloud beta billing projects link "$GCP_PROJECT_ID" \
      --billing-account "$BILLING_ACCOUNT_ID"

    # Verify it was successful
    BILLING_ENABLED=$(gcloud beta billing projects describe "$GCP_PROJECT_ID" --format="value(billingEnabled)")
    if [ "$BILLING_ENABLED" = "True" ]; then
      echo "✅ Billing is now enabled for project '$GCP_PROJECT_ID'."
    else
      echo "❌ Could not enable billing. Exiting..."
      exit 1
    fi
  else
    echo "Exiting because billing is not enabled."
    exit 1
  fi
fi

## 1.5 - Dataset Existence
echo "🔍 Checking if GCP Dataset '$GCP_DATASET_ID' exists in project '$GCP_PROJECT_ID'..."

if bq ls --format=sparse "$GCP_PROJECT_ID:$GCP_DATASET_ID" >/dev/null 2>&1; then
    echo "✅ Dataset '$GCP_DATASET_ID' already exists."
else
    read -p "❌ Dataset not found! Do you want to create the Dataset? [y/n] " CREATE_DS
    if [ "$CREATE_DS" = "y" ]; then
        echo "Creating dataset '$GCP_DATASET_ID' in project '$GCP_PROJECT_ID'..."
        bq mk --dataset --location "$REGION" "$GCP_PROJECT_ID:$GCP_DATASET_ID"
        echo "✅ Dataset '$GCP_DATASET_ID' created."
    else
        echo "Exiting..."
        exit 1
    fi
fi

## 1.6 - Check Table Existence
echo "🔍 Checking if GCP Table '$GCP_TABLE_ID' exists in dataset '$GCP_DATASET_ID'..."

if bq show --format=prettyjson "$GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID" >/dev/null 2>&1; then
    echo "✅ Table '$GCP_TABLE_ID' already exists in dataset '$GCP_DATASET_ID'."
else
    read -p "❌ Table '$GCP_TABLE_ID' not found in dataset '$GCP_DATASET_ID'. Do you want to create the Table? [y/n] " CREATE_TB
    if [ "$CREATE_TB" = "y" ]; then
        echo "🛠️ Creating table ..."
        if bq mk --table \
                 --location $REGION $GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID infrastructure/schemas/bq_table_schema.json ; then
          echo "✅ Table '$GCP_TABLE_ID' created."
        else
          echo "❌ Failed to create table '$GCP_TABLE_ID'."
          exit 1
        fi
    else
        echo "Exiting..."
        exit 1
    fi
fi

# ============================== GCP SA Checks =================================

## 2.1 - Check if the specific Service Account already exists (relevant if the script is run for redeployment)
SA_NAME="${SERVICE_NAME}"
SA_EMAIL="$SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"


## Check 2.2 - Check / Set the correct policy bindings for the service account
EXISTING_SA=$(gcloud iam service-accounts list \
    --filter="email=$SA_EMAIL" \
    --format="value(email)")
if [ -z "$EXISTING_SA" ]; then
  echo "👤 Creating service account: $SA_NAME..."
  gcloud iam service-accounts create "$SA_NAME" --display-name "Measure-JS SA for $SERVICE_NAME"
else
  echo "✅ Service account $SA_EMAIL already exists."
fi

### BigQuery Access (NOT limited to the specific table)
# gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
#   --member="serviceAccount:$SA_EMAIL" \
#   --role="roles/bigquery.dataEditor" > /dev/null 2>&1;

echo "🔑 Assigning BigQuery dataset-level access to $SA_EMAIL on dataset $GCP_DATASET_ID..."

# 1) Retrieve the existing dataset access into a temporary JSON file
bq show --format=prettyjson "$GCP_PROJECT_ID:$GCP_DATASET_ID" > dataset_temp.json

# 2) Use jq to append a new access rule for the service account
#    - 'userByEmail': Use the service account's email
#    - 'role': "WRITER" grants read/write. Use "READER" for read-only, or "OWNER" for full control.
jq --arg SA_EMAIL "$SA_EMAIL" '.access = (.access // []) + [{"userByEmail": $SA_EMAIL, "role": "WRITER"}]' dataset_temp.json > dataset_access.json

# 3) Update the dataset with the modified access
bq update --source dataset_access.json "$GCP_PROJECT_ID:$GCP_DATASET_ID"

# 4) Clean up temporary files
rm dataset_temp.json dataset_access.json


### Firestore Access
echo "🔑 Assigning Firestore access to $SA_EMAIL..."

# Since we know there are conditional bindings, always use the conditional approach
echo "✅ Adding Firestore access with conditional binding..."
gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/datastore.user" \
  --condition="expression=resource.name.startsWith('projects/$GCP_PROJECT_ID/databases/default'),title=FirestoreDatabaseAccess"

## Cloud Run Access
## Create the custom role (if it doesn't exist)
# if ! gcloud iam roles describe cloudRunDeployerInvoker --project=$GCP_PROJECT_ID > /dev/null 2>&1; then
#   echo "🛠️ Creating custom role cloudRunDeployerInvoker..."
#   gcloud iam roles create cloudRunDeployerInvoker \
#     --project=$GCP_PROJECT_ID \
#     --file=custom-run-role.yml
# else
#     echo "✅ custom role cloudRunDeployerInvoker already exists."
# fi

# # Add the service account to the custom role
# gcloud run services add-iam-policy-binding $SERVICE_NAME \
#   --member="serviceAccount:$SA_EMAIL" \
#   --role="projects/$GCP_PROJECT_ID/roles/cloudRunDeployerInvoker" \
#   --region=$REGION

IMAGE_NAME="gcr.io/$GCP_PROJECT_ID/$SERVICE_NAME"
gcloud builds submit --tag "$IMAGE_NAME" .

# Deploy to Cloud Run
echo "🚀 Deploying to Cloud Run..."

# Deploy to Cloud Run with environment variables
gcloud run deploy "$SERVICE_NAME" \
    --image="$IMAGE_NAME" \
    --region="$REGION" \
    --allow-unauthenticated \
    --port 3000 \
    --service-account="$SA_EMAIL" \
    --set-env-vars=^--^GCP_PROJECT_ID=$GCP_PROJECT_ID--GCP_DATASET_ID=$GCP_DATASET_ID--GCP_TABLE_ID=$GCP_TABLE_ID--CLIENT_ID_COOKIE_NAME=$CLIENT_ID_COOKIE_NAME--HASH_COOKIE_NAME=$HASH_COOKIE_NAME--DAILY_SALT=$DAILY_SALT--GEO_ACCOUNT=$GEO_ACCOUNT--GEO_KEY=$GEO_KEY--CORS_ORIGIN=$CORS_ORIGIN--RATE_LIMIT_WINDOW_MS=$RATE_LIMIT_WINDOW_MS--RATE_LIMIT_MAX_REQUESTS=$RATE_LIMIT_MAX_REQUESTS--RATE_LIMIT_SKIP_SUCCESS=$RATE_LIMIT_SKIP_SUCCESS--RATE_LIMIT_SKIP_FAILED=$RATE_LIMIT_SKIP_FAILED

echo "✅ Deployment complete!"
echo "🌍 Your app is live at: $(gcloud run services describe $SERVICE_NAME --region $REGION --format='value(status.url)')"
