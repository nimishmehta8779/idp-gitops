#!/usr/bin/env bash
# Validate generated Crossplane YAML files for a pattern.
# Usage: validate_pattern.sh <pattern-name>
set -euo pipefail

PATTERN=$1
PATTERN_DIR="infrastructure/patterns/${PATTERN}/compositions"
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

errors=0
echo "=== Validating pattern: ${PATTERN} ==="

for f in xrd.yaml composition.yaml; do
  if [[ ! -f "${PATTERN_DIR}/${f}" ]]; then
    echo "MISSING: ${PATTERN_DIR}/${f}"
    errors=$((errors + 1))
  fi
done

if command -v yq &>/dev/null; then
  for yaml_file in "${PATTERN_DIR}"/*.yaml; do
    if yq eval '.' "$yaml_file" > /dev/null 2>&1; then
      echo "OK (yaml):  $yaml_file"
    else
      echo "FAIL (yaml): $yaml_file"
      yq eval '.' "$yaml_file" 2>&1 | head -5
      errors=$((errors + 1))
    fi
  done
else
  echo "WARN: yq not found — install with: brew install yq"
fi

if [[ -f "${PATTERN_DIR}/composition.yaml" ]]; then
  for tag in managed-by team environment cost-center; do
    if grep -q "${tag}" "${PATTERN_DIR}/composition.yaml"; then
      echo "OK (tag): ${tag}"
    else
      echo "FAIL (tag): mandatory tag '${tag}' missing in composition.yaml"
      errors=$((errors + 1))
    fi
  done
fi

echo ""
if [[ $errors -eq 0 ]]; then
  echo "✓ All checks passed for pattern: ${PATTERN}"
  exit 0
else
  echo "✗ ${errors} check(s) failed"
  exit 1
fi
