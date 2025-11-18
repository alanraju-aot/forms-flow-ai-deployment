#!/bin/bash

echo "*******************************************"
echo "*     formsflow.ai Installation Script    *"
echo "*******************************************"
echo ""

# Detect Docker Compose
COMPOSE_COMMAND=""
if docker compose version &>/dev/null; then
    COMPOSE_COMMAND="docker compose"
elif docker-compose version &>/dev/null; then
    COMPOSE_COMMAND="docker-compose"
else
    echo "ERROR: Neither docker compose nor docker-compose is installed."
    echo "Please install Docker Desktop or Docker Engine with Compose."
    exit 1
fi
echo "Using $COMPOSE_COMMAND"

# Get Docker version
docker_info=$(docker -v 2>&1)
docker_version=$(echo "$docker_info" | awk '{print $3}' | tr -d ',')
echo "Docker version: $docker_version"

# --- Docker Version Validation ---
url="https://forms-flow-docker-versions.s3.ca-central-1.amazonaws.com/docker_versions.html"
versionsFile="tested_versions.tmp"
echo "Fetching tested Docker versions from $url..."
if command -v curl &>/dev/null; then
    curl -L -s "$url" -o "$versionsFile" 2>/dev/null
    
    if [ -f "$versionsFile" ] && [ -s "$versionsFile" ]; then
        echo "Checking if your Docker version is tested..."
        if grep -q "$docker_version" "$versionsFile"; then
            echo "Your Docker version $docker_version is in the tested list."
            rm -f "$versionsFile"
        else
            echo "WARNING: Your Docker version $docker_version is not in the tested list!"
            read -p "Do you want to continue anyway? [y/n] " continue
            if [[ ! "$continue" =~ ^[Yy]$ ]]; then
                echo "Installation cancelled."
                rm -f "$versionsFile"
                exit 1
            fi
            rm -f "$versionsFile"
            echo "Continuing with untested Docker version..."
        fi
    else
        echo "Failed to fetch tested versions. Skipping validation."
        rm -f "$versionsFile"
    fi
else
    echo "curl not found, skipping version validation."
fi
echo ""

# --- Detect IP address automatically ---
echo "Finding your IP address..."
ip_add=""

# Try different methods to get IP
if command -v ip &>/dev/null; then
    ip_add=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
