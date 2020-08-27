#!/bin/bash

versions-only() {
  if ! dpkg --compare-versions "$PG_VERSION" $@; then
    skip "not available in $TAG"
  fi
}

setup() {
  export OLD_DATA_DIRECTORY="$DATA_DIRECTORY"
  export DATA_DIRECTORY=/tmp/datadir
  mkdir "$DATA_DIRECTORY"

  export WORK_DIR=/tmp/work
}

teardown() {
  stop_pg

  rm -rf "$DATA_DIRECTORY"
  export DATA_DIRECTORY="$OLD_DATA_DIRECTORY"
  unset OLD_DATA_DIRECTORY

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

get_full_postgis_version()
{
  major=$1

  dpkg-query --showformat='${Version}' --show "postgresql-${PG_VERSION}-postgis-${major}" | awk -F '+' '{print $1}'
}

check_postgis() {
  major=$1

  check_postgis_library $major
  check_postgis_scripts $major
}

check_postgis_library() {
  major=$1

  # Ensure the library is available to support already-installed version of PostGIS
  [[ -f /usr/lib/postgresql/${PG_VERSION}/lib/postgis-${major}.so ]]
}


check_postgis_scripts() {
  major=$1

  # Ensure the scripts are available to install this version of PostGIS
  dpkg --status  postgresql-${PG_VERSION}-postgis-${major}-scripts | grep "Status: install ok installed"
}

