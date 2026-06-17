#!/usr/bin/env bash
set -euo pipefail

echo "Patching ArgoCD ConfigMap for CAIPE account..."
kubectl patch configmap argocd-cm -n argocd --type merge -p '{"data":{"accounts.caipe":"apiKey, login"}}'

echo "Configuring ArgoCD RBAC for CAIPE account..."
POLICY_CSV=$(kubectl get configmap argocd-rbac-cm -n argocd -o jsonpath='{.data.policy\.csv}' 2>/dev/null || echo "")

NEW_POLICY="p, role:caipe, applications, get, */*, allow
p, role:caipe, applications, action/sync, */*, allow
g, caipe, role:caipe"

if [[ -z "$POLICY_CSV" ]]; then
  kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p "{\"data\":{\"policy.csv\":\"p, role:caipe, applications, get, */*, allow\\np, role:caipe, applications, action/sync, */*, allow\\ng, caipe, role:caipe\\n\"}}"
else
  if ! echo "$POLICY_CSV" | grep -q "caipe"; then
    kubectl patch configmap argocd-rbac-cm -n argocd --type merge -p "{\"data\":{\"policy.csv\":\"$POLICY_CSV\\np, role:caipe, applications, get, */*, allow\\np, role:caipe, applications, action/sync, */*, allow\\ng, caipe, role:caipe\\n\"}}"
  fi
fi

echo "ArgoCD RBAC setup complete for CAIPE."
