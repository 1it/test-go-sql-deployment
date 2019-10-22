#!/usr/bin/env bash

dir="$(dirname "$0")"

source "${dir}/.env"
source "${dir}/gcp_env_check.sh"

# Postgres database parameters
export DBPORT=$DBPORT
export DBUSER=$DBUSER
export DBPASS=$DBPASS
export DBNAME=$DBNAME

# Application deployment parameters
export DOCKER_TAG=0.1.10
export APP_NAME=test-api
export APP_PATH="$dir/app"

# GKE and Cloud SQL parameters
export GCP_EXT_IP_NAME=${APP_NAME}-address
export GKE_SQL_SECRET=cloudsql-sa-creds
export GKE_SQL_CCREDS=cloudsql-connection-creds
export GKE_SQL_CONFIG_MAP=sqlconnection
export GKE_CLUSTER_NAME=${APP_NAME}-cluster
export GKE_API_FILE="$dir/deployment/api.yaml"
export GKE_DEPLOYMENT_FILE="$dir/deployment/deployment.yaml"
export GKE_SA_NAME=${APP_NAME}-gke
export SQL_SA_NAME=${APP_NAME}-sql
export GKE_SA_FULLNAME=${GKE_SA_NAME}@${GCP_PROJECT}.iam.gserviceaccount.com
export SQL_SA_FULLNAME=${SQL_SA_NAME}@${GCP_PROJECT}.iam.gserviceaccount.com
export GKE_SA_CREDENTIALS=gke-credentials.json
export SQL_SA_CREDENTIALS=sql-credentials.json
export GCR_CREDS=gcr-docker-creds

# Postgres instance name must be unique, GCP doesn't allow to reuse the same name even after instance deletion.
if [ -e "$dir/.cloudsql.name" ]; then
    PG_INSTANCE_NAME=$(<"$dir/.cloudsql.name")
else
    SUFFIX="0$(( $RANDOM % 10000 ))"; 
    export PG_INSTANCE_NAME=${APP_NAME}-sql-node-${SUFFIX}; echo "${PG_INSTANCE_NAME}" > "$dir/.cloudsql.name"
fi

# GCP required APIs list 
export GCP_API_LIST=(
    'container.googleapis.com'
    'containerregistry.googleapis.com'
    'iam.googleapis.com'
    'sql-component.googleapis.com'
    'sqladmin.googleapis.com'
)

# Service acounts roles
export SQL_SA_ROLES=(
    'roles/cloudsql.client'
)

export GKE_SA_ROLES=(
    'roles/storage.objectViewer'
    'roles/logging.logWriter'
    'roles/monitoring.metricWriter'
    'roles/monitoring.viewer'
)
