# EKS Cluster: ${{ values.clusterName }}

This repository contains the Crossplane EKSCluster claim manifest for provisioning the **${{ values.clusterName }}** cluster.

## Request Details
- **Requested By Team**: ${{ values.teamName }}
- **Environment**: ${{ values.environment }}
- **AWS Region**: ${{ values.awsRegion }}
- **Worker Node Count**: ${{ values.nodeCount }}
- **Worker Instance Type**: ${{ values.instanceType }}

## Request Strategy
{% if values.environment == 'dev' %}
- **Strategy**: Pushed directly to `main` branch.
- **ArgoCD Sync**: Immediate sync on `main` branch.
{% else %}
- **Strategy**: Raised a Pull Request against `main` branch.
- **Pull Request URL**: [PR #1](https://github.com/nimishmehta8779/eks-cluster-${{ values.clusterName }}/pull/1)
- **Status**: Pending approval and merge to `main`.
{% endif %}

## Tracking Provisioning Status
1. **ArgoCD**: The GitOps repository is watched by ArgoCD. ArgoCD will sync the EKSCluster claim defined in `gitops/cluster-claims/${{ values.teamName }}/${{ values.clusterName }}.yaml` to the target Kubernetes cluster once it is merged/synced to `main`.
2. **Crossplane**: Once synced, Crossplane will reconcile the claim and communicate with AWS to provision the EKS cluster. You can check the status of the claim using:
   ```bash
   kubectl get EKSCluster ${{ values.clusterName }}
   ```

## Daily Auto-Pause Policy

To keep this cluster running beyond 8 PM daily auto-pause, add:
```yaml
metadata:
  annotations:
    idp.platform.io/long-running: "true"
```
to your claim file in the GitOps repo.

