#!/usr/bin/env bash

export LC_ALL=C

gridcoinresearchd getblockchaininfo > /dev/null 2>&1 || exit 1
