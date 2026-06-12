#!/usr/bin/env bash
#
# Catalog Hygiene Check Script
#
# NOTE: When Backstage moves to a hosted environment, this script can be converted
# to a scheduled GitHub Actions workflow by replacing the localhost URL
# (http://localhost:7007 or via BACKSTAGE_BACKEND_URL) with the hosted Backstage URL.
#
# This script:
# 1. Obtains a guest auth token from Backstage
# 2. Queries all entities from the Backstage catalog
# 3. Flags entities with missing spec.owner
# 4. Flags entities with non-existent owner Groups
# 5. Flags Resource entities of type 'kubernetes-cluster' that are missing claim files (ghost entries)
# 6. Outputs a Markdown table of issues and exits non-zero if any issues are found.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

node "${SCRIPT_DIR}/catalog-hygiene.js" "$@"
