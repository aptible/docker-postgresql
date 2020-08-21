#!/usr/bin/env bats

@test "It should install PostgreSQL 9.4.26" {
  /usr/lib/postgresql/9.4/bin/postgres --version | grep "9.4.26"
}

@test "This image needs to forever support PostGIS 2.1" {
  run dpkg --status  postgresql-9.4-postgis-2.1

  [[ "$output" =~ "Status: install ok installed" ]]
}