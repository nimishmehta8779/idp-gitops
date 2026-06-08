# Cluster Claims

This directory contains Crossplane `EKSCluster` claim manifests, organised by
team name.

```
cluster-claims/
├── team-alpha/
│   └── alpha-dev.yaml        # EKSCluster claim for team-alpha dev cluster
├── team-beta/
│   └── beta-staging.yaml     # EKSCluster claim for team-beta staging cluster
└── platform-team/
    └── platform-prod.yaml    # EKSCluster claim for platform-team
```

## How claims arrive here

- **dev environment** — Backstage scaffolder pushes the rendered claim YAML
  directly to the `main` branch.
- **staging environment** — Backstage scaffolder opens a Pull Request.
  The platform team reviews and merges.

## What happens next

Once a claim YAML lands on `main`:

1. ArgoCD syncs the claim to the kind cluster.
2. Crossplane matches the claim against the `XEKSCluster` XRD.
3. The `eks-cluster` Composition expands the claim into managed AWS resources
   (VPC, subnets, IGW, route table, EKS cluster, IAM role, node group).
4. AWS resources are provisioned (~15–20 minutes).
5. A kubeconfig connection secret is written to the `clusters` namespace.
