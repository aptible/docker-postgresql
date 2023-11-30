#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 15.5" {
  /usr/lib/postgresql/15/bin/postgres --version | grep "15.5"
}

@test "This image needs to forever support PostGIS 3" {

  check_postgis "3"

  full=$(get_full_postgis_version "3")

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis VERSION '${full}';\""
  [ "$status" -eq "0" ]
}
