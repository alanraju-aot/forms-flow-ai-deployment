@echo off

set /p choice=Do you want to uninstall formsflow.ai installation? [y/n]
if %choice%==y (
    set /a uninstall=1
) else (
    set /a uninstall=0
)

if %uninstall%==1 (
    call:main
)

echo ********************** formsflow.ai is successfully uninstalled ****************************


EXIT /B %ERRORLEVEL%


:: ================&&&&&&===  Functions  ====&&&&&&&&&============================

:: #############################################################
:: ################### Main Function ###########################
:: #############################################################

:main
    call:forms-flow-all ..\docker-compose
    call:forms-flow-analytics ..\docker-compose
    call:prune-docker
    call:clear-env ..\docker-compose
    call:remove-folders ..\docker-compose
    EXIT /B 0
   
:: #############################################################
:: ################### forms-flow-forms ########################
:: #############################################################

:forms-flow-all

    if exist %~1 (
        docker-compose -p formsflow-ai -f %~1\docker-compose.yml down
	)
    EXIT /B 0

:: #############################################################
:: ################### forms-flow-analytics ########################
:: #############################################################

:forms-flow-analytics

    if exist %~1 (
        docker-compose -p formsflow-ai -f %~1\analytics-docker-compose.yml down
	)
    EXIT /B 0

:: ##############################################################
:: ##############################################################


:clear-env
    if exist "%~1\.env" (
        echo Removing environment file...
        del /q "%~1\.env"
    ) else (
        echo .env not found in %~1
    )
    exit /b 0

:remove-folders
    if exist "%~1\postgres" (
        echo Removing postgres folder...
        rmdir /s /q "%~1\postgres"
    ) else (
        echo postgres folder not found in %~1
    )

    if exist "%~1\mongodb" (
        echo Removing mongodb folder...
        rmdir /s /q "%~1\mongodb"
    ) else (
        echo mongodb folder not found in %~1
    )
    exit /b 0
    
	
:: #############################################################
:: ############# clearing dangling images ######################
:: #############################################################

:prune-docker
    docker volume prune -f
    docker image prune --all -f --filter label=Name="formsflow"