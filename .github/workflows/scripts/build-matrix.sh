#!/bin/bash
# Generate GitHub Actions matrix for building mamba images
#
# Usage:
#   ./build-matrix.sh                    # All releases from FROM_TAG
#   ./build-matrix.sh --latest           # Only latest release
#   ./build-matrix.sh --from 25.11       # All releases >= 25.11
#
# Environment variables:
#   FROM_TAG   - Default: 25.11
#   BUILD_MODE - "latest" or "all", default: "latest"

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Parse arguments
FROM_TAG="${FROM_TAG:-25.11}"
BUILD_MODE="${BUILD_MODE:-latest}"

while [ $# -gt 0 ]; do
    case "$1" in
        --latest) BUILD_MODE="latest"; shift ;;
        --from) FROM_TAG="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Function: convert tag to integer (YYMM)
tag_to_int() {
    echo "${1//./}"
}

# Function: get ubuntu version for a given miniforge tag
get_ubuntu_version() {
    local tag="$1"
    local tag_int=$(tag_to_int "$tag")
    local ubuntu_version=""
    local best_threshold=0

    # Read mapping config (skip comments and empty lines)
    while IFS=: read -r threshold ubuntu; do
        [ -z "$threshold" ] && continue
        [[ "$threshold" =~ ^# ]] && continue
        threshold_int=$(tag_to_int "$threshold")
        if [ "$threshold_int" -le "$tag_int" ] && [ "$threshold_int" -ge "$best_threshold" ]; then
            best_threshold=$threshold_int
            ubuntu_version="$ubuntu"
        fi
    done < "$SCRIPT_DIR/ubuntu-mapping.conf"

    echo "${ubuntu_version:-24.04}"
}

# Detect releases
DETECT_OUTPUT=$("$SCRIPT_DIR/detect-miniforge.sh" --from "$FROM_TAG")

# Parse releases into arrays
declare -a TAGS VERSIONS UBUNTUS

while IFS= read -r line; do
    TAG=$(echo "$line" | grep -oP 'TAG=\K[^ ]+')
    VERSION=$(echo "$line" | grep -oP 'VERSION=\K.+')
    UBUNTU=$(get_ubuntu_version "$TAG")
    TAGS+=("$TAG")
    VERSIONS+=("$VERSION")
    UBUNTUS+=("$UBUNTU")
done <<< "$DETECT_OUTPUT"

# Build matrix JSON
if [ "$BUILD_MODE" = "latest" ]; then
    echo "{\"include\":[{\"tag\":\"${TAGS[0]}\",\"version\":\"${VERSIONS[0]}\",\"ubuntu\":\"${UBUNTUS[0]}\",\"is_latest\":true}]}"
else
    echo -n '{"include":['
    for i in "${!TAGS[@]}"; do
        [ $i -gt 0 ] && echo -n ','
        IS_LATEST="false"
        [ $i -eq 0 ] && IS_LATEST="true"
        echo -n "{\"tag\":\"${TAGS[$i]}\",\"version\":\"${VERSIONS[$i]}\",\"ubuntu\":\"${UBUNTUS[$i]}\",\"is_latest\":$IS_LATEST}"
    done
    echo ']}'
fi
