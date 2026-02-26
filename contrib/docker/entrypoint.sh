#!/usr/bin/env bash

export LC_ALL=C

set -e

DATA_DIR="/home/gridcoin/.GridcoinResearch"
CONF_FILE="${DATA_DIR}/gridcoinresearch.conf"

# Ensure the data directory exists and is owned by gridcoin
mkdir -p "${DATA_DIR}"
chown -R gridcoin:gridcoin "${DATA_DIR}"

# Bootstrap config if it doesn't exist
if [ ! -f "${CONF_FILE}" ]; then
    echo "Creating default gridcoinresearch.conf..."
    cat > "${CONF_FILE}" <<EOF
server=1
rpcuser=gridcoinrpc
rpcpassword=$(openssl rand -hex 32)
rpcallowip=127.0.0.1
rpcallowip=10.0.0.0/8
rpcallowip=172.16.0.0/12
rpcallowip=192.168.0.0/16
EOF
    chown gridcoin:gridcoin "${CONF_FILE}"
    chmod 0600 "${CONF_FILE}"
fi

# Force printtoconsole=1 for Docker log visibility
if grep -q '^printtoconsole=' "${CONF_FILE}"; then
    sed -i 's/^printtoconsole=.*/printtoconsole=1/' "${CONF_FILE}"
else
    echo "printtoconsole=1" >> "${CONF_FILE}"
fi

# If first arg starts with '-', prepend the daemon binary
if [ "${1:0:1}" = '-' ]; then
    set -- gridcoinresearchd "$@"
fi

# Drop privileges for Gridcoin binaries
if [ "$1" = 'gridcoinresearchd' ] || [ "$1" = 'gridcoinresearch' ]; then
    exec gosu gridcoin:gridcoin "$@"
fi

# Allow arbitrary commands (e.g. bash for debugging)
exec "$@"
