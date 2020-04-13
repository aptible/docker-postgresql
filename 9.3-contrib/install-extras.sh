#!/bin/bash
set -o errexit
set -o nounset

# Install packaged extensions first
apt-install "^postgresql-plpython-${PG_VERSION}$" "^postgresql-plpython3-${PG_VERSION}$" \
  "^postgresql-plperl-${PG_VERSION}$" "^postgresql-${PG_VERSION}-repack"

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
pip install 'pgxnclient<1.3'

pgxn install "tds_fdw==1.0.7"
pgxn install "plv8==1.4.4"
pgxn install --testing "pg_proctab==0.0.5"
USE_PGXS=1 pgxn install "mysql_fdw==2.1.2"
PYTHON_OVERRIDE=python pgxn install "multicorn==1.3.3"
