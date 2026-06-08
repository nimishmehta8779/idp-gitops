# ArgoCD Configuration for IDP

This directory contains the ArgoCD manifests that wire GitOps-driven cluster
provisioning into the IDP.

## Quick start

```bash
# 1. Ensure ArgoCD is installed in the kind cluster
make -C ../ install-argocd

# 2. Export your GitHub token (needs 'repo' scope for private repos)
export GITHUB_TOKEN=ghp_...

# 3. Bootstrap ArgoCD — creates repo secret, project, and root app
make -C ../ argocd-bootstrap

# 4. Check status
make -C ../ argocd-app-list

# 5. Port-forward the UI
make -C ../ argocd-ui
# Then open http://localhost:8080
#   username: admin
#   password: (printed by 'make argocd-login')
```

## App-of-apps hierarchy

```
idp-root (Application)
│
│  watches: github.com/nimishmehta8779/idp-gitops → gitops/apps/
│
├── gitops/apps/cluster-claims-app.yaml
│     │
│     └── cluster-claims (Application)
│           │
│           │  watches: gitops/cluster-claims/ (recursive)
│           │
│           ├── gitops/cluster-claims/team-alpha/alpha-dev.yaml     → EKSCluster claim
│           ├── gitops/cluster-claims/team-beta/beta-staging.yaml   → EKSCluster claim
│           └── ...
│                 │
│                 ▼
│           Applied to kind cluster (namespace: clusters)
│                 │
│                 ▼
│           Crossplane picks up claim → provisions AWS resources
│
└── gitops/apps/crossplane-compositions-app.yaml
      │
      └── crossplane-compositions (Application)
            │
            │  watches: infrastructure/crossplane/eks/
            │
            ├── xrd.yaml          → CompositeResourceDefinition
            ├── composition.yaml  → Composition
            └── namespace.yaml    → clusters Namespace
                  │
                  ▼
            Applied to kind cluster (namespace: crossplane-system)
```

### Why two levels?

The root app watches `gitops/apps/`, which contains **ArgoCD Application
manifests** (not raw Crossplane claims). Each child Application then watches
its own specific directory. This two-level indirection is intentional:

- Adding a new resource type only requires adding a new Application YAML to
  `gitops/apps/` — the root app auto-discovers it.
- Each child app has its own sync policy (e.g. `prune: false` on compositions
  to prevent accidental deletion of infra definitions).
- `ignoreDifferences` can be scoped per-app (e.g. ignoring Crossplane status
  fields only on the cluster-claims app).

## Directory structure

```
infrastructure/argocd/
├── apps/
│   ├── root-app.yaml                      # Root app — watches gitops/apps/
│   ├── cluster-claims-app.yaml            # Source-of-truth definition
│   └── crossplane-compositions-app.yaml   # Source-of-truth definition
├── projects/
│   └── idp-platform.yaml                  # AppProject
├── secrets/
│   └── repo-secret.yaml                   # Repo credential template
└── README.md                              # This file
```

The actual files that ArgoCD discovers live in the GitOps repo:

```
gitops/apps/
├── cluster-claims-app.yaml                # Discovered by root app
└── crossplane-compositions-app.yaml       # Discovered by root app
```

## Sync policies

| Application | prune | selfHeal | Why |
|---|---|---|---|
| `idp-root` | `true` | `true` | Removing an app YAML from `gitops/apps/` should remove the child Application |
| `cluster-claims` | `true` | `true` | Removing a claim from Git should delete the AWS cluster (via Crossplane) |
| `crossplane-compositions` | **`false`** | `true` | Never auto-delete compositions — doing so while claims exist would break all clusters |

## ignoreDifferences

The `cluster-claims` app ignores the following fields to prevent false
`OutOfSync` warnings while Crossplane is reconciling:

```yaml
ignoreDifferences:
  - group: platform.io
    kind: XEKSCluster
    jsonPointers:
      - /status
      - /metadata/annotations/crossplane.io~1external-name
  - group: platform.io
    kind: EKSCluster
    jsonPointers:
      - /status
      - /metadata/annotations/crossplane.io~1external-name
```

Without this, ArgoCD would constantly show `OutOfSync` because Crossplane
writes status fields and annotations that do not exist in the Git source.

## Testing the GitOps flow

Run the end-to-end test without AWS credentials:

```bash
make -C ../ test-gitops
```

This script:
1. Copies `claim-example.yaml` into `gitops/cluster-claims/team-alpha/`
2. Commits and pushes to GitHub `main` branch
3. Waits for ArgoCD to sync (or forces sync)
4. Verifies the `EKSCluster` claim appears in the `clusters` namespace
5. Cleans up by deleting the file from Git and confirming ArgoCD prunes it

The claim will stay in `Pending` state without AWS credentials — that is
expected. Its existence in the cluster confirms the ArgoCD → Crossplane
handoff is working.

## Manual operations

```bash
# Force sync of ALL ArgoCD applications
make -C ../ argocd-sync-all

# Force sync of only the cluster-claims app
make -C ../ argocd-sync-claims

# List all apps with health and sync status
make -C ../ argocd-app-list

# Check detailed app info (requires argocd CLI login)
make -C ../ argocd-login
argocd app get idp-root
argocd app get cluster-claims
argocd app get crossplane-compositions

# View ArgoCD server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50
```

## Prerequisites

- ArgoCD must be installed (`make -C ../ install-argocd`)
- `GITHUB_TOKEN` must be set with at least `repo` scope
- The `idp-gitops` GitHub repository must exist with `gitops/apps/` and
  `gitops/cluster-claims/` directories (including `.gitkeep` files — ArgoCD
  errors on missing paths)
- Crossplane must be installed (`make -C ../ install-crossplane`) before the
  compositions app will sync successfully
