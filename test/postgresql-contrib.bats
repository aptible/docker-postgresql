#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

contrib-only() {
  if [[ ! "$TAG" =~ .*-contrib ]]; then
  	skip "-contrib only"
  fi
}

versions-only() {
  if ! dpkg --compare-versions "$PG_VERSION" $@; then
    skip "not available in $TAG"
  fi
}

@test "It should support PLV8" {
  contrib-only
  
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION plv8;"
  sudo -u postgres psql --command "CREATE EXTENSION plls;"
  sudo -u postgres psql --command "CREATE EXTENSION plcoffee;"
}


@test "It should support plpythonu" {
  contrib-only

  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION plpythonu;"
}

@test "It should support plpython2u" {
  contrib-only

  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION plpython2u;"
}

@test "It should support plpython3u" {
  contrib-only

  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION plpython3u;"
}


@test "It should support plperl" {
  contrib-only

  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE LANGUAGE plperl;"
}

@test "It should support plperlu" {
  contrib-only

  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE LANGUAGE plperlu;"
}

@test "It should support mysql_fdw" {
  contrib-only

  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION mysql_fdw;"
}

@test "It should support multicorn" {
  contrib-only

  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION multicorn;"
}

@test "It should support wal2json" {
  contrib-only
  versions-only ge 9.4

  initialize_and_start_pg
  sudo -u postgres psql --command "ALTER SYSTEM SET wal_level='logical';"
  sudo -u postgres psql --command "ALTER SYSTEM SET max_replication_slots=1;"
  restart_pg
  sudo -u postgres psql --command "SELECT 'init' FROM pg_create_logical_replication_slot('test_slot', 'wal2json');"
  sudo -u postgres psql --command "SELECT 'stop' FROM pg_drop_replication_slot('test_slot');"
}

@test "It should support pgaudit" {
  contrib-only
  versions-only ge 9.5

  dpkg-query -l "postgresql-${PG_VERSION}-pgaudit"
  initialize_and_start_pg
  sudo -u postgres psql --command "ALTER SYSTEM SET shared_preload_libraries='pgaudit';"
  restart_pg
  sudo -u postgres psql --command "CREATE EXTENSION pgaudit;"
}

@test "It should support pg-safeupdate" {
  contrib-only
  versions-only ge 9.4

  initialize_and_start_pg
  sudo -u postgres psql --command "ALTER SYSTEM SET shared_preload_libraries='safeupdate';"
  restart_pg
  sudo -u postgres psql --command "CREATE TABLE foo (i int);"
  sudo -u postgres psql --command "INSERT INTO foo VALUES (1234);"
  run sudo -u postgres psql --command "DELETE FROM foo;"
  [ "$status" -eq "1" ]
  [ "${lines[0]}" = "ERROR:  DELETE requires a WHERE clause" ]
}

@test "It should support pglogical" {
  contrib-only
  versions-only ge 9.4

  dpkg-query -l postgresql-${PG_VERSION}-pglogical
  initialize_and_start_pg
  sudo -u postgres psql --command "ALTER SYSTEM SET shared_preload_libraries='pglogical';"
  restart_pg
  echo "$PG_VERSION"
  if dpkg --compare-versions "$PG_VERSION" eq 9.4; then
    sudo -u postgres psql --command "CREATE EXTENSION pglogical_origin;"
  fi
  sudo -u postgres psql --command "CREATE EXTENSION pglogical;"
}
