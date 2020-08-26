#!/usr/bin/env bats

@test "It should install PostgreSQL 9.4.26" {
  /usr/lib/postgresql/9.4/bin/postgres --version | grep "9.4.26"
}

@test "This image needs to forever support PostGIS 2.1" {

  check_postgis "2.1"

  full=$(get_full_postgis_version "2.1")

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis VERSION '${full}';\""
  [ "$status" -eq "0" ]
}
