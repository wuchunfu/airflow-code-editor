#!/usr/bin/env bash
set -e

export CURRENT_DIR=`realpath $(dirname "$0")`

source "${CURRENT_DIR}/activate.sh"
source "${CURRENT_DIR}/config.sh"
airflow "$@"
