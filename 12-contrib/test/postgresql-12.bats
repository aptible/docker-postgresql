#!/usr/bin/env bats

@test "It should install PostgreSQL 12.3" {
  /usr/lib/postgresql/12/bin/postgres --version | grep "12.3"
}
