@echo off
setlocal EnableDelayedExpansion

echo *******************************************
echo *     formsflow.ai Installation Script    *
echo *******************************************
echo.

REM Detect Docker Compose
set "COMPOSE_COMMAND="
for /f "tokens=*" %%A in ('docker compose version 2^>nul') do set "COMPOSE_COMMAND=docker compose"
if "!COMPOSE_COMMAND!"=="" (
    for /f "tokens=*" %%A in ('docker-compose version 2^>nul') do set "COMPOSE_COMMAND=docker-compose"
)
if "!COMPOSE_COMMAND!"=="" (
    echo ERROR: Neither docker compose nor docker-compose is installed.
    echo Please install Docker Desktop or Docker Engine with Compose.
    pause
    exit /b 1
)
echo Using !COMPOSE_COMMAND!

REM Get Docker version
for /f "tokens=*" %%A in ('docker -v 2^>^&1') do set "docker_info=%%A"
set "docker_version="
for /f "tokens=3 delims= " %%A in ("!docker_info!") do (
    set "docker_version=%%A"
    set "docker_version=!docker_version:,=!"
)
echo Docker version: !docker_version!

:: --- Docker Version Validation ---
set "url=https://forms-flow-docker-versions.s3.ca-central-1.amazonaws.com/docker_versions.html"
set "versionsFile=tested_versions.tmp"
echo Fetching tested Docker versions from !url!...
where curl >nul 2>nul
if errorlevel 1 (
    echo curl not found, skipping version validation.
    goto SkipVersionCheck
)
curl -L -s "%url%" -o "%versionsFile%" 2>nul

if not exist "%versionsFile%" (
    echo Failed to fetch tested versions. Skipping validation.
    goto SkipVersionCheck
)
for %%A in ("%versionsFile%") do set "fileSize=%%~zA"
if !fileSize! LSS 10 (
    echo Downloaded file empty. Skipping validation.
    goto SkipVersionCheck
)

echo Checking if your Docker version is tested...
findstr /C:"%docker_version%" "%versionsFile%" >nul 2>&1
if !ERRORLEVEL! EQU 0 (
    echo ✅ Your Docker version %docker_version% is in the tested list.
    del "%versionsFile%" 2>nul
    goto SkipVersionCheck
)
echo ⚠️ WARNING: Your Docker version %docker_version% is not in the tested list!
set /p continue=Do you want to continue anyway? [y/n] 
if /i "!continue!" neq "y" (
    echo Installation cancelled.
    del "%versionsFile%" 2>nul
    exit /b 1
)
del "%versionsFile%" 2>nul
echo Continuing with untested Docker version...
:SkipVersionCheck
echo.

REM --- Detect IP address automatically ---
echo Finding your IP address...
set "ip_add="
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr "IPv4"') do (
    set "temp_ip=%%a"
    set "temp_ip=!temp_ip: =!"
    echo !temp_ip! | find "127." >nul
    if errorlevel 1 if not defined ip_add (
        set "ip_add=!temp_ip!"
    )
)
if not defined ip_add (
    echo WARNING: Could not automatically detect your IP address.
    set /p "ip_add=Please enter your IP address manually: "
) else (
    echo Detected IP address: !ip_add!
    set /p "confirmIP=Is this correct? [y/n] "
    if /i "!confirmIP!" neq "y" (
        set /p "ip_add=Please enter your correct IP address: "
    )
)
echo IP address set to: !ip_add!
echo.

REM --- Detect architecture ---
echo Detecting system architecture...
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" (
    set "ARCH=arm64"
) else (
    set "ARCH=amd64"
)
echo Detected architecture: !ARCH!
echo.

REM --- Check Docker OSType ---
set "DOCKER_OSTYPE="
for /f "tokens=2 delims=:" %%o in ('docker info 2^>nul ^| findstr /c:"OSType"') do (
    set "DOCKER_OSTYPE=%%o"
)
if defined DOCKER_OSTYPE (
    set "DOCKER_OSTYPE=!DOCKER_OSTYPE: =!"
)
if /i "!DOCKER_OSTYPE!"=="windows" (
    echo ❌ ERROR: Docker is using Windows containers.
    echo Please switch Docker Desktop to "Use Linux containers" and re-run.
    pause
    exit /b 1
)
if "!ARCH!"=="amd64" (
    set "PLATFORM=linux/amd64"
) else (
    set "PLATFORM=linux/arm64/v8"
)
echo Using PLATFORM: !PLATFORM!
echo.

REM --- Select edition ---
echo Select installation type:
echo   1. Open Source (Community Edition)
echo   2. Premium (Enterprise Edition)
set /p "editionChoice=Enter your choice [1-2]: "

if "!editionChoice!"=="2" (
    set "EDITION=ee"
    echo Selected: Premium (Enterprise Edition)
) else (
    set "EDITION=ce"
    echo Selected: Open Source (Community Edition)
)
echo.

REM --- Locate docker-compose files ---
echo Locating docker-compose files...
set "COMPOSE_FILE="
set "ANALYTICS_COMPOSE_FILE="

if exist "..\docker-compose\docker-compose.yml" (
    set "COMPOSE_FILE=..\docker-compose\docker-compose.yml"
    set "DOCKER_COMPOSE_DIR=..\docker-compose"
    echo Found docker-compose.yml.
)
if exist "!DOCKER_COMPOSE_DIR!\analytics-docker-compose.yml" (
    set "ANALYTICS_COMPOSE_FILE=!DOCKER_COMPOSE_DIR!\analytics-docker-compose.yml"
    echo Found analytics-docker-compose.yml.
)
echo Using compose file: !COMPOSE_FILE!
echo.
if not defined COMPOSE_FILE (
    echo ERROR: Could not find docker-compose file. Expected "..\docker-compose\docker-compose.yml".
    echo Please ensure you are running this installer from the repository root or that the docker-compose files exist.
    pause
    exit /b 1
)

REM --- Analytics & Data Analysis selections ---
set /p "includeAnalytics=Do you want to include analytics in the installation? [y/n] "
if /i "!includeAnalytics!"=="y" (
    set "analytics=1"
    echo Analytics will be included.
) else (
    set "analytics=0"
    echo Analytics will not be included.
)
echo.
set /p "includeDataAnalysis=Do you want to include forms-flow-data-analysis-api? [y/n] "
if /i "!includeDataAnalysis!"=="y" (
    set "dataanalysis=1"
    echo Data Analysis API will be included.
) else (
    set "dataanalysis=0"
    echo Data Analysis API will not be included.
)
echo.

REM If analytics requested but analytics compose file is missing, warn and skip analytics
if "!analytics!"=="1" (
    if not defined ANALYTICS_COMPOSE_FILE (
        echo WARNING: analytics compose file not found; skipping analytics setup.
        set "analytics=0"
    )
)

echo Installation summary:
echo - IP Address: !ip_add!
echo - Edition: !EDITION!
echo - Architecture: !ARCH!
echo - PLATFORM: !PLATFORM!
echo - Analytics: !analytics!
echo - Data Analysis: !dataanalysis!
echo.
set /p "confirmInstall=Begin installation with these settings? [y/n] "
if /i "!confirmInstall!" neq "y" (
    echo Installation cancelled.
    pause
    exit /b 0
)

REM --- Set version ---
set "FORMSFLOW_VERSION=v7.3.0"

REM --- Configure image names based on architecture and edition ---
set "KEYCLOAK_CUSTOMIZATIONS_IMAGE=formsflow/keycloak-customizations"
set "FORMS_FLOW_WEB_IMAGE=formsflow/forms-flow-web"
set "FORMS_FLOW_BPM_IMAGE=formsflow/forms-flow-bpm"
set "FORMS_FLOW_WEBAPI_IMAGE=formsflow/forms-flow-webapi"
set "FORMS_FLOW_DOCUMENTS_API_IMAGE=formsflow/forms-flow-documents-api"
set "FORMS_FLOW_DATA_ANALYSIS_API_IMAGE=formsflow/forms-flow-data-analysis-api"
set "DOCUMENTS_API_TAG=!FORMSFLOW_VERSION!"
set "DATA_ANALYSIS_API_TAG=!FORMSFLOW_VERSION!"

REM Apply edition suffix
if "!EDITION!"=="ee" (
    set "KEYCLOAK_CUSTOMIZATIONS_IMAGE=!KEYCLOAK_CUSTOMIZATIONS_IMAGE!-ee"
    set "FORMS_FLOW_WEB_IMAGE=!FORMS_FLOW_WEB_IMAGE!-ee"
    set "FORMS_FLOW_BPM_IMAGE=!FORMS_FLOW_BPM_IMAGE!-ee"
    set "FORMS_FLOW_WEBAPI_IMAGE=!FORMS_FLOW_WEBAPI_IMAGE!-ee"
    set "FORMS_FLOW_DOCUMENTS_API_IMAGE=!FORMS_FLOW_DOCUMENTS_API_IMAGE!-ee"
    set "FORMS_FLOW_DATA_ANALYSIS_API_IMAGE=!FORMS_FLOW_DATA_ANALYSIS_API_IMAGE!-ee"
)

