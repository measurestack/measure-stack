#!/bin/bash

# ============================== Configuration ================================

# Deploy dbt as a Cloud Run job for scheduled execution
# This script deploys dbt as a Cloud Run job that can be triggered by Cloud Scheduler

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/dbt_deploy.log"
TEMP_DIR="${SCRIPT_DIR}/.tmp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =========================== Utility Functions ===============================

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    cleanup
    exit 1
}

info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Trap to cleanup on exit
trap cleanup EXIT

# Create temp directory
mkdir -p "$TEMP_DIR"

# =========================== ENV Var Definition ==============================

# Source environment variables from project root .env file
if [ -f "${PROJECT_ROOT}/.env" ]; then
    log "Loading environment variables from ${PROJECT_ROOT}/.env..."
    set -a  # automatically export all variables
    source "${PROJECT_ROOT}/.env"
    set +a
else
    info "No .env file found at ${PROJECT_ROOT}/.env"
fi

# Required environment variables
required_vars=(
    "GCP_PROJECT_ID"
    "GCP_DATASET_ID"
    "REGION"
    "GCP_TABLE_ID"  # Added this - needed for source table access
)

# Set default values for optional variables
DBT_JOB_NAME=${DBT_JOB_NAME:-measure-dbt-job}
DBT_SA_NAME=${DBT_SA_NAME:-measure-dbt-sa}
DBT_MEMORY=${DBT_MEMORY:-2Gi}
DBT_CPU=${DBT_CPU:-1}
DBT_MAX_RETRIES=${DBT_MAX_RETRIES:-3}
DBT_TIMEOUT=${DBT_TIMEOUT:-1800s}
DBT_SCHEDULE=${DBT_SCHEDULE:-"0 6 * * *"}  # Daily at 6 AM
DBT_TARGET=${DBT_TARGET:-prod}

# Derived values
SA_EMAIL="$DBT_SA_NAME@$GCP_PROJECT_ID.iam.gserviceaccount.com"
IMAGE_NAME="gcr.io/$GCP_PROJECT_ID/$DBT_JOB_NAME"
SCHEDULER_JOB_NAME="measure-dbt-scheduler"

# =========================== Validation ===================================

validate_env_vars() {
    log "Validating environment variables..."
    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        error "Missing required environment variables: ${missing_vars[*]}"
    fi

    log "All required environment variables are set"
}

check_dependencies() {
    log "Checking dependencies..."

    local deps=("gcloud" "docker" "bq")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing dependencies: ${missing_deps[*]}"
    fi

    log "All dependencies are available"

    # Check BigQuery authentication
    log "Checking BigQuery authentication..."
    if ! bq ls --project_id="$GCP_PROJECT_ID" &>/dev/null; then
        warn "BigQuery CLI not authenticated. Attempting to authenticate..."
        gcloud auth application-default login || \
            error "Failed to authenticate BigQuery CLI"
    fi
    log "BigQuery authentication verified"
}

validate_dockerfile() {
    log "Validating dbt Dockerfile..."

    local dockerfile_path="${PROJECT_ROOT}/data/dbt/Dockerfile"

    if [ ! -f "$dockerfile_path" ]; then
        error "dbt Dockerfile not found at: $dockerfile_path"
    fi

    # Check if dbt profiles directory exists
    if [ ! -d "${PROJECT_ROOT}/data/dbt" ]; then
        warn "dbt directory not found at: ${PROJECT_ROOT}/data/dbt"
    fi

    log "dbt Dockerfile validation completed"
}

# =========================== GCP Authentication ===============================

check_gcp_auth() {
    log "Checking GCP authentication..."

    local active_account
    active_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null)

    if [ -z "$active_account" ]; then
        warn "No active GCP account found. Initiating login..."
        gcloud auth login || error "Failed to authenticate with GCP"
        active_account=$(gcloud auth list --filter=status:ACTIVE --format="value(account)")
    fi

    log "Authenticated as: $active_account"

    # Check permissions
    local permission_check
    permission_check=$(gcloud projects get-iam-policy "$GCP_PROJECT_ID" \
        --flatten="bindings[].members" \
        --format="value(bindings.role)" \
        --filter="bindings.members:user:$active_account" 2>/dev/null | \
        grep -E "roles/owner|roles/editor|roles/iam.admin" || true)

    if [ -z "$permission_check" ]; then
        error "User '$active_account' lacks required IAM permissions (Owner, Editor, or IAM Admin)"
    fi

    log "User has sufficient permissions"
}

# =========================== GCP Services =====================================

enable_gcp_services() {
    log "Enabling required GCP services..."

    local services=(
        "run.googleapis.com"
        "cloudbuild.googleapis.com"
        "bigquery.googleapis.com"
        "cloudscheduler.googleapis.com"
    )

    for service in "${services[@]}"; do
        if gcloud services enable "$service" --project="$GCP_PROJECT_ID"; then
            log "Enabled service: $service"
        else
            error "Failed to enable service: $service"
        fi
    done
}

# =========================== Project Setup ====================================

setup_project() {
    log "Setting up GCP project..."

    if gcloud projects describe "$GCP_PROJECT_ID" &> /dev/null; then
        log "Project '$GCP_PROJECT_ID' exists"
    else
        read -p "Project '$GCP_PROJECT_ID' not found. Create it? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            gcloud projects create "$GCP_PROJECT_ID" \
                --name="$GCP_PROJECT_ID" \
                --set-as-default || error "Failed to create project"
            log "Created project: $GCP_PROJECT_ID"
        else
            error "Project creation declined"
        fi
    fi

    # Set as default project
    gcloud config set project "$GCP_PROJECT_ID" || error "Failed to set project"
}

check_billing() {
    log "Checking billing status..."

    local billing_enabled
    billing_enabled=$(gcloud beta billing projects describe "$GCP_PROJECT_ID" \
        --format="value(billingEnabled)" 2>/dev/null)

    if [ "$billing_enabled" = "True" ]; then
        log "Billing is enabled"
    else
        warn "Billing is not enabled for project '$GCP_PROJECT_ID'"
        read -p "Link project to billing account? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            gcloud beta billing accounts list
            read -p "Enter Billing Account ID: " billing_account_id

            gcloud beta billing projects link "$GCP_PROJECT_ID" \
                --billing-account "$billing_account_id" || error "Failed to link billing"

            log "Billing enabled successfully"
        else
            error "Billing is required for this deployment"
        fi
    fi
}

# =========================== Service Account Setup ============================

setup_service_account() {
    log "Setting up service account for dbt job..."

    # Create service account if it doesn't exist
    if gcloud iam service-accounts describe "$SA_EMAIL" &>/dev/null; then
        log "Service account '$SA_EMAIL' exists"
    else
        gcloud iam service-accounts create "$DBT_SA_NAME" \
            --display-name="DBT Service Account for Measure-JS" || \
            error "Failed to create service account"
        log "Created service account: $SA_EMAIL"
    fi

    # Grant required permissions
    grant_bigquery_permissions
}

grant_bigquery_permissions() {
    log "Configuring BigQuery permissions..."

    # Grant project-level BigQuery permissions
    local roles=(
        "roles/bigquery.dataEditor"
        "roles/bigquery.jobUser"
        "roles/bigquery.user"
    )

    for role in "${roles[@]}"; do
        if gcloud projects get-iam-policy "$GCP_PROJECT_ID" \
            --flatten="bindings[].members" \
            --filter="bindings.members:serviceAccount:$SA_EMAIL AND bindings.role:$role" \
            --format="value(bindings.role)" | grep -q "$role"; then
            log "Role '$role' already granted"
        else
            gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
                --member="serviceAccount:$SA_EMAIL" \
                --role="$role" || \
                error "Failed to grant role: $role"
            log "Granted role: $role"
        fi
    done

    # Verify and configure dataset access
    configure_dataset_access

    log "BigQuery permissions configured successfully"
}

configure_dataset_access() {
    log "Configuring dataset-specific access..."

    # Check if dataset exists
    if ! bq show --format=sparse "$GCP_PROJECT_ID:$GCP_DATASET_ID" &>/dev/null; then
        warn "Dataset '$GCP_DATASET_ID' does not exist."
        read -p "Create dataset '$GCP_DATASET_ID'? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log "Creating dataset '$GCP_DATASET_ID'..."
            bq mk --dataset --location "$REGION" "$GCP_PROJECT_ID:$GCP_DATASET_ID" || \
                error "Failed to create dataset"
            log "Dataset created successfully"
        else
            error "Dataset is required for dbt to function"
        fi
    fi

    # Configure dataset access using JSON approach (more reliable)
    log "Setting up dataset access control..."

    # Get current dataset info
    bq show --format=prettyjson "$GCP_PROJECT_ID:$GCP_DATASET_ID" > "$TEMP_DIR/dataset_current.json"

    # Check if service account already has access
    if jq -e --arg SA_EMAIL "$SA_EMAIL" '.access[]? | select(.userByEmail == $SA_EMAIL and .role == "WRITER")' "$TEMP_DIR/dataset_current.json" >/dev/null; then
        log "Service account already has WRITER access to dataset"
    else
        log "Adding service account WRITER access to dataset..."
        # Add service account with WRITER role
        jq --arg SA_EMAIL "$SA_EMAIL" \
            '.access = (.access // []) + [{"userByEmail": $SA_EMAIL, "role": "WRITER"}]' \
            "$TEMP_DIR/dataset_current.json" > "$TEMP_DIR/dataset_updated.json"

        # Apply the updated access
        bq update --source "$TEMP_DIR/dataset_updated.json" "$GCP_PROJECT_ID:$GCP_DATASET_ID" || \
            error "Failed to update dataset access"

        log "Dataset access configured successfully"
    fi

    # Verify source table exists and is accessible
    verify_source_table_access
}

