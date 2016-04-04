#!/usr/bin/env bash

set -ex

if [ $# -ne 1 ]
  then
    echo "You must provide env argument"
    exit 1
fi

env=$1

activator clean
activator compile
activator check
activator -Denv=${env:-ci} report
