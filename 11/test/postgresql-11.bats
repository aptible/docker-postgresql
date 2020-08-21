#!/usr/bin/env bats

@test "It should install PostgreSQL 11.9" {
  /usr/lib/postgresql/11/bin/postgres --version | grep "11.9"
}

@test "This image needs to forever support PostGIS 2.5" {
  run dpkg --status  postgresql-11-postgis-2.5

  [[ "$output" =~ "Status: install ok installed" ]]
}
