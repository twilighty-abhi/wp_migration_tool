#!/bin/bash
# WordPress Migration Orchestrator
# This script orchestrates the complete WordPress migration process:
# 1. Backup source site using migrate.py
# 2. Deploy new WordPress instance using deploy-client.sh
# 3. Import backup with increased upload limits using import.py

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MIGRATE_SCRIPT="migrate.py"
DEPLOY_SCRIPT="./k3s-wp-spawner.sh"
IMPORT_SCRIPT="import.py"
TEMP_DIR="/tmp/wp_migration_$$"
LOG_FILE="migrate.log"

# Default values for optional parameters
DEFAULT_NEW_DOMAIN="wp-migrated-$(date +%s).test.kunj.company"
DEFAULT_CLIENT_NAMESPACE="wp-migration-$(date +%s | tail -c 6)"
DEFAULT_ADMIN_EMAIL="admin@example.com"

# Global variables for parameters
SOURCE_WP_URL=""
SOURCE_USERNAME=""
SOURCE_PASSWORD=""
NEW_DOMAIN=""
CLIENT_NAMESPACE=""
ADMIN_EMAIL=""
INTERACTIVE_MODE=true

# --- UTILITY FUNCTIONS ---

# Function to log messages to file and display on terminal
log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Remove ANSI color codes for log file
    local clean_message=$(echo -e "$message" | sed 's/\x1b\[[0-9;]*m//g')
    
    # Write to log file with timestamp
    echo "[$timestamp] $clean_message" >> "$LOG_FILE"
}

print_header() {
    local message="\n${BLUE}===========================================${NC}\n${BLUE}$1${NC}\n${BLUE}===========================================${NC}\n"
    echo -e "$message"
    log_message "=========================================="
    log_message "$1"
    log_message "=========================================="
}

print_success() {
    local message="${GREEN}✅ $1${NC}"
    echo -e "$message"
    log_message "SUCCESS: $1"
}

print_error() {
    local message="${RED}❌ $1${NC}"
    echo -e "$message"
    log_message "ERROR: $1"
}

print_warning() {
    local message="${YELLOW}⚠️  $1${NC}"
    echo -e "$message"
    log_message "WARNING: $1"
}

print_info() {
    local message="${BLUE}ℹ️  $1${NC}"
    echo -e "$message"
    log_message "INFO: $1"
}

# Function to show usage
show_usage() {
    local usage_text="Usage: $0 [OPTIONS]

OPTIONS:
  -u, --url <URL>           Source WordPress URL (required for non-interactive mode)
  -n, --username <USER>     Source WordPress admin username (required for non-interactive mode)
  -p, --password <PASS>     Source WordPress admin password (required for non-interactive mode)
  -d, --domain <DOMAIN>     New domain for migrated site (optional, defaults to auto-generated)
  -s, --namespace <NS>      Kubernetes namespace (optional, defaults to auto-generated)
  -e, --email <EMAIL>       Admin email (optional, defaults to admin@example.com)
  -h, --help               Show this help message

EXAMPLES:
  Interactive mode:
    $0

  Non-interactive mode with required parameters:
    $0 -u https://old-site.com -n admin -p password123

  Non-interactive mode with all parameters:
    $0 -u https://old-site.com -n admin -p password123 -d new-site.com -s wp-client -e admin@newsite.com

All migration activities are logged to: $LOG_FILE"
    
    echo "$usage_text"
    log_message "Help requested - showing usage information"
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--url)
                SOURCE_WP_URL="$2"
                shift 2
                ;;
            -n|--username)
                SOURCE_USERNAME="$2"
                shift 2
                ;;
            -p|--password)
                SOURCE_PASSWORD="$2"
                shift 2
                ;;
            -d|--domain)
                NEW_DOMAIN="$2"
                shift 2
                ;;
            -s|--namespace)
                CLIENT_NAMESPACE="$2"
                shift 2
                ;;
            -e|--email)
                ADMIN_EMAIL="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Check if we have the minimum required parameters for non-interactive mode
    if [[ -n "$SOURCE_WP_URL" || -n "$SOURCE_USERNAME" || -n "$SOURCE_PASSWORD" ]]; then
        # If any parameter is provided, all required ones must be provided
        if [[ -z "$SOURCE_WP_URL" || -z "$SOURCE_USERNAME" || -z "$SOURCE_PASSWORD" ]]; then
            print_error "When using non-interactive mode, you must provide all required parameters:"
            print_error "  --url, --username, and --password are all required"
            show_usage
            exit 1
        fi
        INTERACTIVE_MODE=false
        
        # Set defaults for optional parameters if not provided
        [[ -z "$NEW_DOMAIN" ]] && NEW_DOMAIN="$DEFAULT_NEW_DOMAIN"
        [[ -z "$CLIENT_NAMESPACE" ]] && CLIENT_NAMESPACE="$DEFAULT_CLIENT_NAMESPACE"
        [[ -z "$ADMIN_EMAIL" ]] && ADMIN_EMAIL="$DEFAULT_ADMIN_EMAIL"
        
        print_info "Running in non-interactive mode with provided parameters"
        log_message "Non-interactive mode parameters: URL=$SOURCE_WP_URL, Domain=$NEW_DOMAIN, Namespace=$CLIENT_NAMESPACE"
    else
        print_info "Running in interactive mode"
        log_message "Interactive mode - will prompt for parameters"
    fi
}

