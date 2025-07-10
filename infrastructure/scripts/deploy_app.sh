# ============================== Configuration ================================

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/deploy.log"
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
    "REGION"
    "GCP_DATASET_ID"
    "GCP_TABLE_ID"
    "SERVICE_NAME"
    "CLIENT_ID_COOKIE_NAME"
    "HASH_COOKIE_NAME"
    "COOKIE_DOMAIN"
    "DAILY_SALT"
    "GEO_ACCOUNT"
    "GEO_KEY"
    "CORS_ORIGIN"
)

# Set default values for optional variables
RATE_LIMIT_WINDOW_MS=${RATE_LIMIT_WINDOW_MS:-60000}
RATE_LIMIT_MAX_REQUESTS=${RATE_LIMIT_MAX_REQUESTS:-100}
RATE_LIMIT_SKIP_SUCCESS=${RATE_LIMIT_SKIP_SUCCESS:-false}
RATE_LIMIT_SKIP_FAILED=${RATE_LIMIT_SKIP_FAILED:-false}
MEMORY=${MEMORY:-512Mi}
CPU=${CPU:-1}
MAX_INSTANCES=${MAX_INSTANCES:-10}
MIN_INSTANCES=${MIN_INSTANCES:-0}
TIMEOUT=${TIMEOUT:-300}

# Validate required environment variables
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

# =========================== Dependency Checks ===============================

