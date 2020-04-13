#!/bin/bash
set -o errexit
set -o nounset

# pg_repack linked against libpq5 11 breaks with libpq5 12
# https://www.postgresql.org/message-id/flat/20191007065916.GH14532%40paquier.xyz#f9902a2c15d0448bf95c4eac15ec86b3
# 11 worked so let's use that. We can get the older version by adding the "11" archive our source list:
# https://wiki.postgresql.org/wiki/Apt/FAQ#I_want_libpq5_for_version_X.2C_but_there_is_only_version_Y_in_the_repository

sed -i '$ s/$/ 11/' /etc/apt/sources.list.d/pgdg.list

cat > /etc/apt/preferences.d/libpq << EOL
Package: libpq5
Pin: version 11.*
Pin-Priority: 1000

Package: libpq-dev
Pin: version 11.*
Pin-Priority: 1000
EOL

apt-install --force-yes "libpq5"

# We'll need the pglogical repo...
echo "deb [arch=amd64] http://packages.2ndquadrant.com/pglogical/apt/ wheezy-2ndquadrant main" >> /etc/apt/sources.list

# ...and its key
apt-key add /tmp/GPGkeys/pglogical.key

# Install packaged extensions first
apt-install "^postgresql-plpython-${PG_VERSION}$" "^postgresql-plpython3-${PG_VERSION}$" \
  "^postgresql-plperl-${PG_VERSION}$" "^postgresql-${PG_VERSION}-pglogical$" "^postgresql-${PG_VERSION}-wal2json$" \
  "^postgresql-${PG_VERSION}-repack" "^pgagent$"

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
pgxn install safeupdate