# Function to get required input (modified for interactive mode)
get_input() {
    local prompt_text="$1"
    local var_name="$2"
    local is_password="$3"
    local default_value="$4"
    local input
    
    # If we already have a value from command line arguments, use it
    local current_value
    eval "current_value=\$$var_name"
    if [[ -n "$current_value" ]]; then
        return 0
    fi
    
    while true; do
        if [[ -n "$default_value" ]]; then
            if [ "$is_password" = "true" ]; then
                read -s -p "$prompt_text [$default_value]: " input
                echo
            else
                read -p "$prompt_text [$default_value]: " input
            fi
            # Use default if input is empty
            [[ -z "$input" ]] && input="$default_value"
        else
            if [ "$is_password" = "true" ]; then
                read -s -p "$prompt_text" input
                echo
            else
                read -p "$prompt_text" input
            fi
        fi
        
        if [ -z "$input" ] && [ -z "$default_value" ]; then
            print_error "Input cannot be empty. Please try again."
        else
            eval "$var_name=\"$input\""
            break
        fi
    done
}

# Function to validate required files
validate_files() {
    local missing_files=()
    
    log_message "Validating required files..."
    [ ! -f "$MIGRATE_SCRIPT" ] && missing_files+=("$MIGRATE_SCRIPT")
    [ ! -f "$DEPLOY_SCRIPT" ] && missing_files+=("$DEPLOY_SCRIPT")
    [ ! -f "$IMPORT_SCRIPT" ] && missing_files+=("$IMPORT_SCRIPT")
    
    if [ ${#missing_files[@]} -ne 0 ]; then
        print_error "Missing required files:"
        printf ' - %s\n' "${missing_files[@]}"
        log_message "Missing required files: ${missing_files[*]}"
        exit 1
    fi
    
    log_message "All required files found: $MIGRATE_SCRIPT, $DEPLOY_SCRIPT, $IMPORT_SCRIPT"
}

# Function to update Python script configuration
update_migrate_config() {
    local wp_url="$1"
    local username="$2"
    local password="$3"
    
    # Create temporary migrate.py with updated configuration
    sed \
        -e "s|^WP_URL = \".*\"|WP_URL = \"$wp_url\"|" \
        -e "s|^USERNAME = \".*\"|USERNAME = \"$username\"|" \
        -e "s|^PASSWORD = \".*\"|PASSWORD = \"$password\"|" \
        "$MIGRATE_SCRIPT" > "${TEMP_DIR}/migrate_configured.py"
}

update_import_config() {
    local source_wp_url="$1"
    local target_wp_url="$2"
    local target_username="$3"
    local target_password="$4"
    local source_username="$5"
    local source_password="$6"
    
    # Create temporary import.py with updated configuration
    sed \
        -e "s|^SOURCE_WP_URL = \".*\"|SOURCE_WP_URL = \"$source_wp_url\"|" \
        -e "s|^TARGET_WP_URL = \".*\"|TARGET_WP_URL = \"$target_wp_url\"|" \
        -e "s|^TARGET_USERNAME = \".*\"|TARGET_USERNAME = \"$target_username\"|" \
        -e "s|^TARGET_PASSWORD = \".*\"|TARGET_PASSWORD = \"$target_password\"|" \
        -e "s|^SOURCE_USERNAME = \".*\"|SOURCE_USERNAME = \"$source_username\"|" \
        -e "s|^SOURCE_PASSWORD = \".*\"|SOURCE_PASSWORD = \"$source_password\"|" \
        "$IMPORT_SCRIPT" > "${TEMP_DIR}/import_configured.py"
}

# Function to increase WordPress upload limits
increase_upload_limits() {
    local namespace="$1"
    local pod_name
    
    print_info "Increasing WordPress upload limits..."
    
    # Get WordPress pod name
    pod_name=$(sudo kubectl get pods -n "$namespace" -l app=wordpress -o jsonpath='{.items[0].metadata.name}' 2>&1 | tee -a "$LOG_FILE" | tail -n 1 || echo "")
    
    if [ -z "$pod_name" ]; then
        print_error "Could not find WordPress pod in namespace $namespace"
        return 1
    fi
    
    # Create .htaccess content for increased limits
    cat << 'EOF' > "${TEMP_DIR}/htaccess_high_limits"
# Temporary high upload limits for migration
php_value upload_max_filesize 512M
php_value post_max_size 512M
php_value memory_limit 512M
php_value max_execution_time 300
php_value max_input_time 300
EOF

    # Backup original .htaccess if it exists and copy new one
    sudo kubectl exec -n "$namespace" "$pod_name" -- sh -c 'cp /var/www/html/.htaccess /var/www/html/.htaccess.backup 2>/dev/null || true' 2>&1 | tee -a "$LOG_FILE"
    sudo kubectl cp "${TEMP_DIR}/htaccess_high_limits" "$namespace/$pod_name:/var/www/html/.htaccess" 2>&1 | tee -a "$LOG_FILE"
    
    print_success "Upload limits increased to 512M"
}

# Function to restore original upload limits
restore_upload_limits() {
    local namespace="$1"
    local pod_name
    
    print_info "Restoring original upload limits..."
    
    # Get WordPress pod name
    pod_name=$(sudo kubectl get pods -n "$namespace" -l app=wordpress -o jsonpath='{.items[0].metadata.name}' 2>&1 | tee -a "$LOG_FILE" | tail -n 1 || echo "")
    
    if [ -z "$pod_name" ]; then
        print_warning "Could not find WordPress pod in namespace $namespace"
        return 1
    fi
    
    # Restore backup or create default .htaccess
    sudo kubectl exec -n "$namespace" "$pod_name" -- sh -c '
        if [ -f /var/www/html/.htaccess.backup ]; then
            mv /var/www/html/.htaccess.backup /var/www/html/.htaccess
        else
            cat > /var/www/html/.htaccess << "EOF"
# Default WordPress .htaccess
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]

# Standard upload limits
php_value upload_max_filesize 2M
php_value post_max_size 2M
php_value memory_limit 64M
php_value max_execution_time 30
EOF
        fi
    ' 2>&1 | tee -a "$LOG_FILE"
    
    print_success "Upload limits restored to default (2M)"
}

# Function to wait for WordPress to be ready
wait_for_wordpress() {
    local target_url="$1"
    local max_attempts=30
    local attempt=1
    
    print_info "Waiting for WordPress to be ready at $target_url..."
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s -f "$target_url/wp-admin/" > /dev/null 2>&1; then
            print_success "WordPress is ready!"
            return 0
        fi
        
        print_info "Attempt $attempt/$max_attempts - WordPress not ready yet, waiting 10 seconds..."
        log_message "WordPress readiness check attempt $attempt/$max_attempts failed"
        sleep 10
        attempt=$((attempt + 1))
    done
    
    print_error "WordPress did not become ready within expected time"
    return 1
}

# Cleanup function
cleanup() {
    print_info "Cleaning up temporary files..."
    log_message "Cleaning up temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR" 2>/dev/null || true
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# --- MAIN WORKFLOW ---

main() {
    # Initialize log file
    echo "========================================" > "$LOG_FILE"
    echo "WordPress Migration Orchestrator Log" >> "$LOG_FILE"
    echo "Started at: $(date)" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    
    print_header "WordPress Migration Orchestrator"
    print_info "Migration log is being written to: $LOG_FILE"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    log_message "Created temporary directory: $TEMP_DIR"
    
    # Validate required files
    validate_files
    
    print_info "This script will:"
    print_info "1. Backup your source WordPress site"
    print_info "2. Deploy a new WordPress instance on Kubernetes"
    print_info "3. Import the backup to the new instance"
    echo
    
    # --- COLLECT ALL INFORMATION FIRST ---
    print_header "MIGRATION CONFIGURATION"
    
    if [[ "$INTERACTIVE_MODE" == true ]]; then
        print_info "Source Site Information:"
        get_input "Enter source WordPress URL (e.g., https://old-site.com): " SOURCE_WP_URL
        get_input "Enter source WordPress admin username: " SOURCE_USERNAME
        get_input "Enter source WordPress admin password: " SOURCE_PASSWORD true
        
        echo
        print_info "Target Site Information (optional - defaults will be used if empty):"
        get_input "Enter new domain for migrated site: " NEW_DOMAIN "" false "$DEFAULT_NEW_DOMAIN"
        get_input "Enter Kubernetes namespace for new site: " CLIENT_NAMESPACE "" false "$DEFAULT_CLIENT_NAMESPACE"
        get_input "Enter WordPress admin email: " ADMIN_EMAIL "" false "$DEFAULT_ADMIN_EMAIL"
    else
        print_info "Using provided parameters:"
        print_info "Source URL: $SOURCE_WP_URL"
        print_info "Source Username: $SOURCE_USERNAME"
        print_info "Source Password: [hidden]"
        print_info "New Domain: $NEW_DOMAIN"
        print_info "Namespace: $CLIENT_NAMESPACE"
        print_info "Admin Email: $ADMIN_EMAIL"
        
        # Log configuration (without password)
        log_message "Configuration - Source URL: $SOURCE_WP_URL"
        log_message "Configuration - Source Username: $SOURCE_USERNAME"
        log_message "Configuration - New Domain: $NEW_DOMAIN"
        log_message "Configuration - Namespace: $CLIENT_NAMESPACE"
        log_message "Configuration - Admin Email: $ADMIN_EMAIL"
    fi
    
    # Construct target URL from domain (assuming HTTP)
    TARGET_WP_URL="http://$NEW_DOMAIN"
    
    # For k3s deployment, we'll get the generated credentials
    print_info "New WordPress will be deployed with auto-generated credentials..."
    
    # --- PHASE 1: SOURCE SITE BACKUP ---
    print_header "PHASE 1: SOURCE SITE BACKUP"
    
    print_info "Updating migrate.py configuration..."
    update_migrate_config "$SOURCE_WP_URL" "$SOURCE_USERNAME" "$SOURCE_PASSWORD"
    
    print_info "Starting backup process..."
    if python3 "${TEMP_DIR}/migrate_configured.py" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Backup completed successfully!"
    else
        print_error "Backup failed. Please check the logs above."
        exit 1
    fi
    
    # --- PHASE 2: DEPLOY NEW WORDPRESS INSTANCE ---
    print_header "PHASE 2: DEPLOY NEW WORDPRESS INSTANCE"
    
    print_info "Deploying new WordPress instance with domain: $NEW_DOMAIN and namespace: $CLIENT_NAMESPACE"
    
    # Run the k3s deployment script with our parameters
    if "$DEPLOY_SCRIPT" "$NEW_DOMAIN" "$CLIENT_NAMESPACE" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "WordPress deployment completed successfully!"
    else
        print_error "WordPress deployment failed. Please check the logs above."
        exit 1
    fi
    
    # --- PHASE 3: SETUP WORDPRESS ADMIN ---
    print_header "PHASE 3: SETTING UP WORDPRESS ADMIN"
    
    # Get generated admin password from credentials file
    CREDENTIALS_FILE="/home/ubuntu/k3s-wordpress-${NEW_DOMAIN//\./-}/credentials.txt"
    if [ -f "$CREDENTIALS_FILE" ]; then
        GENERATED_PASSWORD=$(grep "WordPress Admin Password:" "$CREDENTIALS_FILE" | cut -d: -f2 | xargs)
        print_info "Found generated password in credentials file"
    else
        print_warning "Could not find credentials file, generating new password"
        GENERATED_PASSWORD=$(openssl rand -base64 16 | tr -d "=+/" | cut -c1-16)
    fi
    
    # Setup WordPress admin using the setup script
    print_info "Configuring WordPress admin user..."
    if /home/ubuntu/wp_migration_tool/setup-wordpress-admin.sh -n "$CLIENT_NAMESPACE" -d "$NEW_DOMAIN" -p "$GENERATED_PASSWORD" -e "$ADMIN_EMAIL" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "WordPress admin setup completed successfully!"
        TARGET_USERNAME="admin"
        TARGET_PASSWORD="$GENERATED_PASSWORD"
    else
        print_error "WordPress admin setup failed. Continuing with manual credentials..."
        TARGET_USERNAME="admin"
        TARGET_PASSWORD="$GENERATED_PASSWORD"
    fi
    
    # --- PHASE 4: EXTRACTING DEPLOYMENT CREDENTIALS ---
    print_header "PHASE 4: EXTRACTING DEPLOYMENT CREDENTIALS"
    
    # Get credentials from the generated file
    CREDENTIALS_FILE="/home/ubuntu/k3s-wordpress-${NEW_DOMAIN//\./-}/credentials.txt"
    if [ -f "$CREDENTIALS_FILE" ]; then
        TARGET_USERNAME="admin"  # WordPress default for fresh install
        TARGET_PASSWORD=$(grep "WordPress Admin Password:" "$CREDENTIALS_FILE" | cut -d: -f2 | xargs)
        print_success "Found generated credentials"
        print_info "Target Username: $TARGET_USERNAME"
        print_info "Target Password: $TARGET_PASSWORD"
    else
        print_warning "Could not find credentials file, using defaults"
        TARGET_USERNAME="admin"
        TARGET_PASSWORD="admin"
    fi
    
    # Wait for WordPress to be ready (check locally since we need host header)
    print_info "Waiting for WordPress to be accessible..."
    sleep 30  # Give deployment time to stabilize
    
    # --- PHASE 5: INCREASE UPLOAD LIMITS ---
    print_header "PHASE 5: PREPARING FOR IMPORT"
    
    increase_upload_limits "$CLIENT_NAMESPACE"
    
    # --- PHASE 6: IMPORT BACKUP ---
    print_header "PHASE 6: IMPORTING BACKUP"
    
    print_info "Updating import.py configuration..."
    update_import_config "$SOURCE_WP_URL" "$TARGET_WP_URL" "$TARGET_USERNAME" "$TARGET_PASSWORD" "$SOURCE_USERNAME" "$SOURCE_PASSWORD"
    
    print_info "Starting import process..."
    if python3 "${TEMP_DIR}/import_configured.py" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Import completed successfully!"
    else
        print_error "Import failed. Please check the logs above."
        # Still try to restore limits even if import failed
        restore_upload_limits "$CLIENT_NAMESPACE"
        exit 1
    fi
    
    # --- PHASE 7: RESTORE UPLOAD LIMITS ---
    print_header "PHASE 7: FINALIZING"
    
    restore_upload_limits "$CLIENT_NAMESPACE"
    
    # --- COMPLETION ---
    print_header "MIGRATION COMPLETE!"
    
    print_success "WordPress migration completed successfully!"
    print_info "Source site: $SOURCE_WP_URL"
    print_info "Target site: $TARGET_WP_URL"
    print_info "Kubernetes namespace: $CLIENT_NAMESPACE"
    print_info "You can now access your migrated site at: $TARGET_WP_URL"
    print_info "Login with your original source site credentials:"
    print_info "  Username: $SOURCE_USERNAME"
    print_info "  Password: [your source site password]"
    
    echo -e "\n${GREEN}🎉 Migration orchestration completed successfully!${NC}\n"
    
    # Final log entry
    log_message "========================================="
    log_message "Migration completed successfully at: $(date)"
    log_message "Total migration time: $SECONDS seconds"
    log_message "Log file location: $(pwd)/$LOG_FILE"
    log_message "========================================="
    
    print_info "Complete migration log saved to: $(pwd)/$LOG_FILE"
}

# Check if running as source or direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi