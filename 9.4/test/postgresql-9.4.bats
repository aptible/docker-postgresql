#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 9.4.26" {
  /usr/lib/postgresql/9.4/bin/postgres --version | grep "9.4.26"
}

@test "It should support some version of PostGIS" {
  # The versioning of the packages that gets installed is all messed up,
  # but this version is deprecated so there's no need to make changes.

  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis;\""
  [ "$status" -eq "0" ]
}
