#!/usr/bin/env bats

@test "It should install PostgreSQL 11.9" {
  /usr/lib/postgresql/11/bin/postgres --version | grep "11.9"
}
