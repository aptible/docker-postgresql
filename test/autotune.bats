#!/usr/bin/env bats

@test "autotune should pass its self-tests" {
  /usr/local/bin/autotune --test
}
