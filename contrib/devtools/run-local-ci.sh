#!/usr/bin/env bash

export LC_ALL=C

# -----------------------------------------------------------------------------
# Gridcoin Local CI Wrapper
# -----------------------------------------------------------------------------

# Act Configuration constants
ACT_PLATFORM="-P ubuntu-24.04=catthehacker/ubuntu:act-latest"
ACT_ARCH="--container-architecture linux/amd64"
# We will append --env flags to this variable
ACT_OPTS="--container-options \"--privileged\""

# Variables to hold final values
WORKFLOW=""
JOB="all"
MATRIX_FILTER=""
PARALLEL_LIMIT=""

# -----------------------------------------------------------------------------
# Function: Help
# -----------------------------------------------------------------------------
show_help() {
    echo "Usage: ./run-local-ci.sh workflow=PATH [job=NAME] [matrix=key:val] [parallel=N]"
    echo ""
    echo "Arguments:"
    echo "  workflow=PATH   (Required) Path to the YAML workflow file."
    echo "  job=NAME        Specific job ID to run. Default: all"
    echo "  matrix=k:v      Filter matrix jobs (e.g., matrix=host:x86_64-w64-mingw32)."
    echo "  parallel=N      Max build threads per job. Default: Auto-calculated."
    echo ""
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
            ACT_OPTS="$ACT_OPTS --matrix $MATRIX_VAL"
            MATRIX_FILTER="true"
            ;;
        parallel=*)
            PARALLEL_LIMIT="${ARG#*=}"
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
# Concurrency Logic
# -----------------------------------------------------------------------------
HOST_CORES=$(nproc)

# If user didn't specify a manual limit, calculate it dynamically
if [ -z "$PARALLEL_LIMIT" ]; then
    echo "Analyzing workflow to determine job count..."

    # Run act in list mode to see what WOULD run.
    # 'tail -n +2' skips the header line. 'grep -v "^$"' skips empty lines.
    # Note: We don't need platform/arch flags just to list jobs.
    ACT_PLAN=$(act -W "$WORKFLOW" $JOB_FLAG --list | tail -n +2 | grep -v "^$")

    # Count the lines (each line is a job container)
    JOB_COUNT=$(echo "$ACT_PLAN" | wc -l)

    # Sanity check
    if [ "$JOB_COUNT" -lt 1 ]; then JOB_COUNT=1; fi

    echo "Detected $JOB_COUNT jobs scheduled to run."

    # Calculate Limit: Host Cores / Job Count
    # We use integer division (bash default)
    PARALLEL_LIMIT=$((HOST_CORES / JOB_COUNT))

    # Ensure at least 1 thread per job
    if [ "$PARALLEL_LIMIT" -lt 1 ]; then PARALLEL_LIMIT=1; fi

    echo "Auto-Scaling: $HOST_CORES Host Cores / $JOB_COUNT Jobs = Limit $PARALLEL_LIMIT threads per job."
else
    echo "Manual Limit: Using $PARALLEL_LIMIT threads per job."
fi

# Inject the limit as environment variables for CMake and CTest
ACT_OPTS="$ACT_OPTS --env CMAKE_BUILD_PARALLEL_LEVEL=$PARALLEL_LIMIT"
ACT_OPTS="$ACT_OPTS --env CTEST_PARALLEL_LEVEL=$PARALLEL_LIMIT"

echo "--------------------------------------------------------"
echo "Running Local CI via act"
echo "Workflow: $WORKFLOW"
echo "Job:      $JOB"
echo "Threads:  $PARALLEL_LIMIT (Per Container)"
echo "--------------------------------------------------------"

CMD="act -W \"$WORKFLOW\" $JOB_FLAG $ACT_PLATFORM $ACT_ARCH $ACT_OPTS"

echo "Executing: $CMD"
echo ""
eval "$CMD"
