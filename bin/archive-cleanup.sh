#!/usr/bin/env bash

set -o nounset

find "$ARCHIVE_DIRECTORY" -mtime +2 -exec rm {} \;
