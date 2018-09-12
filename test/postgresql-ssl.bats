#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/test_helper.sh"

PG_URL="postgresql://aptible:foobar@127.0.0.1:5432/db"

make_random_cert() {
  local cert_dir="${WORK_DIR}/cert"

  export SSL_CERTIFICATE_PATH="${dir}/server.crt"
  export SSL_KEY_PATH="${dir}/server.key"

  SUBJ="/C=US/ST=New York/L=New York/O=Example/CN=MyPostgreSQL"
  openssl req -nodes -new -x509 -sha256 -subj "$SUBJ" \
    -out "$SSL_CERTIFICATE_PATH" -keyout "$SSL_KEY_PATH"
}

@test "It should auto-generate a SSL certificate at --initialize, and reuse it at runtime" {
  initialize_and_start_pg

  FULL_URL="${PG_URL}?sslmode=verify-ca&sslrootcert=${CONF_DIRECTORY}/ssl/server.crt"
  psql "${FULL_URL}" -c "\dt"

  # However, using another cert should trigger an error.
  make_random_cert
  FULL_URL="${PG_URL}?sslmode=verify-ca&sslrootcert=${SSL_CERTIFICATE_PATH}"

  run psql "${FULL_URL}" -c "\dt"
  [[ ! "$status" -eq 0 ]]
  [[ "$output" =~ "certificate verify failed" ]]
}

@test "It should accept a certificate from the environment at --initialize" {
  make_random_cert
  SSL_KEY="$(cat "$SSL_KEY_PATH")" SSL_CERTIFICATE="$(cat "$SSL_CERTIFICATE_PATH")" \
    PASSPHRASE=foobar initialize_and_start_pg
  FULL_URL="${PG_URL}?sslmode=verify-ca&sslrootcert=${SSL_CERTIFICATE_PATH}"

  psql "${FULL_URL}" -c "\dt"
}

@test "It should accept a replacement certificate from the environment at runtime" {
  PASSPHRASE=foobar run-database.sh --initialize

  make_random_cert
  SSL_KEY="$(cat "$SSL_KEY_PATH")" SSL_CERTIFICATE="$(cat "$SSL_CERTIFICATE_PATH")" \
    run-database.sh 2>&1 &
  wait_for_pg

  FULL_URL="${PG_URL}?sslmode=verify-ca&sslrootcert=${SSL_CERTIFICATE_PATH}"

  psql "${FULL_URL}" -c "\dt"
}
