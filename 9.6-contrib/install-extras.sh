#!/bin/bash
set -o errexit
set -o nounset

# Install packaged extensions first
apt-install "^postgresql-plpython-${PG_VERSION}$" "^postgresql-plpython3-${PG_VERSION}$" \
  "^postgresql-plperl-${PG_VERSION}$"

# Now, install source extensions

# We'll need backports for libv8
echo "deb http://httpredir.debian.org/debian wheezy-backports main" >> /etc/apt/sources.list

DEPS=(
  build-essential python-pip
  libpq-dev "^postgresql-server-dev-${PG_VERSION}$"
  libv8-3.14-dev
  python-dev
)

apt-install "${DEPS[@]}"
pip install pgxnclient

pgxn install "plv8==1.4.4"
pgxn install "multicorn==1.3.3"
