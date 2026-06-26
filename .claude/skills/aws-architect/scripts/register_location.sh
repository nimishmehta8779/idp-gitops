#!/usr/bin/env bash
# Register a pattern's Backstage Location entity via the Backstage API.
# Usage: register_location.sh <pattern-name> <backstage-base-url>
# The Location entity tells Backstage where to find the template.yaml.
set -euo pipefail

PATTERN=$1
BACKSTAGE_URL=${2:-http://localhost:7007}
LOCATION_FILE="infrastructure/patterns/${PATTERN}/backstage/location.yaml"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

if [[ ! -f "$LOCATION_FILE" ]]; then
  echo "ERROR: $LOCATION_FILE not found. Generate the pattern first."
  exit 1
fi

echo "Registering location for pattern: ${PATTERN}"
curl -s -X POST \
  "${BACKSTAGE_URL}/api/catalog/locations" \
  -H "Content-Type: application/json" \
  -d "{\"type\": \"url\", \"target\": \"$(cat $LOCATION_FILE | grep 'targets:' -A1 | tail -1 | tr -d ' -')\"}" \
  | jq .

echo "Done. Backstage will crawl the template within ~60 seconds."
