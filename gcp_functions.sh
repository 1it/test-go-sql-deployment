#!/usr/bin/env bash

function gcp_enable_api() {
  SERVICE=$1
  if [[ $(gcloud services list --format="value(NAME)" --filter="NAME:$SERVICE" 2>&1) != "$SERVICE" ]]; then
    echo "Enabling $SERVICE"
    gcloud services enable "$SERVICE"
  else
    echo "Nothing to do. $SERVICE is already enabled"
  fi
}

function gke_cluster_create() {
    CLUSTER=$1; SA_NAME=$2;
    if [[ $(gcloud container clusters list --format="value(NAME)" --filter="NAME:$CLUSTER" 2>&1) != "$CLUSTER" ]]; then
        GKE_VERSION=$(gcloud container get-server-config --zone "$GCP_ZONE" --format="value(validMasterVersions[0])")
        gcloud container clusters create "$CLUSTER" \
        --cluster-version "$GKE_VERSION" \
        --num-nodes "${GKE_CLUSTER_SIZE:-1}" \
        --enable-autorepair \
        --zone "$GCP_ZONE" \
        --service-account="$SA_NAME"
    else
        echo "Nothing to do. Cluster $CLUSTER is already exists"
    fi   
}

function gke_cluster_delete() {
    CLUSTER=$1;
    if [[ $(gcloud container clusters list --format="value(NAME)" --filter="NAME:$CLUSTER" 2>&1) == "$CLUSTER" ]]; then
        gcloud container clusters delete "$CLUSTER" \
        --zone "$GCP_ZONE" \
        --quiet
    else
        echo "Nothing to do. Cluster $CLUSTER is not exists"
    fi   
}

function gcp_compute_address_create() {
    NAME=$1
    if [[ $(gcloud compute addresses list --format="value(NAME)" --filter="NAME:$NAME") != "$NAME" ]]; then
        gcloud compute addresses create "$NAME" --region "$GCP_REGION"
    else
        echo "Nothing to do. Address $NAME is already exists"
    fi   
}

function gcp_compute_address_delete() {
    NAME=$1
    if [[ $(gcloud compute addresses list --format="value(NAME)" --filter="NAME:$NAME") == "$NAME" ]]; then
        gcloud compute addresses delete "$NAME" --region "$GCP_REGION" --quiet
    else
        echo "Nothing to do. Address $NAME is not exists"
    fi   
}

function gcp_images_delete() {
    NAME=$1
    if [[ $(gcloud container images list --format="value(NAME)" --filter="NAME:$NAME") == "$NAME" ]]; then
        gcloud container images delete $NAME --force-delete-tags --quiet;
    else
        echo "Nothing to do. Image $NAME is not exists"
    fi       
}

function gke_cluster_get_credentials() {
    CLUSTER=$1
    gcloud container clusters get-credentials "$CLUSTER" --zone "$GCP_ZONE"    
}

function gcr_docker_build() {
    NAME=$1; TAG=$2; BUILD_PATH=$3;
    docker build -t "gcr.io/$GCP_PROJECT/$NAME:$TAG" "$BUILD_PATH"
}

function gcr_docker_push() {
    NAME=$1; TAG=$2;
    gcloud docker -- push "gcr.io/$GCP_PROJECT/$NAME:$TAG"
}

function cloud_sql_pg_instance_create() {
    INSTANCE_NAME=$1
    if [[ $(gcloud sql instances list --format="value(NAME)" --filter="NAME:$INSTANCE_NAME" 2>&1) != "$INSTANCE_NAME" ]]; then
        echo "Creating sql instance: $INSTANCE_NAME"
        gcloud sql instances create "$INSTANCE_NAME" \
                   --database-version "${PG_DATABASE_VERSION:-POSTGRES_9_6}" \
                   --region "$GCP_REGION" \
                   --tier "${PG_INSTACE_TIER:-db-f1-micro}" \
                   --storage-type "${PG_INSTACE_STORAGE_TYPE:-HDD}" \
                   --async \
                   --quiet
    else
        echo "Nothing to do. SQL instance is already exists"
    fi

    COUNTER=60
    until [  $COUNTER -lt 2 ]; do
      echo "Waiting for Cloud SQL instance provisioning complete"
      if gcloud sql instances describe "$INSTANCE_NAME" --format="default(state)" | grep -q RUNNABLE; then echo "Done!"; break; fi
      sleep 10; COUNTER=$(( COUNTER - 1 ));
    done

    if [[ $COUNTER -lt 2 ]]; then echo "Sorry, I gave up. Cloud SQL instance creation timed out" && exit 1; fi

}

function cloud_sql_pg_instance_delete() {
    INSTANCE_NAME=$1
    if [[ $(gcloud beta sql instances list --format="value(NAME)" --filter="NAME:$INSTANCE_NAME" 2>&1) == "$INSTANCE_NAME" ]]; then
        echo "Deleting sql instance: $INSTANCE_NAME"
        gcloud beta sql instances delete "$INSTANCE_NAME" --quiet
    else
        echo "Nothing to do. SQL instance is not exists"
    fi
}

function cloud_sql_pg_user_create() {
    USER=$1; PASS=$2; INSTANCE_NAME=$3;
    if [[ $(gcloud sql users list --instance "$INSTANCE_NAME" --format="value(NAME)" --filter="NAME:$USER" 2>&1) != "$USER" ]]; then
        echo "Creating Cloud SQL user: $USER"
        gcloud sql users create "$USER" \
                --host '%' \
                --instance "$INSTANCE_NAME" \
                --password "$PASS"
    else
        echo "Nothing to do. CLoud SQL user already exists"
    fi
}

