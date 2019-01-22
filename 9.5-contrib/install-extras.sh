#!/bin/bash
set -o errexit
set -o nounset

# We'll need the pglogical repo...
echo "deb [arch=amd64] http://packages.2ndquadrant.com/pglogical/apt/ wheezy-2ndquadrant main" >> /etc/apt/sources.list

# ...and its key
apt-key add /tmp/pglogical.key

# Install packaged extensions first
apt-install "^postgresql-plpython-${PG_VERSION}$" "^postgresql-plpython3-${PG_VERSION}$" \
  "^postgresql-plperl-${PG_VERSION}$" "^postgresql-${PG_VERSION}-pglogical$" "^postgresql-${PG_VERSION}-pgaudit$" \
  "^postgresql-${PG_VERSION}-wal2json$"

# Now, install source extensions

DEPS=(
  build-essential python-pip
  libpq-dev "^postgresql-server-dev-${PG_VERSION}$"
  freetds-dev
  libv8-3.14-dev
  libmysqlclient-dev
  python-dev
)

apt-install "${DEPS[@]}"
pip install pgxnclient

pgxn install "tds_fdw==1.0.7"
pgxn install "plv8==1.4.4"
USE_PGXS=1 pgxn install "mysql_fdw==2.1.2"
pgxn install "multicorn==1.3.3"
pgxn install safeupdate
