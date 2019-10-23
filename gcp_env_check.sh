#!/usr/bin/env bash 

if ! which -s gcloud; then echo "Error: gcloud is not installed" && exit 1; fi
if ! which -s kubectl; then echo "Error: kubectl is not installed" && exit 1; fi

GCP_PROJECT=$(gcloud config get-value core/project)
if [ "$GCP_PROJECT" != "" ]; then
    export GCP_PROJECT=$GCP_PROJECT; echo "Your default GCP project is $GCP_PROJECT";
else 
    echo "Error: GCP_PROJECT is not set.";
    echo "Please follow the instructions and run 'gcloud init' first" && exit 1;
fi

GCP_REGION=$(gcloud config get-value compute/region)
if [ "$GCP_REGION" != "" ]; then
    export GCP_REGION=$GCP_REGION; echo "Your default GCP region is $GCP_REGION";
else 
    echo "Error: GCP_REGION is not set.";
    echo "Please choose your default GCP region and run 'gcloud config set compute/region REGION'" && exit 1;
fi

GCP_ZONE=$(gcloud config get-value compute/zone)
if [ "$GCP_ZONE" != "" ]; then
    export GCP_ZONE=$GCP_ZONE; echo "Your default GCP zone is $GCP_ZONE";
else 
    echo "Error: GCP_ZONE is not set.";
    echo "Please choose your default GCP zone and run 'gcloud config set compute/zone ZONE'" && exit 1;
fi
