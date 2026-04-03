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
# Allow RPC from Docker networks. Any rpcallowip entry causes the daemon
# to bind on all interfaces (required for Docker port forwarding).
# Host-side access is restricted by -p 127.0.0.1:15715:15715.
# Gridcoin uses wildcard matching (not CIDR), so 172.*.*.* is broader
# than RFC 1918's 172.16-31.x.x -- acceptable since only Docker network
# traffic can reach the container's interfaces.
rpcallowip=10.*.*.*
rpcallowip=172.*.*.*
rpcallowip=192.168.*.*
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
