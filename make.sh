#!/usr/bin/env bash

# Error Handling
function on_error() {
    echo "error: [ ${BASH_SOURCE[1]} at line ${BASH_LINENO[0]} ]";
}

set -o errtrace
trap on_error ERR

dir="$(dirname "$0")"
source "${dir}/gcp_provisioning.sh"

function docker_build() {
    docker-compose up -d --build
}

function docker_cleanup() {
    docker-compose down
    docker system prune
}

function usage() {
    echo "Usage: ./make.sh option"
    echo "Options: docker-build, -- run docker-compose up -d --build"
    echo "         docker-cleanup -- run docker-compose down & system prune"
    echo "         gcp-build (optional flag: -t v0.x.x), -- build Docker image and push to gcr.io"
    echo "         gcp-create, -- run GCP provisioning and deployment"
    echo "         gcp-destroy, -- destroy GCP resorces"
    echo "Examples: "
    echo "         ./make.sh -t 0.1.10 gcp-build"
    echo "         ./make.sh -t 0.1.10 -c 3 gcp-deploy"
}

while [[ $# -gt 0 ]]; do
    case $1 in
        gcp-build)
        gcp_build "$TAG";
        shift
        ;;
        gcp-create)
        gcp_create;
        ./test.sh remote;
        shift
        ;;
        gcp-deploy)
        gcp_deploy "$TAG" "$COUNT";
        ./test.sh remote;
        shift
        ;;
        gcp-destroy)
        gcp_destroy;
        shift
        ;;
        docker-build)
        docker_build;
        ./test.sh local;
        shift
        ;;
        docker-cleanup)
        docker_cleanup;
        shift
        ;;
        -t)
        TAG=$2;
        shift
        ;;
        -c)
        COUNT=$3;
        shift
        ;;        
        test)
        test;
        shift
        ;;
        --help|help)
        usage;
        shift
        ;;
        *)
        echo "Check ./make.sh help for more information";
        shift
    esac
done
