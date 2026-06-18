# ${{ values.clusterName }} Cluster Infrastructure

**Cluster**: ${{ values.clusterName }}
**Team**: ${{ values.teamName }}
**Environment**: ${{ values.environment }}
**Region**: ${{ values.awsRegion }}

---

## 📊 Quick Status

- **Status**: Check Backstage for real-time status
- **Cluster Info**: [CLUSTER_INFO.md](./CLUSTER_INFO.md)
- **Add-on Status**: [ADDON_STATUS.md](./ADDON_STATUS.md)

---

## 🚀 Quick Start

### 1. Get Kubeconfig

**Option A: Download from GitHub**
```bash
gh run -R ${{ values.teamName }}/${{ values.clusterName }}-infra download <run-id> -n kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig.yaml
```

**Option B: Trigger Workflow**
```bash
gh workflow run get-kubeconfig.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra
```

**Option C: Use AWS CLI**
```bash
aws eks update-kubeconfig \
  --name ${{ values.clusterName }} \
  --region ${{ values.awsRegion }}
```

### 2. Verify Access

```bash
kubectl get nodes
kubectl get pods --all-namespaces
```

### 3. View Cluster Details

```bash
# View cluster information
cat CLUSTER_INFO.md

# View add-on status
cat ADDON_STATUS.md

# Check provisioning progress
gh run list -R ${{ values.teamName }}/${{ values.clusterName }}-infra
```

---

## 📁 Repository Structure

```
.
├── .github/
│   └── workflows/
│       ├── get-kubeconfig.yml         # Retrieve cluster credentials
│       ├── cluster-info.yml           # Display cluster details
│       ├── addon-status.yml           # Monitor add-ons
│       └── provisioning-status.yml    # Track provisioning progress
├── docs/
│   ├── README.md                      # This file
│   ├── CLUSTER_INFO.md                # Auto-generated cluster info
│   └── ADDON_STATUS.md                # Auto-generated add-on status
├── scripts/
│   ├── get-cluster-info.sh            # Local script to fetch info
│   └── test-access.sh                 # Test cluster access
└── .gitignore
```

---

## 🔧 GitHub Actions Workflows

### `get-kubeconfig.yml`
**Triggered**: Manual (on-demand)
**Purpose**: Securely retrieve cluster kubeconfig via OIDC authentication
**Output**: Kubeconfig artifact + base64 encoded output

```bash
gh workflow run get-kubeconfig.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra
```

### `cluster-info.yml`
**Triggered**: Manual or Hourly
**Purpose**: Gather and document cluster information
**Output**: Automatically updates CLUSTER_INFO.md

```bash
gh workflow run cluster-info.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra
```

### `addon-status.yml`
**Triggered**: Manual or Every 15 minutes
**Purpose**: Monitor add-on health and versions
**Output**: Automatically updates ADDON_STATUS.md

```bash
gh workflow run addon-status.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra
```

### `provisioning-status.yml`
**Triggered**: Manual or Every 5 minutes (during provisioning)
**Purpose**: Track real-time provisioning progress
**Output**: Status displayed in GitHub Actions summary

```bash
gh workflow run provisioning-status.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra
```

---

## 🔐 Security & Permissions

### GitHub Actions OIDC Role
- **Trust**: GitHub Actions (Federated)
- **Permissions**: EKS cluster access only
- **Scope**: Read-only for most operations
- **Credential**: Temporary STS tokens (no long-lived keys)

### Required Secrets
```yaml
AWS_ACCOUNT_ID: "123456789"  # Your AWS account ID
AWS_REGION: "${{ values.awsRegion }}"
SLACK_WEBHOOK_URL: "https://hooks.slack.com/..."  # Optional
```

---

## 📝 Available Operations

### View Cluster Info
```bash
# Trigger cluster-info workflow
gh workflow run cluster-info.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra

# View results
cat CLUSTER_INFO.md
```

### Check Add-on Status
```bash
gh workflow run addon-status.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra
cat ADDON_STATUS.md
```

### Get Kubeconfig
```bash
gh workflow run get-kubeconfig.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra

# Download artifact
gh run -R ${{ values.teamName }}/${{ values.clusterName }}-infra download <run-id> -n kubeconfig
```

### Monitor Provisioning
```bash
gh workflow run provisioning-status.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra

# Watch live
gh run watch -R ${{ values.teamName }}/${{ values.clusterName }}-infra <run-id>
```

---

## 🎯 Common Tasks

### Scale Node Group
```bash
aws eks update-nodegroup-config \
  --cluster-name ${{ values.clusterName }} \
  --nodegroup-name <nodegroup-name> \
  --scaling-config desiredSize=5 \
  --region ${{ values.awsRegion }}
```

### Deploy Application
```bash
# Get kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig.yaml

# Deploy using kubectl
kubectl apply -f your-app.yaml

# Or use Helm
helm install my-release my-chart \
  --kubeconfig=$(pwd)/kubeconfig.yaml
```

### Check Cluster Health
```bash
# View cluster events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# View node status
kubectl get nodes -o wide

# View pod status
kubectl get pods --all-namespaces
```

### Update Add-ons
```bash
aws eks update-addon \
  --cluster-name ${{ values.clusterName }} \
  --addon-name vpc-cni \
  --addon-version <version> \
  --region ${{ values.awsRegion }}
```

---

## 🔍 Troubleshooting

### Kubeconfig Not Working
```bash
# Re-download kubeconfig
gh workflow run get-kubeconfig.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra

# Verify AWS credentials
aws sts get-caller-identity

# Test cluster access
kubectl cluster-info dump
```

### Add-ons in Degraded State
```bash
# Check add-on details
aws eks describe-addon \
  --cluster-name ${{ values.clusterName }} \
  --addon-name <addon-name> \
  --region ${{ values.awsRegion }}

# View add-on logs
kubectl logs -n kube-system -l app=<addon-name>
```

### Provisioning Stuck
```bash
# Check provisioning status
gh workflow run provisioning-status.yml -R ${{ values.teamName }}/${{ values.clusterName }}-infra

# View Crossplane status
kubectl get xeksclusters

# Check cluster events
kubectl describe xeksclusters ${{ values.clusterName }} -n clusters-${{ values.environment }}
```

---

## 📚 Links

- [Backstage Catalog](http://localhost:3000/catalog/default/resource/${{ values.clusterName }})
- [AWS EKS Console](https://console.aws.amazon.com/eks/home?region=${{ values.awsRegion }}#/clusters/${{ values.clusterName }})
- [ArgoCD Applications](http://localhost:8080/applications/${{ values.teamName }}-eks-clusters)
- [GitHub Repository](https://github.com/${{ values.teamName }}/${{ values.clusterName }}-infra)

---

## 📞 Support

For issues or questions:

1. Check [CLUSTER_INFO.md](./CLUSTER_INFO.md) for cluster details
2. Check [ADDON_STATUS.md](./ADDON_STATUS.md) for add-on health
3. Review troubleshooting section above
4. Contact platform team in #platform-team Slack channel

---

*This cluster repository is automatically generated and managed by the IDP.*
