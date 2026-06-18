# Enhanced EKS Provisioning with GitHub Repo & Live Monitoring
## Single Pane of Glass Architecture

**Date**: June 18, 2026
**Status**: Design & Implementation Plan

---

## Overview

Enhance EKS cluster provisioning to provide developers with:
1. ✅ **Dedicated GitHub Repository** - Cluster-specific infra repo with GitHub Actions for secure access
2. ✅ **Live Progress Monitoring** - Real-time provisioning and addon deployment status in Backstage
3. ✅ **Terraform Outputs** - Immediate access to cluster URLs, ARNs, endpoints after completion
4. ✅ **Single Pane of Glass** - All provisioning info and access mechanisms in one Backstage card

---

## Architecture Design

### 1. Enhanced EKS Template Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                  Request EKS Cluster Template                   │
└─────────────────────────────────────────────────────────────────┘
         │
         ├─ Step 1: Create team infra repo cluster claim
         │          └─ eks/<cluster-name>.yaml
         │
         ├─ Step 2: Create cluster-specific GitHub repo
         │          └─ <team>-<cluster-name>-infra (NEW)
         │
         ├─ Step 3: Initialize cluster repo with:
         │          ├─ .github/workflows/get-kubeconfig.yml
         │          ├─ .github/workflows/cluster-info.yml
         │          ├─ .github/workflows/addon-status.yml
         │          ├─ terraform/outputs.tf
         │          └─ README.md (cluster info)
         │
         ├─ Step 4: Create Backstage catalog entity
         │          └─ Includes status tracking annotations
         │
         └─ Step 5: Monitor & display progress
                   └─ Watch Crossplane resources
                   └─ Display status in Backstage dashboard
```

### 2. GitHub Repository Structure for Each Cluster

```
<team>-<cluster-name>-infra/
├── .github/
│   ├── workflows/
│   │   ├── get-kubeconfig.yml         # Retrieve kubeconfig via OIDC
│   │   ├── cluster-info.yml           # Display cluster details
│   │   ├── addon-status.yml           # Show addon deployment status
│   │   ├── terraform-outputs.yml      # Display terraform outputs
│   │   └── access-token.yml           # Generate temporary access token
│   └── CODEOWNERS
├── terraform/
│   ├── outputs.tf                      # Terraform output definitions
│   └── .terraform.lock.hcl
├── docs/
│   ├── README.md                       # Cluster overview & quick start
│   ├── CLUSTER_INFO.md                # Dynamically generated cluster details
│   └── ADDON_STATUS.md                # Dynamically generated addon status
├── scripts/
│   ├── get-cluster-info.sh            # Local script to fetch cluster info
│   └── test-access.sh                 # Test cluster access
└── .gitignore
```

### 3. Backstage Catalog Enhancement

#### New Component Type: `eks-cluster-instance`

```yaml
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: alpha-dev-general-01
  namespace: default
  labels:
    type: kubernetes-cluster
    provisioning-state: provisioning
  annotations:
    eks.idp.platform.io/cluster-status: provisioning
    eks.idp.platform.io/progress: "35%"
    eks.idp.platform.io/current-step: "provisioning-node-group"
    eks.idp.platform.io/estimated-time-remaining: "8 minutes"
    crossplane.io/composite-name: alpha-dev-general-01
    github.com/repo: alpha-dev-general-01-infra
spec:
  type: kubernetes-cluster
  owner: group:default/team-alpha
  system: system:default/eks-provisioning
status:
  eks:
    clusterStatus: PROVISIONING
    clusterEndpoint: "https://xxx.eks.amazonaws.com"
    clusterArn: "arn:aws:eks:us-east-1:123456789:cluster/alpha-dev-general-01"
    nodeGroupStatus: CREATING
    activeAddons: ["vpc-cni", "kube-proxy"]
    pendingAddons: ["coredns", "ebs-csi"]
    progress:
      step: "provisioning-node-group"
      percentage: 35
      startTime: "2026-06-18T10:00:00Z"
      estimatedCompletionTime: "2026-06-18T10:45:00Z"
