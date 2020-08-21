#!/usr/bin/env bats

@test "It should install PostgreSQL 9.3.25" {
  /usr/lib/postgresql/9.3/bin/postgres --version | grep "9.3.25"
}

@test "This image needs to forever support PostGIS 2.1" {
  run dpkg --status  postgresql-9.3-postgis-2.1

  [[ "$output" =~ "Status: install ok installed" ]]
}