REM Apply architecture-specific settings
if "!ARCH!"=="arm64" (
    REM ARM64 specific image tags
    if "!EDITION!"=="ee" (
        set "DOCUMENTS_API_TAG=!FORMSFLOW_VERSION!-arm64"
    ) else (
        set "DOCUMENTS_API_TAG=!FORMSFLOW_VERSION!-arm64"
    )
) else (
    REM AMD64 specific - EE has special tag for data-analysis-api
    if "!EDITION!"=="ee" (
        set "DATA_ANALYSIS_API_TAG=!FORMSFLOW_VERSION!-trim"
    )
)

REM --- Create .env file ---
echo Creating .env file...
(
echo # FormsFlow.ai Configuration
echo # Generated on %date% %time%
echo # Architecture: !ARCH!
echo # Edition: !EDITION!
echo.
echo # Version
echo FORMSFLOW_VERSION=!FORMSFLOW_VERSION!
echo.
echo # Architecture and Platform
echo ARCHITECTURE=!ARCH!
echo PLATFORM=!PLATFORM!
echo.
echo # Edition
echo EDITION=!EDITION!
echo.
echo # Image Names
echo KEYCLOAK_CUSTOMIZATIONS_IMAGE=!KEYCLOAK_CUSTOMIZATIONS_IMAGE!
echo FORMS_FLOW_WEB_IMAGE=!FORMS_FLOW_WEB_IMAGE!
echo FORMS_FLOW_BPM_IMAGE=!FORMS_FLOW_BPM_IMAGE!
echo FORMS_FLOW_WEBAPI_IMAGE=!FORMS_FLOW_WEBAPI_IMAGE!
echo FORMS_FLOW_DOCUMENTS_API_IMAGE=!FORMS_FLOW_DOCUMENTS_API_IMAGE!
echo DOCUMENTS_API_TAG=!DOCUMENTS_API_TAG!
echo FORMS_FLOW_DATA_ANALYSIS_API_IMAGE=!FORMS_FLOW_DATA_ANALYSIS_API_IMAGE!
echo DATA_ANALYSIS_API_TAG=!DATA_ANALYSIS_API_TAG!
echo.
echo # Database Configuration
echo KEYCLOAK_JDBC_DB=keycloak
echo KEYCLOAK_JDBC_USER=admin
echo KEYCLOAK_JDBC_PASSWORD=changeme
echo FORMIO_DB_USERNAME=admin
echo FORMIO_DB_PASSWORD=changeme
echo FORMIO_DB_NAME=formio
echo CAMUNDA_JDBC_USER=admin
echo CAMUNDA_JDBC_PASSWORD=changeme
echo CAMUNDA_JDBC_DB_NAME=formsflow-bpm
echo FORMSFLOW_API_DB_USER=postgres
echo FORMSFLOW_API_DB_PASSWORD=changeme
echo FORMSFLOW_API_DB_NAME=webapi
echo DATA_ANALYSIS_DB_USER=general
echo DATA_ANALYSIS_DB_PASSWORD=changeme
echo DATA_ANALYSIS_DB_NAME=dataanalysis
echo.
echo # Keycloak Configuration
echo KEYCLOAK_ADMIN_USER=admin
echo KEYCLOAK_ADMIN_PASSWORD=changeme
echo KEYCLOAK_URL=http://!ip_add!:8080
echo KEYCLOAK_URL_REALM=forms-flow-ai
echo KEYCLOAK_URL_HTTP_RELATIVE_PATH=/auth
echo KEYCLOAK_BPM_CLIENT_ID=forms-flow-bpm
echo KEYCLOAK_BPM_CLIENT_SECRET=e4bdbd25-1467-4f7f-b993-bc4b1944c943
echo KEYCLOAK_WEB_CLIENT_ID=forms-flow-web
echo.
echo # API URLs
echo FORMIO_DEFAULT_PROJECT_URL=http://!ip_add!:3001
echo FORMSFLOW_API_URL=http://!ip_add!:5001
echo BPM_API_URL=http://!ip_add!:8000/camunda
echo DOCUMENT_SERVICE_URL=http://!ip_add!:5006
echo DATA_ANALYSIS_URL=http://!ip_add!:6001
echo.
echo # Application Configuration
echo APPLICATION_NAME=formsflow.ai
echo LANGUAGE=en
echo NODE_ENV=production
echo.
echo # Security
echo WEBSOCKET_ENCRYPT_KEY=giert989jkwrgb@DR55
echo FORMIO_JWT_SECRET=---- change me now ---
echo FORM_EMBED_JWT_SECRET=f6a69a42-7f8a-11ed-a1eb-0242ac120002
echo.
echo # Redis
echo REDIS_ENABLED=false
echo REDIS_URL=redis://redis:6379/0
echo.
echo # Feature Flags
echo MULTI_TENANCY_ENABLED=false
echo CUSTOM_SUBMISSION_ENABLED=false
echo DRAFT_ENABLED=false
echo EXPORT_PDF_ENABLED=false
echo PUBLIC_WORKFLOW_ENABLED=false
echo ENABLE_FORMS_MODULE=true
echo ENABLE_TASKS_MODULE=true
echo ENABLE_DASHBOARDS_MODULE=true
echo ENABLE_PROCESSES_MODULE=true
echo ENABLE_APPLICATIONS_MODULE=true
) > "!DOCKER_COMPOSE_DIR!\.env"

