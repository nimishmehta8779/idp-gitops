#!/bin/bash
# Test enterprise GitOps flow end to end

# Load GITHUB_TOKEN from env or local .env
if [ -z "$GITHUB_TOKEN" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ENV_FILE="${SCRIPT_DIR}/../backstage/.env"
  if [ -f "$ENV_FILE" ]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
  fi
fi

if [ -n "$GITHUB_TOKEN" ]; then
  export GH_TOKEN="$GITHUB_TOKEN"
fi

echo "=== Enterprise IDP Flow Test ==="

# Step 1: Pushing test claim
echo -n "Step 1: Pushing test claim to team-alpha-infra... "
EXISTING_SHA=$(gh api repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml 2>/dev/null | jq -r '.sha // empty')

if [ -n "$EXISTING_SHA" ] && [ "$EXISTING_SHA" != "null" ]; then
  if gh api --method PUT \
    repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml \
    --field message="test: update alpha-dev-test-01 claim" \
    --field content="$(cat infrastructure/crossplane/eks/claim-example.yaml | base64)" \
    --field sha="$EXISTING_SHA" >/dev/null 2>&1; then
    echo "✅"
  else
    echo "❌"
    exit 1
  fi
else
  if gh api --method PUT \
    repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml \
    --field message="test: add alpha-dev-test-01 claim" \
    --field content="$(cat infrastructure/crossplane/eks/claim-example.yaml | base64)" >/dev/null 2>&1; then
    echo "✅"
  else
    echo "❌"
    exit 1
  fi
fi

# Step 2: Wait for ArgoCD to detect change
echo "Step 2: Waiting for ArgoCD sync..."
sleep 30

# Step 3: Force ArgoCD sync
echo -n "Step 3: Forcing ArgoCD sync... "
SYNC_RES=$(argocd app sync team-alpha-eks-clusters --insecure >/dev/null 2>&1 && echo "ok" || echo "failed")
if [ "$SYNC_RES" = "ok" ]; then
  echo "✅"
else
  echo "❌"
  exit 1
fi

# Step 4: Verify claim appears in kind cluster
echo -n "Step 4: Claim in kind cluster... "
KUBE_GET=$(kubectl get eksclusters -n clusters-dev 2>/dev/null | grep alpha-test || true)
if [ -n "$KUBE_GET" ]; then
  echo "✅ alpha-dev-test-01 found"
else
  echo "❌ (Not found)"
  exit 1
fi

# Step 5: Verify Crossplane picked it up
echo -n "Step 5: Crossplane composite... "
X_GET=$(kubectl get xeksclusters 2>/dev/null | grep alpha-test || true)
if [ -n "$X_GET" ]; then
  echo "✅ xekscluster created"
else
  echo "❌ (Not found)"
  exit 1
fi

# Step 6: Cleanup
echo -n "Step 6: Cleanup... "
SHA_VAL=$(gh api repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml 2>/dev/null | jq -r '.sha // empty')
if [ -n "$SHA_VAL" ] && [ "$SHA_VAL" != "null" ]; then
  if gh api --method DELETE \
    repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml \
    --field message="test: remove alpha-dev-test-01 claim" \
    --field sha="$SHA_VAL" >/dev/null 2>&1; then
    echo "✅"
  else
    echo "❌"
    exit 1
  fi
else
  echo "❌ (Could not fetch file SHA)"
  exit 1
fi

sleep 30
argocd app sync team-alpha-eks-clusters --insecure >/dev/null 2>&1 || true

# Step 7: Pruned correctly
echo -n "Step 7: Pruned correctly... "
CLEANUP_CHECK=$(kubectl get eksclusters -n clusters-dev 2>/dev/null | grep alpha-test || true)
if [ -z "$CLEANUP_CHECK" ]; then
  echo "✅"
else
  echo "❌"
  exit 1
fi

echo "=== Flow test complete ==="
