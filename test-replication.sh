#!/bin/bash
set -o errexit
set -o nounset

IMG="$1"

MASTER_CONTAINER="postgres-master"
MASTER_DATA_CONTAINER="${MASTER_CONTAINER}-data"
SLAVE_CONTAINER="postgres-slave"
SLAVE_DATA_CONTAINER="${SLAVE_CONTAINER}-data"
LOGICAL_SLAVE_CONTAINER="postgres-logical-slave"
LOGICAL_SLAVE_DATA_CONTAINER="${LOGICAL_SLAVE_CONTAINER}-data"

function cleanup {
  echo "Cleaning up"
  docker rm -f "$MASTER_CONTAINER" \
    "$MASTER_DATA_CONTAINER" \
    "$SLAVE_CONTAINER" \
    "$SLAVE_DATA_CONTAINER" \
    "$LOGICAL_SLAVE_CONTAINER" \
    "$LOGICAL_SLAVE_DATA_CONTAINER" > /dev/null 2>&1 || true
}

trap cleanup EXIT
cleanup

USER=testuser
PASSPHRASE=testpass
DATABASE=testdb


echo "Initializing data containers"

docker create --name "$MASTER_DATA_CONTAINER" "$IMG"
docker create --name "$SLAVE_DATA_CONTAINER" "$IMG"


echo "Initializing replication master"

MASTER_PORT=54321

docker run -i --rm \
  -e USERNAME="$USER" -e PASSPHRASE="$PASSPHRASE" -e DATABASE="$DATABASE" \
  --volumes-from "$MASTER_DATA_CONTAINER" \
  "$IMG" --initialize

docker run -d --name="$MASTER_CONTAINER" \
  -e "PORT=${MASTER_PORT}" \
  --volumes-from "$MASTER_DATA_CONTAINER" \
  "$IMG"

until docker exec -i "$MASTER_CONTAINER" sudo -u postgres psql -c '\dt'; do sleep 0.1; done

MASTER_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$MASTER_CONTAINER")"
MASTER_URL="postgresql://$USER:$PASSPHRASE@$MASTER_IP:$MASTER_PORT/$DATABASE"


echo "Creating test_before table"

docker run -i --rm "$IMG" --client "$MASTER_URL" -c "CREATE TABLE test_before (col TEXT PRIMARY KEY);"
docker run -i --rm "$IMG" --client "$MASTER_URL" -c "INSERT INTO test_before VALUES ('TEST DATA BEFORE');"


echo "Initializing replication slave"
SLAVE_PORT=54322

docker run -i --rm \
  -e USERNAME="$USER" -e PASSPHRASE="$PASSPHRASE" -e DATABASE="$DATABASE" \
  -e APTIBLE_DATABASE_HREF="https://api.aptible.com/databases/8675309" \
  --volumes-from "$SLAVE_DATA_CONTAINER" \
  "$IMG" --initialize-from "$MASTER_URL"

docker run -d --name "$SLAVE_CONTAINER" \
  -e "PORT=${SLAVE_PORT}" \
  --volumes-from "$SLAVE_DATA_CONTAINER" \
  "$IMG"


SLAVE_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$SLAVE_CONTAINER")"
SLAVE_URL="postgresql://$USER:$PASSPHRASE@$SLAVE_IP:$SLAVE_PORT/$DATABASE"


# Wait for slave to come up
until docker exec -i "$SLAVE_CONTAINER" sudo -u postgres psql -c '\dt'; do sleep 0.1; done

# Create a test table now that replication has started
docker run -i --rm "$IMG" --client "$MASTER_URL" -c "CREATE TABLE test_after (col TEXT PRIMARY KEY);"
docker run -i --rm "$IMG" --client "$MASTER_URL" -c "INSERT INTO test_after VALUES ('TEST DATA AFTER');"

# Give replication a little time. (Hopefully) much more than needed!
sleep 1

