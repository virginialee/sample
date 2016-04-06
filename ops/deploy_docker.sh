#!/usr/bin/env bash

set -exu

export DEPLOY_VERSION=$1
export DEPLOY_ENVIRONMENT=$2
export DEPLOY_AMI=${3:-''}
echo Deploying $DEPLOY_VERSION $DEPLOY_AMI to $DEPLOY_ENVIRONMENT

PROJECT_NAME=$(echo "${JOB_NAME}${BUILD_NUMBER}" | tr -d -)
PROJECT_NAME=${PROJECT_NAME:-sample-ops-deploy}
COMPOSE_ARGS="-p ${PROJECT_NAME} -f docker-compose-deploy.yml"

cleanup() {
  docker-compose $COMPOSE_ARGS stop
  docker-compose $COMPOSE_ARGS rm -f -v
}
trap cleanup EXIT

cleanup

docker-compose $COMPOSE_ARGS build
docker-compose $COMPOSE_ARGS run --rm ops_deploy
