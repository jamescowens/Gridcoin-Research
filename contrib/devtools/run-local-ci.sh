#!/usr/bin/env bash

export LC_ALL=C

# -----------------------------------------------------------------------------
# Gridcoin Local CI Wrapper
# -----------------------------------------------------------------------------
# This script wraps 'act' to run GitHub Actions workflows locally using Docker.
# It pre-configures the necessary QEMU and privileged flags required for
# cross-compilation jobs.
#
# Requirements:
#   1. Docker
#      NOTE: It is highly recommended to add your local user to the 'docker' group
#      to avoid running this script with root privileges.
#        $ sudo usermod -aG docker $USER
#        $ newgrp docker
#
#   2. act (https://github.com/nektos/act)
#      Installation (Linux):
#        $ curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
#      Installation (macOS):
#        $ brew install act
# -----------------------------------------------------------------------------

# Default Configuration
DEFAULT_JOB="all"

# Act Configuration constants
ACT_PLATFORM="-P ubuntu-24.04=catthehacker/ubuntu:act-latest"
ACT_ARCH="--container-architecture linux/amd64"
ACT_OPTS="--container-options \"--privileged\""

# Variables to hold final values
WORKFLOW=""
JOB="$DEFAULT_JOB"

# -----------------------------------------------------------------------------
# Function: Help
# -----------------------------------------------------------------------------
show_help() {
    echo "Usage: ./run-local-ci.sh workflow=PATH [job=NAME]"
    echo ""
    echo "Wrapper for 'act' to run GitHub Actions workflows locally with QEMU support."
    echo ""
    echo "Arguments:"
    echo "  workflow=PATH   (Required) Path to the YAML workflow file."
    echo "  job=NAME        Specific job ID to run (e.g., 'linux-arm64-system')."
    echo "                  Set to 'all' to run every job in the workflow."
    echo "                  Default: $DEFAULT_JOB"
    echo ""
    echo "  help            Show this message."
    echo ""
    echo "Examples:"
    echo "  ./contrib/run-local-ci.sh workflow=.github/workflows/cmake_compatibility.yml"
    echo "  ./contrib/run-local-ci.sh workflow=.github/workflows/cmake_compatibility.yml job=linux-arm64-system"
    echo ""
}

# -----------------------------------------------------------------------------
# Argument Parsing (name=value)
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
            # Extracts "key:value" (e.g., host:x86_64-pc-linux-gnu)
            MATRIX_VAL="${ARG#*=}"
            # Appends it to the ACT options
            ACT_OPTS="$ACT_OPTS --matrix $MATRIX_VAL"
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

# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

# 1. Check if workflow argument was provided
if [ -z "$WORKFLOW" ]; then
    echo "Error: You must specify a workflow file using 'workflow=path/to/file.yml'."
    echo ""
    show_help
    exit 1
fi

# 2. Check if the file actually exists on disk
if [ ! -f "$WORKFLOW" ]; then
    echo "Error: Workflow file not found at: $WORKFLOW"
    exit 1
fi

# -----------------------------------------------------------------------------
# Logic & Execution
# -----------------------------------------------------------------------------

# Construct the job flag
# If job is "all", we simply omit the -j flag, and act runs everything.
JOB_FLAG=""
if [ "$JOB" != "all" ]; then
    JOB_FLAG="-j $JOB"
fi

echo "--------------------------------------------------------"
echo "Running Local CI via act"
echo "Workflow: $WORKFLOW"
echo "Job:      $JOB"
echo "--------------------------------------------------------"

# Execute act
# Note: We use eval to handle the quoted --container-options correctly
CMD="act -W \"$WORKFLOW\" $JOB_FLAG $ACT_PLATFORM $ACT_ARCH $ACT_OPTS"

echo "Executing: $CMD"
echo ""

eval "$CMD"
