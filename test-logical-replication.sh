#!/bin/bash
set -o errexit
set -o nounset

IMG="$1"

MASTER_CONTAINER="postgres-master"
MASTER_DATA_CONTAINER="${MASTER_CONTAINER}-data"
SLAVE_CONTAINER="postgres-slave"
SLAVE_DATA_CONTAINER="${SLAVE_CONTAINER}-data"

function cleanup {
  echo "Cleaning up"
  docker rm -f "$MASTER_CONTAINER" "$MASTER_DATA_CONTAINER" "$SLAVE_CONTAINER" "$SLAVE_DATA_CONTAINER" >/dev/null 2>&1 || true
}

#trap cleanup EXIT
cleanup

USER=testuser
PASSPHRASE=testpass
DATABASE=testdb


echo "Initializing data containers"

docker create --name "$MASTER_DATA_CONTAINER" "$IMG"
docker create --name "$SLAVE_DATA_CONTAINER" "$IMG"


echo "Initializing logical replication master"

MASTER_PORT=54321

docker run -i --rm \
  -e USERNAME="$USER" -e PASSPHRASE="$PASSPHRASE" -e DATABASE="$DATABASE" \
  --volumes-from "$MASTER_DATA_CONTAINER" \
  "$IMG" --initialize

docker run -d --name="$MASTER_CONTAINER" \
  -e PORT="$MASTER_PORT" \
  --volumes-from "$MASTER_DATA_CONTAINER" \
  "$IMG"


until docker exec -i "$MASTER_CONTAINER" sudo -u postgres psql -c '\dt'; do sleep 0.1; done

MASTER_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$MASTER_CONTAINER")"
MASTER_URL="postgresql://$USER:$PASSPHRASE@$MASTER_IP:$MASTER_PORT/$DATABASE"


## shellcheck disable=SC2016
#if docker run --rm --entrypoint bash "$IMG" -c 'dpkg --compare-versions "$PG_VERSION" le 9.5'; then
#  # Ensure replication slots are enabled
#  docker run -i --rm "$IMG" --client "$MASTER_URL" -c "ALTER SYSTEM SET max_replication_slots = 10;"
#  docker restart "$MASTER_CONTAINER"
#  echo "Replication slots enabled"
#
#  until docker exec -i "$MASTER_CONTAINER" sudo -u postgres psql -c '\dt'; do sleep 0.1; done
#fi


echo "Creating test_before table"

docker run -i --rm "$IMG" --client "$MASTER_URL" -c "CREATE TABLE test_before (col TEXT PRIMARY KEY);"
docker run -i --rm "$IMG" --client "$MASTER_URL" -c "INSERT INTO test_before VALUES ('TEST DATA BEFORE');"


echo "Initializing logical replication slave"
SLAVE_PORT=54322

docker run -i --rm \
  -e USERNAME="$USER" -e PASSPHRASE="$PASSPHRASE" \
  -e DATABASE="$DATABASE" -e PORT="$SLAVE_PORT" \
  --volumes-from "$SLAVE_DATA_CONTAINER" \
  "$IMG" --initialize-from-logical "$MASTER_URL"

docker run -d --name "$SLAVE_CONTAINER" \
  -e PORT="$SLAVE_PORT" \
  --volumes-from "$SLAVE_DATA_CONTAINER" \
  "$IMG"


SLAVE_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$SLAVE_CONTAINER")"
SLAVE_URL="postgresql://$USER:$PASSPHRASE@$SLAVE_IP:$SLAVE_PORT/$DATABASE"


# Wait for slave to come up
until docker exec -i "$SLAVE_CONTAINER" sudo -u postgres psql -c '\dt'; do sleep 0.1; done

## shellcheck disable=SC2016
#if docker run --rm --entrypoint bash "$IMG" -c 'dpkg --compare-versions "$PG_VERSION" le 9.5'; then
#  # Ensure replication slots are enabled
#  docker run -i --rm "$IMG" --client "$SLAVE_URL" -c "ALTER SYSTEM SET max_replication_slots = 10;"
#  docker restart "$SLAVE_CONTAINER"
#  echo "Replication slots enabled"
#
#  until docker exec -i "$MASTER_CONTAINER" sudo -u postgres psql -c '\dt'; do sleep 0.1; done
#fi

# Give replication a little time.
# Check that the replica's table has the data.
for _ in {1..25}; do
  sleep 0.2

  if docker run -i --rm "$IMG" --client "$SLAVE_URL" -c 'SELECT * FROM test_before;' | grep 'TEST DATA BEFORE'; then
    echo "Logical replication set up OK!"
    exit 0
  fi
done

exit 1
