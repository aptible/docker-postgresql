#!/usr/bin/env bats

@test "It should install PostgreSQL 9.5.22" {
  /usr/lib/postgresql/9.5/bin/postgres --version | grep "9.5.22"
}

@test "This image needs to forever support PostGIS 2.2" {
  run dpkg --status  postgresql-9.5-postgis-2.2

  [[ "$output" =~ "Status: install ok installed" ]]
}
