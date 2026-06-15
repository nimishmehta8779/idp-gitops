#!/bin/bash
# Test enterprise GitOps flow end to end

# Load GITHUB_TOKEN from env or local .env
if [ -z "$GITHUB_TOKEN" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ENV_FILE="${SCRIPT_DIR}/../backstage/.env"
  if [ -f "$ENV_FILE" ]; then
    echo "Loading GITHUB_TOKEN from ${ENV_FILE}..."
    export $(grep -v '^#' "$ENV_FILE" | xargs)
  fi
fi

if [ -n "$GITHUB_TOKEN" ]; then
  export GH_TOKEN="$GITHUB_TOKEN"
fi

echo "=== Enterprise IDP Flow Test ==="

# Step 1: Simulate Backstage form submission by directly pushing claim to team repo
echo "Step 1: Pushing test claim to team-alpha-infra..."
gh api \
  --method PUT \
  repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml \
  --field message="test: add alpha-dev-test-01 claim" \
  --field content="$(cat infrastructure/crossplane/eks/claim-example.yaml | base64)"

# Step 2: Wait for ArgoCD to detect change
echo "Step 2: Waiting for ArgoCD sync (30 seconds)..."
sleep 30

# Step 3: Force ArgoCD sync
echo "Step 3: Forcing ArgoCD sync..."
argocd app sync team-alpha-eks-clusters

# Step 4: Verify claim appears in kind cluster
echo "Step 4: Checking claim in kind cluster..."
kubectl get eksclusters -n clusters-dev | grep alpha-dev-test-01

# Step 5: Verify Crossplane picked it up
echo "Step 5: Checking Crossplane composite resource..."
kubectl get xeksclusters | grep alpha-dev-test-01

# Step 6: Cleanup
echo "Step 6: Cleaning up test claim..."
gh api \
  --method DELETE \
  repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml \
  --field message="test: remove alpha-dev-test-01 claim" \
  --field sha="$(gh api repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml | jq -r '.sha')"

sleep 30
argocd app sync team-alpha-eks-clusters

echo "Step 7: Verifying cleanup..."
kubectl get eksclusters -n clusters-dev | grep alpha-dev-test-01 \
  && echo "❌ Claim still exists" \
  || echo "✅ Claim successfully pruned"

echo "=== Flow test complete ==="
