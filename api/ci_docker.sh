#!/usr/bin/env bash

set -ex

PROJECT_NAME=$(echo "${JOB_NAME}${BUILD_NUMBER}" | tr -d -)
PROJECT_NAME=${PROJECT_NAME:-sample}
COMPOSE_ARGS="-p ${PROJECT_NAME}"

cleanup() {
  docker-compose $COMPOSE_ARGS stop
  docker-compose $COMPOSE_ARGS rm -f -v
}
trap cleanup EXIT

cleanup
docker-compose $COMPOSE_ARGS build
docker-compose $COMPOSE_ARGS run --rm ci
docker cp $(docker-compose $COMPOSE_ARGS ps -q ci_output):/root/app/target ./docker_build
