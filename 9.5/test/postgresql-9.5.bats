#!/usr/bin/env bats

@test "It should install PostgreSQL 9.5.15" {
  /usr/lib/postgresql/9.5/bin/postgres --version | grep "9.5.15"
}
