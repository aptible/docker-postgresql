#!/usr/bin/env bats

@test "It should install PostgreSQL 12.4" {
  /usr/lib/postgresql/12/bin/postgres --version | grep "12.4"
}

@test "This image needs to forever support PostGIS 2.5" {
  run dpkg --status  postgresql-12-postgis-2.5

  [[ "$output" =~ "Status: install ok installed" ]]
}
