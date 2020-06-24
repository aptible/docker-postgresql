#!/bin/bash
set -o errexit
set -o nounset

# We'll need the pglogical repo...
echo "deb [arch=amd64] http://packages.2ndquadrant.com/pglogical/apt/ wheezy-2ndquadrant main" >> /etc/apt/sources.list

# ...and its key
apt-key add /tmp/GPGkeys/pglogical.key

# Install packaged extensions first
apt-install "^postgresql-${PG_VERSION}-pglogical$"

DEPS=(
  build-essential
  libpq-dev "^postgresql-server-dev-${PG_VERSION}$"
  )

apt-install "${DEPS[@]}"


# Install extension from source
wget -O pg_cron-"${PG_CRON_VERSION}".tar.gz https://codeload.github.com/citusdata/pg_cron/tar.gz/v"${PG_CRON_VERSION}"
echo "${PG_CRON_SHA1SUM}  pg_cron-${PG_CRON_VERSION}.tar.gz" | sha1sum -c -
tar -xzf pg_cron-"${PG_CRON_VERSION}".tar.gz && cd pg_cron-"${PG_CRON_VERSION}"
make && make install
cd .. && rm -rf pg_cron-"${PG_CRON_VERSION}".tar.gz pg_cron-"${PG_CRON_VERSION}"
