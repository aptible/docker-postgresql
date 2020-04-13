#!/bin/bash
set -o errexit
set -o nounset
set -x
# We'll need the pglogical repo...
echo "deb [arch=amd64] http://packages.2ndquadrant.com/pglogical/apt/ stretch-2ndquadrant main" >> /etc/apt/sources.list

# ...and its key
apt-key add /tmp/GPGkeys/pglogical.key

# Install packaged extensions first
apt-install "^postgresql-plperl-${PG_VERSION}$" "^pgagent$" "^postgresql-${PG_VERSION}-pglogical$" \
  "^postgresql-plpython3-${PG_VERSION}$" "^postgresql-${PG_VERSION}-wal2json$"
