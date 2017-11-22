#!/bin/bash
set -o errexit
set -o pipefail


# shellcheck disable=SC1091
. /usr/bin/utilities.sh

# Defaults, which may be overridden by setting them in the environment
DEFAULT_RUN_DIRECTORY="/var/run/postgresql"
DEFAULT_PORT="5432"

SSL_DIRECTORY="${CONF_DIRECTORY}/ssl"

PG_CONF="${CONF_DIRECTORY}/main/postgresql.conf"
PG_AUTOTUNE_CONF="${CONF_DIRECTORY}/main/postgresql.autotune.conf"
PG_HBA="${CONF_DIRECTORY}/main/pg_hba.conf"

function pg_init_ssl () {
  mkdir -p "$SSL_DIRECTORY"

  local ssl_cert_file="${SSL_DIRECTORY}/server.crt"
  local ssl_key_file="${SSL_DIRECTORY}/server.key"

  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    echo "Certs present in environment - using them"
    echo "$SSL_CERTIFICATE" > "$ssl_cert_file"
    echo "$SSL_KEY" > "$ssl_key_file"
  elif [ -f "$ssl_cert_file" ] && [ -f "$ssl_key_file" ]; then
    echo "Certs present on filesystem - using them"
  else
    echo "No certs found - autogenerating"
    SUBJ="/C=US/ST=New York/L=New York/O=Example/CN=PostgreSQL"
    OPTS="req -nodes -new -x509 -sha256 -days 365000"
    # shellcheck disable=2086
    openssl $OPTS -subj "$SUBJ" -keyout "$ssl_key_file" -out "$ssl_cert_file" 2> /dev/null
  fi

  chown -R postgres:postgres "$SSL_DIRECTORY"
  chmod 600 "$ssl_cert_file" "$ssl_key_file"
}

function pg_init_conf () {
  # Set up the PG config files

  # Copy over configuration, make substitutions as needed.
  # Useless use of cat, but makes the pipeline more readable.
  # shellcheck disable=SC2002
  cat "${PG_CONF}.template" \
    | grep --fixed-strings --invert-match "__NOT_IF_PG_${PG_VERSION}__" \
    | sed "s:__DATA_DIRECTORY__:${DATA_DIRECTORY}:g" \
    | sed "s:__CONF_DIRECTORY__:${CONF_DIRECTORY}:g" \
    | sed "s:__RUN_DIRECTORY__:${RUN_DIRECTORY:-"$DEFAULT_RUN_DIRECTORY"}:g" \
    | sed "s:__PORT__:${PORT:-"$DEFAULT_PORT"}:g" \
    | sed "s:__PG_VERSION__:${PG_VERSION}:g" \
    | sed "s:__PRELOAD_LIB__:${PRELOAD_LIB}:g"\
    | sed "s:__PG_AUTOTUNE_CONF__:${PG_AUTOTUNE_CONF}:g"\
    > "${PG_CONF}"

  cat "${PG_HBA}.template"\
    | sed "s:__AUTH_METHOD__:${AUTH_METHOD}:g" \
    > "${PG_HBA}"

  # Write the autotune configuration
  /usr/local/bin/autotune > "$PG_AUTOTUNE_CONF"

  # Ensure we have a certificate, either from the environment, the filesystem,
  # or just a random one.
  pg_init_ssl
}


function pg_init_data () {
  chown -R postgres:postgres "$DATA_DIRECTORY"
  chmod go-rwx "$DATA_DIRECTORY"
}


function pg_run_server () {
  # Run pg! Remove potentially sensitive ENV and passthrough options.
  unset SSL_CERTIFICATE
  unset SSL_KEY
  unset PASSPHPRASE

  echo "Running PG with options:" "$@"
  exec gosu postgres "/usr/lib/postgresql/$PG_VERSION/bin/postgres" -D "$DATA_DIRECTORY" -c "config_file=$PG_CONF" "$@"
}


if [[ "$1" == "--initialize" ]]; then
  pg_init_conf
  pg_init_data

  gosu postgres "/usr/lib/postgresql/$PG_VERSION/bin/initdb" -D "$DATA_DIRECTORY"
  gosu postgres /etc/init.d/postgresql start
  # The username is double-quoted because it's a name, but the password is single quoted, because it's a string.
  gosu postgres psql --command "CREATE USER \"${USERNAME:-aptible}\" WITH SUPERUSER PASSWORD '$PASSPHRASE'"
  gosu postgres psql --command "CREATE DATABASE ${DATABASE:-db}"
  gosu postgres /etc/init.d/postgresql stop

elif [[ "$1" == "--initialize-from" ]]; then
  [ -z "$2" ] && echo "docker run -it aptible/postgresql --initialize-from postgresql://..." && exit 1

  # Force our username to lowercase to avoid confusion
  # http://www.postgresql.org/message-id/4219EA03.8030302@archonet.com
  REPL_USER=${REPLICATION_USERNAME:-"repl_$(pwgen -s 10 | tr '[:upper:]' '[:lower:]')"}
  REPL_PASS=${REPLICATION_PASSPHRASE:-"$(pwgen -s 20)"}

  # See above regarding quoting
  psql "$2" --command "CREATE USER \"$REPL_USER\" REPLICATION LOGIN ENCRYPTED PASSWORD '$REPL_PASS'" > /dev/null

  pg_init_conf
  pg_init_data

  # TODO: We force ssl=true here, but it's not entirely correct to do so. Perhaps Sweetness should be providing this.
  # TODO: Either way, we should respect whatever came in via the original URL..!
  parse_url "$2"
  # shellcheck disable=SC2154
  gosu postgres pg_basebackup -D "$DATA_DIRECTORY" -R -d "$protocol$REPL_USER:$REPL_PASS@$host_and_port/$database?ssl=true"

elif [[ "$1" == "--client" ]]; then
  [ -z "$2" ] && echo "docker run -it aptible/postgresql --client postgresql://..." && exit
  url="$2"
  shift
  shift
  psql "$url" "$@"

elif [[ "$1" == "--dump" ]]; then
  [ -z "$2" ] && echo "docker run aptible/postgresql --dump postgresql://... > dump.psql" && exit
  # If the file /dump-output exists, write output there. Otherwise, use stdout.
  # shellcheck disable=SC2015
  [ -e /dump-output ] && exec 3>/dump-output || exec 3>&1
  pg_dump "$2" >&3

elif [[ "$1" == "--restore" ]]; then
  [ -z "$2" ] && echo "docker run -i aptible/postgresql --restore postgresql://... < dump.psql" && exit
  # If the file /restore-input exists, read input there. Otherwise, use stdin.
  # shellcheck disable=SC2015
  [ -e /restore-input ] && exec 3</restore-input || exec 3<&0
  psql "$2" <&3

elif [[ "$1" == "--readonly" ]]; then
  pg_init_conf
  pg_run_server --default_transaction_read_only=on

else
  pg_init_conf
  pg_run_server

fi
