# Changelog for forms-flow-ai-Deployment

Mark  items as `Added`, `Changed`, `Fixed`, `Removed`, `Untested Features`, `Upcoming Features`, `Known Issues`

## 7.3.0 - 2025-10-14

`Added` 

* Added new env `REACT_APP_ENABLE_COMPACT_FORM_VIEW` for `forms-flow-web`

`Modified`

* Updated default value for `USER_NAME_DISPLAY_CLAIM` with 'preferred_username` value in bpm and webapi


## 7.1.0 - 2025-07-01

`Added` 

* Added a refined Windows installation script with improved execution flow and proper component installation order.
* Added new componant named Forms-Flow-Data-Layer.
* Updated the keycloak image to 26.1.2.

`Modified`

* Updated commands to fetch Docker and Docker Compose versions using the latest script format.
* Refined environment variables in both docker-compose.yml and .env files.
* Updated the list of working Docker versions, modified the script to reflect these changes, and added an S3 URL for   fetching Docker version details.  

`Removed`

* Removed all unwanted README.md files and refined the Repository


## 7.0.0 - 2025-01-10

`Added` 

* Redis container added for lightweight Redis service using the official Redis Alpine image
* Added new IP fetching script for mac and windows users for smooth usage
* Added Multi-arch image for BPM.
* Updated the keycloak image to 25.0.4.
* Added keycloak customization as a container to fetch Realm, themes and other customizations as image.

`Modified`

* Updated shell script for finding the correct docker compose file and install the application
* Updated the scripts to check for the docker-compose file been used in the system("docker-compose"/"docker compose")
* Updated the env's in the docker-compose file and env file.
* Updated the Working docker versions 

`Upcoming Features`

* We will be adding the verfied and tested versions of docker into a json file or yml file and check the condition from it.
* Service call concept insted of IP usage will be implemented.

## 6.0.0 - 2024-4-8

`Added`

*  Added a new variable `KEYCLOAK_WEB_CLIENTID` for `forms-flow-bpm` 
*  Added `shell script` for starting keycloak.
*  Added an option for the users to run `data-analysis-api` as an optional feature.

`Modified`

*  Updated the keycloak image to 23.0.7.
*  Updated the `docker-compose` file for the keycloak 23 changes.
*  Modified the environment variables.

## 5.3.0 - 2023-11-24

`Added`

*  Added `Data-analysis-api` service into docker-compose file.
*  Added IP confirmation check to confirm the user IP.
*  Added `Docker engine` versions that are tested and working fine.
*  Added `docker-compose` file for Enterprise edition.

`Modified`

*  Updated batch script by adding tested docker-versions
*  Updated shell script for better understanding.
*  Modified the environment variables.

`Upcoming Features`

* An update will be introduced to provide users with the option to run the data analysis API, making it an optional feature.
* An update in the script to enable a quick installation process specifically tailored for enterprise edition users.

## 5.2.0 - 2023-07-07

`Added`

*  Added `Label-Name` for images to easily uninstall images using label name.
*  Added a checkpoint for webapi to check whether it runs in the browser.
*  Added `DB-port` for keycloak.
*  Added `Documents-api` container as a new feature in quick installation.


`Modified`

*  Updated web-api port from `5000` to `5001`
*  Updated Redash image 
*  Updated the docker-compose by including networks for all containers.
*  Updated the `ENV` variables for Web


`Removed`

*  Removed the `config.js` file since it is directly taken through image.


## 5.1.1 - 2023-05-18


`Added`

* `docker-compose` Seperate Docker-compose file has added for windows, and Mac.
*  Added IP confirmation to avoid IP issues.
*  Added CI/CD pipeline.


`Modified`

*  Reduced script size
*  Fixed versions for databases
