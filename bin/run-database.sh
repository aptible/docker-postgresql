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
DB="${DATABASE:-db}"

function pg_init_ssl () {
  mkdir -p "$SSL_DIRECTORY"

  local ssl_cert_file="${SSL_DIRECTORY}/server.crt"
  local ssl_key_file="${SSL_DIRECTORY}/server.key"

  if [ -n "$SSL_CERTIFICATE" ] && [ -n "$SSL_KEY" ]; then
    echo "Certs present in environment - using them"
    echo "$SSL_CERTIFICATE" > "$ssl_cert_file"
    echo "$SSL_KEY" > "$ssl_key_file"
    if [ -n "$CA_CERTIFICATE" ]; then
      echo "$CA_CERTIFICATE" >> "$ssl_cert_file"
    fi
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

  if dpkg --compare-versions "$PG_VERSION" lt '9.4'; then
    WAL_LEVEL=hot_standby
  else
    WAL_LEVEL=logical
  fi

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
    | sed "s:__WAL_LEVEL__:${WAL_LEVEL}:g"\
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


function initialize() {
  pg_init_conf
  pg_init_data

  gosu postgres "/usr/lib/postgresql/$PG_VERSION/bin/initdb" -D "$DATA_DIRECTORY"
  gosu postgres /etc/init.d/postgresql start
  # The username is double-quoted because it's a name, but the password is single quoted, because it's a string.
  gosu postgres psql --command "CREATE USER \"${USERNAME:-aptible}\" WITH SUPERUSER PASSWORD '$PASSPHRASE'"
  gosu postgres psql --command "CREATE DATABASE ${DB}"
  gosu postgres /etc/init.d/postgresql stop
}


if [[ "$1" == "--initialize" ]]; then
  initialize

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

  basebackup_options=(
    -D "$DATA_DIRECTORY"
    -R
    -d "$protocol$REPL_USER:$REPL_PASS@$host_and_port/$database?ssl=true"
  )

  # Allow for optional bypassing of replication slots to support
  # legacy replicas.
  if [[ -z "${NO_SLOTS}" ]] && dpkg --compare-versions "$PG_VERSION" ge '9.6'; then
    REPL_SLOT="$(pwgen -s 20 | tr '[:upper:]' '[:lower:]')_$(date +%s)"
    psql "$2" --command "SELECT * FROM pg_create_physical_replication_slot('$REPL_SLOT');" > /dev/null

    basebackup_options=(
      "${basebackup_options[@]}"
      -X stream
      -S "$REPL_SLOT"
    )
  fi

  gosu postgres pg_basebackup "${basebackup_options[@]}"

  # Create the trigger to allow PG < 12 replicas to be promoted
  # (PG 12+ natively allows `SELECT pg_promote();`)
  if dpkg --compare-versions "$PG_VERSION" lt '12'; then
    TRIGGER="trigger_file = '${DATA_DIRECTORY}/pgsql.trigger'"
    echo "${TRIGGER}" >> "${DATA_DIRECTORY}/recovery.conf"
  fi

elif [[ "$1" == "--initialize-from-logical" ]]; then
  [ -z "$2" ] && echo "docker run -it aptible/postgresql --initialize-from-logical postgresql://..." && exit 1

  master_url="$2"

  psql "$master_url" --tuples-only --command "SELECT setting FROM pg_settings WHERE name = 'wal_level'" \
    | grep 'logical' > /dev/null \
    || { echo "Error: Master database's \"wal_level\" must be \"logical\"" && CONFIG_ERROR=1; }
  psql "$master_url" --tuples-only --command "SELECT setting FROM pg_settings WHERE name = 'shared_preload_libraries'" \
    | grep 'pglogical' > /dev/null \
    || { echo "Error: \"pglogical\" must be in master database's \"shared_preload_libraries\"" && CONFIG_ERROR=1; }

  if [[ -n "$CONFIG_ERROR" ]]; then
    exit "$CONFIG_ERROR"
  fi

  initialize

  parse_url "$master_url"

  PUBLISHER_DSN="host=${host} port=${port} user=${user} password=${password} dbname=${database}"
  SUBSCRIBER_DSN="host=127.0.0.1 port=${PORT:-"$DEFAULT_PORT"} user=${USERNAME:-aptible} password=${PASSPHRASE} dbname=${DB}"
  REPLICATION_SET_NAME="aptible_replication_set"

  gosu postgres /etc/init.d/postgresql start
  pg_dump --schema-only --schema public "$master_url" | gosu postgres psql --dbname "${DB}" > /dev/null

  # PG 9.4 requires the pglogical_origin extension to be installed
  if psql "$master_url" --tuples-only --command "SELECT version()" | grep "PostgreSQL 9.4"; then
    psql "$master_url" --command "CREATE EXTENSION IF NOT EXISTS pglogical_origin"
  fi
  if dpkg --compare-versions "$PG_VERSION" eq '9.4'; then
    gosu postgres psql --dbname "${DB}" --command "CREATE EXTENSION IF NOT EXISTS pglogical_origin"
  fi

  psql "$master_url" --command "CREATE EXTENSION IF NOT EXISTS pglogical"
  gosu postgres psql --dbname "${DB}" --command "CREATE EXTENSION IF NOT EXISTS pglogical"

  # There can only be one node per database
  # Nodes must have unique names
  # Nodes can have multiple connection interfaces
  psql "$master_url" --command "SELECT pglogical.create_node(node_name := 'aptible_publisher', dsn := '${PUBLISHER_DSN}')" \
    || { echo "Error: Failed to create publisher node. Is there already a pglogical node on the ${database} database?" && exit 1; }
  gosu postgres psql --dbname "${DB}" --command "SELECT pglogical.create_node(node_name := 'aptible_subscriber', dsn := '${SUBSCRIBER_DSN}')"

  psql "$master_url" --command "SELECT pglogical.create_replication_set(set_name := '${REPLICATION_SET_NAME}')"
  psql "$master_url" --command "SELECT pglogical.replication_set_add_all_tables('${REPLICATION_SET_NAME}', ARRAY['public'])"
  psql "$master_url" --command "SELECT pglogical.replication_set_add_all_sequences('${REPLICATION_SET_NAME}', ARRAY['public'])"
  gosu postgres psql --dbname "${DB}" --command "SELECT pglogical.create_subscription(subscription_name := 'aptible_subscription', provider_dsn := '${PUBLISHER_DSN}', replication_sets := ARRAY['${REPLICATION_SET_NAME}'])"
  gosu postgres psql --dbname "${DB}" --command "SELECT pglogical.wait_for_subscription_sync_complete('aptible_subscription');"
  gosu postgres /etc/init.d/postgresql stop

elif [[ "$1" == "--initialize-backup" ]]; then
  # Remove recovery.conf if present to not start following the master.
  rm -f "${DATA_DIRECTORY}/recovery.conf"

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
  echo "----The following persistent configuration changes are present----"
  egrep -v "^#" "${DATA_DIRECTORY}/postgresql.auto.conf" || true
  echo "--------------End persistent configuration changes----------------"

  pg_init_conf
  pg_run_server

fi
