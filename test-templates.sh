#!/bin/bash
# Automated Template Testing Script
# Tests all 4 templates and their enhancements

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKSTAGE_URL="${BACKSTAGE_URL:-http://localhost:7007}"
ARGOCD_URL="${ARGOCD_URL:-http://localhost:8080}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

log_pass() {
  echo -e "${GREEN}✅ $1${NC}"
  ((PASS++))
}

log_fail() {
  echo -e "${RED}❌ $1${NC}"
  ((FAIL++))
}

echo "════════════════════════════════════════════════════════════"
echo "  IDP Template Enhancement Testing"
echo "════════════════════════════════════════════════════════════"
echo ""

# Phase 1: Quick Environment Check
echo "Phase 1: Quick Environment Check..."
echo "─────────────────────────────────────────────────────────────"

if [ -n "$GITHUB_TOKEN" ]; then
  log_pass "GITHUB_TOKEN is set (optional for file validation)"
else
  echo -e "${YELLOW}⚠️  GITHUB_TOKEN not set (required for GitHub tests, not needed for file validation)${NC}"
fi

if command -v kubectl &> /dev/null; then
  log_pass "kubectl is installed"
else
  log_fail "kubectl not found"
fi

echo ""
echo "Phase 2: Template File Validation..."
echo "─────────────────────────────────────────────────────────────"

# Check new-service template files
if [ -f "$SCRIPT_DIR/development/templates/new-service/skeleton/score.yaml" ]; then
  log_pass "new-service: score.yaml exists"
else
  log_fail "new-service: score.yaml missing"
fi

if grep -q "score.dev/v1b1" "$SCRIPT_DIR/development/templates/new-service/skeleton/score.yaml" 2>/dev/null; then
  log_pass "new-service: score.yaml has correct apiVersion"
else
  log_fail "new-service: score.yaml missing apiVersion"
fi

if [ -f "$SCRIPT_DIR/development/templates/new-service/skeleton/.github/workflows/init-setup.yaml" ]; then
  log_pass "new-service: init-setup.yaml exists"
else
  log_fail "new-service: init-setup.yaml missing"
fi

if [ -f "$SCRIPT_DIR/development/templates/new-service/skeleton/.github/workflows/initial-config.yaml" ]; then
  log_pass "new-service: initial-config.yaml exists"
else
  log_fail "new-service: initial-config.yaml missing"
fi

if grep -q "validate-score" "$SCRIPT_DIR/development/templates/new-service/skeleton/.github/workflows/ci.yaml" 2>/dev/null; then
  log_pass "new-service: CI has validate-score job"
else
  log_fail "new-service: CI missing validate-score job"
fi

# Check eks-cluster template files (infrastructure - no score.yaml needed)
if ! [ -f "$SCRIPT_DIR/development/templates/eks-cluster/skeleton/score.yaml" ]; then
  log_pass "eks-cluster: score.yaml correctly not present (infrastructure)"
else
  log_fail "eks-cluster: should not have score.yaml"
fi

# Check onboard-team template files (platform - no score.yaml needed)
if ! [ -f "$SCRIPT_DIR/development/templates/onboard-team/skeleton/score.yaml" ]; then
  log_pass "onboard-team: score.yaml correctly not present (platform)"
else
  log_fail "onboard-team: should not have score.yaml"
fi

if [ -f "$SCRIPT_DIR/development/templates/onboard-team/skeleton/.github/workflows/init-setup.yaml" ]; then
  log_pass "onboard-team: init-setup.yaml exists"
else
  log_fail "onboard-team: init-setup.yaml missing"
fi

echo ""
echo "Phase 3: Catalog Integration..."
echo "─────────────────────────────────────────────────────────────"

# Check annotations in template catalog files
if grep -q "score.dev/workload-spec" "$SCRIPT_DIR/development/templates/new-service/skeleton/catalog-info.yaml" 2>/dev/null; then
  log_pass "new-service: catalog has score.dev annotations"
else
  log_fail "new-service: catalog missing score.dev annotations"
fi

if ! grep -q "score.dev/workload-spec" "$SCRIPT_DIR/development/templates/eks-cluster/skeleton/catalog-info.yaml" 2>/dev/null; then
  log_pass "eks-cluster: correctly no score.dev annotations (infrastructure)"
else
  log_fail "eks-cluster: should not have score.dev annotations"
fi

if ! grep -q "score.dev/workload-spec" "$SCRIPT_DIR/development/templates/onboard-team/skeleton/catalog-info.yaml" 2>/dev/null; then
  log_pass "onboard-team: correctly no score.dev annotations (platform)"
else
  log_fail "onboard-team: should not have score.dev annotations"
fi

