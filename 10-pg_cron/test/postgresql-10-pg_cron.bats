#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 10.19" {
  /usr/lib/postgresql/10/bin/postgres --version | grep "10.19"
}

@test "It should support pg_cron" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION pg_cron;"
}

@test "This image needs to forever support PostGIS 2.4" {

  check_postgis "2.4"

  full=$(get_full_postgis_version "2.4")

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