```

#### Backstage Card Components

```
┌─────────────────────────────────────────────────────────────┐
│                 EKS Cluster: alpha-dev-general-01            │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Status: 🟡 PROVISIONING (35% complete)                     │
│  Current Step: Creating Node Group (8 min remaining)        │
│                                                              │
│  [████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░] 35%            │
│                                                              │
│  ┌─ Provisioning Timeline ──────────────────┐               │
│  │ ✅ 10:00  Cluster role created           │               │
│  │ ✅ 10:02  IAM policies attached          │               │
│  │ ✅ 10:05  EKS cluster created            │               │
│  │ 🟡 10:20  Node group creating...         │               │
│  │ ⏳ 10:30  Addons deploying               │               │
│  │ ⏳ 10:45  Monitoring setup                │               │
│  └──────────────────────────────────────────┘               │
│                                                              │
│  Addon Status:                                               │
│  ✅ vpc-cni (ACTIVE)                                         │
│  ✅ kube-proxy (ACTIVE)                                      │
│  🟡 coredns (PENDING)                                        │
│  ⏳ ebs-csi (PENDING)                                        │
│                                                              │
│  Quick Actions:                                              │
│  [Get Kubeconfig] [Cluster Info] [GitHub Repo]             │
│                                                              │
│  Terraform Outputs (once complete):                         │
│  Endpoint: https://xxx.eks.amazonaws.com                   │
│  ARN: arn:aws:eks:us-east-1:123456789:cluster/...         │
│  OIDC Provider: arn:aws:iam::123456789:oidc-provider/...  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Details

### Part 1: Create Cluster-Specific GitHub Repository

**File**: `development/templates/eks-cluster/template.yaml` (ENHANCED)

Add a new step after fetching skeleton:

```yaml
- id: create-cluster-repo
  name: Create Cluster-Specific GitHub Repository
  action: github:repo:create
  input:
    repoUrl: github.com?owner=${{ parameters.teamName }}
    name: ${{ parameters.clusterName }}-infra
    description: "Infrastructure repository for EKS cluster ${{ parameters.clusterName }}"
    private: true
    hasIssues: true
    hasProjects: true
    homepageUrl: http://localhost:3000/catalog/default/resource/${{ parameters.clusterName }}
    topics:
      - eks
      - cluster
      - infrastructure
      - ${{ parameters.teamName }}
```

### Part 2: Initialize Cluster Repo with GitHub Actions Workflows

Create skeleton files in the new repo:

#### `.github/workflows/get-kubeconfig.yml`
```yaml
name: Get Kubeconfig
on:
  workflow_dispatch:

jobs:
  get-kubeconfig:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Get kubeconfig
        run: |
          aws eks update-kubeconfig \
            --name ${{ env.CLUSTER_NAME }} \
            --region ${{ env.AWS_REGION }} \
            --output text
          
          # Display kubeconfig (masked in logs)
          echo "KUBECONFIG_GENERATED=true" >> $GITHUB_OUTPUT
          
          # Save as artifact for download
          mkdir -p kubeconfig
          aws eks update-kubeconfig \
            --name ${{ env.CLUSTER_NAME }} \
            --region ${{ env.AWS_REGION }} \
            --kubeconfig kubeconfig/config
      
      - uses: actions/upload-artifact@v3
        with:
          name: kubeconfig
          path: kubeconfig/config
```

#### `.github/workflows/cluster-info.yml`
```yaml
name: Cluster Information
on:
  workflow_dispatch:
  schedule:
    - cron: '0 * * * *'  # Hourly

jobs:
  cluster-info:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: write
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Get Cluster Information
        id: cluster-info
        run: |
          CLUSTER_NAME="${{ env.CLUSTER_NAME }}"
          REGION="${{ env.AWS_REGION }}"
          
          # Get cluster details
          CLUSTER_INFO=$(aws eks describe-cluster --name $CLUSTER_NAME --region $REGION)
          
          # Extract information
          ENDPOINT=$(echo $CLUSTER_INFO | jq -r '.cluster.endpoint')
          ARN=$(echo $CLUSTER_INFO | jq -r '.cluster.arn')
          STATUS=$(echo $CLUSTER_INFO | jq -r '.cluster.status')
          VERSION=$(echo $CLUSTER_INFO | jq -r '.cluster.version')
          OIDC_ISSUER=$(echo $CLUSTER_INFO | jq -r '.cluster.identity.oidc.issuer')
          
          # Get node groups
          NODE_GROUPS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query 'nodegroups' --output json)
          
          # Get addons
          ADDONS=$(aws eks list-addons --cluster-name $CLUSTER_NAME --region $REGION --query 'addons' --output json)
          
          # Generate markdown
          cat > CLUSTER_INFO.md << EOF
          # Cluster Information: $CLUSTER_NAME
          
          ## Overview
          - **Status**: $STATUS
          - **Kubernetes Version**: $VERSION
          - **Region**: $REGION
          
          ## Endpoints & ARNs
          - **Endpoint**: $ENDPOINT
          - **ARN**: $ARN
          - **OIDC Issuer**: $OIDC_ISSUER
          
          ## Node Groups
          \`\`\`json
          $NODE_GROUPS
          \`\`\`
          
          ## Add-ons
          \`\`\`json
          $ADDONS
          \`\`\`
          
          ## Related Resources
          - [View in Backstage](http://localhost:3000/catalog/default/resource/$CLUSTER_NAME)
          - [View in AWS Console](https://console.aws.amazon.com/eks/home?region=$REGION#/clusters/$CLUSTER_NAME)
          - [View in ArgoCD](http://localhost:8080/applications/${{ env.TEAM_NAME }}-eks-clusters)
          
          Generated: $(date)
          EOF
      
      - uses: EndBug/add-and-commit@v9
        with:
          message: 'docs: update cluster information'
          add: 'CLUSTER_INFO.md'
```

