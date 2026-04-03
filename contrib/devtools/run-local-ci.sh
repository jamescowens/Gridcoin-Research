#!/usr/bin/env bash

export LC_ALL=C

# -----------------------------------------------------------------------------
# Gridcoin Local CI Wrapper
# -----------------------------------------------------------------------------

# Act Configuration constants
ACT_PLATFORM="-P ubuntu-24.04=catthehacker/ubuntu:act-latest -P ubuntu-22.04=catthehacker/ubuntu:act-22.04"
ACT_ARCH="--container-architecture linux/amd64"
ACT_OPTS="--container-options \"--privileged\""

# Variables
WORKFLOW=""
JOB="all"
MATRIX_FLAGS=""
PARALLEL_LIMIT=""
ACT_JOBS="" # New variable for container concurrency

# -----------------------------------------------------------------------------
# Function: Help
# -----------------------------------------------------------------------------
show_help() {
    echo "Usage: ./run-local-ci.sh workflow=PATH [job=NAME] [matrix=key:val] [parallel=N] [act_jobs=N]"
    echo ""
    echo "Arguments:"
    echo "  workflow=PATH   (Required) Path to the YAML workflow file."
    echo "  job=NAME        Specific job ID to run. Default: all"
    echo "  matrix=k:v      Filter matrix jobs (e.g., matrix=host:x86_64-w64-mingw32)."
    echo "  parallel=N      Max build threads per job (inside container)."
    echo "  act_jobs=N      Max concurrent containers (overrides default of 4)."
    echo ""
    echo "Note: This script ALWAYS runs in a temporary copy of the repository"
    echo "      to prevent polluting your local source tree."
}

# -----------------------------------------------------------------------------
# Argument Parsing
# -----------------------------------------------------------------------------
for ARG in "$@"; do
    case "$ARG" in
        workflow=*)
            WORKFLOW="${ARG#*=}"
            ;;
        job=*)
            JOB="${ARG#*=}"
            ;;
        matrix=*)
            MATRIX_VAL="${ARG#*=}"
            MATRIX_FLAGS="--matrix $MATRIX_VAL"
            ACT_OPTS="$ACT_OPTS $MATRIX_FLAGS"
            ;;
        parallel=*)
            PARALLEL_LIMIT="${ARG#*=}"
            ;;
        act_jobs=*)
            ACT_JOBS="${ARG#*=}"
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown argument '$ARG'"
            show_help
            exit 1
            ;;
    esac
done

# Validation
if [ -z "$WORKFLOW" ] || [ ! -f "$WORKFLOW" ]; then
    echo "Error: Workflow file not found."
    exit 1
fi

# Prepare Job Flag for Act
JOB_FLAG=""
if [ "$JOB" != "all" ]; then
    JOB_FLAG="-j $JOB"
fi

# -----------------------------------------------------------------------------
# Ccache Configuration
# -----------------------------------------------------------------------------
if [ -d "$HOME/.ccache" ]; then
    echo "Detected ~/.ccache on host. Mapping to container..."
    ACT_OPTS="${ACT_OPTS/\"--privileged\"/\"--privileged -v $HOME/.ccache:/root/.ccache\"}"
else
    echo "Warning: ~/.ccache not found on host. Build will be slower."
fi

# -----------------------------------------------------------------------------
# Isolation Logic (Mandatory)
# -----------------------------------------------------------------------------
TEMP_DIR=$(mktemp -d -t act-gridcoin-XXXXXXXX)
echo "--------------------------------------------------------"
echo "ISOLATION MODE: Copying source to $TEMP_DIR"
echo "--------------------------------------------------------"

if command -v rsync >/dev/null 2>&1; then
    # Explicitly INCLUDE the build script so the wildcard exclude doesn't kill it
    # Add --chmod=u+w to ensure read-only files (git packs) become writable
    rsync -a --chmod=u+w \
        --include '/build_targets.sh' \
        --exclude '/build/' \
        --exclude '/build_*' \
        --exclude 'release_packages/' \
        . "$TEMP_DIR/"
