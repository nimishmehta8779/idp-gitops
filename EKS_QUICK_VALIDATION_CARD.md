# EKS Cluster Provisioning - Quick Validation Card
## Print This & Keep With You 🖨️

---

## ⏱️ Timeline & Expected Outcomes

```
T+0min    ┌─ START: Fill template in Backstage
T+2min    │  ✅ GitHub repo created: <team>-<cluster-name>-infra
T+5min    │  ✅ Template completes - you get success page
T+10min   │  ✅ ArgoCD syncs claim
          │  ✅ Cluster status: CREATING
          │
T+15min   │  ✅ EKS cluster ACTIVE
          │  ✅ Node group CREATING
          │  ✅ Add-ons deploying
          │
T+25min   │  ✅ Node group ACTIVE
          │  ✅ Nodes show "Ready"
          │  ✅ Add-ons mostly ACTIVE
          │
T+30min   ├─ ✅ ALL READY FOR USE
          │  ✅ Kubeconfig working
          │  ✅ kubectl get nodes (shows nodes)
          │  ✅ All add-ons ACTIVE
T+35min   └─ 🚀 PRODUCTION READY
```

---

## 🎯 4-Phase Validation Checklist

### PHASE 1: Immediate (0-5 min)
```
☐ Backstage shows success page
☐ GitHub repo created and accessible
☐ Cluster claim file in team infra repo
☐ 4 workflows in GitHub Actions
```

**Key Checks:**
```bash
gh repo view <team>/<cluster-name>-infra
gh workflow list -R <team>/<cluster-name>-infra
```

---

### PHASE 2: Provisioning Started (5-15 min)
```
☐ ArgoCD shows "Synced" status
☐ kubectl get xeksclusters shows resource
☐ AWS cluster appears in console
☐ Cluster status: CREATING
☐ IAM roles created (cluster-role, node-role)
```

**Key Checks:**
```bash
kubectl describe xeksclusters <cluster-name> -n clusters-dev
aws eks describe-cluster --name <cluster-name> --region us-east-1
```

---

### PHASE 3: Cluster Created (15-25 min)
```
☐ Cluster status: ACTIVE
☐ Node group: CREATING (or ACTIVE)
☐ Cluster endpoint accessible
☐ Add-ons: CREATING or ACTIVE
☐ Desired nodes = Requested count
```

**Key Checks:**
```bash
aws eks describe-cluster --name <cluster-name> --region us-east-1 --query 'cluster.status'
kubectl get nodes
aws eks list-addons --cluster-name <cluster-name> --region us-east-1
```

---

### PHASE 4: Ready For Use (25-35 min)
```
☐ All nodes show "Ready" status
☐ All add-ons show "ACTIVE"
☐ Kubeconfig retrieved successfully
☐ kubectl cluster-info works
☐ kubectl get pods shows kube-system pods
☐ All 7 tests in test-access.sh pass
```

**Key Checks:**
```bash
export KUBECONFIG=~/.kube/config
kubectl get nodes
kubectl cluster-info
./scripts/test-access.sh <cluster-name>
```

---

## 🔍 Critical Validation Commands

### ✅ Did Everything Work?
```bash
# Test 1: Check cluster exists in AWS
aws eks describe-cluster \
  --name <cluster-name> \
  --region us-east-1 \
  --query 'cluster.status'
# Expected: "ACTIVE"

# Test 2: Verify nodes are ready
kubectl get nodes
# Expected: 
#   NAME                        STATUS   ROLES    AGE
#   ip-10-0-1-100.ec2.internal  Ready    <none>   5m

# Test 3: Check add-ons running
kubectl get pods -n kube-system | grep -E "aws-node|coredns|kube-proxy"
# Expected: All pods in "Running" state

# Test 4: Verify kubeconfig works
kubectl cluster-info
# Expected: Control plane URL, CoreDNS URL

# Test 5: Run helper script (final check)
./scripts/test-access.sh <cluster-name>
# Expected: ✅ All tests passed!
```

---

## ❌ If Something Goes Wrong

```
STUCK at PROVISIONING?
  → Check: kubectl describe xeksclusters <name> -n clusters-dev
  → Look for: Error events or conditions

NODES NOT READY?
  → Check: kubectl describe nodes
  → Check: aws eks describe-nodegroup
  → Solution: Verify IAM permissions

ADD-ONS STUCK PENDING?
  → Check: kubectl logs -n kube-system
  → Check: aws eks describe-addon
  → Solution: Manually update add-on

KUBECONFIG NOT WORKING?
  → Check: aws sts get-caller-identity
  → Solution: Re-run: aws eks update-kubeconfig

GITHUB WORKFLOW FAILED?
  → Check: https://github.com/<team>/<cluster-name>-infra/actions
  → Look for: AWS credential error or cluster not found
  → Solution: Verify AWS_ACCOUNT_ID secret
```

---

## 📊 Pre-Provisioning Checklist

Before clicking "Create" in Backstage:

```
☐ Team Name: Selected (not blank)
☐ Cluster Name: Format correct (team-env-purpose-##)
  Examples:
    ✅ alpha-dev-general-01
    ✅ beta-staging-app-02
    ✅ gamma-dev-test-01
  ❌ myCluster (wrong: not lowercase)
  ❌ alpha-dev (wrong: missing parts)

☐ Environment: Selected
  dev = Auto-delete when decommissioned ✅
  staging = Manual AWS cleanup needed ⚠️

☐ AWS Region: Valid (usually us-east-1)
☐ Node Count: 1-10 (dev: 2-3, staging: 3-5)
☐ Instance Type: t3.medium (dev) or larger
☐ Kubernetes Version: 1.34 (latest)
☐ Add-ons: Selected as needed
```

