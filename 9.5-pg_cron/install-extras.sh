#!/bin/bash
set -o errexit
set -o nounset


DEPS=(
  build-essential
  libpq-dev "^postgresql-server-dev-${PG_VERSION}$"
  )

apt-install "${DEPS[@]}"


# Install extension from source
wget -O pg_cron-1.0.0.tar.gz https://codeload.github.com/citusdata/pg_cron/tar.gz/v1.0.0
echo "73463bf2b778bbe711b42a29ee4101d2839344f1  pg_cron-1.0.0.tar.gz" | sha1sum -c -
tar -xzf pg_cron-1.0.0.tar.gz && cd pg_cron-1.0.0
make && make install
cd .. && rm -rf pg_cron-1.0.0.tar.gz pg_cron-1.0.0
