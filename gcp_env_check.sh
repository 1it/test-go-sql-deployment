#!/usr/bin/env bash 

if ! which -s gcloud; then echo "gcloud is not installed" && exit 1; fi
if ! which -s kubectl; then echo "kubectl is not installed" && exit 1; fi

# OS=$(uname -s)
GCP_PROJECT=$(gcloud config get-value core/project)
GCP_REGION=$(gcloud config get-value compute/region)
GCP_ZONE=$(gcloud config get-value compute/zone)

if [ ! -z "$GCP_PROJECT" ]; then 
    export GCP_PROJECT=$GCP_PROJECT; 
else 
    echo "GCP_PROJECT is not set. Please follow the instructions and run 'gcloud init' first"
fi

if [ ! -z "$GCP_REGION" ]; then 
    export GCP_REGION=$GCP_REGION; 
else 
    echo "GCP_REGION is not set. Please run 'gcloud init' and choose your default region"
fi

if [ ! -z "$GCP_ZONE" ]; then 
    export GCP_ZONE=$GCP_ZONE; 
else 
    echo "GCP_ZONE is not set. Please run 'gcloud init' and choose your default zone"
fi
 
