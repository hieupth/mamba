#!/bin/bash
# Detect miniforge releases from GitHub
# - Groups releases by YY.MM
# - Picks latest release per month (highest patch/build)
# - Formats tag as YY.MM (zero-padded month)
#
# Usage:
#   ./detect-miniforge.sh                     # Print all releases
#   ./detect-miniforge.sh --latest            # Print only latest
#   ./detect-miniforge.sh --tag TAG           # Get version for specific tag
#   ./detect-miniforge.sh --from TAG          # Print releases >= TAG
#   ./detect-miniforge.sh --latest --from TAG # Print latest if >= TAG

set -e

API_URL="https://api.github.com/repos/conda-forge/miniforge/releases?per_page=100"

# Parse arguments
MODE="all"
FROM_TAG=""
REQUESTED_TAG=""

while [ $# -gt 0 ]; do
    case "$1" in
        --latest)
            MODE="latest"
            shift
            ;;
        --tag)
            MODE="tag"
            REQUESTED_TAG="$2"
            shift 2
            ;;
        --from)
            FROM_TAG="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Fetch all releases, filter out prereleases, extract tag_names
RELEASES=$(curl -s "$API_URL" | perl -ne 'if (/"tag_name":\s*"([^"]+)"/) { $tag=$1 } if (/"prerelease":\s*false/ && $tag) { print "$tag\n"; $tag=undef }')

if [ -z "$RELEASES" ]; then
    echo "Error: Could not fetch miniforge releases" >&2
    exit 1
fi

# Process releases: group by YY.MM, pick latest per month
# Version format: YY.MM.PATCH-BUILD
declare -A MONTHLY_RELEASES

while IFS= read -r version; do
    # Extract components
    year=$(echo "$version" | cut -d'.' -f1)
    month=$(echo "$version" | cut -d'.' -f2)
    patch=$(echo "$version" | cut -d'.' -f3 | cut -d'-' -f1)
    build=$(echo "$version" | cut -d'-' -f2)

    # Zero-pad month to 2 digits
    month_padded=$(printf "%02d" "$month")

    # Create tag YY.MM
    tag="${year}.${month_padded}"

    # Create sort key: PATCH*1000 + BUILD (for comparing within same month)
    sort_key=$((patch * 1000 + build))

    # Store if this is newer for this month
    if [ -z "${MONTHLY_RELEASES[$tag]}" ]; then
        MONTHLY_RELEASES[$tag]="${version}|${sort_key}"
    else
        existing_key=$(echo "${MONTHLY_RELEASES[$tag]}" | cut -d'|' -f2)
        if [ "$sort_key" -gt "$existing_key" ]; then
            MONTHLY_RELEASES[$tag]="${version}|${sort_key}"
        fi
    fi
done <<< "$RELEASES"

# Function to convert tag to comparable integer (YYMM)
tag_to_int() {
    local tag="$1"
    echo "${tag//./}"
}

# Handle output mode
case "$MODE" in
    latest)
        # Get the latest tag
        latest_tag=$(printf "%s\n" "${!MONTHLY_RELEASES[@]}" | sort -t. -k1,1nr -k2,2nr | head -1)

        # Check --from filter
        if [ -n "$FROM_TAG" ]; then
            latest_int=$(tag_to_int "$latest_tag")
            from_int=$(tag_to_int "$FROM_TAG")
            if [ "$latest_int" -lt "$from_int" ]; then
                echo "Error: Latest tag $latest_tag is older than --from $FROM_TAG" >&2
                exit 1
            fi
        fi

        version=$(echo "${MONTHLY_RELEASES[$latest_tag]}" | cut -d'|' -f1)
        echo "VERSION=$version"
        echo "TAG=$latest_tag"
        ;;
    tag)
        if [ -z "$REQUESTED_TAG" ]; then
            echo "Error: --tag requires a tag argument (e.g., --tag 25.11)" >&2
            exit 1
        fi
        if [ -z "${MONTHLY_RELEASES[$REQUESTED_TAG]}" ]; then
            echo "Error: Tag $REQUESTED_TAG not found" >&2
            exit 1
        fi
        version=$(echo "${MONTHLY_RELEASES[$REQUESTED_TAG]}" | cut -d'|' -f1)
        echo "VERSION=$version"
        echo "TAG=$REQUESTED_TAG"
        ;;
    *)
        # Print releases sorted by tag descending, optionally filtered by --from
        if [ -n "$FROM_TAG" ]; then
            from_int=$(tag_to_int "$FROM_TAG")
        fi

        printf "%s\n" "${!MONTHLY_RELEASES[@]}" | sort -t. -k1,1nr -k2,2nr | while read -r tag; do
            if [ -n "$FROM_TAG" ]; then
                tag_int=$(tag_to_int "$tag")
                if [ "$tag_int" -lt "$from_int" ]; then
                    continue
                fi
            fi
            version=$(echo "${MONTHLY_RELEASES[$tag]}" | cut -d'|' -f1)
            echo "TAG=$tag VERSION=$version"
        done
        ;;
esac
