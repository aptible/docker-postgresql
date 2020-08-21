#!/usr/bin/env bats

@test "It should install PostgreSQL 9.5.23" {
  /usr/lib/postgresql/9.5/bin/postgres --version | grep "9.5.23"
}
