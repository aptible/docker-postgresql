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

@test "It should autotune for a 512MB container" {
  APTIBLE_CONTAINER_SIZE=512 initialize_and_start_pg
  gosu postgres psql db -c'SHOW shared_buffers;' | grep 128MB
}

@test "It should autotune for a 1GB container" {
  APTIBLE_CONTAINER_SIZE=1024 initialize_and_start_pg
  gosu postgres psql db -c'SHOW shared_buffers;' | grep 256MB
}

@test "It should autotune for a 2GB container" {
  APTIBLE_CONTAINER_SIZE=2048 initialize_and_start_pg
  gosu postgres psql db -c'SHOW shared_buffers;' | grep 512MB
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
  url="postgresql://aptible:foobar@127.0.0.1:5432/db"

  initialize_and_start_pg
  run-database.sh --dump "$url" \
    | grep "PostgreSQL database dump complete"
}

@test "It should restore from stdin by default" {
  url="postgresql://aptible:foobar@127.0.0.1:5432/db"

  initialize_and_start_pg
  run-database.sh --client "$url" -c "CREATE TABLE foos (i TEXT);"
  run-database.sh --client "$url" -c "INSERT INTO foos VALUES('canary');"
  run-database.sh --dump "$url" > /tmp/restore-test

  run-database.sh --client "$url" -c "DROP TABLE foos;"

  run /usr/bin/run-database.sh --restore "$url" < /tmp/restore-test
  rm /tmp/restore-test

  run-database.sh --client "$url" -c "SELECT * FROM foos;" | grep 'canary'
}

@test "It should dump to /dump-output if /dump-output exists" {
  out="/dump-output"
  initialize_and_start_pg

  touch "$out"
  /usr/bin/run-database.sh --dump postgresql://aptible:foobar@127.0.0.1:5432/db

  grep "PostgreSQL database dump complete" "$out"
  rm "$out"
}

@test "It should restore from /restore-input if /restore-input exists" {
  in="/restore-input"
  url="postgresql://aptible:foobar@127.0.0.1:5432/db"

  initialize_and_start_pg
  run-database.sh --client "$url" -c "CREATE TABLE foos (i TEXT);"
  run-database.sh --client "$url" -c "INSERT INTO foos VALUES('canary');"
  run-database.sh --dump "$url" > "$in"

  run-database.sh --client "$url" -c "DROP TABLE foos;"

  run /usr/bin/run-database.sh --restore "$url"
  rm "$in"

  run-database.sh --client "$url" -c "SELECT * FROM foos;" | grep 'canary'
}

@test "It should use ICU as default collation for PostgreSQL 15 and beyond" {
  skip 'keeping for future usage, but we are sticking with glibc for the immediate future'
  versions-only ge 15
  url="postgresql://aptible:foobar@127.0.0.1:5432/db"
  initialize_and_start_pg
  gosu postgres psql db -c'select datlocprovider from pg_database where datname=current_database();' | grep 'i'
}

@test "It should be collation version 153.14 for PostgreSQL 15 and beyond" {
  skip 'keeping for future usage, but we are sticking with glibc for the immediate future'
  versions-only ge 15
  url="postgresql://aptible:foobar@127.0.0.1:5432/db"
  initialize_and_start_pg
  gosu postgres psql db -c'select datcollversion from pg_database where datname=current_database();' | grep '153.14'
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

  if dpkg --compare-versions "$PG_VERSION" ge '9.6'; then
    run sudo -u postgres psql --command "select slot_type from pg_replication_slots;"
      echo $lines
    [ "$status" -eq "0" ]
    [ "${lines[2]}" = " physical" ]
    [ "${lines[3]}" = "(1 row)" ]
   fi

  kill $(cat "$FOLLOWER_RUN/$PG_VERSION-main.pid")
  rm -rf "$FOLLOWER_DIRECTORY"
}

@test "It should set up a follower not using replication slots with NO_SLOTS set" {
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

  NO_SLOTS=1 DATA_DIRECTORY="$FOLLOWER_DATA" CONF_DIRECTORY="$FOLLOWER_CONF" RUN_DIRECTORY="$FOLLOWER_RUN" PORT="$SLAVE_PORT" \
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

  run sudo -u postgres psql --command "select slot_type from pg_replication_slots;"
  [ "$status" -eq "0" ]
  [ "${lines[2]}" = "(0 rows)" ]
  
  kill $(cat "$FOLLOWER_RUN/$PG_VERSION-main.pid")
  rm -rf "$FOLLOWER_DIRECTORY"
}

@test "It prints the persistent configuration changes on boot." {
  initialize_and_start_pg
  echo "log_min_duration_statement = 12345" >> "${DATA_DIRECTORY}/postgresql.auto.conf"

  restart_pg
  grep "persistent configuration changes" /tmp/postgres.log
  grep "log_min_duration_statement" /tmp/postgres.log
}

@test "It does not print primary_conninfo with the persistent configuration changes." {
  versions-only ge 12
  initialize_and_start_pg
  echo " primary_conninfo = '12345'" >> "${DATA_DIRECTORY}/postgresql.auto.conf"

  restart_pg
  grep "persistent configuration changes" /tmp/postgres.log
  ! grep "primary_conninfo =" /tmp/postgres.log
}

@test "It should support pglogical" {
  
  dpkg-query -l postgresql-${PG_VERSION}-pglogical
  initialize_and_start_pg
  sudo -u postgres psql --command "ALTER SYSTEM SET shared_preload_libraries='pglogical';"
  restart_pg
  echo "$PG_VERSION"
  sudo -u postgres psql --command "CREATE EXTENSION pglogical;"
}

@test "It avoids upgrading to problematic glibc versions" {
  # https://wiki.postgresql.org/wiki/Locale_data_changes
  # Need to be sure for now that we're only building images with glibc before 2.28
  versions-only le 14
  BAD="2.28"
  INSTALLED=$(ldd --version | head -n 1 | grep -oE '[^ ]+$')
  NEWEST=$(printf "${INSTALLED}\n${BAD}" | sort --version-sort | tail -n 1)

  [ ${NEWEST} != ${INSTALLED} ]
}

@test "It should be using glibc version 2.31 on Debian 11" {
  versions-only ge 15
  VER="2.31"
  INSTALLED=$(ldd --version | head -n 1 | grep -oE '[^ ]+$')

  [ VER != ${INSTALLED} ]
}

@test "It includes a valid TZ data" {
  test -f /usr/share/zoneinfo/America/New_York
}

@test "It includes an updated TZ data" {
  test -f /usr/share/zoneinfo/America/Ciudad_Juarez
}

@test "It should support pg_repack" {
  versions-only ge 14

  dpkg-query -l postgresql-${PG_VERSION}-repack

  initialize_and_start_pg
  sudo -u postgres psql --command "ALTER SYSTEM SET shared_preload_libraries='pg_repack';"
  restart_pg
  sudo -u postgres psql --command "CREATE EXTENSION pg_repack;"
  sudo -u postgres pg_repack --dry-run
}

@test "It should support pgvector" {
  versions-only ge 15

  dpkg-query -l postgresql-${PG_VERSION}-repack

  initialize_and_start_pg
  sudo -u postgres psql --command "CREATE EXTENSION vector;"
  sudo -u postgres psql --command "CREATE TABLE items (id bigserial PRIMARY KEY, embedding vector(3));"
  sudo -u postgres psql --command "DROP TABLE items;"
}