#!/bin/bash
set -o errexit
set -o nounset
set -x

# We'll need the pglogical repo...
echo "deb [arch=amd64] https://dl.2ndquadrant.com/default/release/apt stretch-2ndquadrant main" >> /etc/apt/sources.list

# ...and its key
apt-key add /tmp/GPGkeys/pglogical.key

# Install packaged extensions first
apt-install "^postgresql-${PG_VERSION}-pglogical$" "^postgresql-${PG_VERSION}-repack$" "^postgresql-${PG_VERSION}-wal2json"

DEPS=(
  build-essential
  "^postgresql-server-dev-${PG_VERSION}$"
)

apt-install "${DEPS[@]}"