# Check that data is present in both tables
docker run -i --rm "$IMG" --client "$SLAVE_URL" -c 'SELECT * FROM test_before;' | grep 'TEST DATA BEFORE'
docker run -i --rm "$IMG" --client "$SLAVE_URL" -c 'SELECT * FROM test_after;' | grep 'TEST DATA AFTER'


# The primary database should have a replica slot that corresponds to the replica's database ID.
# shellcheck disable=SC2016
if docker run --rm --entrypoint bash "$IMG" -c 'dpkg --compare-versions "$PG_VERSION" gt 9.5'; then
  docker run -i --rm "$IMG" --client "$MASTER_URL" -c "SELECT slot_name FROM pg_replication_slots;" | grep "aptible_replica_8675309"
  echo "Replication slot OK"
fi

echo "Replication set up OK!"

# Set the promote command based on PG version
if docker run --rm --entrypoint bash "$IMG" -c 'dpkg --compare-versions "$PG_VERSION" ge 12'; then
  PROMOTE_CMD="SELECT pg_promote();"
else
  PROMOTE_CMD="COPY (SELECT 'fast') TO '/var/db/pgsql.trigger';"
fi

echo "Verify replica is not writeable"
! docker run -i --rm "$IMG" --client "$SLAVE_URL" -c "INSERT INTO test_after VALUES ('READ ONLY PLEASE');"

echo "Promote the replica"
docker run -i --rm "$IMG" --client "$SLAVE_URL" -c "$PROMOTE_CMD"
sleep 5

echo "Write to promoted replica"
docker run -i --rm "$IMG" --client "$SLAVE_URL" -c "INSERT INTO test_after VALUES ('WRITE PLEASE');"

echo "Physical replication OK!"


# Logical replicaiton
# Only test supported pg_versions
docker run --rm --entrypoint bash "$IMG" -c 'dpkg --compare-versions "$PG_VERSION" lt 9.4' && exit


echo "Initializing logical replica data container"

docker create --name "$LOGICAL_SLAVE_DATA_CONTAINER" "$IMG"


echo "Initializing logical replication slave"
LOGICAL_SLAVE_PORT=54323

docker run -i --rm \
  -e USERNAME="$USER" -e PASSPHRASE="$PASSPHRASE" \
  -e DATABASE="$DATABASE" -e PORT="$LOGICAL_SLAVE_PORT" \
  --volumes-from "$LOGICAL_SLAVE_DATA_CONTAINER" \
  "$IMG" --initialize-from-logical "$MASTER_URL"

docker run -d --name "$LOGICAL_SLAVE_CONTAINER" \
  -e PORT="$LOGICAL_SLAVE_PORT" \
  --volumes-from "$LOGICAL_SLAVE_DATA_CONTAINER" \
  "$IMG"


LOGICAL_SLAVE_IP="$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' "$LOGICAL_SLAVE_CONTAINER")"
LOGICAL_SLAVE_URL="postgresql://$USER:$PASSPHRASE@$LOGICAL_SLAVE_IP:$LOGICAL_SLAVE_PORT/$DATABASE"


# Wait for slave to come up
until docker exec -i "$LOGICAL_SLAVE_CONTAINER" sudo -u postgres psql -c '\dt'; do sleep 0.1; done

# Give replication a little time.
# Check that the replica's has initialized.
(
  for _ in {1..25}; do
    sleep 0.2

    if docker run -i --rm "$IMG" --client "$LOGICAL_SLAVE_URL" -c 'SELECT * FROM test_before;' | grep 'TEST DATA BEFORE'; then
      echo "Logical replication set up OK!"
      exit
    fi
  done

  exit 1
)

docker run -i --rm "$IMG" --client "$MASTER_URL" -c "INSERT INTO test_after VALUES ('TEST DATA AFTER LOGICAL');"

# Give replication a little time.
# Check that the replica has new data.
(
  for _ in {1..25}; do
    sleep 0.2

    if docker run -i --rm "$IMG" --client "$LOGICAL_SLAVE_URL" -c 'SELECT * FROM test_after;' | grep 'TEST DATA AFTER LOGICAL'; then
      echo "Logical replication OK!"
      exit
    fi
  done

  exit 1
)
