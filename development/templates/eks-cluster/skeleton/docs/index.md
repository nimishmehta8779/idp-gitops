# EKS Cluster ${{ values.clusterName }}

Welcome to the documentation for EKS cluster `${{ values.clusterName }}`.

## Cluster Metadata
- **Owner Team:** ${{ values.teamName }}
- **Environment:** ${{ values.environment }}
- **AWS Region:** ${{ values.awsRegion }}
- **Kubernetes Version:** ${{ values.kubernetesVersion }}
- **Node Count:** ${{ values.nodeCount }}
- **Instance Type:** ${{ values.instanceType }}

## Accessing the Cluster

To configure your `kubectl` context to point to this cluster:

```bash
# Authenticate with AWS CLI
aws eks update-kubeconfig --region ${{ values.awsRegion }} --name ${{ values.clusterName }}

# Verify cluster connectivity
kubectl get nodes
```
