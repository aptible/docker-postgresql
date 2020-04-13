#!/usr/bin/env bats

@test "It should install PostgreSQL 11.7" {
  /usr/lib/postgresql/11/bin/postgres --version | grep "11.7"
}
