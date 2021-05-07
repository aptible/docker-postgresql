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
  "^postgresql-plpython3-${PG_VERSION}$" "^postgresql-${PG_VERSION}-wal2json$" \
  "^postgresql-${PG_VERSION}-pgaudit$" "^postgresql-plperl-${PG_VERSION}$" \
  "^postgresql-${PG_VERSION}-repack"

# Now, install source extensions

DEPS=(
  build-essential python-pip
  libpq-dev "^postgresql-server-dev-${PG_VERSION}$"
  libv8-3.14-dev
  default-libmysqlclient-dev
  python-dev
)

apt-install "${DEPS[@]}"

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
  https://github.com/pgpartman/pg_partman/archive/v4.3.1.tar.gz \
  22eb8069800614a4601a4ce76519a3d9a41c3311