check_dependencies() {
    log "Checking dependencies..."

    local deps=("gcloud" "bq" "jq" "docker")
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
        "firestore.googleapis.com"
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

    #TODO: Check if billing setup is ACTUALLY REQUIRED
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

# =========================== BigQuery Setup ===================================

setup_bigquery() {
    log "Setting up BigQuery resources..."

    # Create dataset if it doesn't exist
    if bq ls --format=sparse "$GCP_PROJECT_ID:$GCP_DATASET_ID" &>/dev/null; then
        log "Dataset '$GCP_DATASET_ID' exists"
    else
        read -p "Create dataset '$GCP_DATASET_ID'? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bq mk --dataset --location "$REGION" "$GCP_PROJECT_ID:$GCP_DATASET_ID" || \
                error "Failed to create dataset"
            log "Created dataset: $GCP_DATASET_ID"
        else
            error "Dataset creation declined"
        fi
    fi

    # Create table if it doesn't exist
    if bq show --format=prettyjson "$GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID" &>/dev/null; then
        log "Table '$GCP_TABLE_ID' exists"
    else
        local schema_file="infrastructure/schemas/bq_table_schema.json"
        if [ ! -f "$schema_file" ]; then
            error "Schema file not found: $schema_file"
        fi

        read -p "Create table '$GCP_TABLE_ID'? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bq mk --table --location "$REGION" \
                "$GCP_PROJECT_ID:$GCP_DATASET_ID.$GCP_TABLE_ID" \
                "$schema_file" || error "Failed to create table"
            log "Created table: $GCP_TABLE_ID"
        else
            error "Table creation declined"
        fi
    fi
}

# =========================== Service Account Setup ============================

setup_service_account() {
    log "Setting up service account..."

    local sa_name="$SERVICE_NAME"
    local sa_email="$sa_name@$GCP_PROJECT_ID.iam.gserviceaccount.com"

    # Create service account if it doesn't exist
    if gcloud iam service-accounts describe "$sa_email" &>/dev/null; then
        log "Service account '$sa_email' exists"
    else
        gcloud iam service-accounts create "$sa_name" \
            --display-name="Measure-JS SA for $SERVICE_NAME" || \
            error "Failed to create service account"
        log "Created service account: $sa_email"
    fi

    # Set BigQuery dataset access
    log "Configuring BigQuery access..."

    # Get current dataset access
    bq show --format=prettyjson "$GCP_PROJECT_ID:$GCP_DATASET_ID" > "$TEMP_DIR/dataset_temp.json"

    # Check if access already exists
    if jq -e --arg SA_EMAIL "$sa_email" '.access[]? | select(.userByEmail == $SA_EMAIL)' "$TEMP_DIR/dataset_temp.json" >/dev/null; then
        log "BigQuery access already configured for service account"
    else
        # Add service account access
        jq --arg SA_EMAIL "$sa_email" \
            '.access = (.access // []) + [{"userByEmail": $SA_EMAIL, "role": "WRITER"}]' \
            "$TEMP_DIR/dataset_temp.json" > "$TEMP_DIR/dataset_access.json"

        bq update --source "$TEMP_DIR/dataset_access.json" "$GCP_PROJECT_ID:$GCP_DATASET_ID" || \
            error "Failed to configure BigQuery access"

        log "Configured BigQuery access for service account"
    fi

    # Set Firestore access
    log "Configuring Firestore access..."

    # Check if binding already exists
    if gcloud projects get-iam-policy "$GCP_PROJECT_ID" \
        --flatten="bindings[].members" \
        --filter="bindings.members:serviceAccount:$sa_email AND bindings.role:roles/datastore.user" \
        --format="value(bindings.role)" | grep -q "roles/datastore.user"; then
        log "Firestore access already configured"
    else
        gcloud projects add-iam-policy-binding "$GCP_PROJECT_ID" \
            --member="serviceAccount:$sa_email" \
            --role="roles/datastore.user" \
            --condition="expression=resource.name.startsWith('projects/$GCP_PROJECT_ID/databases/default'),title=FirestoreDatabaseAccess" || \
            error "Failed to configure Firestore access"

        log "Configured Firestore access for service account"
    fi

    export SA_EMAIL="$sa_email"
}

# =========================== Build and Deploy =================================

build_and_deploy() {
    log "Building and deploying application..."

    local image_name="gcr.io/$GCP_PROJECT_ID/$SERVICE_NAME"

    # Build the image
    log "Building Docker image..."
    gcloud builds submit --tag "$image_name" . || error "Failed to build image"

    # Deploy to Cloud Run
    log "Deploying to Cloud Run..."

    # Construct environment variables
    local env_vars="GCP_PROJECT_ID=$GCP_PROJECT_ID"
    env_vars+="--GCP_DATASET_ID=$GCP_DATASET_ID"
    env_vars+="--GCP_TABLE_ID=$GCP_TABLE_ID"
    env_vars+="--CLIENT_ID_COOKIE_NAME=$CLIENT_ID_COOKIE_NAME"
    env_vars+="--HASH_COOKIE_NAME=$HASH_COOKIE_NAME"
    env_vars+="--DAILY_SALT=$DAILY_SALT"
    env_vars+="--GEO_ACCOUNT=$GEO_ACCOUNT"
    env_vars+="--GEO_KEY=$GEO_KEY"
    env_vars+="--CORS_ORIGIN=$CORS_ORIGIN"
    env_vars+="--RATE_LIMIT_WINDOW_MS=$RATE_LIMIT_WINDOW_MS"
    env_vars+="--RATE_LIMIT_MAX_REQUESTS=$RATE_LIMIT_MAX_REQUESTS"
    env_vars+="--RATE_LIMIT_SKIP_SUCCESS=$RATE_LIMIT_SKIP_SUCCESS"
    env_vars+="--RATE_LIMIT_SKIP_FAILED=$RATE_LIMIT_SKIP_FAILED"

    gcloud run deploy "$SERVICE_NAME" \
        --image="$image_name" \
        --region="$REGION" \
        --allow-unauthenticated \
        --port=3000 \
        --service-account="$SA_EMAIL" \
        --set-env-vars="^--^$env_vars" \
        --memory="$MEMORY" \
        --cpu="$CPU" \
        --max-instances="$MAX_INSTANCES" \
        --min-instances="$MIN_INSTANCES" \
        --timeout="$TIMEOUT" \
        --execution-environment=gen2 || error "Failed to deploy to Cloud Run"

    local service_url
    service_url=$(gcloud run services describe "$SERVICE_NAME" \
        --region "$REGION" \
        --format='value(status.url)')

    log "Deployment completed successfully!"
    log "Service URL: $service_url"

    # Generate SDK with actual endpoint
    generate_sdk "$service_url"
}

# =========================== SDK Generation ===================================

generate_sdk() {
    local service_url="$1"
    local sdk_template="${PROJECT_ROOT}/static/measure.js.template"
    local sdk_output="${PROJECT_ROOT}/static/measure.js"

    log "Generating SDK with endpoint: $service_url"

    if [ ! -f "$sdk_template" ]; then
        error "SDK template not found at: $sdk_template"
    fi

    # Replace template placeholder with actual endpoint
    sed "s|{{ endpoint }}|$service_url|g" "$sdk_template" > "$sdk_output"

    log "SDK generated at: $sdk_output"
    log "Users can now include this SDK in their websites"

    # Optionally, serve the SDK from your Cloud Run service
    if [ -d "${PROJECT_ROOT}/public" ]; then
        cp "$sdk_output" "${PROJECT_ROOT}/public/measure.js"
        log "SDK also copied to public directory for serving at: $service_url/measure.js"
    fi
}


# =========================== Health Check =====================================

health_check() {
    log "Performing health check..."

    local service_url
    service_url=$(gcloud run services describe "$SERVICE_NAME" \
        --region "$REGION" \
        --format='value(status.url)')

    if [ -z "$service_url" ]; then
        error "Could not retrieve service URL"
    fi

    # Wait for service to be ready
    local max_attempts=30
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        if curl -f -s "${service_url}/health" >/dev/null 2>&1; then
            log "Health check passed"
            return 0
        fi

        info "Health check attempt $attempt/$max_attempts failed, retrying in 10 seconds..."
        sleep 10
        ((attempt++))
    done

    warn "Health check failed after $max_attempts attempts"
    warn "Service may still be starting up. Check manually: $service_url"
}


# =========================== Success Message ==================================

show_deployment_success() {
    local service_url="$1"

    log "Deployment completed successfully!"
    log "Service URL: $service_url"

    # Show user-friendly implementation instructions
    log ""
    log "🎉 Deployment successful! Here's how to use the tracking SDK:"
    log ""
    log "📋 Copy this code into your website:"
    log "----------------------------------------"
    log "<script src=\"$service_url/measure.js\"></script>"
    log "<script>"
    log "  _measure.pageview();"
    log "  _measure.event('button_click', { button_id: 'signup' });"
    log "</script>"
    log "----------------------------------------"
    log ""
    log "📊 Available tracking methods:"
    log "  • _measure.pageview() - Track page views"
    log "  • _measure.event('event_name', { data: 'value' }) - Track custom events"
    log "  • _measure.consent({ id: true }) - Handle user consent"
    log ""
    log "🔗 SDK URL: $service_url/measure.js"
    log "📈 Events endpoint: $service_url/events"
    log ""
}



# =========================== Main Execution ===================================

main() {
    log "Starting deployment process..."

    # Create log file
    touch "$LOG_FILE"

    # Validate environment
    validate_env_vars
    check_dependencies

    # Set up GCP
    check_gcp_auth
    setup_project
    check_billing
    enable_gcp_services

    # Set up resources
    setup_bigquery
    setup_service_account

    # Deploy
    build_and_deploy

    # Verify deployment
    health_check

    # Get service URL for success message
    local service_url
    service_url=$(gcloud run services describe "$SERVICE_NAME" \
        --region "$REGION" \
        --format='value(status.url)')

    show_deployment_success "$service_url"

    log "Deployment process completed successfully!"
    log "Check the full log at: $LOG_FILE"

    # Ask if user wants to deploy dbt job
    echo ""
    read -p "Deploy dbt as a Cloud Run job for scheduled data processing? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Deploying dbt Cloud Run job..."
        bash infrastructure/scripts/deploy_dbt_job.sh
    fi
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
            echo "  --help, -h     Show this help message"
            echo "  --verbose, -v  Enable verbose logging"
            echo "  --dry-run      Perform a dry run without making changes"
            exit 0
            ;;
        --verbose|-v)
            set -x
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            error "Unknown option: $1"
    esac
done

# Run main function
main "$@"
