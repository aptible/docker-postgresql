#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 9.3.25" {
  /usr/lib/postgresql/9.3/bin/postgres --version | grep "9.3.25"
}

@test "It should support tds_fdw" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION tds_fdw;"
}

@test "It should support pg_proctab" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION pg_proctab;"
}

@test "This image needs to forever support PostGIS 2.1" {
  run dpkg --status  postgresql-9.3-postgis-2.1

  [[ "$output" =~ "Status: install ok installed" ]]
}
