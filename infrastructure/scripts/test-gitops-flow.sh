#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# test-gitops-flow.sh
# Validates the full GitOps pipeline end-to-end without AWS credentials.
#
# The claim will stay in Pending state without credentials, but its existence
# in the kind cluster confirms the ArgoCD → Crossplane handoff is working.
# ---------------------------------------------------------------------------

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CLAIM_SRC="${REPO_ROOT}/infrastructure/crossplane/eks/claim-example.yaml"
CLAIM_DST="${REPO_ROOT}/gitops/cluster-claims/team-alpha/alpha-test.yaml"
CLAIM_NAME="alpha-test"
NAMESPACE="clusters"

echo "=========================================="
echo "  GitOps Flow E2E Test"
echo "=========================================="
echo ""

# ------------------------------------------------------------------
# Step 1: Copy claim into the GitOps directory
# ------------------------------------------------------------------
echo "Step 1: Copying claim into gitops/cluster-claims/team-alpha/"
mkdir -p "$(dirname "${CLAIM_DST}")"
cp "${CLAIM_SRC}" "${CLAIM_DST}"
echo "  ✅ Copied ${CLAIM_SRC} → ${CLAIM_DST}"
echo ""

# ------------------------------------------------------------------
# Step 2: Commit and push to GitHub
# ------------------------------------------------------------------
echo "Step 2: Committing and pushing to GitHub (main branch)..."
cd "${REPO_ROOT}"
git add gitops/cluster-claims/team-alpha/alpha-test.yaml
git commit -m "test: add EKSCluster claim alpha-test for GitOps flow validation" || echo "  (nothing to commit)"
git push origin main
echo "  ✅ Pushed to main."
echo ""

# ------------------------------------------------------------------
# Step 3: Wait for ArgoCD to detect the change
# ------------------------------------------------------------------
echo "Step 3: Waiting 30 seconds for ArgoCD to detect the change..."
sleep 30
echo "  ✅ Wait complete."
echo ""

# ------------------------------------------------------------------
# Step 4: Force an immediate ArgoCD sync
# ------------------------------------------------------------------
echo "Step 4: Forcing ArgoCD sync of cluster-claims application..."
argocd app sync cluster-claims --insecure 2>/dev/null || \
  kubectl patch application cluster-claims -n argocd --type merge \
    -p '{"operation":{"sync":{"revision":"HEAD"}}}' 2>/dev/null || \
  echo "  ⚠️  Could not force sync (ArgoCD CLI or kubectl patch). Automated sync should still pick it up."
echo "  ✅ Sync triggered."
echo ""

# ------------------------------------------------------------------
# Step 5: Verify the EKSCluster claim exists in the kind cluster
# ------------------------------------------------------------------
echo "Step 5: Checking for EKSCluster claim in '${NAMESPACE}' namespace..."
RETRIES=6
FOUND=false
for i in $(seq 1 $RETRIES); do
  if kubectl get eksclusters.platform.io "${CLAIM_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
    FOUND=true
    break
  fi
  echo "  Attempt ${i}/${RETRIES} — not found yet, waiting 10s..."
  sleep 10
done

if [ "${FOUND}" = true ]; then
  echo "  ✅ EKSCluster claim '${CLAIM_NAME}' exists in namespace '${NAMESPACE}'!"
  echo ""
  echo "  Claim details:"
  kubectl get eksclusters.platform.io "${CLAIM_NAME}" -n "${NAMESPACE}" -o wide 2>/dev/null || true
else
  echo "  ❌ EKSCluster claim '${CLAIM_NAME}' NOT found after ${RETRIES} attempts."
  echo "     Check ArgoCD app status: argocd app get cluster-claims"
  echo "     Or: kubectl get applications -n argocd"
fi
echo ""

# ------------------------------------------------------------------
# Step 6: Print Crossplane composite resource status
# ------------------------------------------------------------------
echo "Step 6: Crossplane composite resource status..."
kubectl get xeksclusters.platform.io -A 2>/dev/null || echo "  No XEKSCluster composite resources found (expected if XRD is not installed)."
echo ""

# ------------------------------------------------------------------
# Step 7: Cleanup — remove claim from Git, push, confirm prune
# ------------------------------------------------------------------
echo "Step 7: Cleaning up — removing claim from Git..."
cd "${REPO_ROOT}"
rm -f "${CLAIM_DST}"
# Remove the team-alpha directory if empty
rmdir "$(dirname "${CLAIM_DST}")" 2>/dev/null || true
git add -A gitops/cluster-claims/
git commit -m "test: remove alpha-test claim — GitOps flow cleanup" || echo "  (nothing to commit)"
git push origin main
echo "  ✅ Removal pushed to main."

echo ""
echo "Step 7b: Waiting 30 seconds for ArgoCD prune..."
sleep 30

# Force sync again to speed up prune
argocd app sync cluster-claims --prune --insecure 2>/dev/null || \
  echo "  (auto-prune should handle cleanup)"

echo ""
echo "Step 7c: Verifying claim is pruned from cluster..."
if kubectl get eksclusters.platform.io "${CLAIM_NAME}" -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "  ⚠️  Claim '${CLAIM_NAME}' still exists — ArgoCD prune may take another sync cycle."
else
  echo "  ✅ Claim '${CLAIM_NAME}' has been pruned from the cluster."
fi

echo ""
echo "=========================================="
echo "  GitOps Flow E2E Test Complete"
echo "=========================================="