verify_source_table_access() {
    log "Verifying source table access..."

    # Check if the main events table exists (this is what dbt will read from)
    if bq show --format=sparse "$GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID" &>/dev/null; then
        log "Source table '$GCP_TABLE_ID' exists and is accessible"

        # Test read access
        if bq query --dry_run --use_legacy_sql=false \
            "SELECT COUNT(*) FROM \`$GCP_PROJECT_ID.$GCP_DATASET_ID.$GCP_TABLE_ID\` LIMIT 1" &>/dev/null; then
            log "Service account can read from source table"
        else
            warn "Service account may not have read access to source table"
        fi
    else
        warn "Source table '$GCP_TABLE_ID' does not exist in dataset '$GCP_DATASET_ID'"
        warn "This table must be created before dbt can process data"
        warn "Run the main deployment script first to create the events table"
    fi
}

# =========================== Build and Deploy =================================

build_dbt_image() {
    log "Building dbt Docker image..."

    # Check if Cloud Build is available
    if ! gcloud services list --enabled --filter="name:cloudbuild.googleapis.com" --format="value(name)" | grep -q "cloudbuild.googleapis.com"; then
        error "Cloud Build API is not enabled"
    fi

    # Change to dbt directory for build context (where Dockerfile is located)
    cd "${PROJECT_ROOT}/data/dbt" || error "Failed to change to dbt directory"

    gcloud builds submit --tag "$IMAGE_NAME" . || \
        error "Failed to build dbt image"

    log "dbt image built successfully: $IMAGE_NAME"
}

deploy_cloud_run_job() {
    log "Creating Cloud Run job..."

    # Check if job already exists
    if gcloud run jobs describe "$DBT_JOB_NAME" --region="$REGION" &>/dev/null; then
        log "Updating existing Cloud Run job..."

        # Update existing job with new configuration
        gcloud run jobs update "$DBT_JOB_NAME" \
            --image="$IMAGE_NAME" \
            --region="$REGION" \
            --service-account="$SA_EMAIL" \
            --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_DATASET_ID=$GCP_DATASET_ID,REGION=$REGION,DBT_TARGET=$DBT_TARGET" \
            --memory="$DBT_MEMORY" \
            --cpu="$DBT_CPU" \
            --max-retries="$DBT_MAX_RETRIES" \
            --task-timeout="$DBT_TIMEOUT" || \
            error "Failed to update Cloud Run job"

        log "Cloud Run job updated successfully"
    else
        log "Creating new Cloud Run job..."

        gcloud run jobs create "$DBT_JOB_NAME" \
            --image="$IMAGE_NAME" \
            --region="$REGION" \
            --service-account="$SA_EMAIL" \
            --set-env-vars="GCP_PROJECT_ID=$GCP_PROJECT_ID,GCP_DATASET_ID=$GCP_DATASET_ID,REGION=$REGION,DBT_TARGET=$DBT_TARGET" \
            --memory="$DBT_MEMORY" \
            --cpu="$DBT_CPU" \
            --max-retries="$DBT_MAX_RETRIES" \
            --task-timeout="$DBT_TIMEOUT" || \
            error "Failed to create Cloud Run job"

        log "Cloud Run job created successfully"
    fi

    # Now that job exists, configure job-level permissions
    configure_job_permissions
}

configure_job_permissions() {
    log "Configuring job-level permissions..."

    # Grant the service account permission to invoke the job
    gcloud run jobs add-iam-policy-binding "$DBT_JOB_NAME" \
        --region="$REGION" \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/run.invoker" || \
        warn "Failed to grant job invocation permissions (may already exist)"

    log "Job-level permissions configured"
}

# =========================== Scheduler Setup ==============================

