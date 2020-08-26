#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 9.6.18" {
  /usr/lib/postgresql/9.6/bin/postgres --version | grep "9.6.18"
}

@test "This image needs to forever support PostGIS 2.3" {

  check_postgis "2.3"

  full=$(get_full_postgis_version "2.3")

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis VERSION '${full}';\""
  [ "$status" -eq "0" ]
}
