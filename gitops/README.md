# GitOps Directory — ArgoCD Source of Truth

This directory is the **single source of truth** watched by ArgoCD.

Any Kubernetes manifest placed in this directory (or its subdirectories) will be
automatically applied to the local kind cluster by the `idp-root` ArgoCD
Application. Changes merged to the `main` branch are synced within seconds.

## Directory structure

```
gitops/
├── cluster-claims/         # Crossplane EKSCluster claim manifests
│   ├── team-alpha/          #   claims owned by team-alpha
│   ├── team-beta/           #   claims owned by team-beta
│   └── platform-team/       #   claims owned by platform-team
└── README.md                # this file
```

## How it works

1. A developer fills the **Request EKS Cluster** form in Backstage.
2. The Backstage scaffolder renders a Crossplane `EKSCluster` claim YAML and
   pushes it to this repository (directly to `main` for dev, via Pull Request
   for staging).
3. ArgoCD detects the change and applies the claim to the kind cluster.
4. Crossplane picks up the claim and provisions real AWS resources.

## Important notes

- **Do not manually edit files in this directory and push.** All changes should
  flow through Backstage or an approved Pull Request.
- **Deleting a claim file from Git will destroy the corresponding AWS
  resources** — ArgoCD has `prune: true` enabled, so removing the file causes
  ArgoCD to delete the claim, which causes Crossplane to tear down the
  infrastructure.
- **Manual cluster-side changes will be reverted** — ArgoCD has `selfHeal: true`
  enabled.