function cloud_sql_pg_database_create() {
    NAME=$1; INSTANCE_NAME=$2;
    if [[ $(gcloud sql databases list --instance "$INSTANCE_NAME" --format="value(NAME)" --filter="NAME:$NAME" 2>&1) != "$NAME" ]]; then
        echo "Creating Cloud SQL database: $NAME"
        gcloud sql databases create "$NAME" \
                --instance "$INSTANCE_NAME"
    else
        echo "Nothing to do. CLoud SQL database already exists"
    fi
}

function kubectl_create_secret_from_file() {
    NAME=$1; FILE=$2;
    if [[ ! $(kubectl --namespace default get secret "$NAME" 2>&1 | grep -wq "$NAME") ]]; then
    kubectl --namespace default create secret generic "$NAME" \
            --from-file="$FILE"="$FILE"    
    else
        echo "Nothing to do. Secret $NAME is already exists"
    fi
}

function kubectl_create_secret_from_literal() {
    NAME=$1; L_USER=$2; L_PASS=$3;
    if [[ ! $(kubectl --namespace default get secret "$NAME" 2>&1 | grep -wq "$NAME") ]]; then
        kubectl --namespace default create secret generic "$NAME" \
            --from-literal=user="$L_USER" \
            --from-literal=password="$L_PASS"
    else
        echo "Nothing to do. Secret $NAME is already exists"
    fi
}

function kubectl_create_secret_docker_registry() {
    NAME=$1; FILE=$2; EMAIL=$3;
    if [[ ! $(kubectl --namespace default get secret "$NAME" 2>&1 | grep -wq "$NAME") ]]; then
        kubectl --namespace default create secret docker-registry "$NAME" \
            --docker-server="${DOCKER_SERVER:-gcr.io}" \
            --docker-username=_json_key \
            --docker-password="$(cat $FILE)" \
            --docker-email="$EMAIL"
    else
        echo "Nothing to do. Secret $NAME is already exists"
    fi
}

function kubectl_create_config_map() {
    NAME=$1; INSTANCE_NAME=$2;
    CONNECTION_NAME=$(gcloud sql instances describe "$INSTANCE_NAME" --format="value(connectionName)")
    if [[ ! $(kubectl --namespace default get configmap "$NAME" 2>&1 | grep -wq "$NAME") ]]; then
        kubectl --namespace default create configmap "$NAME" \
                --from-literal="$NAME"="$CONNECTION_NAME"
    else
        echo "Nothing to do. ConfigMap $NAME is already exists"
    fi   
}

function update_deployment_file() {
    FILE="$1"
    EXT_IP=$(gcloud compute addresses describe "$GCP_EXT_IP_NAME" --region "$GCP_REGION" --format="value(ADDRESS)"); echo "$EXT_IP" > "$dir/.ext.ipv4"
    sed "s/EXT_IP/$EXT_IP/g; \
         s/DOCKER_TAG/$DOCKER_TAG/g; \
         s/COUNT/$COUNT/g; \
         s/APP_NAME/$APP_NAME/g; \
         s/GCR_CREDS/$GCR_CREDS/g; \
         s/SQL_SA_CREDENTIALS/$SQL_SA_CREDENTIALS/g; \
         s/GCP_PROJECT/$GCP_PROJECT/g" "${FILE}.template" > "$FILE"
}

function kubectl_create_deployment() {
    FILE="$1"
    if [[ ! $(kubectl --namespace default get deployment "$NAME" 2>&1 | grep -wq "$NAME") ]]; then
        kubectl --namespace default create -f "$FILE"
    else
        echo "Nothing to do. Deployment ${APP_NAME}-deployment is already exists"
    fi   
}

function kubectl_deploy() {
    FILE="$1"
    kubectl --namespace default apply -f "$FILE"
    kubectl --namespace default rollout status --request-timeout="5m" -f "$FILE"
}

function iam_service_account_create() {
    SA=$1;
    if [[ $(gcloud iam service-accounts list --format="value(NAME)" --filter="NAME:$SA" 2>&1) != "$SA" ]]; then
        echo "Creating service account: $SA"
        gcloud iam service-accounts create "$SA" --display-name "$SA"
    else
        echo "Nothing to do. Service account already exists"
    fi
}

function iam_service_account_delete() {
    SA=$1;
    if [[ $(gcloud iam service-accounts list --format="value(EMAIL)" --filter="EMAIL:$SA" 2>&1) == "$SA" ]]; then
        echo "Deleting service account: $SA"
        gcloud iam service-accounts delete "$SA" --quiet
    else
        echo "Nothing to do. Service account is not exists"
    fi
}

function iam_service_account_key_create() {
    SA=$1; FILE=$2;
    if [ ! -e "$FILE" ]; then
        gcloud iam service-accounts keys create "$FILE" --iam-account "$SA"
    fi
}

function projects_iam_policy_binding_add() {
    SA=$1; ROLE=$2
    gcloud projects add-iam-policy-binding "$GCP_PROJECT" \
    --member serviceAccount:"$SA" \
    --role "$ROLE" \
    --quiet > /dev/null && echo "Updated IAM policy for [$GCP_PROJECT]. $ROLE added for $SA"
}

function projects_iam_policy_binding_remove() {
    SA=$1; ROLE=$2
    if [[ $(gcloud projects get-iam-policy "$GCP_PROJECT" --flatten="bindings[].members" --format='table(bindings.role)' --filter="bindings.members:$SA" | grep -w "$ROLE") == "$ROLE" ]]; then
        gcloud projects remove-iam-policy-binding "$GCP_PROJECT" \
        --member serviceAccount:"$SA" \
        --role "$ROLE" \
        --quiet 2>&1 > /dev/null && echo "Updated IAM policy for [$GCP_PROJECT]. $SA removed $ROLE"
    else
        echo "Nothing to do. $SA is not a member of $ROLE"
    fi
}
