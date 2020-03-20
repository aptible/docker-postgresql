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
  "^postgresql-${PG_VERSION}-repack" "^pgagent$"

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
  https://github.com/EnterpriseDB/mysql_fdw/archive/REL-2_3_0.tar.gz \
  a2dbd00bb4929ecacbf9c21bde762ad5afbe7af7

