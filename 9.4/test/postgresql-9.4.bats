#!/usr/bin/env bats

@test "It should install PostgreSQL 9.4.26" {
  /usr/lib/postgresql/9.4/bin/postgres --version | grep "9.4.26"
}