---

## 🚀 One-Command Quick Validation

```bash
# Run this after Template completes (T+5)
CLUSTER_NAME="alpha-dev-general-01"
REGION="us-east-1"
TEAM="team-alpha"

echo "=== Checking GitHub Repo ==="
gh repo view $TEAM/$CLUSTER_NAME-infra

echo "=== Checking AWS Cluster ==="
aws eks describe-cluster \
  --name $CLUSTER_NAME \
  --region $REGION \
  --query 'cluster.{status:status,endpoint:endpoint,createdAt:createdAt}'

echo "=== Checking Crossplane ==="
kubectl get xeksclusters $CLUSTER_NAME -n clusters-dev

echo "=== Checking ArgoCD ==="
argocd app get $TEAM-eks-clusters --refresh

echo "✅ Validation complete! Check above for status."
```

---

## 📱 Typical Outputs (What to Expect)

### GitHub Repo
```
name:        alpha-dev-general-01-infra
description: Infrastructure repository for EKS cluster alpha-dev-general-01
private:     Yes
owner:       team-alpha
homepage:    http://localhost:3000/catalog/default/resource/alpha-dev-general-01
```

### AWS Cluster (ACTIVE state)
```json
{
  "status": "ACTIVE",
  "endpoint": "https://example.eks.amazonaws.com",
  "createdAt": "2026-06-18T12:30:00+00:00"
}
```

### Kubernetes Nodes
```
NAME                           STATUS   ROLES    AGE   VERSION
ip-10-0-1-100.ec2.internal    Ready    <none>   5m    v1.34.0
ip-10-0-1-101.ec2.internal    Ready    <none>   5m    v1.34.0
```

### Add-ons
```
vpc-cni        v1.14.0 (ACTIVE)
kube-proxy     v1.34.0 (ACTIVE)
coredns        1.10.0  (ACTIVE)
ebs-csi        v1.20.0 (ACTIVE) [if enabled]
```

---

## 🎯 Success Criteria (Final Check)

All of these should be TRUE:

```
✅ Cluster status in AWS: ACTIVE
✅ Cluster endpoint: Accessible (https://...)
✅ Nodes: All showing "Ready" status
✅ Node count: Matches requested (default 2)
✅ Add-ons: All showing "ACTIVE"
✅ Kubeconfig: kubectl cluster-info works
✅ Pods: kubectl get pods --all-namespaces returns data
✅ Services: kubectl get svc --all-namespaces returns data
✅ GitHub workflows: All 4 present and enabled
✅ Documentation: CLUSTER_INFO.md and ADDON_STATUS.md populated
```

**If ANY are FALSE → Check Troubleshooting section in Operational Guide**

---

## 🔗 Essential Links

| What | Link |
|------|------|
| Start Here | https://github.com/<team>/<cluster-name>-infra |
| Cluster Info | https://github.com/<team>/<cluster-name>-infra/blob/main/docs/CLUSTER_INFO.md |
| Add-on Status | https://github.com/<team>/<cluster-name>-infra/blob/main/docs/ADDON_STATUS.md |
| GitHub Actions | https://github.com/<team>/<cluster-name>-infra/actions |
| AWS Console | https://console.aws.amazon.com/eks/home?region=us-east-1#/clusters |
| Backstage | http://localhost:3000/catalog/default/resource/<cluster-name> |
| ArgoCD | http://localhost:8080/applications/<team>-eks-clusters |

---

## 💬 Quick Questions & Answers

**Q: How long until cluster is ready?**
A: 30-35 minutes from provisioning start

**Q: What if it takes longer?**
A: Check Crossplane events: `kubectl describe xeksclusters <name> -n clusters-dev`

**Q: Can I use the cluster while nodes are provisioning?**
A: No, wait until all nodes show "Ready" status

**Q: How do I share access with team members?**
A: Download kubeconfig and share, or send them the cluster repository link

**Q: What's the difference between dev and staging?**
A: Dev = Auto-deletes, Staging = Manual AWS cleanup

**Q: Can I scale nodes after creation?**
A: Yes: `aws eks update-nodegroup-config --nodegroup-name <name> --scaling-config desiredSize=5`

**Q: Where are all my cluster details?**
A: In the cluster repo: `docs/CLUSTER_INFO.md`

---

## 📞 Need Help?

1. **Check Logs First**
   ```bash
   kubectl describe xeksclusters <cluster-name> -n clusters-dev
   kubectl logs -n kube-system
   ```

2. **Run Diagnostic Script**
   ```bash
   ./scripts/test-access.sh <cluster-name>
   ```

3. **Read Documentation**
   - Detailed guide: `EKS_PROVISIONING_OPERATIONAL_GUIDE.md`
   - Troubleshooting section has 6 common issues with solutions

4. **Contact Platform Team**
   - Slack: #platform-team
   - Provide: cluster name, error message, steps taken

---

**Print This Card & Keep It Handy!** 🖨️

Last Updated: June 18, 2026
Status: Production Ready