setup_scheduler() {
    log "Setting up Cloud Scheduler..."

    # Check if scheduler job exists
    if gcloud scheduler jobs describe "$SCHEDULER_JOB_NAME" --location="$REGION" &>/dev/null; then
        log "Updating existing scheduler job..."

        gcloud scheduler jobs update http "$SCHEDULER_JOB_NAME" \
            --schedule="$DBT_SCHEDULE" \
            --uri="https://$REGION-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$GCP_PROJECT_ID/jobs/$DBT_JOB_NAME:run" \
            --http-method="POST" \
            --oauth-service-account-email="$SA_EMAIL" \
            --location="$REGION" || \
            error "Failed to update scheduler job"

        log "Scheduler job updated successfully"
    else
        log "Creating new scheduler job..."

        gcloud scheduler jobs create http "$SCHEDULER_JOB_NAME" \
            --schedule="$DBT_SCHEDULE" \
            --uri="https://$REGION-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/$GCP_PROJECT_ID/jobs/$DBT_JOB_NAME:run" \
            --http-method="POST" \
            --oauth-service-account-email="$SA_EMAIL" \
            --location="$REGION" || \
            error "Failed to create scheduler job"

        log "Scheduler job created successfully"
    fi
}

# =========================== Testing ======================================

test_deployment() {
    log "Testing dbt deployment..."

    # Test manual execution
    log "Running test execution..."

    local execution_name
    execution_name=$(gcloud run jobs execute "$DBT_JOB_NAME" \
        --region="$REGION" \
        --format="value(metadata.name)" \
        --wait) || {
        warn "Test execution failed - checking logs for details"
        show_recent_logs
        return 1
    }

    log "Test execution completed: $execution_name"
    show_recent_logs
}

show_recent_logs() {
    log "Recent execution logs:"
    gcloud logs read "resource.type=cloud_run_job AND resource.labels.job_name=$DBT_JOB_NAME" \
        --limit=50 \
        --format="value(timestamp,severity,textPayload)" || \
        warn "Failed to retrieve logs"
}

# =========================== Success Message ==============================

show_deployment_success() {
    log "dbt deployment completed successfully!"

    echo ""
    echo "🎉 dbt Cloud Run job deployed successfully!"
    echo ""
    echo "📊 Job Details:"
    echo "  Job name: $DBT_JOB_NAME"
    echo "  Region: $REGION"
    echo "  Service account: $SA_EMAIL"
    echo "  Image: $IMAGE_NAME"
    echo ""
    echo "⏰ Scheduler Details:"
    echo "  Schedule: $DBT_SCHEDULE"
    echo "  Job name: $SCHEDULER_JOB_NAME"
    echo ""
    echo "🚀 Manual Commands:"
    echo "  Execute job:"
    echo "    gcloud run jobs execute $DBT_JOB_NAME --region=$REGION"
    echo ""
    echo "  View logs:"
    echo "    gcloud logs read \"resource.type=cloud_run_job AND resource.labels.job_name=$DBT_JOB_NAME\" --limit=50"
    echo ""
    echo "  View executions:"
    echo "    gcloud run jobs executions list --job=$DBT_JOB_NAME --region=$REGION"
    echo ""
    echo "  Monitor scheduler:"
    echo "    gcloud scheduler jobs describe $SCHEDULER_JOB_NAME --location=$REGION"
    echo ""
}

# =========================== Main Execution ===================================

main() {
    log "Starting dbt deployment process..."

    # Create log file
    touch "$LOG_FILE"

    # Validate environment
    validate_env_vars
    check_dependencies
    validate_dockerfile

    # Set up GCP
    check_gcp_auth
    setup_project
    check_billing
    enable_gcp_services

    # Set up resources
    setup_service_account

    # Build and deploy
    build_dbt_image
    deploy_cloud_run_job

    # Setup scheduler if requested
    if [ "${SKIP_SCHEDULER:-false}" != "true" ]; then
        read -p "Create/update Cloud Scheduler job? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log "Skipping scheduler setup"
        else
            setup_scheduler
        fi
    fi

    # Test deployment
    if [ "${SKIP_TEST:-false}" != "true" ]; then
        read -p "Run test execution? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Nn]$ ]]; then
            log "Skipping test execution"
        else
            test_deployment
        fi
    fi

    # Show success message
    show_deployment_success

    log "Deployment process completed successfully!"
    log "Check the full log at: $LOG_FILE"
}

# =========================== Script Entry Point ===============================

# Enable strict error handling
set -euo pipefail

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --help, -h         Show this help message"
            echo "  --verbose, -v      Enable verbose logging"
            echo "  --skip-scheduler   Skip scheduler setup"
            echo "  --skip-test        Skip test execution"
            echo "  --schedule CRON    Set custom schedule (default: '0 6 * * *')"
            echo "  --dry-run          Perform a dry run without making changes"
            exit 0
            ;;
        --verbose|-v)
            set -x
            shift
            ;;
        --skip-scheduler)
            SKIP_SCHEDULER=true
            shift
            ;;
        --skip-test)
            SKIP_TEST=true
            shift
            ;;
        --schedule)
            DBT_SCHEDULE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Run main function
main "$@"
