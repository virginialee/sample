#!/usr/bin/env bash

set -ex

if [ $# -ne 2 ]
  then
    echo "You must provide env and dbHost arguments"
    exit 1
fi

env=$1
dbHost=$2

activator clean
activator compile
activator db-migrate -Dflyway.url=jdbc:postgresql://${dbHost}:5432/coa
activator check
activator -Denv=${env:-ci} report
