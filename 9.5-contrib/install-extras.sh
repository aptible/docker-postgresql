#!/bin/bash
set -o errexit
set -o nounset

# Install packaged extensions first
apt-install "^postgresql-plpython-${PG_VERSION}$" "^postgresql-plpython3-${PG_VERSION}$"

# Now, install source extensions

# We'll need backports for libv8
echo "deb http://httpredir.debian.org/debian wheezy-backports main" >> /etc/apt/sources.list

DEPS=(
  build-essential python-pip
  libpq-dev "^postgresql-server-dev-${PG_VERSION}$"
  freetds-dev
  libv8-3.14-dev
  libmysqlclient-dev
  python-dev
  "postgresql-plperl-${PG_VERSION}"
)

apt-install "${DEPS[@]}"
pip install pgxnclient

pgxn install "tds_fdw==1.0.7"
pgxn install "plv8==1.4.4"
USE_PGXS=1 pgxn install "mysql_fdw==2.1.2"
pgxn install "multicorn==1.3.3"
