# Cluster: alpha-dev-general-01

**Status:** Provisioning

This EKS Cluster was requested by the **team-alpha** team via the IDP Developer Portal.

## Specifications
- **Environment**: dev
- **Region**: us-east-1
- **Kubernetes Version**: 1.34
- **Node Count**: 2
- **Instance Type**: t3.medium

## Tracking Provisioning
Because this cluster was requested for the **dev** environment, it was {{ values.environment === 'dev' ? 'pushed directly to the main branch' : 'opened as a Pull Request' }}.

To track the creation of your AWS resources:
1. View the [ArgoCD UI](http://localhost:8080/applications/cluster-claims) to see the sync status.
2. Check the crossplane resources locally:
   ```bash
   kubectl get eksclusters -n clusters
   ```

## Retrieving Credentials
Once the cluster reaches the `Ready` state, Crossplane will populate the connection secret. 
Retrieve your kubeconfig with:
```bash
kubectl get secret alpha-dev-general-01-kubeconfig -n clusters -o jsonpath="{.data.kubeconfig}" | base64 -d > kubeconfig.yaml
```
