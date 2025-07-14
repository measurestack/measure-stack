#!/bin/bash

# ============================== Measure.js Deployment Script ================================
# This script provides a convenient way to deploy Measure.js to production
# Usage: ./deploy.sh [options]
# Options:
#   --app-only      Deploy only the main application
#   --dbt-only      Deploy only the dbt data pipeline
#   --full          Deploy both app and dbt (default)
#   --help          Show this help message

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/deploy.log"

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

show_help() {
    echo "Measure.js Deployment Script"
    echo ""
    echo "Usage: ./deploy.sh [options]"
    echo ""
    echo "Options:"
    echo "  --app-only      Deploy only the main application"
    echo "  --dbt-only      Deploy only the dbt data pipeline"
    echo "  --full          Deploy both app and dbt (default)"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./deploy.sh              # Deploy everything"
    echo "  ./deploy.sh --app-only   # Deploy only the app"
    echo "  ./deploy.sh --dbt-only   # Deploy only dbt pipeline"
    echo ""
    echo "Prerequisites:"
    echo "  - Google Cloud CLI (gcloud) installed and authenticated"
    echo "  - Environment variables configured in .env file"
    echo "  - MaxMind GeoIP2 credentials"
}

# =========================== Validation =====================================

check_prerequisites() {
    log "Checking prerequisites..."

    # Check if .env file exists
    if [ ! -f "${SCRIPT_DIR}/.env" ]; then
        error "Environment file (.env) not found. Please copy example.env to .env and configure it."
    fi

    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        error "Google Cloud CLI (gcloud) is not installed. Please install it first."
    fi

    # Check if user is authenticated
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        error "Not authenticated with Google Cloud. Please run 'gcloud auth login' first."
    fi

    # Check if project is set
    if [ -z "$(gcloud config get-value project 2>/dev/null)" ]; then
        error "No Google Cloud project set. Please run 'gcloud config set project YOUR_PROJECT_ID' first."
    fi

    log "Prerequisites check passed"
}

check_environment() {
    log "Validating environment configuration..."

    # Source environment variables
    set -a
    source "${SCRIPT_DIR}/.env"
    set +a

    # Check required environment variables
    local required_vars=(
        "GCP_PROJECT_ID"
        "GCP_DATASET_ID"
        "GCP_TABLE_ID"
        "GEO_ACCOUNT"
        "GEO_KEY"
        "DAILY_SALT"
    )

    local missing_vars=()
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -gt 0 ]; then
        error "Missing required environment variables: ${missing_vars[*]}"
    fi

    log "Environment validation passed"
}

# =========================== Deployment Functions ===========================

deploy_app() {
    log "Deploying main application..."

    if [ ! -f "${SCRIPT_DIR}/infrastructure/scripts/deploy_app.sh" ]; then
        error "Deployment script not found: infrastructure/scripts/deploy_app.sh"
    fi

    if bash "${SCRIPT_DIR}/infrastructure/scripts/deploy_app.sh"; then
        log "Application deployment completed successfully"
    else
        error "Application deployment failed"
    fi
}

deploy_dbt() {
    log "Deploying dbt data pipeline..."

    if [ ! -f "${SCRIPT_DIR}/infrastructure/scripts/deploy_dbt_job.sh" ]; then
        error "dbt deployment script not found: infrastructure/scripts/deploy_dbt_job.sh"
    fi

    if bash "${SCRIPT_DIR}/infrastructure/scripts/deploy_dbt_job.sh"; then
        log "dbt pipeline deployment completed successfully"
    else
        error "dbt pipeline deployment failed"
    fi
}

# =========================== Main Script ===================================

main() {
    # Initialize log file
    echo "=== Measure.js Deployment Log - $(date) ===" > "$LOG_FILE"

    # Parse command line arguments
    local deploy_app_flag=false
    local deploy_dbt_flag=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-only)
                deploy_app_flag=true
                shift
                ;;
            --dbt-only)
                deploy_dbt_flag=true
                shift
                ;;
            --full)
                deploy_app_flag=true
                deploy_dbt_flag=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use --help for usage information."
                ;;
        esac
    done

    # Default to full deployment if no options specified
    if [ "$deploy_app_flag" = false ] && [ "$deploy_dbt_flag" = false ]; then
        deploy_app_flag=true
        deploy_dbt_flag=true
    fi

    # Display deployment plan
    log "Starting Measure.js deployment..."
    if [ "$deploy_app_flag" = true ]; then
        info "Will deploy: Main application"
    fi
    if [ "$deploy_dbt_flag" = true ]; then
        info "Will deploy: dbt data pipeline"
    fi

    # Check prerequisites
    check_prerequisites
    check_environment

    # Perform deployments
    if [ "$deploy_app_flag" = true ]; then
        deploy_app
    fi

    if [ "$deploy_dbt_flag" = true ]; then
        deploy_dbt
    fi

    # Success message
    log "Deployment completed successfully!"
    echo ""
    echo "🎉 Measure.js has been deployed to production!"
    echo ""
    echo "Next steps:"
    echo "1. Integrate the tracking script on your website"
    echo "2. Test the tracking functionality"
    echo "3. Monitor the deployment in Google Cloud Console"
    echo ""
    echo "For more information, see: docs/README.md"
}

# Run main function with all arguments
main "$@"
