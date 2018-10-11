#!/usr/bin/env bash

set -e
set -o nounset

PATH_TO_FILE="$1"
WAL_FILE_NAME="$2"

notify () {
  sudo -u root /usr/bin/pagerduty-notify.sh
}

trap 'notify' ERR

test ! -f "${ARCHIVE_DIRECTORY}/${WAL_FILE_NAME}"
cp "${DATA_DIRECTORY}/${PATH_TO_FILE}" "${ARCHIVE_DIRECTORY}/${WAL_FILE_NAME}"

archive-cleanup.sh
