#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 9.5.15" {
  /usr/lib/postgresql/9.5/bin/postgres --version | grep "9.5.15"
}

@test "It should support pg_cron" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION pg_cron;"
}
