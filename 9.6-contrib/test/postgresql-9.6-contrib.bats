#!/usr/bin/env bats

@test "It should install PostgreSQL 9.6.18" {
  /usr/lib/postgresql/9.6/bin/postgres --version | grep "9.6.18"
}

@test "This image needs to forever support PostGIS 2.3" {
  run dpkg --status  postgresql-9.6-postgis-2.3

  [[ "$output" =~ "Status: install ok installed" ]]
}
