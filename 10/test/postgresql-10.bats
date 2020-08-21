#!/usr/bin/env bats

@test "It should install PostgreSQL 10.13" {
  /usr/lib/postgresql/10/bin/postgres --version | grep "10.13"
}

@test "This image needs to forever support PostGIS 2.4" {
  run dpkg --status  postgresql-10-postgis-2.4

  [[ "$output" =~ "Status: install ok installed" ]]
}
