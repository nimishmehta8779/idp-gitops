#!/usr/bin/env bash
set -euo pipefail

# Resolve script directory and change to repository root
cd "$(dirname "$0")/.."

# Path to tests relative to repository root
TEST_DIR="infrastructure/kyverno/tests"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

FAILED=0

echo "=========================================="
echo "    Kyverno Policy Test Suite"
echo "=========================================="
echo ""

# Helper to run positive test
run_positive_test() {
  local file="$1"
  local desc="$2"
  echo -n "Test: $desc ... "
  if kubectl apply -f "$file" >/dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC} (Admitted successfully)"
    # Cleanup
    kubectl delete -f "$file" --ignore-not-found >/dev/null 2>&1
  else
    echo -e "${RED}FAIL${NC} (Unexpectedly denied)"
    FAILED=1
  fi
}

# Helper to run negative test
run_negative_test() {
  local file="$1"
  local desc="$2"
  echo -n "Test: $desc ... "
  if kubectl apply -f "$file" >/dev/null 2>&1; then
    echo -e "${RED}FAIL${NC} (Unexpectedly admitted)"
    # Cleanup just in case
    kubectl delete -f "$file" --ignore-not-found >/dev/null 2>&1
    FAILED=1
  else
    echo -e "${GREEN}PASS${NC} (Denied as expected)"
  fi
}

# 1. Apply a valid claim → expect admitted
run_positive_test "$TEST_DIR/valid-claim.yaml" "Valid claim (should be admitted)"

# 2. Apply claim missing team label → expect denied
run_negative_test "$TEST_DIR/missing-team-label.yaml" "Missing team label (should be denied)"

# 3. Apply claim with nodeCount: 15 → expect denied
run_negative_test "$TEST_DIR/invalid-node-count.yaml" "nodeCount: 15 (should be denied)"

# 4. Apply claim with unapproved region eu-west-1 → expect denied
run_negative_test "$TEST_DIR/invalid-region.yaml" "Region: eu-west-1 (should be denied)"

# 5. Apply claim with unapproved instanceType → expect denied
run_negative_test "$TEST_DIR/invalid-instance-type.yaml" "InstanceType: t3.nano (should be denied)"

# 6. Apply staging claim without approved-by annotation → expect denied
run_negative_test "$TEST_DIR/staging-no-approval.yaml" "Staging claim without approved-by annotation (should be denied)"

echo ""
echo "=========================================="
if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All Kyverno policy tests passed successfully!${NC}"
  exit 0
else
  echo -e "${RED}Some Kyverno policy tests failed.${NC}"
  exit 1
fi
