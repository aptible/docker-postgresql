#!/bin/bash
set -o errexit
set -o nounset

IMG="$1"

PG_CONTAINER="postgres"
DATA_CONTAINER="${PG_CONTAINER}-data"

function cleanup {
  echo "Cleaning up"
  docker rm -f "$PG_CONTAINER" "$DATA_CONTAINER" >/dev/null 2>&1 || true
}

function wait_for_pg {
  for _ in $(seq 1 60); do
    if docker exec -it "$PG_CONTAINER" gosu postgres psql db -c 'SELECT 1;' >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.1
  done

  echo "DB never came online"
  docker logs "$PG_CONTAINER"
  return 1
}

test_reject_cipher() {
  docker run --rm aptible/sslyze --starttls=postgres --hide_rejected_ciphers "$@" \
    | grep "Server rejected all cipher suites." > /dev/null
}

test_accept_cipher() {
  docker run --rm aptible/sslyze --starttls=postgres --hide_rejected_ciphers "$@" \
    | grep "Preferred:" > /dev/null
}

trap cleanup EXIT
cleanup

(

  cd test/sslyze
  docker build -t aptible/sslyze . 

)

echo "Creating data container"
docker create --name "$DATA_CONTAINER" "$IMG"

echo "Starting DB"
docker run -it --rm \
  -e USERNAME=user -e PASSPHRASE=pass -e DATABASE=db \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG" --initialize \
  >/dev/null 2>&1

docker run -d --name="$PG_CONTAINER" \
  --volumes-from "$DATA_CONTAINER" \
  "$IMG"

echo "Waiting for DB to come online"
wait_for_pg

DB_URL="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$PG_CONTAINER"):5432"

test_accept_cipher --tlsv1_2 "$DB_URL"

if [[ "$IMG" =~ postgresql:1[3-4] ]]; then
  test_reject_cipher --tlsv1_1 "$DB_URL"
  test_reject_cipher --tlsv1 "$DB_URL"
else
  test_accept_cipher --tlsv1_1 "$DB_URL"
  test_accept_cipher --tlsv1 "$DB_URL"
fi

test_reject_cipher --sslv3 "$DB_URL"
