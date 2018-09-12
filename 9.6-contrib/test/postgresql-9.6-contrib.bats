#!/usr/bin/env bats

@test "It should install PostgreSQL 9.6.10" {
  /usr/lib/postgresql/9.6/bin/postgres --version | grep "9.6.10"
}

