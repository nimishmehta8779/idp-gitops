# Granting kubectl Access to a New EKS Cluster

Run these three commands once after a cluster reaches ACTIVE status.
Replace `<cluster-name>`, `<region>`, and `<your-iam-arn>` with your values.

```bash
# 1. Switch auth mode to allow access entries (one-time per cluster)
aws eks update-cluster-config \
  --name <cluster-name> \
  --access-config authenticationMode=API_AND_CONFIG_MAP \
  --region <region>

# 2. Create access entry for your IAM user or role
aws eks create-access-entry \
  --cluster-name <cluster-name> \
  --principal-arn <your-iam-arn> \
  --region <region>

# 3. Grant cluster admin
aws eks associate-access-policy \
  --cluster-name <cluster-name> \
  --principal-arn <your-iam-arn> \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster \
  --region <region>

# 4. Update local kubeconfig
aws eks update-kubeconfig --name <cluster-name> --region <region>

# 5. Verify
kubectl get nodes
```

## Finding your IAM ARN

```bash
aws sts get-caller-identity --query Arn --output text
```
