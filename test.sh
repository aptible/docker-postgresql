#!/bin/bash
set -o errexit
set -o nounset

IMG="$REGISTRY/$REPOSITORY:$TAG"

echo "Unit Tests..."
docker run -it --rm --entrypoint "bash" "$IMG" -c "bats /tmp/test"

TESTS=(
  ssl
  restart
  replication
)

for t in "${TESTS[@]}"; do
  echo "--- START ${t} ---"
  "./test-${t}.sh" "$IMG"
  echo "--- OK    ${t} ---"
  echo
done

echo "#############"
echo "# Tests OK! #"
echo "#############"
