# Recovery Runbook — Pre-Agentic Backup

## Quick Reference
- **Backup Date**: 2026-06-20
- **Git Tag**: `backup-pre-agentic-2026-06-20`
- **Git Branch**: `backup/pre-agentic-2026-06-20`
- **Files Location**: `.backups/pre-agentic-2026-06-20/`

---

## Scenario 1: Agentic development breaks something

### Quick Rollback (last 1-2 commits)
```bash
# See what agents committed
git log --oneline | head -5

# If the last commit broke things:
git revert HEAD
git push origin main

# OR go back to the commit before agentic work started:
git reset --hard backup-pre-agentic-2026-06-20
git push origin main --force-with-lease
```

### Full State Recovery (restore Kubernetes state)
```bash
# 1. Get the backup branch
git checkout backup/pre-agentic-2026-06-20

# 2. Read the Kubernetes state
kubectl apply -f .backups/pre-agentic-2026-06-20/crossplane-compositions.yaml
kubectl apply -f .backups/pre-agentic-2026-06-20/argocd-apps.yaml
kubectl apply -f .backups/pre-agentic-2026-06-20/kyverno-policies.yaml

# 3. Verify state restored
kubectl get compositions
kubectl get applications -A
kubectl get clusterpolicies
```

---

## Scenario 2: Kind cluster corrupted

### Rebuild from Backup
```bash
# 1. Delete corrupted cluster
kind delete cluster --name backstage-dev

# 2. Recreate from manifest
kind create cluster --config infrastructure/kind/kind-config.yaml

# 3. Load backup kubeconfig
export KUBECONFIG=.backups/pre-agentic-2026-06-20/kind-kubeconfig.yaml

# 4. Re-apply critical resources
kubectl apply -f infrastructure/crossplane/
kubectl apply -f infrastructure/argocd/
kubectl apply -f infrastructure/kyverno/
```

---

## Scenario 3: AWS resources got modified unexpectedly

### Verify AWS State
```bash
# Compare current state to backup
aws iam get-role --role-name idp-dev-role | jq . > /tmp/current-dev-role.json
diff .backups/pre-agentic-2026-06-20/idp-dev-role.json /tmp/current-dev-role.json

# If critical fields changed, document and escalate
# (AWS doesn't easily revert to snapshots — manual review needed)
```

---

## Scenario 4: Git history is messy, need to restart

### Hard Reset to Backup State
```bash
# DANGER: Only do this if you're certain and have informed your team

# 1. Switch to backup branch
git checkout backup/pre-agentic-2026-06-20

# 2. Create a new main from backup
git checkout -b main-restored

# 3. Force push (requires team coordination)
git push origin main-restored --force-with-lease
git branch -m main main-before-agentic
git branch -m main-restored main
git push origin main --force-with-lease

# ONLY do this if:
# - No one else is pushing to main
# - You have informed your team
# - You've verified this is necessary
```

---

## Scenario 5: Need to inspect what agents did

### Review Agentic Changes
```bash
# See all commits since agentic work started
git log backup-pre-agentic-2026-06-20..main

# See the exact diff of what changed
git diff backup-pre-agentic-2026-06-20 main

# See which files were touched
git diff --name-only backup-pre-agentic-2026-06-20 main

# Revert specific file if it went wrong
git show backup-pre-agentic-2026-06-20:infrastructure/crossplane/eks/composition.yaml > composition-backup.yaml
git checkout backup-pre-agentic-2026-06-20 -- infrastructure/crossplane/eks/composition.yaml
git commit -m "restore: revert composition to pre-agentic state"
```

---

## Test Recovery (Do This Before Going Live)

Run this checklist to verify recovery works:

```bash
#!/bin/bash
echo "Testing backup recovery..."

# 1. Can you switch to backup branch?
git checkout backup/pre-agentic-2026-06-20 && echo "✅ Backup branch accessible"

# 2. Can you restore from tag?
git checkout backup-pre-agentic-2026-06-20 && echo "✅ Backup tag accessible"

# 3. Are all backup files readable?
test -d .backups/pre-agentic-2026-06-20 && echo "✅ Backup directory present"
test -f .backups/pre-agentic-2026-06-20/kubernetes-state.yaml && echo "✅ Kubernetes state backup present"
test -f .backups/pre-agentic-2026-06-20/aws-iam-roles.json && echo "✅ AWS state backup present"

# 4. Switch back to main
git checkout main

echo "All recovery tests passed ✅"
```

---

## Contact & Escalation

If recovery is needed:

1. **Stop agentic work immediately** — don't queue new tasks
2. **Run the appropriate scenario above** — follow the recovery steps
3. **Document what went wrong** — create a GitHub issue
4. **Review logs** — check `.agentic/logs/` to understand root cause
5. **Update configuration** — fix skills or config to prevent recurrence
6. **Restart** — when ready, resume agentic work

---

## What's Protected in This Backup

✅ Complete Kubernetes cluster state  
✅ All Crossplane EKS configurations  
✅ ArgoCD sync state and policies  
✅ AWS IAM role definitions  
✅ Kyverno security policies  
✅ Cluster access credentials  

---

## File Manifest

```
.backups/pre-agentic-2026-06-20/
├── INVENTORY.md                    # Backup inventory & description
├── kubernetes-state.yaml           # All K8s resources (728K)
├── crossplane-compositions.yaml    # EKS Composition (101K)
├── crossplane-xrds.yaml           # XEKSCluster XRD (12K)
├── eks-claims.yaml                # EKSCluster claims (68B)
├── argocd-apps.yaml               # Applications (74K)
├── argocd-appsets.yaml            # ApplicationSets (21K)
├── argocd-projects.yaml           # AppProjects (7.6K)
├── kyverno-policies.yaml          # Policies (52K)
├── kind-kubeconfig.yaml           # Cluster config (5.5K)
├── aws-iam-roles.json             # IAM roles list (2.5K)
├── idp-dev-role.json              # Dev role (1.1K)
├── idp-staging-role.json          # Staging role (1.1K)
├── idp-platform-admins-role.json  # Admin role (1.1K)
└── eks-clusters.json              # EKS clusters (23B)
```

---

**Last Updated**: 2026-06-20  
**Total Backup Size**: ~1.0 MB  
**Fully Recoverable**: Yes ✅
