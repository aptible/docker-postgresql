#!/bin/bash

setup() {
  export OLD_DATA_DIRECTORY="$DATA_DIRECTORY"
  export DATA_DIRECTORY=/tmp/datadir
  mkdir "$DATA_DIRECTORY"

  export OLD_ARCHIVE_DIRECTORY="$ARCHIVE_DIRECTORY"
  export ARCHIVE_DIRECTORY=/tmp/archive
  mkdir "$ARCHIVE_DIRECTORY"

  export WORK_DIR=/tmp/work
}

teardown() {
  stop_pg

  rm -rf "$DATA_DIRECTORY"
  rm -rf "$ARCHIVE_DIRECTORY"
  export DATA_DIRECTORY="$OLD_DATA_DIRECTORY"
  export ARCHIVE_DIRECTORY="$OLD_ARCHIVE_DIRECTORY"

  unset OLD_DATA_DIRECTORY
  unset OLD_ARCHIVE_DIRECTORY

  rm -f "${CONF_DIRECTORY}/postgresql.conf"
  rm -rf "${CONF_DIRECTORY}/ssl"

  rm -rf "$WORK_DIR"
  unset WORK_DIR

  # Be safe and delete those should a test leave them behind.
  rm -f "/restore-input" "/dump-output"
}

initialize_and_start_pg() {
  PASSPHRASE=foobar /usr/bin/run-database.sh --initialize
  start_pg
}

wait_for_pg() {
  for _ in $(seq 1 60); do
    if /etc/init.d/postgresql status; then
      return 0
    fi
    sleep 1
  done
  echo "Database timed out"
  return 1
}

stop_pg() {
  /etc/init.d/postgresql stop || true
  while /etc/init.d/postgresql status; do sleep 0.1; done
}

start_pg() {
  /usr/bin/run-database.sh > /tmp/postgres.log 2>&1 &
  wait_for_pg
}

restart_pg() {
  stop_pg
  start_pg
}

install-heartbleeder() {
  wget http://gobuild.io/github.com/titanous/heartbleeder/master/linux/amd64
  mv amd64 heartbleeder.zip
  unzip heartbleeder.zip -d heartbleeder/
}

uninstall-heartbleeder() {
  rm -rf heartbleeder.zip heartbleeder
}

versions-only() {
  if ! dpkg --compare-versions "$PG_VERSION" $@; then
    skip "not available in $TAG"
  fi
}
