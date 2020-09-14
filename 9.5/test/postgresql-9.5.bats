#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 9.5.23" {
  /usr/lib/postgresql/9.5/bin/postgres --version | grep "9.5.23"
}

@test "This image needs to forever support PostGIS 2.3 where it is already installed" {
  check_postgis_library 2.3
}

@test "This image needs to forever support PostGIS 2.4 where it is already installed" {
  check_postgis_library 2.4
}

@test "This image needs to forever support PostGIS 2.5 where it is already installed" {
  check_postgis_library 2.5
}

@test "This image needs to forever support PostGIS 2.5 where it is already installed" {
  check_postgis_library 3
}

@test "This image should support installing PostGIS 2.5" {

  check_postgis "2.5"

  full=$(get_full_postgis_version "2.5")

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis VERSION '${full}';\""
  [ "$status" -eq "0" ]
}

@test "This image should support installing PostGIS 3" {

  check_postgis "3"

  full=$(get_full_postgis_version "3")

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis VERSION '${full}';\""
  [ "$status" -eq "0" ]
}
