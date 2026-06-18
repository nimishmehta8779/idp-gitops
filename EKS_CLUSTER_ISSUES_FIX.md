# EKS Cluster Template Issues - Diagnostic and Fix Guide

## Issue 1: ✅ FIXED - EKS Addon Module Trigger Dependencies

**Status**: RESOLVED in commit `34f53d6`

### Changes Made
- Added `readinessChecks` to EKS Cluster resource to wait until `status.atProvider.status == ACTIVE`
- Added explicit `dependsOn: [eks-cluster]` to all addon resources:
  - vpc-cni addon
  - kube-proxy addon
  - coredns addon
  - EBS CSI addon (conditionally generated)
  - OIDC provider
- Added explicit `dependsOn: [eks-cluster]` to NodeGroup to ensure cluster is ready before node provisioning

### Why This Fixes the Issue
Crossplane processes resources in parallel by default. Without dependencies:
- Addons would attempt to deploy before the cluster was ready, causing transient failures
- NodeGroups would be created concurrently with the cluster, potentially missing subnet configuration
- During deletion, resources might be deleted in wrong order, leaving orphaned addons

With explicit dependencies and readiness checks:
- Cluster is confirmed ACTIVE before any dependent resources are created
- Addons only create after cluster is ready
- Reverse dependency order ensures proper cleanup (addons deleted before cluster)

### Verification
After deploying a new EKS cluster, verify:
1. Check Crossplane composite resource status: `kubectl get xeksclusters -o wide`
2. Verify EKS cluster is ACTIVE in AWS console
3. Confirm addons appear in AWS EKS console under cluster → Add-ons tab
4. Verify nodes appear in AWS EKS console under cluster → Compute tab

---

## Issue 2: ⚠️ PENDING - Nodes Not Appearing in AWS Console

### Root Cause Analysis
This is typically caused by one of the following:

#### A. IAM Permission Issue (Most Common)
- NodeGroup IAM role lacks required permissions
- Missing `ec2:RunInstances` permission
- Missing `ec2:CreateTags` permission
- Node role trust relationship incorrect

#### B. Subnet Selection Issue
- Node group subnet selector not finding valid subnets
- Subnets don't have `managed-by: crossplane` label
- Subnets don't have `environment` label matching cluster environment
- Network composition not creating subnets properly

#### C. EC2 Capacity Issue
- AWS account has EC2 capacity limits reached
- Instance type not available in selected region
- VPC has no available IPs for EC2 instances

### Diagnostic Steps

**Step 1: Check NodeGroup Resource Status**
```bash
kubectl describe nodegroup <cluster-name>-node-group -n clusters-dev
# Look for: Events section at bottom
# Check: status.atProvider status
# Expected: "ACTIVE"
```

**Step 2: Verify IAM Role Policies**
```bash
# Check role policies in AWS console or via CLI
aws iam list-attached-role-policies \
  --role-name idp-dev-<cluster-name>-node-role

# Required policies:
# - AmazonEKSWorkerNodePolicy
# - AmazonEKS_CNI_Policy
# - AmazonEC2ContainerRegistryReadOnly
```

**Step 3: Verify Subnets Have Required Labels**
```bash
kubectl get subnets -L managed-by,environment -n upbound-system
# Expected output: subnets should have these labels
# managed-by: crossplane
# environment: dev (or staging)
```

**Step 4: Check Network Composition**
```bash
# Verify network is deployed successfully
kubectl get xnetworks -o wide
# Should show status "READY" or similar
```

### Recommended Fixes

#### Fix 1A: Ensure NodeGroup Waits for IAM Role
Add dependency in composition (should already be there with latest fix):
```yaml
- name: node-group
  base:
    spec:
      dependsOn:
        - eks-cluster
        - nodegroup-role
        - nodegroup-policy-workernode
        - nodegroup-policy-cni
        - nodegroup-policy-registry
```

#### Fix 1B: Add Subnet Validation
Consider adding a validation step in the composition to verify subnets exist:
```yaml
readinessChecks:
  - type: MatchString
    fieldPath: status.atProvider.nodeGroupName
    matchString: <cluster-name>-node-group
```

#### Fix 1C: Add Explicit IAM Role Reference
Update the nodegroup patches to ensure role is fully resolved before use:
```yaml
- type: FromFieldPath
  fromFieldPath: status.atProvider.nodeRoleArn
  toFieldPath: spec.forProvider.nodeRoleArnRef.name
  policy:
    fromFieldPath: Required  # Ensure role exists before proceeding
```

---

## Issue 3: ⚠️ PENDING - Decommissioning Not Deleting EKS Cluster

### Root Cause Analysis
The decommissioning template (`decommission-cluster/template.yaml`) correctly deletes the claim files, but the actual AWS resource deletion depends on:

1. **ArgoCD detecting the claim file deletion** and deleting the EKSCluster Kubernetes resource
2. **Crossplane observing the EKSCluster resource deletion** and cleaning up AWS resources
3. **Deletion policy being set correctly**:
   - `dev` environment: `Delete` policy (resources deleted immediately)
   - `staging` environment: `Orphan` policy (resources remain in AWS, only Kubernetes resource deleted)

