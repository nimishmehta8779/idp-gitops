# IDP Overview and Architecture

Welcome to the Internal Developer Platform (IDP). This platform enables developers to self-serve cloud infrastructure and backend templates following standard enterprise golden paths.

## Core Flow Architecture

The IDP implements a gitops-driven provisioning loop. Below is the workflow for creating and managing resources:

```
[ Backstage Portal ] (Developer requests EKS / Service)
       │
       ▼ (Scaffolder Template)
[ GitHub Repository ] (Manifests committed to GitOps repo)
       │
       ▼ (Webhook / Pull model)
[ ArgoCD GitOps Controller ] (Syncs Git state to Kubernetes Cluster)
       │
       ▼ (Reconciliation)
[ Crossplane Control Plane ] (Translates custom resources into AWS Provider requests)
       │
       ▼ (Cloud Provider API)
[ Amazon Web Services (AWS) ] (EKS, VPC, RDS, IAM, etc.)
```

### 1. Backstage (Developer Portal)
Developers interact with a single pane of glass to discover software catalog entities, run templates, and view system health. When a user requests a new service or resource (e.g., an EKS cluster), Backstage collects the specifications and generates the configuration files.

### 2. GitHub (Source of Truth)
Instead of provisioning resources directly, Backstage commits the generated manifests (Kubernetes Custom Resources) into the team's Git repository or central GitOps repository. This ensures that every change is tracked, auditable, and subject to pull request approvals.

### 3. ArgoCD (Continuous Delivery)
ArgoCD monitors the GitOps repository for configuration changes. When a new manifest is detected in Git, ArgoCD synchronizes it into the local Kind management cluster.

### 4. Crossplane (Infrastructure as Code)
Crossplane acts as the cloud infrastructure controller inside the cluster. It defines Compositions and Custom Resource Definitions (CRDs) that map abstract platform-level definitions (like `XEKSCluster`) to fine-grained AWS resources (like EKS clusters, NodeGroups, IAM roles, and VPCs). Crossplane continually reconciles the actual state in AWS with the desired state declared in Git.

### 5. AWS (Resource Execution)
Amazon Web Services processes the API requests sent by Crossplane, provisioned inside the enterprise security and network boundaries.
