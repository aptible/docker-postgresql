#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 10.14" {
  /usr/lib/postgresql/10/bin/postgres --version | grep "10.14"
}

@test "This image needs to forever support PostGIS 2.4" {

  check_postgis "2.4"

  full=$(get_full_postgis_version "2.4")

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis VERSION '${full}';\""
  [ "$status" -eq "0" ]
}
