#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should install PostgreSQL 9.6.1" {
  run /usr/lib/postgresql/9.6.1/bin/postgres --version
  [[ "$output" =~ "9.6.1"  ]]
}

@test "It should support PLV8" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION plv8;"
  sudo -u postgres psql --command "CREATE EXTENSION plls;"
  sudo -u postgres psql --command "CREATE EXTENSION plcoffee;"
}

@test "It should support plpythonu" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION plpythonu;"
}

@test "It should support plpython2u" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION plpython2u;"
}

@test "It should support plpython3u" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION plpython3u;"
}

@test "It should support multicorn" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION multicorn;"
}

@test "It should support plperl" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE LANGUAGE plperl;" 
}

@test "It should support plperlu" {
  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE LANGUAGE plperlu;" 
}