fi

ORIG_DIR=$(pwd)
cd "$TEMP_DIR" || exit 1

# -----------------------------------------------------------------------------
# YAML Injection: Override Act Concurrency
# -----------------------------------------------------------------------------
# Act defaults to 4 concurrent jobs. We can override this by injecting
# 'max-parallel' into the strategy block of the temporary YAML file.
if [ -n "$ACT_JOBS" ]; then
    echo "Injecting 'max-parallel: $ACT_JOBS' into workflow..."
    # We use sed to insert the line after 'strategy:'.
    # We assume standard 2-space indentation for the injected line (adjusted to context).
    # This works for the specific format of Gridcoin YAMLs.
    sed -i "s/strategy:/strategy:\n      max-parallel: $ACT_JOBS/g" "$WORKFLOW"
fi

# -----------------------------------------------------------------------------
# Concurrency Logic (Threads per Container)
# -----------------------------------------------------------------------------
HOST_CORES=$(nproc)

if [ -z "$PARALLEL_LIMIT" ]; then
    echo "Analyzing workflow to determine job count..."

    ACT_PLAN=$(act -W "$WORKFLOW" $JOB_FLAG $MATRIX_FLAGS --list | tail -n +2 | grep -v "^$")
    JOB_COUNT=$(echo "$ACT_PLAN" | wc -l)

    echo "  -> Act reported $JOB_COUNT job definition(s)."

    if [ -z "$MATRIX_FLAGS" ] && grep -q "matrix:" "$WORKFLOW"; then
        # Search for 'distro' or 'host'. Exclude 'name'/'image'.
        MATRIX_ENTRIES=$(grep -E -c "^\s*(- )?(distro|host):" "$WORKFLOW")

        if [ "$MATRIX_ENTRIES" -gt "$JOB_COUNT" ]; then
             echo "  -> Matrix detected: Found $MATRIX_ENTRIES expansion entries (distro/host)."
             echo "  -> Overriding job count: $JOB_COUNT -> $MATRIX_ENTRIES"
             JOB_COUNT=$MATRIX_ENTRIES
        fi
    fi

    if [ "$JOB_COUNT" -lt 1 ]; then JOB_COUNT=1; fi

    PARALLEL_LIMIT=$((HOST_CORES / JOB_COUNT))
    if [ "$PARALLEL_LIMIT" -lt 1 ]; then PARALLEL_LIMIT=1; fi

    echo "Auto-Scaling: $HOST_CORES Host Cores / $JOB_COUNT Jobs = Limit $PARALLEL_LIMIT threads per job."
else
    echo "Manual Limit: Using $PARALLEL_LIMIT threads per job."
fi

ACT_OPTS="$ACT_OPTS --env CMAKE_BUILD_PARALLEL_LEVEL=$PARALLEL_LIMIT"
ACT_OPTS="$ACT_OPTS --env CTEST_PARALLEL_LEVEL=$PARALLEL_LIMIT"

# We need the real host workspace path
ACT_OPTS="$ACT_OPTS --env HOST_WORKSPACE=$TEMP_DIR"

echo "--------------------------------------------------------"
echo "Running Local CI via act"
echo "Workflow: $WORKFLOW"
echo "Job:      $JOB"
echo "Threads:  $PARALLEL_LIMIT (Per Container)"
echo "Limit:    ${ACT_JOBS:-4} (Concurrent Containers)"
echo "Context:  $TEMP_DIR"
echo "--------------------------------------------------------"

CMD="act -W \"$WORKFLOW\" $JOB_FLAG $ACT_PLATFORM $ACT_ARCH $ACT_OPTS"

echo "Executing: $CMD"
echo ""
eval "$CMD"
RET_CODE=$?

# Cleanup
echo ""
echo "Cleaning up temporary directory..."
cd "$ORIG_DIR" || exit
rm -rf "$TEMP_DIR"

exit $RET_CODE