#### `.github/workflows/addon-status.yml`
```yaml
name: Addon Status
on:
  workflow_dispatch:
  schedule:
    - cron: '*/15 * * * *'  # Every 15 minutes

jobs:
  addon-status:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      
      - name: Check Addon Status
        run: |
          CLUSTER_NAME="${{ env.CLUSTER_NAME }}"
          REGION="${{ env.AWS_REGION }}"
          
          echo "## Addon Status" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          
          aws eks describe-addon \
            --cluster-name $CLUSTER_NAME \
            --region $REGION \
            --addon-name vpc-cni \
            --query 'addon.addonVersion' \
            --output text | xargs -I {} echo "- vpc-cni: {}" >> $GITHUB_STEP_SUMMARY
          
          aws eks describe-addon \
            --cluster-name $CLUSTER_NAME \
            --region $REGION \
            --addon-name kube-proxy \
            --query 'addon.addonVersion' \
            --output text | xargs -I {} echo "- kube-proxy: {}" >> $GITHUB_STEP_SUMMARY
```

### Part 3: Store Terraform Outputs in Kubernetes

Update the Crossplane composition to create a ConfigMap with outputs:

**File**: `infrastructure/crossplane/eks/composition.yaml` (ENHANCED)

Add output transformation step:

```yaml
- step: output-extraction
  functionRef:
    name: function-patch-and-transform
  input:
    apiVersion: pt.fn.crossplane.io/v1beta1
    kind: Resources
    resources:
      - name: terraform-outputs-configmap
        base:
          apiVersion: v1
          kind: ConfigMap
          metadata:
            namespace: crossplane-system
          data:
            cluster_endpoint: ""
            cluster_arn: ""
            oidc_provider_arn: ""
            node_group_id: ""
        patches:
          - fromFieldPath: spec.parameters.clusterName
            toFieldPath: metadata.name
            transforms:
              - type: string
                string:
                  type: Format
                  fmt: "%s-outputs"
          - fromFieldPath: status.atProvider.endpoint
            toFieldPath: data.cluster_endpoint
          - fromFieldPath: status.atProvider.arn
            toFieldPath: data.cluster_arn
          - type: ToCompositeFieldPath
            fromFieldPath: status.atProvider.endpoint
            toFieldPath: status.outputs.clusterEndpoint
```

### Part 4: Backstage Catalog Enhancement

#### New Backstage Card Plugin

Create a custom Backstage card to display live provisioning status:

**File**: `infrastructure/backstage/plugins/eks-cluster-status-card/`

