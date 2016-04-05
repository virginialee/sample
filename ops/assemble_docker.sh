#!/usr/bin/env bash

# Refer to http://ss64.com/bash/set.html
# -e Exit immediately if a simple command exits with a non-zero status
# -x Print a trace of simple commands and their arguments after they are expanded and before they are executed
# -u Treat unset variables as an error when performing parameter expansion. An error message will be written to the standard error,
#    and a non-interactive shell will exit
set -exu

export ASSEMBLE_VERSION=$1
echo Assembling $ASSEMBLE_VERSION

PROJECT_NAME=$(echo "${JOB_NAME}${BUILD_NUMBER}" | tr -d -)
PROJECT_NAME=${PROJECT_NAME:-sample-ops-assemble}
COMPOSE_ARGS="-p ${PROJECT_NAME} -f docker-compose-assemble.yml"

cleanup() {
  docker-compose $COMPOSE_ARGS stop
  docker-compose $COMPOSE_ARGS rm -f -v
}
trap cleanup EXIT

cleanup

docker-compose $COMPOSE_ARGS build

mkdir -p ./docker_build

docker-compose $COMPOSE_ARGS run --rm api_dist
docker cp $(docker-compose $COMPOSE_ARGS ps -q api_dist_output):/root/app/target/universal/sample-1.0-SNAPSHOT.zip ./docker_build/sample-1.0-SNAPSHOT.zip

docker-compose $COMPOSE_ARGS run --rm ops_ami
docker cp $(docker-compose $COMPOSE_ARGS ps -q ops_output):/root/app/tasks/out ./docker_build