echo ""
echo "Phase 4: React Components..."
echo "─────────────────────────────────────────────────────────────"

if [ -f "$SCRIPT_DIR/packages/app/src/components/catalog/ProvisioningDetailsCard.tsx" ]; then
  log_pass "ProvisioningDetailsCard.tsx exists"
else
  log_fail "ProvisioningDetailsCard.tsx missing"
fi

if [ -f "$SCRIPT_DIR/packages/app/src/components/catalog/ProvisioningTimelineCard.tsx" ]; then
  log_pass "ProvisioningTimelineCard.tsx exists"
else
  log_fail "ProvisioningTimelineCard.tsx missing"
fi

echo ""
echo "Phase 5: TechDocs Documentation..."
echo "─────────────────────────────────────────────────────────────"

if grep -q "Score Workload Specification" "$SCRIPT_DIR/development/catalog/systems/docs/getting-started.md" 2>/dev/null; then
  log_pass "TechDocs: Score section exists"
else
  log_fail "TechDocs: Score section missing"
fi

if grep -q "score-compose" "$SCRIPT_DIR/development/catalog/systems/docs/getting-started.md" 2>/dev/null; then
  log_pass "TechDocs: score-compose documented"
else
  log_fail "TechDocs: score-compose not documented"
fi

echo ""
echo "Phase 6: Output Links in Templates..."
echo "─────────────────────────────────────────────────────────────"

if grep -q "Open in Catalog" "$SCRIPT_DIR/development/templates/new-service/template.yaml" 2>/dev/null; then
  log_pass "new-service: Output links configured"
else
  log_fail "new-service: Output links missing"
fi

if grep -q "Track provisioning" "$SCRIPT_DIR/development/templates/eks-cluster/template.yaml" 2>/dev/null; then
  log_pass "eks-cluster: Track provisioning link exists"
else
  log_fail "eks-cluster: Track provisioning link missing"
fi

if grep -q "Open Team in Catalog" "$SCRIPT_DIR/development/templates/onboard-team/template.yaml" 2>/dev/null; then
  log_pass "onboard-team: Output links configured"
else
  log_fail "onboard-team: Output links missing"
fi

echo ""
echo "Phase 7: Catalog Hygiene Script..."
echo "─────────────────────────────────────────────────────────────"

if [ -f "$SCRIPT_DIR/scripts/catalog-hygiene.js" ]; then
  log_pass "catalog-hygiene.js exists"

  if grep -q "score.dev/workload-spec" "$SCRIPT_DIR/scripts/catalog-hygiene.js" 2>/dev/null; then
    log_pass "catalog-hygiene: score.yaml check implemented"
  else
    log_fail "catalog-hygiene: score.yaml check missing"
  fi
else
  log_fail "catalog-hygiene.js missing"
fi

echo ""
echo "Phase 8: YAML Validation (Rendered Templates)..."
echo "─────────────────────────────────────────────────────────────"

# Note: Template files contain Nunjucks templating syntax which is not valid YAML
# until after rendering. We just verify they contain the required structure markers.
# Only new-service has score.yaml (infrastructure templates don't need it)

if grep -q "apiVersion:" "$SCRIPT_DIR/development/templates/new-service/skeleton/score.yaml" && \
   grep -q "metadata:" "$SCRIPT_DIR/development/templates/new-service/skeleton/score.yaml" && \
   grep -q "containers:" "$SCRIPT_DIR/development/templates/new-service/skeleton/score.yaml"; then
  log_pass "new-service: score.yaml has required YAML structure"
else
  log_fail "new-service: score.yaml missing YAML structure"
fi

if ! test -f "$SCRIPT_DIR/development/templates/eks-cluster/skeleton/score.yaml"; then
  log_pass "eks-cluster: score.yaml correctly NOT present (infrastructure template)"
else
  log_fail "eks-cluster: should not have score.yaml"
fi

if ! test -f "$SCRIPT_DIR/development/templates/onboard-team/skeleton/score.yaml"; then
  log_pass "onboard-team: score.yaml correctly NOT present (platform template)"
else
  log_fail "onboard-team: should not have score.yaml"
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "Test Results: $PASS passed, $FAIL failed"
echo "════════════════════════════════════════════════════════════"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}🎉 All automated tests passed!${NC}"
  echo ""
  echo "Next steps:"
  echo "1. Run full manual testing using TESTING_RECOMMENDATIONS.md"
  echo "2. Test each template end-to-end via Backstage UI"
  echo "3. Verify GitHub Actions workflows run correctly"
  echo "4. Test catalog integration and provisioning cards"
  exit 0
else
  echo -e "${RED}⚠️  Some tests failed. Review above and fix issues.${NC}"
  exit 1
fi
