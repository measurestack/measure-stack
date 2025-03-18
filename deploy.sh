
# =========================== ENV VAR Definitions ==============================

export DAILY_SALT=123456789
export CLIENT_ID_COOKIE_NAME=_ms_cid
export HASH_COOKIE_NAME=_ms_h
export GCP_PROJECT_ID=ga4-9fwr
export GCP_DATASET_ID=measure_js
export GCP_TABLE_ID=events
export GEO_ACCOUNT=1136583
export GEO_KEY=
export REGION=europe-west1
export CORS_ORIGIN=https://9fwr.com
export SERVICE_NAME=measure-js-app
export FIRESTORE_DATABASE_ID=(default)
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


## 1.2 - Ensure that the relevant APIs are enabled and the user has the required permissions
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
                 --location $REGION $GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID bq_table_schema.json ; then
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


### BigQuery Access (limited to the specific table)
bq add-iam-policy-binding \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/bigquery.dataEditor" \
  $GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID > /dev/null 2>&1;

### Firestore Accesshow
gcloud projects add-iam-policy-binding $GCP_PROJECT_ID \
  --member="serviceAccount:$SA_EMAIL" \
  --role="roles/datastore.user" \
  --condition="expression=resource.name.startsWith('projects/$GCP_PROJECT_ID/databases/$FIRESTORE_DATABASE_ID'),title=FirestoreDatabaseAccess" > /dev/null 2>&1;

### Cloud Run Access
# Create the custom role (if it doesn't exist)
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