echo .env file created successfully!
echo.

REM --- Start Keycloak first ---
echo ***********************************************
echo *        Starting Keycloak container...        *
echo ***********************************************
!COMPOSE_COMMAND! -p formsflow-ai -f "!COMPOSE_FILE!" up -d keycloak keycloak-db keycloak-customizations
if errorlevel 1 (
    echo ERROR: Failed to start Keycloak.
    pause
    exit /b 1
)
echo Waiting for Keycloak to initialize...
timeout /t 25 /nobreak >nul
echo Keycloak is up.
echo.

REM --- Start Analytics Next (if selected) ---
if "!analytics!"=="1" (
    echo [DEBUG] Analytics is set to 1
    if defined ANALYTICS_COMPOSE_FILE (
        echo [DEBUG] ANALYTICS_COMPOSE_FILE is defined as: !ANALYTICS_COMPOSE_FILE!
        echo ***********************************************
        echo *        Starting Analytics Containers...      *
        echo ***********************************************
        echo [DEBUG] About to run: !COMPOSE_COMMAND! -p formsflow-ai -f "!ANALYTICS_COMPOSE_FILE!" up -d
        call !COMPOSE_COMMAND! -p formsflow-ai -f "!ANALYTICS_COMPOSE_FILE!" up -d
        if errorlevel 1 (
            echo ERROR: Failed to start analytics containers.
            pause
            exit /b 1
        )
        echo Waiting for Analytics ^(Redash^) to initialize...
        timeout /t 25 /nobreak >nul
        set /p "INSIGHT_API_KEY=Enter your Redash API key: "
        set "INSIGHT_API_URL=http://!ip_add!:7001"
        echo INSIGHT_API_KEY=!INSIGHT_API_KEY!>>"!DOCKER_COMPOSE_DIR!\.env"
        echo INSIGHT_API_URL=!INSIGHT_API_URL!>>"!DOCKER_COMPOSE_DIR!\.env"
    ) else (
        echo WARNING: analytics compose file not found; skipping analytics setup.
    )
)
echo.

REM --- Start Main Stack ---
echo ***********************************************
echo *       Starting Main FormsFlow Stack...       *
echo ***********************************************

if "!dataanalysis!"=="1" (
    echo Starting all services including Data Analysis API...
    call !COMPOSE_COMMAND! -p formsflow-ai -f "!COMPOSE_FILE!" up -d
) else (
    echo Starting core services ^(excluding Data Analysis API^)...
    call !COMPOSE_COMMAND! -p formsflow-ai -f "!COMPOSE_FILE!" up -d keycloak keycloak-db keycloak-customizations forms-flow-forms-db forms-flow-webapi forms-flow-webapi-db forms-flow-bpm forms-flow-bpm-db forms-flow-forms forms-flow-documents-api forms-flow-data-layer forms-flow-web redis
)
if errorlevel 1 (
    echo ERROR: Failed to start main containers.
    pause
    exit /b 1
)

echo.
echo ✅ formsflow.ai installation completed successfully!
echo.
echo Access points:
echo   - FormsFlow Web: http://!ip_add!:3000
echo   - Keycloak:      http://!ip_add!:8080/auth
echo   - API:           http://!ip_add!:5001
echo   - BPM:           http://!ip_add!:8000
if "!dataanalysis!"=="1" (
    echo   - Data Analysis: http://!ip_add!:6001
)
if "!analytics!"=="1" (
    echo   - Analytics:     http://!ip_add!:7001
)
echo.
echo Default credentials:
echo   - Username: admin
echo   - Password: changeme
echo.
pause
endlocal
exit /b 0