```typescript
// EksClusterStatusCard.tsx
import React, { useEffect, useState } from 'react';
import { Card, CardContent, LinearProgress, Typography } from '@material-ui/core';
import { useEntity } from '@backstage/plugin-catalog-react';

export const EksClusterStatusCard = () => {
  const { entity } = useEntity();
  const [clusterInfo, setClusterInfo] = useState(null);
  const [outputs, setOutputs] = useState(null);

  useEffect(() => {
    // Fetch cluster info from Crossplane
    const fetchClusterInfo = async () => {
      const compositeName = entity.metadata.annotations?.[
        'crossplane.io/composite-name'
      ];
      
      if (!compositeName) return;

      try {
        // Query Crossplane for cluster status
        const response = await fetch(
          `/api/crossplane/composites/eks/${compositeName}`
        );
        const data = await response.json();
        
        setClusterInfo({
          status: data.status.atProvider.status,
          endpoint: data.status.atProvider.endpoint,
          arn: data.status.atProvider.arn,
          progress: calculateProgress(data),
          currentStep: getCurrentStep(data),
        });

        // Fetch terraform outputs
        const outputsResponse = await fetch(
          `/api/kubernetes/configmaps/crossplane-system/${compositeName}-outputs`
        );
        const outputsData = await outputsResponse.json();
        setOutputs(outputsData.data);
      } catch (error) {
        console.error('Failed to fetch cluster info:', error);
      }
    };

    const interval = setInterval(fetchClusterInfo, 10000); // Poll every 10s
    fetchClusterInfo();

    return () => clearInterval(interval);
  }, [entity]);

  if (!clusterInfo) {
    return <Typography>Loading cluster information...</Typography>;
  }

  return (
    <Card>
      <CardContent>
        <Typography variant="h5" gutterBottom>
          {entity.metadata.name}
        </Typography>
        
        <Typography color="textSecondary" gutterBottom>
          Status: {clusterInfo.status}
        </Typography>

        <LinearProgress 
          variant="determinate" 
          value={clusterInfo.progress} 
        />
        <Typography variant="caption">
          {clusterInfo.progress}% - {clusterInfo.currentStep}
        </Typography>

        {clusterInfo.status === 'ACTIVE' && outputs && (
          <div style={{ marginTop: 16 }}>
            <Typography variant="h6">Terraform Outputs</Typography>
            <table style={{ width: '100%' }}>
              <tbody>
                <tr>
                  <td><strong>Endpoint</strong></td>
                  <td><code>{outputs.cluster_endpoint}</code></td>
                </tr>
                <tr>
                  <td><strong>ARN</strong></td>
                  <td><code>{outputs.cluster_arn}</code></td>
                </tr>
                <tr>
                  <td><strong>OIDC Provider</strong></td>
                  <td><code>{outputs.oidc_provider_arn}</code></td>
                </tr>
              </tbody>
            </table>
          </div>
        )}

        <div style={{ marginTop: 16 }}>
          <a href={outputs?.cluster_endpoint} target="_blank">
            📊 View in AWS Console
          </a>
          {' | '}
          <a href={`https://github.com/${entity.metadata.annotations?.['github.com/repo']}`} target="_blank">
            🔧 GitHub Repository
          </a>
          {' | '}
          <a href="http://localhost:3000/catalog">
            📝 Backstage Catalog
          </a>
        </div>
      </CardContent>
    </Card>
  );
};
```

### Part 5: Real-time Status Updates via WebSocket

Create an API endpoint to stream provisioning events:

**File**: `infrastructure/backstage/backend/routes/eks-cluster-status.ts`

```typescript
import express from 'express';
import * as kubernetes from '@kubernetes/client-node';

const router = express.Router();
const k8sClient = new kubernetes.KubeConfig();
k8sClient.loadFromDefault();

router.ws('/watch/:clusterName', (ws, req) => {
  const { clusterName } = req.params;
  
  const watch = new kubernetes.Watch(k8sClient);
  
  // Watch XEKSCluster resource
  watch.watch(
    `/apis/platform.io/v1alpha1/namespaces/clusters-dev/xeksclusters/${clusterName}`,
    {},
    (type, obj, watchObj) => {
      ws.send(JSON.stringify({
        type,
        resource: {
          status: obj.status,
          progress: calculateProgress(obj),
          conditions: obj.status.conditions,
        },
        timestamp: new Date(),
      }));
    },
    () => {
      // Connection closed
      watch.destroy();
      ws.close();
    },
  );
});

export default router;
```

### Part 6: Provisioning Timeline & Event Tracking

Update Crossplane to emit structured events:

```yaml
# In composition.yaml - add event emission for key milestones
- step: emit-events
  functionRef:
    name: function-go-templating
  input:
    template: |
      {{- if eq .observed.composite.resource.status.atProvider.status "ACTIVE" }}
      apiVersion: v1
      kind: Event
      metadata:
        name: cluster-ready
        namespace: {{ .observed.composite.resource.metadata.namespace }}
      reason: ClusterReady
      message: "EKS cluster is ready for workload deployment"
      involvedObject:
        apiVersion: platform.io/v1alpha1
        kind: XEKSCluster
        name: {{ .observed.composite.resource.metadata.name }}
      {{- end }}
```

---

## Implementation Phases

### Phase 1: Foundation (Week 1)
- [ ] Enhance EKS template to create cluster-specific GitHub repo
- [ ] Initialize repo with basic GitHub Actions workflows
- [ ] Create Backstage card to display cluster status
- [ ] Add ConfigMap for storing Terraform outputs

### Phase 2: Live Monitoring (Week 2)
- [ ] Implement WebSocket API for real-time status updates
- [ ] Add event streaming from Crossplane
- [ ] Build progress tracking visualization
- [ ] Add timeline view of provisioning steps

### Phase 3: Outputs & Access (Week 3)
- [ ] Display Terraform outputs in Backstage card
- [ ] Add quick-access links to GitHub workflows
- [ ] Create CLI helper script for local kubeconfig retrieval
- [ ] Add temporary access token generation

### Phase 4: Polish & Testing (Week 4)
- [ ] Add error handling and retry logic
- [ ] Implement notifications (Slack, email)
- [ ] Create troubleshooting guide
- [ ] Performance optimization and caching

---

## User Experience Flow

### Day 1: Requesting Cluster

```
Developer opens Backstage → Clicks "Request EKS Cluster"
         ↓
