#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 12.9" {
  /usr/lib/postgresql/12/bin/postgres --version | grep "12.9"
}

@test "This image needs to forever support PostGIS 2.5" {

  check_postgis "2.5"

  full=$(get_full_postgis_version "2.5")

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis VERSION '${full}';\""
  [ "$status" -eq "0" ]
}

@test "It also supports PostGIS 3" {
  skip
  check_postgis "3"

  full=$(get_full_postgis_version "3")

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis VERSION '${full}';\""
  [ "$status" -eq "0" ]
}
