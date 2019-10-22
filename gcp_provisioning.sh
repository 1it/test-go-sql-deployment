#!/usr/bin/env bash 

dir="$(dirname "$0")"

source "${dir}/gcp_functions.sh"

# Provisioning resorces functions
function gcp_create() {
    source "${dir}/gcp_defaults.sh"

    echo "Enabling APIs"
    for ((i=0;i<${#GCP_API_LIST[@]};++i)); do
        gcp_enable_api ${GCP_API_LIST[i]};
    done

    gcp_compute_address_create "$GCP_EXT_IP_NAME";

    cloud_sql_pg_instance_create "$PG_INSTANCE_NAME";
    cloud_sql_pg_user_create "$DBUSER" "$DBPASS" "$PG_INSTANCE_NAME";
    cloud_sql_pg_database_create "$DBNAME" "$PG_INSTANCE_NAME";

    iam_service_account_create "$SQL_SA_NAME";
    iam_service_account_create "$GKE_SA_NAME";

    for ((i=0;i<${#SQL_SA_ROLES[@]};++i)); do
        projects_iam_policy_binding_add "$SQL_SA_FULLNAME" "${SQL_SA_ROLES[i]}";
    done

    for ((i=0;i<${#GKE_SA_ROLES[@]};++i)); do
        projects_iam_policy_binding_add "$GKE_SA_FULLNAME" "${GKE_SA_ROLES[i]}";
    done

    iam_service_account_key_create "$GKE_SA_FULLNAME" "$GKE_SA_CREDENTIALS";
    iam_service_account_key_create "$SQL_SA_FULLNAME" "$SQL_SA_CREDENTIALS";

    gke_cluster_create "$GKE_CLUSTER_NAME" "$GKE_SA_FULLNAME";
    gke_cluster_get_credentials "$GKE_CLUSTER_NAME";

    kubectl_create_secret_from_file "$GKE_SQL_SECRET" "$SQL_SA_CREDENTIALS";
    kubectl_create_secret_from_literal "$GKE_SQL_CCREDS" "$DBUSER" "$DBPASS";
    kubectl_create_secret_docker_registry "$GCR_CREDS" "$GKE_SA_CREDENTIALS" "$GKE_SA_FULLNAME";
    kubectl_create_config_map "$GKE_SQL_CONFIG_MAP" "$PG_INSTANCE_NAME";

    gcr_docker_build "$APP_NAME" "$DOCKER_TAG" "$APP_PATH";
    gcr_docker_push "$APP_NAME" "$DOCKER_TAG";

    update_deployment_file "$GKE_DEPLOYMENT_FILE";
    kubectl_create_deployment "$GKE_DEPLOYMENT_FILE";
}

# Build docker image and push to registry
function gcp_build() {
    source "${dir}/gcp_defaults.sh"
    if [ "$1" != "" ]; then export DOCKER_TAG=$1; fi
        
    gcr_docker_build "$APP_NAME" "$DOCKER_TAG" "$APP_PATH";
    gcr_docker_push "$APP_NAME" "$DOCKER_TAG";
}

# Deploy and scale
function gcp_deploy() {
    source "${dir}/gcp_defaults.sh"
    if [ "$1" != "" ]; then export DOCKER_TAG=$1; fi
    if [ "$2" != "" ]; then export COUNT=$2; fi

    update_deployment_file "$GKE_API_FILE";
    kubectl_deploy "$GKE_API_FILE";
}

# Cleanup all resources
function gcp_destroy() {
    source "${dir}/gcp_defaults.sh"

    PG_INSTANCE_NAME=$(<"$dir/.cloudsql.name")

    cloud_sql_pg_instance_delete "${PG_INSTANCE_NAME}"

    gke_cluster_delete "$GKE_CLUSTER_NAME"

    for ((i=0;i<${#SQL_SA_ROLES[@]};++i)); do
        projects_iam_policy_binding_remove "$SQL_SA_FULLNAME" "${SQL_SA_ROLES[i]}";
    done

    for ((i=0;i<${#GKE_SA_ROLES[@]};++i)); do
        projects_iam_policy_binding_remove "$GKE_SA_FULLNAME" "${GKE_SA_ROLES[i]}";
    done

    iam_service_account_delete "$SQL_SA_FULLNAME";
    iam_service_account_delete "$GKE_SA_FULLNAME";

    gcp_compute_address_delete "$GCP_EXT_IP_NAME";

    gcp_images_delete "gcr.io/$GCP_PROJECT/$APP_NAME";

    # Cleanup temporary files
    rm -f "$GKE_DEPLOYMENT_FILE" "$GKE_API_FILE" "$SQL_SA_CREDENTIALS" "$GKE_SA_CREDENTIALS" "$dir/.cloudsql.name" "$dir/.ext.ipv4"
}
