#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

@test "It should bring up a working PostgreSQL instance" {
  initialize_and_start_pg

  su postgres -c "psql --command \"CREATE TABLE foo (i int);\""
  su postgres -c "psql --command \"INSERT INTO foo VALUES (1234);\""
  run su postgres -c "psql --command \"SELECT * FROM foo;\""
  [ "$status" -eq "0" ]
  [ "${lines[0]}" = "  i   " ]
  [ "${lines[1]}" = "------" ]
  [ "${lines[2]}" = " 1234" ]
  [ "${lines[3]}" = "(1 row)" ]
}

@test "It should protect against CVE-2014-0160" {
  skip
  initialize_and_start_pg
  install-heartbleeder
  ./heartbleeder/heartbleeder -pg localhost
  uninstall-heartbleeder
}

@test "It should require a password" {
  if [ ${AUTH_METHOD} == "trust" ]; then
    skip "Peer auth requires a password, trust does not"
  fi
  initialize_and_start_pg
  run psql -U postgres -l
  [ "$status" -ne "0" ]
}

@test "It should use UTF-8 for the default encoding" {
  initialize_and_start_pg
  su postgres -c "psql -l" | grep en_US.utf8
}

@test "It should support pg_stat_statements" {
  initialize_and_start_pg
  run sudo -u postgres psql --command "CREATE EXTENSION pg_stat_statements;"
  [ "$status" -eq "0" ]
  run sudo -u postgres psql --command "SELECT * FROM pg_stat_statements LIMIT 1;"
  [ "$status" -eq "0" ]
}

@test "It should support PostGIS" {
  initialize_and_start_pg
  run su postgres -c "psql --command \"CREATE EXTENSION postgis;\""
  [ "$status" -eq "0" ]
}

@test "It should dump to stdout by default" {
  initialize_and_start_pg
  run /usr/bin/run-database.sh --dump postgresql://aptible:foobar@127.0.0.1:5432/db
  [ "$status" -eq "0" ]
  [ "${lines[1]}" = "-- PostgreSQL database dump" ]
  [ "${lines[-2]}" = "-- PostgreSQL database dump complete" ]
}

@test "It should restore from stdin by default" {
  initialize_and_start_pg
  /usr/bin/run-database.sh --dump postgresql://aptible:foobar@127.0.0.1:5432/db > /tmp/restore-test
  echo "CREATE TABLE foo (i int);" >> /tmp/restore-test
  echo "INSERT INTO foo VALUES (1);" >> /tmp/restore-test
  run /usr/bin/run-database.sh --restore postgresql://aptible:foobar@127.0.0.1:5432/db < /tmp/restore-test
  rm /tmp/restore-test
  [ "$status" -eq "0" ]
  [ "${lines[-2]}" = "CREATE TABLE" ]
  [ "${lines[-1]}" = "INSERT 0 1" ]
}

@test "It should dump to /dump-output if /dump-output exists" {
  initialize_and_start_pg
  touch /dump-output
  run /usr/bin/run-database.sh --dump postgresql://aptible:foobar@127.0.0.1:5432/db
  [ "$status" -eq "0" ]
  [ "$output" = "" ]
  run cat dump-output
  rm /dump-output
  [ "${lines[1]}" = "-- PostgreSQL database dump" ]
  [ "${lines[-2]}" = "-- PostgreSQL database dump complete" ]
}

@test "It should restore from /restore-input if /restore-input exists" {
  initialize_and_start_pg
  /usr/bin/run-database.sh --dump postgresql://aptible:foobar@127.0.0.1:5432/db > /restore-input
  echo "CREATE TABLE foo (i int);" >> /restore-input
  echo "INSERT INTO foo VALUES (1);" >> /restore-input
  run /usr/bin/run-database.sh --restore postgresql://aptible:foobar@127.0.0.1:5432/db
  rm /restore-input
  [ "$status" -eq "0" ]
  [ "${lines[-2]}" = "CREATE TABLE" ]
  [ "${lines[-1]}" = "INSERT 0 1" ]
}

@test "It should set up a follower with --initialize-from" {
  initialize_and_start_pg
  FOLLOWER_DIRECTORY=/tmp/follower
  FOLLOWER_DATA="${FOLLOWER_DIRECTORY}/data"
  FOLLOWER_CONF="${FOLLOWER_DIRECTORY}/conf"
  FOLLOWER_RUN="${FOLLOWER_DIRECTORY}/run"
  mkdir -p "$FOLLOWER_DIRECTORY"

  MASTER_PORT=5432
  SLAVE_PORT=5433

  # Bring over master conf as template for slave. Use empty data dir.
  cp -pr "$CONF_DIRECTORY" "$FOLLOWER_CONF"
  mkdir "$FOLLOWER_DATA"
  mkdir "$FOLLOWER_RUN" && chown postgres:postgres "$FOLLOWER_RUN"

  MASTER_URL="postgresql://aptible:foobar@127.0.0.1:$MASTER_PORT/db"
  SLAVE_URL="postgresql://aptible:foobar@127.0.0.1:$SLAVE_PORT/db"

  DATA_DIRECTORY="$FOLLOWER_DATA" CONF_DIRECTORY="$FOLLOWER_CONF" RUN_DIRECTORY="$FOLLOWER_RUN" PORT="$SLAVE_PORT" \
    /usr/bin/run-database.sh --initialize-from "$MASTER_URL"

  DATA_DIRECTORY="$FOLLOWER_DATA" CONF_DIRECTORY="$FOLLOWER_CONF" RUN_DIRECTORY="$FOLLOWER_RUN" PORT="$SLAVE_PORT" \
    /usr/bin/run-database.sh &

  until run-database.sh --client "$SLAVE_URL" --command '\dt'; do sleep 0.1; done
  run-database.sh --client "$MASTER_URL" --command "CREATE TABLE foo (i int);"
  run-database.sh --client "$MASTER_URL" --command "INSERT INTO foo VALUES (1234);"
  until run-database.sh --client "$SLAVE_URL" --command "SELECT * FROM foo;"; do sleep 0.1; done

  run run-database.sh --client "$SLAVE_URL" --command "SELECT * FROM foo;"
  [ "$status" -eq "0" ]
  [ "${lines[0]}" = "  i   " ]
  [ "${lines[1]}" = "------" ]
  [ "${lines[2]}" = " 1234" ]
  [ "${lines[3]}" = "(1 row)" ]

  kill $(cat "$FOLLOWER_RUN/$PG_VERSION-main.pid")
  rm -rf "$FOLLOWER_DIRECTORY"
}