### Why Cluster Isn't Deleted

#### For Dev Clusters:
- The EKSCluster claim deletion might not trigger ArgoCD sync immediately
- ArgoCD sync interval might not run frequently
- Crossplane deletion controller might have an error

#### For Staging Clusters:
- **This is expected behavior** - Staging uses `Orphan` deletion policy
- AWS resources remain in AWS console even after claim file is deleted
- User must manually delete AWS resources via AWS console

### Fix Strategy

#### Step 1: Verify ArgoCD Sync Settings
Check the ArgoCD application for the team's eks-clusters:
```bash
kubectl get application <team>-eks-clusters -n argocd -o yaml
# Verify syncPolicy includes prune: true
# Verify syncOptions doesn't prevent deletion
```

#### Step 2: Improve Decommissioning Workflow

Add a verification step to the decommission template:

**New Step - Verify Cluster Deletion (Dev Only)**:
```yaml
- id: verify-cluster-deletion-dev
  name: Verify Cluster Deletion
  if: ${{ parameters.environment == 'dev' }}
  action: debug:wait
  input:
    seconds: 30  # Wait for ArgoCD sync

- id: check-cluster-status
  name: Check Cluster Status in AWS
  if: ${{ parameters.environment == 'dev' }}
  action: idp:aws:check-resource
  input:
    resourceType: eks-cluster
    clusterName: ${{ parameters.clusterName.split('/').pop() }}
    region: ${{ parameters.awsRegion }}
    expectedStatus: DELETED  # Should not exist
```

#### Step 3: Add Manual Cleanup Reminder for Staging

Update the staging decommissioning output to be more explicit:

```yaml
output:
  links:
    - title: "AWS Console - EKS Clusters"
      url: https://console.aws.amazon.com/eks/home?region=${{ parameters.awsRegion }}#/clusters
      icon: external-link
  text: |
    ## ⚠️ Important: Manual Cleanup Required
    
    Staging clusters use **Orphan deletion policy**. The cluster claim has been removed from GitOps, but AWS resources still exist and will incur costs.
    
    ### Manual Cleanup Steps:
    1. Open [AWS Console - EKS](https://console.aws.amazon.com/eks/home?region=${{ parameters.awsRegion }}#/clusters)
    2. Find and select cluster: `${{ parameters.clusterName.split('/').pop() }}`
    3. Delete the cluster (this will also delete associated node groups)
    4. Wait for deletion to complete (~15-20 minutes)
    5. Verify VPC, subnets, and security groups are also deleted (or manually delete if retained)
```

#### Step 4: Add Deletion Policy Annotation

Add an annotation to explicitly mark deletion intention:

```yaml
metadata:
  annotations:
    idp.platform.io/decommission-date: ${{ now() }}
    idp.platform.io/pending-deletion: "true"
```

This allows ArgoCD finalizers or webhook controllers to catch the deletion intent.

### Verification Steps

After running decommissioning template:

**Dev Environment**:
1. Check Kubernetes: `kubectl get eksclusters -n clusters-dev` → should return empty or resource in deletion state
2. Wait 2-3 ArgoCD sync cycles (check ArgoCD UI)
3. Check AWS Console: EKS → Clusters → Should not see the cluster
4. Check Crossplane: `kubectl get clusters.eks.aws.upbound.io` → Should be gone

**Staging Environment**:
1. Check Kubernetes: `kubectl get eksclusters -n clusters-staging` → should be deleted
2. Check AWS Console: EKS → Clusters → Cluster should still exist (THIS IS EXPECTED)
3. Manually delete cluster via AWS Console
4. Verify audit record created in `gitops/decommission-records/`

---

## Summary of Changes

### Completed (Commit 34f53d6)
- ✅ Added readinessChecks to EKS cluster
- ✅ Added dependsOn to node group
- ✅ Added dependsOn to all addons
- ✅ Added dependsOn to OIDC provider

### Recommended Next Steps
1. Deploy the updated composition and test with a new dev cluster
2. Monitor NodeGroup creation for permission/subnet issues (Issue 2)
3. Test decommissioning workflow (Issue 3)
4. Implement optional improvements from Issue 3 section

### Testing Checklist
- [ ] Create new dev cluster via Backstage template
- [ ] Verify cluster becomes ACTIVE in AWS
- [ ] Wait for addons to deploy (5-10 minutes)
- [ ] Verify nodes appear in Compute section of AWS EKS console
- [ ] Verify all addons show as "ACTIVE" in EKS Add-ons tab
- [ ] Decommission dev cluster via template
- [ ] Wait for ArgoCD sync (2-3 minutes)
- [ ] Verify cluster is gone from AWS console

---

## References

- [Crossplane Resource Dependencies](https://docs.crossplane.io/latest/concepts/compositions/#composition-functions-pipeline)
- [Crossplane Readiness Checks](https://docs.crossplane.io/latest/concepts/compositions/#readiness-checks)
- [AWS EKS IAM Roles for NodeGroups](https://docs.aws.amazon.com/eks/latest/userguide/create-node-role.html)
- [EKS Add-ons Overview](https://docs.aws.amazon.com/eks/latest/userguide/eks-add-ons.html)
