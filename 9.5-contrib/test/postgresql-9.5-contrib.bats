#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 9.5.22" {
  /usr/lib/postgresql/9.5/bin/postgres --version | grep "9.5.22"
}

@test "It should support tds_fdw" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION tds_fdw;"
}

@test "This image needs to forever support PostGIS 2.2 where it is already installed" {
  check_postgis_library 2.2
}

@test "This image needs to forever support PostGIS 2.2 where it is already installed" {
  check_postgis_library 2.3
}

@test "This image should support installing PostGIS 2.4" {

  check_postgis "2.4"

  full=$(get_full_postgis_version "2.4")

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis VERSION '${full}';\""
  [ "$status" -eq "0" ]
}
