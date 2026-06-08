#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# setup-argocd-github.sh
# Creates (or updates) the ArgoCD repository secret so ArgoCD can
# authenticate to the private idp-gitops GitHub repository.
# ---------------------------------------------------------------------------

REPO_URL="https://github.com/nimishmehta8779/idp-gitops.git"
SECRET_NAME="idp-gitops-repo"
NAMESPACE="argocd"
USERNAME="nimishmehta8779"

# 1. Check that GITHUB_TOKEN is set
if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "Error: GITHUB_TOKEN environment variable is not set."
  echo "Export a Personal Access Token with at minimum 'repo' scope:"
  echo "  export GITHUB_TOKEN=ghp_..."
  exit 1
fi

echo "Creating ArgoCD repository secret '${SECRET_NAME}' in namespace '${NAMESPACE}'..."

# 2. Create or update the secret via dry-run + apply
kubectl create secret generic "${SECRET_NAME}" \
  --namespace "${NAMESPACE}" \
  --from-literal=type=git \
  --from-literal=url="${REPO_URL}" \
  --from-literal=username="${USERNAME}" \
  --from-literal=password="${GITHUB_TOKEN}" \
  --dry-run=client -o yaml \
| kubectl label --local -f - \
    argocd.argoproj.io/secret-type=repository \
    --overwrite -o yaml \
| kubectl apply -f -

echo "Secret '${SECRET_NAME}' applied."

# 3. Verify ArgoCD picked up the repository
echo ""
echo "Verifying ArgoCD recognises the repository..."
sleep 3

# Check the secret exists with the correct label
LABEL=$(kubectl get secret "${SECRET_NAME}" -n "${NAMESPACE}" \
  -o jsonpath='{.metadata.labels.argocd\.argoproj\.io/secret-type}' 2>/dev/null || echo "")

if [[ "${LABEL}" == "repository" ]]; then
  echo "✅  Secret '${SECRET_NAME}' has the correct ArgoCD label (argocd.argoproj.io/secret-type: repository)."
  echo "✅  ArgoCD will use this secret to authenticate to ${REPO_URL}."
else
  echo "⚠️  Warning: Secret exists but label 'argocd.argoproj.io/secret-type: repository' is missing."
  echo "    ArgoCD may not recognise this secret as a repo credential."
  exit 1
fi

echo ""
echo "Done. Run 'argocd repo list' to confirm the repo appears in ArgoCD."
