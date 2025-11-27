#!/bin/bash

# ================&&&&&&===  Functions  ====&&&&&&&&&============================

# #############################################################
# ################### Main Function ###########################
# #############################################################

main() {
    forms_flow_all "../docker-compose"
    forms_flow_analytics "../docker-compose"
    prune_docker
    clear_env "../docker-compose"
    remove_folders "../docker-compose"
    return 0
}

# #############################################################
# ################### forms-flow-forms ########################
# #############################################################

forms_flow_all() {
    if [ -d "$1" ]; then
        docker-compose -p formsflow-ai -f "$1/docker-compose.yml" down
    fi
    return 0
}

# #############################################################
# ################### forms-flow-analytics ####################
# #############################################################

forms_flow_analytics() {
    if [ -d "$1" ]; then
        docker-compose -p formsflow-ai -f "$1/analytics-docker-compose.yml" down
    fi
    return 0
}

# ##############################################################

clear_env() {
    if [ -f "$1/.env" ]; then
        echo "Removing environment file..."
        rm -f "$1/.env"
    else
        echo ".env not found in $1"
    fi
    return 0
}

remove_folders() {
    if [ -d "$1/postgres" ]; then
        echo "Removing postgres folder..."
        rm -rf "$1/postgres"
    else
        echo "postgres folder not found in $1"
    fi

    if [ -d "$1/mongodb" ]; then
        echo "Removing mongodb folder..."
        rm -rf "$1/mongodb"
    else
        echo "mongodb folder not found in $1"
    fi
    return 0
}

# #############################################################
# ############# clearing dangling images ######################
# #############################################################

prune_docker() {
    docker volume prune -f
    docker image prune --all -f --filter label=Name="formsflow"
}

# ====================== Start Script ==========================

read -p "Do you want to uninstall formsflow.ai installation? [y/n] " choice
if [ "$choice" == "y" ]; then
    uninstall=1
else
    uninstall=0
fi

if [ $uninstall -eq 1 ]; then
    main
fi

echo "********************** formsflow.ai is successfully uninstalled ****************************"

exit 0
