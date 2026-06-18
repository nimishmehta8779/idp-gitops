# EKS Cluster Provisioning - Operational Guide
## Complete Step-by-Step Instructions & Validation Checklist

**Last Updated**: June 18, 2026
**Version**: 1.0
**Status**: Production Ready

---

## Table of Contents
1. [Pre-Requisites](#pre-requisites)
2. [Step-by-Step Provisioning](#step-by-step-provisioning)
3. [Validation Checklist](#validation-checklist)
4. [Using the Cluster Repository](#using-the-cluster-repository)
5. [Troubleshooting](#troubleshooting)
6. [Post-Provisioning Setup](#post-provisioning-setup)
7. [Quick Reference](#quick-reference)

---

## Pre-Requisites

### ✅ What You Need Before Starting

#### 1. Access Requirements
- [ ] Access to Backstage (http://localhost:3000)
- [ ] GitHub account in the organization
- [ ] AWS console access (for verification)
- [ ] kubectl installed locally
- [ ] AWS CLI configured
- [ ] jq installed (for parsing JSON)

#### 2. Cluster Details (Prepare These)
- [ ] **Cluster Name**: Format: `<team>-<env>-<purpose>-<index>`
  - Example: `alpha-dev-general-01`
  - Pattern: Must follow `^[a-z0-9]+-[a-z0-9]+-[a-z0-9]+-[0-9]+$`
  
- [ ] **Team Name**: One of the predefined teams
  - Options: `platform-team`, `team-alpha`, `team-beta`, `team-gamma`
  
- [ ] **Environment**: Where cluster will be deployed
  - Options: `dev` (auto-delete), `staging` (requires manual cleanup)
  
- [ ] **AWS Region**: Region for cluster
  - Default: `us-east-1`
  - Must have available capacity for instance type
  
- [ ] **Node Count**: Number of worker nodes (1-10)
  - Dev: Usually 2-3
  - Staging: Usually 3-5
  
- [ ] **Instance Type**: EC2 instance for nodes
  - Options: `t3.medium`, `t3.large`, `m5.large`
  - Dev typically uses `t3.medium`
  
- [ ] **Kubernetes Version**: EKS K8s version
  - Default: `1.34`
  - Options: `1.34`, `1.33`
  
- [ ] **Add-ons** (Optional, but recommended):
  - [ ] Cluster Autoscaler: Auto-scale nodes based on demand
  - [ ] External DNS: Automatic Route53 DNS records
  - [ ] Velero: Backup and disaster recovery

#### 3. Team Verification
- [ ] You belong to the selected team
- [ ] Team has space in GitHub organization
- [ ] Team has AWS account quota for resources
- [ ] Cost center code available for billing

---

## Step-by-Step Provisioning

### STEP 1: Access Backstage and Open Template

**What to Do:**
1. Open browser: http://localhost:3000
2. Navigate to "Create Component"
3. Search for "Request EKS Cluster"
4. Click on template

**What to Validate:**
```
✅ Backstage loads without errors
✅ Template "Request EKS Cluster" appears in search
✅ Template page loads with all fields
✅ You can see the parameters form
```

**Screenshot Expected:**
```
┌─────────────────────────────────────────────────────┐
│ Request EKS Cluster                                  │
├─────────────────────────────────────────────────────┤
│ Cluster Specifications                               │
│                                                      │
│ Team Name: [dropdown ▼]                             │
│ Cluster Name: [text input]                          │
│ Environment: [dropdown ▼]                           │
│ AWS Region: [us-east-1]                             │
│ Node Count: [2]                                      │
│ Instance Type: [dropdown ▼]                         │
│ Kubernetes Version: [dropdown ▼]                    │
│ Enable Cluster Autoscaler: [checkbox]               │
│ Enable External DNS: [checkbox]                     │
│ Enable Velero: [checkbox]                           │
│                                                      │
│ [Next] or [Create]                                  │
└─────────────────────────────────────────────────────┘
```

---

### STEP 2: Fill in Cluster Specifications

**What to Do:**
1. **Select Team Name**
   - Click dropdown
   - Choose your team
   - Example: `team-alpha`

2. **Enter Cluster Name**
   - Must follow pattern: `<team>-<env>-<purpose>-<index>`
   - Example: `alpha-dev-general-01`
   - No spaces, lowercase only

3. **Select Environment**
   - `dev`: Cluster auto-deletes when claim is deleted
   - `staging`: Requires manual AWS cleanup (Orphan policy)
   - First time? Use `dev`

4. **Set AWS Region**
   - Default: `us-east-1`
   - Change only if needed for compliance
   - Check region has capacity for instance type

5. **Set Node Count**
   - Dev: `2` (sufficient for testing)
   - Staging: `3-5` (production workloads)
   - Minimum: 1, Maximum: 10

6. **Select Instance Type**
   - `t3.medium`: Cost-effective for dev (recommended)
   - `t3.large`: Better performance
   - `m5.large`: More memory, higher cost

7. **Select Kubernetes Version**
   - Default: `1.34` (latest, recommended)
   - `1.33`: Previous version if needed
   - Check app compatibility

8. **Enable Add-ons** (Optional but recommended)
   - [ ] Cluster Autoscaler: Auto-scale nodes
   - [ ] External DNS: Automatic DNS management
   - [ ] Velero: Backup capability
   - Recommendation: Enable all for production-ready cluster

**What to Validate:**
```
BEFORE clicking next/create, verify:

✅ Team Name: Selected (not blank)
✅ Cluster Name: Follows pattern (e.g., alpha-dev-general-01)
✅ Environment: Selected (dev or staging)
✅ AWS Region: Valid and has capacity
✅ Node Count: Between 1-10
✅ Instance Type: Selected
✅ Kubernetes Version: Selected
✅ Add-ons: Chosen as needed

Example Valid Inputs:
├─ Team Name: team-alpha
├─ Cluster Name: alpha-dev-general-01
├─ Environment: dev
├─ AWS Region: us-east-1
├─ Node Count: 2
├─ Instance Type: t3.medium
├─ Kubernetes Version: 1.34
└─ Add-ons: Cluster Autoscaler ✓
```

---

### STEP 3: Review and Submit

**What to Do:**
1. Review all entered values
2. For Staging: Read and acknowledge warning about manual cleanup
3. Click "Create" or "Submit" button

**What to Validate:**
```
✅ All fields filled correctly
✅ Cluster name format is correct
✅ Environment selection understood (especially if staging)
✅ Ready to click Create
```

**Expected Output:**
```
Processing... Please wait while your cluster is being provisioned.

✅ Cluster claim rendering
✅ Cluster-specific GitHub repository creation
✅ GitHub workflows initialization
✅ Template completion
```

---

### STEP 4: Provisioning Begins - Wait for Template Completion

**What to Expect (Timeline):**
```
T+0min:    Template starts processing
T+1min:    ✅ Cluster claim rendered
T+2min:    ✅ GitHub repo created: <team>-<cluster-name>-infra
T+3min:    ✅ Workflows pushed to GitHub repo
T+5min:    ✅ Template processing complete (you get confirmation)
           ✅ Backstage shows success page with links
T+5-10min: ArgoCD detects claim and syncs
T+10min:   Crossplane begins creating AWS resources
```

**What to Validate:**
```
After template completes, you should see:

✅ Success message in Backstage
✅ Links to:
   • Decommission audit record (GitHub)
   • ArgoCD sync status
   • AWS cluster console
   • GitHub repository
   • Backstage catalog entry
   • Cluster info tracking page

Example Success Page:
┌──────────────────────────────────────────────────┐
│ ✅ EKS Cluster Provisioning Complete              │
├──────────────────────────────────────────────────┤
│ Cluster: alpha-dev-general-01                    │
│ Status: Creating (see ArgoCD for live updates)   │
│                                                   │
│ Quick Links:                                      │
│ [📊 View in Catalog]                             │
│ [⚙️  ArgoCD sync status]                         │
│ [☁️  AWS console]                                │
│ [🔧 GitHub Repository]                           │
│                                                   │
│ Next Steps:                                       │
│ 1. Monitor provisioning (5-30 minutes)            │
│ 2. Check GitHub repo for cluster info            │
│ 3. Get kubeconfig when ready                     │
│ 4. Deploy your apps                               │
└──────────────────────────────────────────────────┘
```

---

## Validation Checklist

### 🔍 Phase 1: Immediate Validation (0-5 minutes)

#### GitHub Repository Created
```bash
# Check if cluster repo was created
gh repo view <team>/<cluster-name>-infra

# Expected output:
# Name:        <cluster-name>-infra
# Description: Infrastructure repository for EKS cluster <cluster-name>
# Private:     Yes
```

**Validate:**
- [ ] Repository exists
- [ ] Repository is private
- [ ] You have access
- [ ] Contains `.github/workflows/`

#### Cluster Claim File Created
```bash
# Check if claim file exists in team infra repo
gh repo view <team>/<team>-infra

# Then check:
# cat eks/<cluster-name>.yaml

# Should show:
# apiVersion: platform.io/v1alpha1
# kind: EKSCluster
# metadata:
#   name: <cluster-name>
#   namespace: clusters-dev (or clusters-staging)
```

**Validate:**
- [ ] Claim file exists
- [ ] Correct namespace (clusters-dev or clusters-staging)
- [ ] All parameters populated correctly

#### GitHub Actions Workflows Available
```bash
# Check workflows in cluster repo
gh workflow list -R <team>/<cluster-name>-infra

# Expected output:
# ID  Name                    Status
# 1   Get Kubeconfig          ✓
# 2   Cluster Information     ✓
# 3   Addon Status Check      ✓
# 4   Provisioning Status     ✓
```

**Validate:**
- [ ] 4 workflows present
- [ ] All workflows enabled (status = ✓)
- [ ] Can view workflow files

---

### 🔍 Phase 2: Provisioning In Progress (5-15 minutes)

#### Check ArgoCD Sync
```bash
# View ArgoCD application
# Navigate to: http://localhost:8080/applications/<team>-eks-clusters

# Or use CLI:
argocd app get <team>-eks-clusters

# Expected:
# Status:     OutOfSync (syncing) or Synced
# Sync Status: Progressing
```

**Validate:**
- [ ] ArgoCD application exists
- [ ] Status shows "Syncing" or "Synced"
- [ ] No errors in sync logs
- [ ] Destination cluster correct

#### Check Crossplane Resources
```bash
# View Crossplane composite resource
kubectl get xeksclusters -n clusters-dev

# Expected:
# NAME                        READY   SYNCED   STATE
# alpha-dev-general-01        False   True     Creating

# Get details:
kubectl describe xeksclusters <cluster-name> -n clusters-dev

# Look for:
# Status: Creating
# Conditions: Should show progress
# Events: Should show steps being executed
```

**Validate:**
- [ ] XEKSCluster resource created
- [ ] Status shows "Creating" or "Provisioning"
- [ ] SYNCED = True
- [ ] No error messages in conditions
- [ ] Events show progression

#### Check AWS Resources Starting
```bash
# Check if cluster is being created in AWS
aws eks list-clusters --region us-east-1

# Should show your cluster name

# Get cluster status:
aws eks describe-cluster \
  --name <cluster-name> \
  --region us-east-1 \
  --query 'cluster.status'

# Expected output:
# "CREATING"
```

**Validate:**
- [ ] Cluster appears in AWS
- [ ] Status is "CREATING"
- [ ] Cluster ARN shows in output
- [ ] Region is correct

#### Check IAM Resources
```bash
# Check if IAM roles are created
aws iam list-roles | grep <cluster-name>

# Should show:
# - idp-dev-<cluster-name>-cluster-role
# - idp-dev-<cluster-name>-node-role

# Verify role policies:
aws iam list-attached-role-policies \
  --role-name idp-dev-<cluster-name>-cluster-role

# Should include:
# - AmazonEKSClusterPolicy
```

**Validate:**
- [ ] Cluster role created
- [ ] Node role created
- [ ] Cluster role has required policies
- [ ] Node role has required policies

---

### 🔍 Phase 3: Cluster Created - Waiting for Add-ons (15-25 minutes)

#### Check EKS Cluster Status
```bash
# Get cluster details
aws eks describe-cluster \
  --name <cluster-name> \
  --region us-east-1

# Check: status field
# Expected: "ACTIVE"

# Get cluster endpoint
aws eks describe-cluster \
  --name <cluster-name> \
  --region us-east-1 \
  --query 'cluster.endpoint'

# Save this endpoint - you'll need it
```

**Validate:**
- [ ] Cluster status is "ACTIVE"
- [ ] Cluster endpoint returns URL (https://xxx.eks.amazonaws.com)
- [ ] OIDC provider shows (if EBS CSI enabled)
- [ ] Creation timestamp is recent

#### Check Node Group
```bash
# List node groups
aws eks list-nodegroups \
  --cluster-name <cluster-name> \
  --region us-east-1

# Should show:
# <cluster-name>-node-group

# Get node group status:
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <cluster-name>-node-group \
  --region us-east-1

# Check: status field
# Expected: "CREATING" then "ACTIVE"
```

**Validate:**
- [ ] Node group created
- [ ] Status is "CREATING" or "ACTIVE"
- [ ] Desired nodes = requested count
- [ ] Min/Max size configured correctly

#### Check Add-on Status
```bash
# List add-ons being deployed
aws eks list-addons \
  --cluster-name <cluster-name> \
  --region us-east-1

# Should show:
# - vpc-cni
# - kube-proxy
# - coredns
# (+ optional: ebs-csi, cluster-autoscaler, external-dns, velero)

# Get individual add-on status:
aws eks describe-addon \
  --cluster-name <cluster-name> \
  --addon-name vpc-cni \
  --region us-east-1

# Check: addonHealth.issues
# Expected: Empty array (no issues)
```

**Validate:**
- [ ] All required add-ons listed
- [ ] Add-ons show "CREATING" or "ACTIVE" status
- [ ] No health issues reported
- [ ] Versions are appropriate

#### Monitor via GitHub Actions
```bash
# Check provisioning status workflow
gh run list -R <team>/<cluster-name>-infra \
  --workflow provisioning-status.yml

# Or navigate to:
# https://github.com/<team>/<cluster-name>-infra/actions

# Watch "Provisioning Status" workflow
# It updates every 5 minutes showing:
# - Current step
# - Progress percentage
# - Estimated completion time
```

**Validate:**
- [ ] Provisioning Status workflow running
- [ ] Shows progress percentage increasing
- [ ] Current step updating
- [ ] No errors in workflow logs

---

### 🔍 Phase 4: Cluster Ready - Access & Validation (25-35 minutes)

#### Get Kubeconfig
```bash
# Method 1: Via GitHub Actions (Recommended)
# Navigate to: https://github.com/<team>/<cluster-name>-infra/actions
# Find "Get Kubeconfig" workflow
# Click "Run workflow"
# Download "kubeconfig" artifact

# Method 2: Via AWS CLI
aws eks update-kubeconfig \
  --name <cluster-name> \
  --region us-east-1

# Method 3: From cluster repo
gh run -R <team>/<cluster-name>-infra download <run-id> -n kubeconfig
```

**Validate:**
- [ ] Kubeconfig file downloaded
- [ ] File contains valid YAML
- [ ] Cluster endpoint matches AWS console
- [ ] User/token present in config

#### Verify kubectl Access
```bash
# Set kubeconfig
export KUBECONFIG=/path/to/kubeconfig.yaml

# Test cluster connection
kubectl cluster-info

# Expected output:
# Kubernetes control plane is running at https://xxx.eks.amazonaws.com
# CoreDNS is running at https://xxx.eks.amazonaws.com/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

# Check nodes
kubectl get nodes

# Expected output:
# NAME                            STATUS   ROLES    AGE   VERSION
# ip-10-0-1-100.ec2.internal     Ready    <none>   5m    v1.34.x
# ip-10-0-1-101.ec2.internal     Ready    <none>   5m    v1.34.x
```

**Validate:**
- [ ] kubectl cluster-info succeeds
- [ ] Cluster endpoint is accessible
- [ ] Node count matches requested
- [ ] All nodes show "Ready" status
- [ ] Kubernetes version matches selected

#### Verify Add-ons Are Running
```bash
# Check add-on pods
kubectl get pods -n kube-system

# Expected pods:
# - aws-node-xxxx (vpc-cni)
# - kube-proxy-xxxx (kube-proxy)
# - coredns-xxxx (coredns)
# (+ optional add-ons if enabled)

# All should show "Running" status

# Check add-on services
kubectl get svc -n kube-system

# Should include CoreDNS service
```

**Validate:**
- [ ] All add-on pods running
- [ ] No pods in "Pending" or "CrashLoopBackOff"
- [ ] All add-on services accessible
- [ ] CoreDNS resolving names correctly

#### Check Cluster Info Documentation
```bash
# GitHub repo should auto-generate documentation
# Navigate to: https://github.com/<team>/<cluster-name>-infra

# Files to check:
# - docs/CLUSTER_INFO.md (auto-generated hourly)
# - docs/ADDON_STATUS.md (auto-generated every 15 min)
# - README.md (always available)

# Example CLUSTER_INFO.md shows:
# Endpoint:    https://xxx.eks.amazonaws.com
# ARN:         arn:aws:eks:us-east-1:123456789:cluster/...
# Status:      ACTIVE
# Nodes:       2 ready
# Add-ons:     vpc-cni (ACTIVE), kube-proxy (ACTIVE), coredns (ACTIVE)
```

**Validate:**
- [ ] CLUSTER_INFO.md exists and is populated
- [ ] ADDON_STATUS.md exists and shows statuses
- [ ] Endpoint matches kubectl config
- [ ] All add-ons listed and "ACTIVE"

#### Test Actual Access - Run Helper Script
```bash
# Navigate to cluster repository
cd <cluster-name>-infra

# Test access (7-point verification)
./scripts/test-access.sh <cluster-name> us-east-1

# Expected output:
# ✅ AWS CLI can access cluster
# ✅ kubectl cluster-info successful
# ✅ Found 2 nodes
# ✅ Can access namespaces (8 namespaces)
# ✅ Can access pods (15 pods cluster-wide)
# ✅ Current user: arn:aws:iam::123456789:user/...
# ✅ Found 7 services
# ✅ All tests passed!
```

**Validate:**
- [ ] All 7 tests pass
- [ ] AWS CLI authenticated
- [ ] kubectl connected
- [ ] Node count correct
- [ ] Pods running
- [ ] Services accessible

---

### 📋 Final Validation Summary

```
🎯 PROVISIONING COMPLETE CHECKLIST

Pre-Provisioning:
  ☑ All parameters verified
  ☑ Cluster name format correct
  ☑ Team and environment selected

Template Execution (0-5 min):
  ☑ Backstage template completed
  ☑ GitHub repo created
  ☑ Workflows deployed
  ☑ Claim file in team infra repo

Provisioning Started (5-15 min):
  ☑ ArgoCD synced claim
  ☑ Crossplane resource created
  ☑ AWS resources starting
  ☑ IAM roles created
  ☑ Cluster status "CREATING"

Cluster Created (15-25 min):
  ☑ Cluster status "ACTIVE"
  ☑ Node group created
  ☑ Nodes show "Ready" status
  ☑ Add-ons deploying
  ☑ Cluster endpoint accessible

Ready For Use (25-35 min):
  ☑ Kubeconfig retrieved
  ☑ kubectl access working
  ☑ All add-ons "ACTIVE"
  ☑ Helper scripts work
  ☑ Documentation auto-generated
  ☑ All 7 access tests pass

🚀 CLUSTER READY FOR PRODUCTION USE
```

---

## Using the Cluster Repository

### 📦 What's in Your Cluster Repository

```
<team>-<cluster-name>-infra/
├── .github/workflows/           # 4 GitHub Actions
│   ├── get-kubeconfig.yml       # Retrieve kubeconfig on-demand
│   ├── cluster-info.yml         # Updates cluster info hourly
│   ├── addon-status.yml         # Updates addon status every 15 min
│   └── provisioning-status.yml  # Tracks progress every 5 min
├── docs/
│   ├── CLUSTER_INFO.md          # Auto-updated cluster details
│   ├── ADDON_STATUS.md          # Auto-updated addon health
│   └── README.md                # Quick start guide
├── scripts/
│   ├── get-cluster-info.sh      # Local cluster info
│   └── test-access.sh           # Verify access
└── .github/CODEOWNERS           # Code review policies
```

### 🚀 Common Operations

#### Get Kubeconfig Anytime
```bash
# Option 1: GitHub Actions (Recommended)
# Go to: https://github.com/<team>/<cluster-name>-infra/actions
# Run "Get Kubeconfig" workflow
# Download artifact

# Option 2: Command line
gh workflow run get-kubeconfig.yml \
  -R <team>/<cluster-name>-infra

# Option 3: AWS CLI
aws eks update-kubeconfig \
  --name <cluster-name> \
  --region us-east-1
```

#### View Cluster Information
```bash
# Option 1: Read auto-generated docs
cat https://github.com/<team>/<cluster-name>-infra/blob/main/docs/CLUSTER_INFO.md

# Option 2: Run locally
./scripts/get-cluster-info.sh <cluster-name> us-east-1

# Option 3: GitHub workflow (trigger manually)
gh workflow run cluster-info.yml -R <team>/<cluster-name>-infra
```

#### Check Add-on Status
```bash
# Read auto-generated docs
cat https://github.com/<team>/<cluster-name>-infra/blob/main/docs/ADDON_STATUS.md

# Or manually trigger
gh workflow run addon-status.yml -R <team>/<cluster-name>-infra
```

#### Test Cluster Access
```bash
# Clone the cluster repo
git clone https://github.com/<team>/<cluster-name>-infra
cd <cluster-name>-infra

# Run 7-point test
./scripts/test-access.sh <cluster-name>
```

---

## Troubleshooting

### ❌ Common Issues & Solutions

#### Issue 1: GitHub Repository Not Created

**Symptom:**
```
❌ Cluster repo <team>-<cluster-name>-infra does not exist
❌ Error: Repository not found
```

**Causes:**
- GitHub API permissions insufficient
- Team/organization limits
- Naming conflict with existing repo

**Solution:**
```bash
# Check if repo exists
gh repo view <team>/<cluster-name>-infra

# If not found, check Backstage logs:
# 1. Go to http://localhost:3000/admin/tasks
# 2. Find the failed template execution
# 3. Check error message
# 4. Common fixes:
#    - Verify GitHub token has repo creation permission
#    - Try different cluster name (avoid conflicts)
#    - Contact platform team if org limits exceeded
```

---

#### Issue 2: Cluster Stuck in "PROVISIONING"

**Symptom:**
```
⏳ Cluster status: PROVISIONING
⏳ After 30+ minutes, still not ACTIVE
```

**Diagnosis:**
```bash
# Check Crossplane events
kubectl describe xeksclusters <cluster-name> -n clusters-dev

# Look for error events
# Common errors:
# - Insufficient IAM permissions
# - Subnet selection failed
# - EC2 capacity exhausted
# - VPC quota exceeded

# Check specific resource status
kubectl get clusters.eks.aws.upbound.io
kubectl describe cluster <cluster-name> -n upbound-system
```

**Solutions:**
```bash
# 1. Check IAM permissions
aws iam list-role-policies \
  --role-name idp-dev-<cluster-name>-cluster-role

# 2. Verify subnets exist
aws ec2 describe-subnets \
  --filters "Name=tag:managed-by,Values=crossplane"

# 3. Check EC2 capacity
aws ec2 describe-instance-type-offerings \
  --filters "Name=instance-type,Values=t3.medium" \
  --region us-east-1

# 4. Review ArgoCD logs
argocd app logs <team>-eks-clusters
```

---

#### Issue 3: Nodes Not Appearing

**Symptom:**
```
✅ Cluster is ACTIVE
❌ Nodes still "Not Ready" or missing
❌ kubectl get nodes shows 0 nodes
```

**Diagnosis:**
```bash
# Check node group status
aws eks describe-nodegroup \
  --cluster-name <cluster-name> \
  --nodegroup-name <cluster-name>-node-group \
  --region us-east-1

# Look for: status = ACTIVE, desired/current count

# Check if EC2 instances are created
aws ec2 describe-instances \
  --filters "Name=tag:eks:nodegroup-name,Values=<cluster-name>-node-group"

# Check node group events for errors
```

**Solutions:**
```bash
# 1. Verify IAM role has correct permissions
aws iam get-role-policy \
  --role-name idp-dev-<cluster-name>-node-role \
  --policy-name AmazonEKSWorkerNodePolicy

# 2. Check security groups allow traffic
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=eks-<cluster-name>*"

# 3. Verify subnets have available IPs
aws ec2 describe-subnets \
  --subnet-ids <subnet-ids> \
  --query 'Subnets[].AvailableIpAddressCount'

# 4. If still not ready, manually scale
aws eks update-nodegroup-config \
  --cluster-name <cluster-name> \
  --nodegroup-name <cluster-name>-node-group \
  --scaling-config desiredSize=1
```

---

#### Issue 4: Add-ons Stuck in "PENDING"

**Symptom:**
```
⏳ Add-on vpc-cni status: PENDING
⏳ After 15+ minutes, still not ACTIVE
```

**Diagnosis:**
```bash
# Check add-on health
aws eks describe-addon \
  --cluster-name <cluster-name> \
  --addon-name vpc-cni \
  --region us-east-1 \
  --query 'addon.addonHealth.issues'

# Check add-on pod status
kubectl get pods -n kube-system | grep aws-node

# Check pod logs
kubectl logs -n kube-system -l k8s-app=aws-node
```

**Solutions:**
```bash
# 1. Verify cluster is ready
kubectl get nodes

# 2. Check OIDC provider (for some add-ons)
aws iam list-open-id-connect-providers

# 3. Manually update add-on
aws eks update-addon \
  --cluster-name <cluster-name> \
  --addon-name vpc-cni \
  --addon-version 1.14.0

# 4. Check resource quotas
kubectl describe resourcequota --all-namespaces
```

---

#### Issue 5: Kubeconfig Authentication Fails

**Symptom:**
```
❌ Error: Unauthorized
❌ error: Unable to connect to the server
❌ error: User does not have permission
```

**Diagnosis:**
```bash
# Check kubeconfig validity
cat $KUBECONFIG | grep cluster

# Verify AWS credentials
aws sts get-caller-identity

# Check cluster access
aws eks describe-cluster \
  --name <cluster-name> \
  --region us-east-1
```

**Solutions:**
```bash
# 1. Regenerate kubeconfig
aws eks update-kubeconfig \
  --name <cluster-name> \
  --region us-east-1 \
  --kubeconfig ~/.kube/config-new

# 2. Verify AWS credentials
aws configure

# 3. Check IAM user/role has EKS access
aws iam get-user-policy \
  --user-name $(aws iam get-user --query 'User.UserName' --output text) \
  --policy-name *EKS*

# 4. Add IAM principal to cluster auth config
# This requires platform team access
```

---

#### Issue 6: GitHub Workflow Fails

**Symptom:**
```
❌ Workflow run failed
❌ Error in GitHub Actions logs
```

**Common Causes & Solutions:**

```bash
# 1. AWS credentials not configured
# Solution: Check AWS_ACCOUNT_ID secret in GitHub
# https://github.com/<team>/<cluster-name>-infra/settings/secrets

# 2. OIDC role trust relationship issue
# Solution: Verify role exists in AWS
aws iam get-role --role-name github-actions-<cluster-name>-role

# 3. Missing cluster permissions
# Solution: Update role policy with EKS permissions
# https://docs.aws.amazon.com/eks/latest/userguide/iam-policies.html

# 4. Cluster not found
# Solution: Verify cluster exists and name matches
aws eks describe-cluster --name <cluster-name> --region us-east-1

# 5. Network/API throttling
# Solution: Check AWS service quotas
# https://console.aws.amazon.com/servicequotas
```

---

## Post-Provisioning Setup

### ✅ After Cluster is Ready

#### 1. Share Cluster Access
```bash
# Create IAM user for team members
aws iam create-user --user-name <username>

# Add to EKS cluster auth
# Send kubeconfig to team members

# Or create RBAC role
kubectl create role developer \
  --verb=get,list,watch \
  --resource=pods,services,deployments

kubectl create rolebinding developer-binding \
  --clusterrole=developer \
  --user=<iam-user>
```

#### 2. Install Common Add-ons/Tools
```bash
# Verify essential add-ons
kubectl get daemonsets -n kube-system

# Install ingress controller (if needed)
helm repo add nginx-stable https://helm.nginx.com/stable
helm install ingress-nginx nginx-stable/nginx-ingress \
  --namespace ingress-nginx \
  --create-namespace

# Install metrics-server (for HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.5.0/components.yaml

# Install cert-manager (if needed)
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace
```

#### 3. Configure Monitoring (Optional but Recommended)
```bash
# Install Prometheus for metrics
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Install CloudWatch Container Insights
kubectl create namespace amazon-cloudwatch
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | \
  sed "s/{{cluster_name}}/<cluster-name>/g" | \
  sed "s/{{region_name}}/us-east-1/g" | \
  kubectl apply -f -
```

#### 4. Set Up Log Aggregation (Optional)
```bash
# Send logs to CloudWatch
kubectl create namespace amazon-logs
kubectl create configmap cluster-info \
  --namespace amazon-logs \
  --from-literal=cluster.name=<cluster-name>

# Or configure Fluent Bit/Logstash
helm repo add fluent https://fluent.github.io/helm-charts
helm install fluent-bit fluent/fluent-bit \
  --namespace logging \
  --create-namespace
```

#### 5. Set Up Auto-Scaling (If Enabled)
```bash
# Verify Cluster Autoscaler is running
kubectl get deployment -n kube-system cluster-autoscaler

# Check logs
kubectl logs -n kube-system -l app=cluster-autoscaler -f

# Verify External DNS (if enabled)
kubectl get deployment -n external-dns external-dns
```

#### 6. Document Your Cluster
```bash
# Update README with cluster-specific info
cat > CLUSTER_ONBOARDING.md << EOF
# Cluster: <cluster-name>

## Quick Links
- Endpoint: <endpoint-from-docs/CLUSTER_INFO.md>
- ARN: <arn-from-docs/CLUSTER_INFO.md>
- OIDC Issuer: <oidc-from-docs/CLUSTER_INFO.md>

## Access
1. Get kubeconfig: gh workflow run get-kubeconfig.yml
2. Test access: ./scripts/test-access.sh
3. Deploy app: kubectl apply -f app.yaml

## Team
- Owner: <your-team>
- Contact: <team-slack-channel>
EOF

git add CLUSTER_ONBOARDING.md
git commit -m "docs: add cluster onboarding guide"
git push
```

---

## Quick Reference

### 📋 Quick Command Cheatsheet

```bash
# GET KUBECONFIG
export KUBECONFIG=~/.kube/config-<cluster-name>
aws eks update-kubeconfig \
  --name <cluster-name> \
  --region us-east-1

# VERIFY CLUSTER
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces

# CHECK STATUS
kubectl get xeksclusters -n clusters-dev
aws eks describe-cluster --name <cluster-name> --region us-east-1

# VIEW CLUSTER INFO
cat docs/CLUSTER_INFO.md
cat docs/ADDON_STATUS.md

# RUN HELPER SCRIPTS
./scripts/get-cluster-info.sh <cluster-name>
./scripts/test-access.sh <cluster-name>

# SCALE NODES
aws eks update-nodegroup-config \
  --cluster-name <cluster-name> \
  --nodegroup-name <cluster-name>-node-group \
  --scaling-config desiredSize=5

# VIEW LOGS
kubectl logs -n kube-system -f
kubectl logs -n kube-system -l app=<addon-name>

# DEPLOY APPLICATION
kubectl apply -f my-app.yaml
kubectl get deployments
kubectl get services
```

---

### 📚 Reference Links

| Link | Purpose |
|------|---------|
| https://console.aws.amazon.com/eks | AWS EKS Console |
| http://localhost:3000/catalog | Backstage Catalog |
| http://localhost:8080/applications | ArgoCD Applications |
| https://github.com/<team>/<cluster-name>-infra | Cluster Repo |
| https://docs.aws.amazon.com/eks | AWS EKS Documentation |
| https://kubernetes.io/docs | Kubernetes Documentation |

---

### 🆘 Support & Escalation

```
Problem? Follow this escalation path:

1. Check Diagnostics
   └─ ./scripts/test-access.sh <cluster-name>
   └─ kubectl describe xeksclusters <cluster-name> -n clusters-dev

2. Review Documentation
   └─ docs/CLUSTER_INFO.md
   └─ docs/ADDON_STATUS.md
   └─ README.md

3. Check Logs
   └─ kubectl logs -n kube-system
   └─ kubectl describe nodes

4. Search Troubleshooting
   └─ This guide's "Troubleshooting" section
   └─ GitHub Actions workflow logs

5. Contact Platform Team
   └─ #platform-team Slack channel
   └─ Attach: cluster name, error message, steps taken
```

---

## Summary Checklist

```
✅ COMPLETE EKS PROVISIONING CHECKLIST

BEFORE PROVISIONING:
 □ All cluster details prepared
 □ Team name verified
 □ Cluster name format correct
 □ Backstage access confirmed

DURING PROVISIONING:
 □ Template fields filled correctly
 □ Environment selected (dev/staging)
 □ Add-ons configured as needed
 □ Submission successful

IMMEDIATE VALIDATION (0-5 min):
 □ Backstage shows success
 □ GitHub repo created
 □ Cluster claim file exists
 □ 4 workflows deployed

PROVISIONING PROGRESS (5-25 min):
 □ ArgoCD synced
 □ Crossplane resources created
 □ AWS cluster creating
 □ IAM roles created
 □ Node group provisioning
 □ Add-ons deploying

CLUSTER READY (25-35 min):
 □ Cluster status: ACTIVE
 □ Nodes: Ready
 □ Add-ons: ACTIVE
 □ Kubeconfig: Retrieved
 □ kubectl access: Working
 □ Helper scripts: Working
 □ Documentation: Auto-generated

POST-PROVISIONING:
 □ Team members granted access
 □ Applications deployed
 □ Monitoring configured
 □ Logging configured
 □ Cluster documented

🎉 CLUSTER READY FOR PRODUCTION USE
```

---

**Questions? Check the troubleshooting section or contact the platform team in #platform-team Slack channel.**