Fills in cluster details (name, team, region, etc.)
         ↓
Submits template
         ↓
Backstage creates:
  1. Cluster claim in team infra repo
  2. New GitHub repo: team-cluster-name-infra
  3. Catalog entity with status tracking
         ↓
Developer sees Backstage card:
  "✅ Provisioning started (0% complete)"
  "📊 Monitoring GitHub Actions workflows"
```

### Day 1-2: Monitoring Progress

```
Developer navigates to cluster resource in Backstage
         ↓
Sees live provisioning dashboard:
  Status: 🟡 PROVISIONING
  Progress: 🟢 25% - Creating Node Group (8 min remaining)
  
  Timeline:
  ✅ Cluster role created (10:00)
  ✅ IAM policies attached (10:02)
  ✅ EKS cluster created (10:05)
  🟡 Node group creating... (10:20)
  ⏳ Addons deploying
  ⏳ Monitoring setup
  
  Addon Status:
  ✅ vpc-cni (ACTIVE)
  ✅ kube-proxy (ACTIVE)
  🟡 coredns (PENDING)
  ⏳ ebs-csi (PENDING)
         ↓
Clicks [Get Kubeconfig] button
         ↓
GitHub Actions workflow runs
         ↓
Kubeconfig downloaded automatically
         ↓
Developer: kubectl get nodes
Result:
  NAME                          STATUS   ROLES
  ip-10-0-1-100.ec2.internal   Ready    <none>
  ip-10-0-1-101.ec2.internal   Ready    <none>
```

### Day 2: Cluster Ready

```
Developer refreshes Backstage card
         ↓
Status now shows:
  ✅ ACTIVE (100% complete)
  
  Terraform Outputs:
  ├─ Endpoint: https://xxx.eks.amazonaws.com
  ├─ ARN: arn:aws:eks:us-east-1:123456789:cluster/alpha-dev-general-01
  ├─ OIDC Provider: arn:aws:iam::123456789:oidc-provider/...
  └─ Node Group ARN: arn:aws:eks:us-east-1:123456789:nodegroup/...
  
  Quick Actions:
  [Get Kubeconfig] [Cluster Info] [GitHub Repo] [AWS Console]
         ↓
Developer can now:
  - Download kubeconfig
  - View cluster information
  - Access GitHub repo for infrastructure
  - Deploy applications to cluster
```

---

## Benefits

### For Developers
✅ **Single source of truth** - All cluster info in Backstage
✅ **Real-time visibility** - See exactly what's happening
✅ **No waiting** - Know estimated completion time
✅ **Easy access** - One-click kubeconfig retrieval
✅ **Immediate outputs** - URLs and ARNs ready instantly

### For Platform Team
✅ **Better support** - Users know what's happening (fewer tickets)
✅ **Audit trail** - GitHub repo tracks all cluster config
✅ **Automation** - Workflows eliminate manual steps
✅ **Observability** - Monitor provisioning in real-time
✅ **Scalability** - Template scales to hundreds of clusters

### For Infrastructure
✅ **Centralized** - One GitHub repo per cluster
✅ **Traceable** - All changes tracked in Git
✅ **Secure** - GitHub Actions with OIDC for credentials
✅ **Maintainable** - Standard structure for all clusters
✅ **Reproducible** - Easy to clone for new teams

---

## Success Metrics

- ⏱️ Provisioning time awareness (estimated vs actual)
- 📊 Real-time visibility of 10+ concurrent provisions
- 🎯 100% of developers use Backstage card vs Slack/tickets
- ✅ 0% confused about cluster deletion (staging vs dev)
- 🚀 Time to first kubectl command: < 5 minutes after completion

---

## Next Steps

1. **Review design** with your team
2. **Prioritize phases** - Start with Foundation
3. **Allocate resources** - Estimate 4 weeks for full implementation
4. **Set up infrastructure** - Backend APIs, WebSocket server
5. **Begin Phase 1** - GitHub repo creation in template

Would you like me to start implementing this solution? I can begin with:
1. **Phase 1a**: Enhanced template to create cluster-specific GitHub repo
2. **Phase 1b**: Initialize GitHub Actions workflows
3. **Phase 1c**: Backstage catalog entity updates

Should I proceed?