elif command -v ifconfig &>/dev/null; then
    ip_add=$(ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1' | head -n1)
elif command -v hostname &>/dev/null; then
    ip_add=$(hostname -I 2>/dev/null | awk '{print $1}')
fi

if [ -z "$ip_add" ]; then
    echo "WARNING: Could not automatically detect your IP address."
    read -p "Please enter your IP address manually: " ip_add
else
    echo "Detected IP address: $ip_add"
    read -p "Is this correct? [y/n] " confirmIP
    if [[ ! "$confirmIP" =~ ^[Yy]$ ]]; then
        read -p "Please enter your correct IP address: " ip_add
    fi
fi
echo "IP address set to: $ip_add"
echo ""

# --- Detect architecture ---
echo "Detecting system architecture..."
machine_arch=$(uname -m)
if [[ "$machine_arch" == "aarch64" || "$machine_arch" == "arm64" ]]; then
    ARCH="arm64"
else
    ARCH="amd64"
fi
echo "Detected architecture: $ARCH"
echo ""

# --- Check Docker OSType ---
DOCKER_OSTYPE=$(docker info 2>/dev/null | grep "OSType" | awk '{print $2}')
if [ -n "$DOCKER_OSTYPE" ]; then
    DOCKER_OSTYPE=$(echo "$DOCKER_OSTYPE" | tr -d ' ')
fi

if [[ "$DOCKER_OSTYPE" == "windows" ]]; then
    echo "ERROR: Docker is using Windows containers."
    echo "Please switch Docker Desktop to 'Use Linux containers' and re-run."
    exit 1
fi

if [ "$ARCH" == "amd64" ]; then
    PLATFORM="linux/amd64"
else
    PLATFORM="linux/arm64/v8"
fi
echo "Using PLATFORM: $PLATFORM"
echo ""

# --- Select edition ---
echo "Select installation type:"
echo "  1. Open Source (Community Edition)"
echo "  2. Premium (Enterprise Edition)"
read -p "Enter your choice [1-2]: " editionChoice

if [ "$editionChoice" == "2" ]; then
    EDITION="ee"
    echo ""
    echo "============================================"
    echo "Selected: Premium (Enterprise Edition)"
    echo "============================================"
    echo ""
else
    EDITION="ce"
    echo ""
    echo "============================================"
    echo "Selected: Open Source (Community Edition)"
    echo "============================================"
    echo ""
fi

# --- Locate docker-compose files ---
echo "Locating docker-compose files..."
COMPOSE_FILE=""
ANALYTICS_COMPOSE_FILE=""

if [ -f "../docker-compose/docker-compose.yml" ]; then
    COMPOSE_FILE="../docker-compose/docker-compose.yml"
    DOCKER_COMPOSE_DIR="../docker-compose"
    echo "Found docker-compose.yml."
fi

if [ -f "$DOCKER_COMPOSE_DIR/analytics-docker-compose.yml" ]; then
    ANALYTICS_COMPOSE_FILE="$DOCKER_COMPOSE_DIR/analytics-docker-compose.yml"
    echo "Found analytics-docker-compose.yml."
fi

echo "Using compose file: $COMPOSE_FILE"
echo ""

if [ -z "$COMPOSE_FILE" ]; then
    echo "ERROR: Could not find docker-compose file. Expected '../docker-compose/docker-compose.yml'."
    echo "Please ensure you are running this installer from the repository root or that the docker-compose files exist."
    exit 1
fi

# --- Analytics & Data Analysis selections ---
read -p "Do you want to include analytics in the installation? [y/n] " includeAnalytics
if [[ "$includeAnalytics" =~ ^[Yy]$ ]]; then
    analytics=1
    echo "Analytics will be included."
else
    analytics=0
    echo "Analytics will not be included."
fi
echo ""

echo "Sentiment Analysis enables assessment of sentiments within forms by"
echo "considering specific topics specified during form creation."
echo "The data analysis API provides interfaces for sentiment analysis."
echo ""
read -p "Do you want to include forms-flow-data-analysis-api? [y/n] " includeDataAnalysis
if [[ "$includeDataAnalysis" =~ ^[Yy]$ ]]; then
    dataanalysis=1
    echo "Data Analysis API will be included."
else
    dataanalysis=0
    echo "Data Analysis API will not be included."
fi
echo ""

# If analytics requested but analytics compose file is missing, warn and skip analytics
if [ "$analytics" == "1" ]; then
    if [ -z "$ANALYTICS_COMPOSE_FILE" ]; then
        echo "WARNING: analytics compose file not found; skipping analytics setup."
        analytics=0
    fi
fi

echo ""
echo "============================================"
echo "Installation summary:"
echo "============================================"
echo "- IP Address: $ip_add"
echo "- Edition: $EDITION"
echo "- Architecture: $ARCH"
echo "- PLATFORM: $PLATFORM"
echo "- Analytics: $analytics"
echo "- Data Analysis: $dataanalysis"
echo "============================================"
echo ""
read -p "Begin installation with these settings? [y/n] " confirmInstall
if [[ ! "$confirmInstall" =~ ^[Yy]$ ]]; then
    echo "Installation cancelled."
    exit 0
fi

# --- Set version ---
FORMSFLOW_VERSION="v7.3.0"

# --- Configure image names based on edition and architecture ---
echo ""
echo "Configuring images for Edition: $EDITION, Architecture: $ARCH"

# Set base image names according to edition
if [ "$EDITION" == "ee" ]; then
    echo "Applying Enterprise Edition configuration..."
    KEYCLOAK_CUSTOMIZATIONS_IMAGE="formsflow/keycloak-customizations-ee"
    FORMS_FLOW_WEB_IMAGE="formsflow/forms-flow-web-ee"
    FORMS_FLOW_BPM_IMAGE="formsflow/forms-flow-bpm-ee"
    FORMS_FLOW_WEBAPI_IMAGE="formsflow/forms-flow-webapi-ee"
    FORMS_FLOW_DOCUMENTS_API_IMAGE="formsflow/forms-flow-documents-api-ee"
    FORMS_FLOW_DATA_ANALYSIS_API_IMAGE="formsflow/forms-flow-data-analysis-api-ee"
else
    echo "Applying Community Edition configuration..."
    KEYCLOAK_CUSTOMIZATIONS_IMAGE="formsflow/keycloak-customizations"
    FORMS_FLOW_WEB_IMAGE="formsflow/forms-flow-web"
    FORMS_FLOW_BPM_IMAGE="formsflow/forms-flow-bpm"
    FORMS_FLOW_WEBAPI_IMAGE="formsflow/forms-flow-webapi"
    FORMS_FLOW_DOCUMENTS_API_IMAGE="formsflow/forms-flow-documents-api"
    FORMS_FLOW_DATA_ANALYSIS_API_IMAGE="formsflow/forms-flow-data-analysis-api"
fi

# Configure tags based on architecture and edition
if [ "$ARCH" == "arm64" ]; then
    echo "Applying ARM64-specific configuration..."
    DOCUMENTS_API_TAG="$FORMSFLOW_VERSION-arm64"
    DATA_ANALYSIS_API_TAG="$FORMSFLOW_VERSION"
else
    echo "Applying AMD64-specific configuration..."
    DOCUMENTS_API_TAG="$FORMSFLOW_VERSION"
    if [ "$EDITION" == "ee" ]; then
        DATA_ANALYSIS_API_TAG="$FORMSFLOW_VERSION-trim"
    else
        DATA_ANALYSIS_API_TAG="$FORMSFLOW_VERSION"
    fi
fi

# Display final image configuration
echo ""
echo "============================================"
echo "Final Image Configuration:"
echo "============================================"
echo "KEYCLOAK_CUSTOMIZATIONS_IMAGE=$KEYCLOAK_CUSTOMIZATIONS_IMAGE:$FORMSFLOW_VERSION"
echo "FORMS_FLOW_WEB_IMAGE=$FORMS_FLOW_WEB_IMAGE:$FORMSFLOW_VERSION"
echo "FORMS_FLOW_BPM_IMAGE=$FORMS_FLOW_BPM_IMAGE:$FORMSFLOW_VERSION"
echo "FORMS_FLOW_WEBAPI_IMAGE=$FORMS_FLOW_WEBAPI_IMAGE:$FORMSFLOW_VERSION"
echo "FORMS_FLOW_DOCUMENTS_API_IMAGE=$FORMS_FLOW_DOCUMENTS_API_IMAGE:$DOCUMENTS_API_TAG"
echo "FORMS_FLOW_DATA_ANALYSIS_API_IMAGE=$FORMS_FLOW_DATA_ANALYSIS_API_IMAGE:$DATA_ANALYSIS_API_TAG"
echo "============================================"
echo ""

# --- Create .env file ---
echo "Creating .env file..."
cat > "$DOCKER_COMPOSE_DIR/.env" << EOF
# FormsFlow.ai Configuration
# Generated on $(date)
# Architecture: $ARCH
# Edition: $EDITION

# Version
FORMSFLOW_VERSION=$FORMSFLOW_VERSION

# Architecture and Platform
ARCHITECTURE=$ARCH
PLATFORM=$PLATFORM

# Edition
EDITION=$EDITION

# Image Names
KEYCLOAK_CUSTOMIZATIONS_IMAGE=$KEYCLOAK_CUSTOMIZATIONS_IMAGE
FORMS_FLOW_WEB_IMAGE=$FORMS_FLOW_WEB_IMAGE
FORMS_FLOW_BPM_IMAGE=$FORMS_FLOW_BPM_IMAGE
FORMS_FLOW_WEBAPI_IMAGE=$FORMS_FLOW_WEBAPI_IMAGE
FORMS_FLOW_DOCUMENTS_API_IMAGE=$FORMS_FLOW_DOCUMENTS_API_IMAGE
DOCUMENTS_API_TAG=$DOCUMENTS_API_TAG
FORMS_FLOW_DATA_ANALYSIS_API_IMAGE=$FORMS_FLOW_DATA_ANALYSIS_API_IMAGE
DATA_ANALYSIS_API_TAG=$DATA_ANALYSIS_API_TAG

# Database Configuration
KEYCLOAK_JDBC_DB=keycloak
KEYCLOAK_JDBC_USER=admin
KEYCLOAK_JDBC_PASSWORD=changeme
FORMIO_DB_USERNAME=admin
FORMIO_DB_PASSWORD=changeme
FORMIO_DB_NAME=formio
CAMUNDA_JDBC_USER=admin
CAMUNDA_JDBC_PASSWORD=changeme
CAMUNDA_JDBC_DB_NAME=formsflow-bpm
FORMSFLOW_API_DB_USER=postgres
FORMSFLOW_API_DB_PASSWORD=changeme
FORMSFLOW_API_DB_NAME=webapi
DATA_ANALYSIS_DB_USER=general
DATA_ANALYSIS_DB_PASSWORD=changeme
DATA_ANALYSIS_DB_NAME=dataanalysis

# Keycloak Configuration
KEYCLOAK_ADMIN_USER=admin
KEYCLOAK_ADMIN_PASSWORD=changeme
KEYCLOAK_URL=http://$ip_add:8080
KEYCLOAK_URL_REALM=forms-flow-ai
KEYCLOAK_URL_HTTP_RELATIVE_PATH=/auth
KEYCLOAK_BPM_CLIENT_ID=forms-flow-bpm
KEYCLOAK_BPM_CLIENT_SECRET=e4bdbd25-1467-4f7f-b993-bc4b1944c943
KEYCLOAK_WEB_CLIENT_ID=forms-flow-web
KEYCLOAK_ENABLE_CLIENT_AUTH=false

# API URLs
FORMIO_DEFAULT_PROJECT_URL=http://$ip_add:3001
FORMSFLOW_API_URL=http://$ip_add:5001
BPM_API_URL=http://$ip_add:8000/camunda
DOCUMENT_SERVICE_URL=http://$ip_add:5006
DATA_ANALYSIS_URL=http://$ip_add:6001
DATA_ANALYSIS_API_BASE_URL=http://$ip_add:6001

# Application Configuration
APPLICATION_NAME=formsflow.ai
LANGUAGE=en
NODE_ENV=production

# Security
WEBSOCKET_ENCRYPT_KEY=giert989jkwrgb@DR55
FORMIO_JWT_SECRET=---- change me now ---
FORM_EMBED_JWT_SECRET=f6a69a42-7f8a-11ed-a1eb-0242ac120002

# Redis
REDIS_ENABLED=false
REDIS_URL=redis://redis:6379/0

# Feature Flags
MULTI_TENANCY_ENABLED=false
CUSTOM_SUBMISSION_ENABLED=false
DRAFT_ENABLED=false
EXPORT_PDF_ENABLED=false
PUBLIC_WORKFLOW_ENABLED=false
ENABLE_FORMS_MODULE=true
ENABLE_TASKS_MODULE=true
ENABLE_DASHBOARDS_MODULE=true
ENABLE_PROCESSES_MODULE=true
ENABLE_APPLICATIONS_MODULE=true
ENABLE_APPLICATIONS_ACCESS_PERMISSION_CHECK=false

# Formio Configuration
FORMIO_ROOT_EMAIL=admin@example.com
FORMIO_ROOT_PASSWORD=changeme
NO_INSTALL=1

# Camunda Configuration
CAMUNDA_JDBC_URL=jdbc:postgresql://forms-flow-bpm-db:5432/formsflow-bpm
CAMUNDA_JDBC_DRIVER=org.postgresql.Driver
CAMUNDA_APP_ROOT_LOG_FLAG=error

# Database Connection Strings
FORMSFLOW_API_DB_URL=postgresql://postgres:changeme@forms-flow-webapi-db:5432/webapi
FORMSFLOW_API_DB_HOST=forms-flow-webapi-db
FORMSFLOW_API_DB_PORT=5432

# Additional Configuration
APP_SECURITY_ORIGIN=*
FORMSFLOW_API_CORS_ORIGINS=*
CONFIGURE_LOGS=true
API_LOG_ROTATION_WHEN=d
API_LOG_ROTATION_INTERVAL=1
API_LOG_BACKUP_COUNT=7
DATE_FORMAT=DD-MM-YY
TIME_FORMAT=hh:mm:ss A
USER_NAME_DISPLAY_CLAIM=preferred_username
ENABLE_COMPACT_FORM_VIEW=false

# Worker Configuration
GUNICORN_WORKERS=5
GUNICORN_THREADS=10
GUNICORN_TIMEOUT=120
FORMSFLOW_DATA_LAYER_WORKERS=4
EOF

echo ".env file created successfully!"
echo ""

# --- Function to configure Redash ---
configure_redash() {
    echo "***********************************************"
    echo "*     Configuring Analytics (Redash)...       *"
    echo "***********************************************"
    
    REDASH_HOST="http://$ip_add:7001"
    PYTHONUNBUFFERED="0"
    REDASH_LOG_LEVEL="INFO"
    REDASH_REDIS_URL="redis://redis:6379/0"
    POSTGRES_USER="postgres"
    POSTGRES_PASSWORD="changeme"
    POSTGRES_DB="postgres"
    REDASH_COOKIE_SECRET="redash-selfhosted"
    REDASH_SECRET_KEY="redash-selfhosted"
    REDASH_DATABASE_URL="postgresql://postgres:changeme@postgres/postgres"
    REDASH_CORS_ACCESS_CONTROL_ALLOW_ORIGIN="*"
    REDASH_REFERRER_POLICY="no-referrer-when-downgrade"
    REDASH_CORS_ACCESS_CONTROL_ALLOW_HEADERS="Content-Type, Authorization"
    
    echo "Configuring Redash..."
    
    cat >> "$DOCKER_COMPOSE_DIR/.env" << EOF

# Redash Analytics Configuration
REDASH_HOST=$REDASH_HOST
PYTHONUNBUFFERED=$PYTHONUNBUFFERED
REDASH_LOG_LEVEL=$REDASH_LOG_LEVEL
REDASH_REDIS_URL=$REDASH_REDIS_URL
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_DB=$POSTGRES_DB
REDASH_COOKIE_SECRET=$REDASH_COOKIE_SECRET
REDASH_SECRET_KEY=$REDASH_SECRET_KEY
REDASH_DATABASE_URL=$REDASH_DATABASE_URL
REDASH_CORS_ACCESS_CONTROL_ALLOW_ORIGIN=$REDASH_CORS_ACCESS_CONTROL_ALLOW_ORIGIN
REDASH_REFERRER_POLICY=$REDASH_REFERRER_POLICY
REDASH_CORS_ACCESS_CONTROL_ALLOW_HEADERS=$REDASH_CORS_ACCESS_CONTROL_ALLOW_HEADERS
EOF
    
    echo "Redash configuration complete."
    echo ""
    
    echo "***********************************************"
    echo "*     Creating Analytics Database...           *"
    echo "***********************************************"
    echo "Creating analytics database..."
    $COMPOSE_COMMAND -p formsflow-ai -f "$ANALYTICS_COMPOSE_FILE" run --rm server create_db || echo "WARNING: Database creation may have failed, but continuing..."
    
    echo "***********************************************"
    echo "*        Starting Analytics Containers...      *"
    echo "***********************************************"
    $COMPOSE_COMMAND -p formsflow-ai -f "$ANALYTICS_COMPOSE_FILE" up -d
    if [ $? -ne 0 ]; then
        echo "ERROR: Failed to start analytics containers."
        echo "Please check the logs with: docker logs redash"
        return 1
    fi
    
    echo "Waiting for Analytics (Redash) to initialize..."
    sleep 15
    
    echo ""
    echo "============================================"
    echo "Redash is now running at: http://$ip_add:7001"
    echo "============================================"
    echo ""
    echo "IMPORTANT: To complete Redash setup:"
    echo "1. Open http://$ip_add:7001 in your browser"
    echo "2. Create an admin account"
    echo "3. Go to Settings -> API Key to generate an API key"
    echo "4. Copy the API key for the next step"
    echo ""
    
    echo "INSIGHT_API_URL=http://$ip_add:7001" >> "$DOCKER_COMPOSE_DIR/.env"
    
    read -p "Enter your Redash API key: " INSIGHT_API_KEY
    echo "INSIGHT_API_KEY=$INSIGHT_API_KEY" >> "$DOCKER_COMPOSE_DIR/.env"
    echo "API key saved to .env file."
    
    return 0
}

# --- Start Keycloak first ---
echo "***********************************************"
echo "*        Starting Keycloak container...        *"
echo "***********************************************"
$COMPOSE_COMMAND -p formsflow-ai -f "$COMPOSE_FILE" up -d keycloak keycloak-db keycloak-customizations
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start Keycloak."
    exit 1
fi
echo "Waiting for Keycloak to initialize..."
sleep 25
echo "Keycloak is up."
echo ""

# --- Start Analytics (if selected) ---
if [ "$analytics" == "1" ]; then
    if [ -n "$ANALYTICS_COMPOSE_FILE" ]; then
        configure_redash
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to configure or start analytics."
            exit 1
        fi
    else
        echo "WARNING: analytics compose file not found; skipping analytics setup."
    fi
fi

# --- Start Main Stack ---
echo "***********************************************"
echo "*       Starting Main FormsFlow Stack...       *"
echo "***********************************************"

if [ "$dataanalysis" == "1" ]; then
    echo "Starting all services including Data Analysis API..."
    $COMPOSE_COMMAND -p formsflow-ai -f "$COMPOSE_FILE" up -d
else
    echo "Starting core services (excluding Data Analysis API)..."
    $COMPOSE_COMMAND -p formsflow-ai -f "$COMPOSE_FILE" up -d keycloak keycloak-db keycloak-customizations forms-flow-forms-db forms-flow-webapi forms-flow-webapi-db forms-flow-bpm forms-flow-bpm-db forms-flow-forms forms-flow-documents-api forms-flow-data-layer forms-flow-web redis
fi

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to start main containers."
    exit 1
fi

echo ""
echo "============================================"
echo "formsflow.ai installation completed successfully!"
echo "============================================"
echo ""
echo "Access points:"
echo "  - FormsFlow Web: http://$ip_add:3000"
echo "  - Keycloak:      http://$ip_add:8080/auth"
echo "  - API:           http://$ip_add:5001"
echo "  - BPM:           http://$ip_add:8000"
if [ "$dataanalysis" == "1" ]; then
    echo "  - Data Analysis: http://$ip_add:6001"
fi
if [ "$analytics" == "1" ]; then
    echo "  - Analytics:     http://$ip_add:7001"
fi
echo ""
echo "Default credentials:"
echo "  - Username: admin"
echo "  - Password: changeme"
echo ""
echo "Edition installed: $EDITION ($ARCH)"
echo ""