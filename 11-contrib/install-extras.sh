#!/bin/bash
set -o errexit
set -o nounset
set -x
# We'll need the pglogical repo...
echo "deb [arch=amd64] http://packages.2ndquadrant.com/pglogical/apt/ stretch-2ndquadrant main" >> /etc/apt/sources.list

# ...and its key
apt-key add /tmp/GPGkeys/pglogical.key

# Install packaged extensions first
apt-install "^postgresql-plpython-${PG_VERSION}$" "^postgresql-plpython3-${PG_VERSION}$" \
  "^postgresql-plperl-${PG_VERSION}$" "^postgresql-${PG_VERSION}-pglogical$" \
  "^postgresql-${PG_VERSION}-pgaudit$" "^postgresql-${PG_VERSION}-wal2json$" \
  "^postgresql-${PG_VERSION}-repack" "^pgagent$" "^postgresql-${PG_VERSION}-pgl-ddl-deploy$"

# Now, install source extensions

DEPS=(
  build-essential python-pip
  libpq-dev "^postgresql-server-dev-${PG_VERSION}$"
  libv8-3.14-dev
  default-libmysqlclient-dev
  python-dev
)

apt-install "${DEPS[@]}"
pip install 'pgxnclient<1.3'

# PLV8 v2.3.7 required for PG11
# https://github.com/plv8/plv8/blob/r3.0alpha/Changes#L15-L16
# GYP_CHROMIUM_NO_ACTION=0 pgxn install "plv8==2.3.7"

# Not supported yet for PG11
# https://github.com/Kozea/Multicorn/issues/217
# pgxn install "multicorn==1.3.5"

#pgxn install safeupdate

# Install extensions from source (expects tarball URL as argument)
install_extension_from_source() {
  tarball_url=$1
  shift
  shasum=$1
  shift

  pushd .
  tempdir=$(mktemp -d)

  cd $tempdir
  wget -O extension.tar.gz $tarball_url
  echo "${shasum}  extension.tar.gz" | sha1sum -c - || exit
  mkdir -p extension
  tar xzf extension.tar.gz -C extension --strip-components 1

  cd extension
  make USE_PGXS=1 install

  cd $tempdir
  rm -rf extension extension.tar.gz
  popd
}

 install_extension_from_source \
   https://github.com/EnterpriseDB/mysql_fdw/archive/REL-2_5_1.tar.gz \
   0b43b339ec82a31c2b7a1ce9a2b5899039d1a98d

install_extension_from_source \
  https://github.com/pgpartman/pg_partman/archive/v4.3.1.tar.gz \
  22eb8069800614a4601a4ce76519a3d9a41c3311
