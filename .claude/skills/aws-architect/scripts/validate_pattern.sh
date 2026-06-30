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

# WELL-ARCHITECTED REVIEW: block on unresolved high-severity Gaps
WA_DOC="${REPO_ROOT}/infrastructure/patterns/${PATTERN}/docs/well-architected-review.md"
if [[ ! -f "$WA_DOC" ]]; then
  echo "MISSING: docs/well-architected-review.md (run well-architected workflow step)"
  errors=$((errors + 1))
else
  echo "OK (exists): docs/well-architected-review.md"
  # A high-severity Gap that is still unresolved looks like "| Gap |" on a
  # row whose Pillar column begins with a capital letter (not a header row).
  # We grep for lines that have a Gap cell and flag them.
  if grep -qiP '^\|\s*(SEC|REL|OPS|PERF|COST|SUS)\s*\|.*\|\s*Gap\s*\|' "$WA_DOC" 2>/dev/null; then
    echo "FAIL (well-architected): high-severity Gap(s) found in well-architected-review.md"
    grep -iP '^\|\s*(SEC|REL|OPS|PERF|COST|SUS)\s*\|.*\|\s*Gap\s*\|' "$WA_DOC" | head -10
    errors=$((errors + 1))
  else
    echo "OK (well-architected): no blocking high-severity Gaps"
  fi
fi

# DIAGRAM: check architecture.png and .svg are present and non-empty
# Only required for composite patterns (those with a composition.yaml).
if [[ -f "${PATTERN_DIR}/composition.yaml" ]]; then
  for ext in png svg; do
    diagram_file="${REPO_ROOT}/infrastructure/patterns/${PATTERN}/docs/architecture.${ext}"
    if [[ ! -f "$diagram_file" ]]; then
      echo "MISSING: docs/architecture.${ext} (run diagram workflow step)"
      errors=$((errors + 1))
    elif [[ ! -s "$diagram_file" ]]; then
      echo "FAIL (diagram): docs/architecture.${ext} is empty"
      errors=$((errors + 1))
    else
      echo "OK (diagram):  docs/architecture.${ext}"
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
