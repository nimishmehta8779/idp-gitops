# Pre-Agentic Backup Inventory

## Date
Created: 2026-06-20 22:30 UTC+5:30

## Contents

### Kubernetes State
- **kubernetes-state.yaml**: Complete Kubernetes resource dump (pods, services, statefulsets, etc.)
- **crossplane-compositions.yaml**: EKS Composition definition
- **crossplane-xrds.yaml**: XEKSCluster XRD definition
- **eks-claims.yaml**: EKSCluster claims (user-facing cluster definitions)

### ArgoCD State
- **argocd-apps.yaml**: All ArgoCD Applications (velero, external-dns, cluster-autoscaler, etc.)
- **argocd-projects.yaml**: ArgoCD Projects (RBAC and resource whitelists)
- **argocd-appsets.yaml**: ApplicationSets (eks-addon-*, team-infra-appset)

### Security & Admission Control
- **kyverno-policies.yaml**: Kyverno ClusterPolicies (validation/mutation rules)

### Cluster Access
- **kind-kubeconfig.yaml**: Kind management cluster kubeconfig

### AWS Infrastructure State
- **aws-iam-roles.json**: List of all IDP-managed IAM roles
- **idp-dev-role.json**: Dev Crossplane provisioning role (full details)
- **idp-staging-role.json**: Staging Crossplane provisioning role
- **idp-platform-admins-role.json**: Break-glass admin role
- **eks-clusters.json**: List of active EKS clusters in us-east-1

**Note**: alpha-dev-general-1.json skipped (cluster decommissioned per requirements)

## What This Backup Protects Against

✅ Accidental Kubernetes resource deletion
✅ ArgoCD configuration corruption
✅ IAM role policy changes
✅ Crossplane composition/XRD schema changes
✅ Kyverno policy unintended modifications
✅ Cluster connectivity loss

## Recovery Procedures

### Restore Kubernetes Resources
```bash
kubectl apply -f kubernetes-state.yaml
kubectl apply -f crossplane-compositions.yaml
kubectl apply -f crossplane-xrds.yaml
```

### Restore ArgoCD Configuration
```bash
kubectl apply -f argocd-projects.yaml
kubectl apply -f argocd-appsets.yaml
kubectl apply -f argocd-apps.yaml
```

### Restore Kyverno Policies
```bash
kubectl apply -f kyverno-policies.yaml
```

### Restore Kind Kubeconfig
```bash
cp kind-kubeconfig.yaml ~/.kube/config
```

### Restore AWS IAM Roles
Use the JSON exports to recreate roles via AWS Console or Terraform:
```bash
# Role definitions are in idp-dev-role.json, etc.
# Use AWS CLI to recreate or compare against current state
aws iam get-role --role-name idp-dev-role | diff - idp-dev-role.json
```

## Backup Size
```
$(du -sh $BACKUP_DIR 2>/dev/null | cut -f1)
```

## Git Location
Branch: backup/pre-agentic-2026-06-20
Tag: backup-pre-agentic-2026-06-20

## Next Steps
If disaster recovery is needed:
1. Check this backup date
2. Use kubectl apply -f for Kubernetes resources
3. Use git checkout for code/config rollback
4. Use AWS CLI to verify/restore IAM roles
