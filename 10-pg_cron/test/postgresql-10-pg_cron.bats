#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 10.13" {
  /usr/lib/postgresql/10/bin/postgres --version | grep "10.13"
}

@test "It should support pg_cron" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION pg_cron;"
}

@test "This image needs to forever support PostGIS 2.4" {
  run dpkg --status  postgresql-10-postgis-2.4

  [[ "$output" =~ "Status: install ok installed" ]]
}
