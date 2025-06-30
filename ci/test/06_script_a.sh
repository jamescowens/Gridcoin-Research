#!/usr/bin/env bash
#
# Copyright (c) 2018-2020 The Bitcoin Core developers
# Distributed under the MIT software license, see the accompanying
# file COPYING or https://opensource.org/licenses/mit-license.php.

export LC_ALL=C.UTF-8

# Define common configuration flags for Autotools.
# These set the installation prefixes for binaries and libraries to the depends output directory.
GRIDCOIN_CONFIG_ALL="--disable-dependency-tracking --prefix=$DEPENDS_DIR/$HOST --bindir=$BASE_OUTDIR/bin --libdir=$BASE_OUTDIR/lib"

# Zero out ccache statistics and set its maximum size for the current build.
DOCKER_EXEC "ccache --zero-stats --max-size=$CCACHE_SIZE"

# --- Autogen Step ---
# Run the autogen.sh script to generate configure and other build system files.
# This step is conditional on whether CONFIG_SHELL is defined.
BEGIN_FOLD autogen
if [ -n "$CONFIG_SHELL" ]; then
  DOCKER_EXEC "$CONFIG_SHELL" -c "./autogen.sh"
else
  DOCKER_EXEC ./autogen.sh
fi
END_FOLD

# Create the base build directory if it doesn't exist.
DOCKER_EXEC mkdir -p "${BASE_BUILD_DIR}"
# Set the current CI directory context.
export P_CI_DIR="${BASE_BUILD_DIR}"

# --- First Configure Pass (in BASE_ROOT_DIR) ---
# This block handles the initial configure script execution.
# It ensures PKG_CONFIG_PATH is correctly set for depends-based builds
# and clears the config.cache to prevent "environment changed" errors.

# Clear the config.cache before running configure to ensure a clean state.
# This prevents errors if environment variables like PKG_CONFIG_PATH change between runs.
DOCKER_EXEC rm -f config.cache

if [ -z "$NO_DEPENDS" ]; then
  # If NO_DEPENDS is NOT set (meaning depends are used, e.g., cross-compilation),
  # we export PKG_CONFIG_PATH within the same DOCKER_EXEC subshell as configure.
  DOCKER_EXEC bash -c "
    export PKG_CONFIG_PATH=\"${DEPENDS_DIR}/${HOST}/lib/pkgconfig:\$PKG_CONFIG_PATH\"
    echo \"PKG_CONFIG_PATH set for first configure: \$PKG_CONFIG_PATH\"
    \"${BASE_ROOT_DIR}/configure\" --cache-file=config.cache ${GRIDCOIN_CONFIG_ALL} ${GRIDCOIN_CONFIG} || ( (cat config.log) && false)
  "
else
  # If NO_DEPENDS IS set (meaning system libs are used, e.g., native builds),
  # run configure directly without modifying PKG_CONFIG_PATH.
  DOCKER_EXEC "${BASE_ROOT_DIR}/configure" --cache-file=config.cache ${GRIDCOIN_CONFIG_ALL} ${GRIDCOIN_CONFIG} || ( (cat config.log) && false)
fi

# --- Make Distdir Step ---
# Create a distribution tarball of the source code.
BEGIN_FOLD distdir
DOCKER_EXEC make distdir VERSION=$HOST
END_FOLD

# Update the current CI directory context to the newly created distdir.
export P_CI_DIR="${BASE_BUILD_DIR}/gridcoin-$HOST"

# --- Second Configure Pass (in distdir) ---
# This block handles the configure script execution within the distribution directory.
# It also ensures PKG_CONFIG_PATH is correctly set and clears config.cache,
# all within a single DOCKER_EXEC invocation.

# Perform the operations in the distdir within a single DOCKER_EXEC call.
if [ -z "$NO_DEPENDS" ]; then
  DOCKER_EXEC bash -c "
    pushd \"${BASE_BUILD_DIR}/gridcoin-${HOST}\" >/dev/null && \
    rm -f config.cache && \
    export PKG_CONFIG_PATH=\"${DEPENDS_DIR}/${HOST}/lib/pkgconfig:\$PKG_CONFIG_PATH\" && \
    echo \"PKG_CONFIG_PATH set for second configure: \$PKG_CONFIG_PATH\" && \
    ./configure --cache-file=../config.cache ${GRIDCOIN_CONFIG_ALL} ${GRIDCOIN_CONFIG} || ( (cat config.log) && false) && \
    popd >/dev/null
  "
else
  DOCKER_EXEC bash -c "
    pushd \"${BASE_BUILD_DIR}/gridcoin-${HOST}\" >/dev/null && \
    rm -f config.cache && \
    ./configure --cache-file=../config.cache ${GRIDCOIN_CONFIG_ALL} ${GRIDCOIN_CONFIG} || ( (cat config.log) && false) && \
    popd >/dev/null
  "
fi

# --- Error Trace Trap (for Sanitizer Output) ---
# Set up a trap to output sanitizer logs if the build fails.
set -o errtrace
trap 'DOCKER_EXEC "cat ${BASE_SCRATCH_DIR}/sanitizer-output/* 2> /dev/null"' ERR

# --- Build Step ---
# Compile the project using make. If it fails, rerun with verbose output for debugging.
# This ensures that zlib is linked after Boost libraries that depend on it.
# This appends -lz to the LDFLAGS just before the main build.
# This should happen within the DOCKER_EXEC context for the build.
if [ -z "$NO_DEPENDS" ]; then
  # For depends builds, prepend depends-built zlib path and library.
  DOCKER_EXEC bash -c "
    export LDFLAGS=\"\$LDFLAGS -L${DEPENDS_DIR}/${HOST}/lib -lz\"
    echo \"Adjusted LDFLAGS for build: \$LDFLAGS\"
    make \$MAKEJOBS \$GOAL || ( echo \"Build failure. Verbose build follows.\" && make \$GOAL V=1 ; false )
  "
else
  # For non-depends builds, use system zlib
  DOCKER_EXEC bash -c "
    export LDFLAGS=\"\$LDFLAGS -lz\"
    echo \"Adjusted LDFLAGS for build: \$LDFLAGS\"
    make \$MAKEJOBS \$GOAL || ( echo \"Build failure. Verbose build follows.\" && make \$GOAL V=1 ; false )
  "
fi

# --- Cache Statistics ---
# Display ccache statistics and disk usage of depends and previous releases directories.
BEGIN_FOLD cache_stats
DOCKER_EXEC "ccache --version | head -n 1 && ccache --show-stats"
DOCKER_EXEC du -sh "${DEPENDS_DIR}"/*/
DOCKER_EXEC du -sh "${PREVIOUS_RELEASES_DIR}"
END_FOLD
