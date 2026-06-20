# EKS Configuration — FROZEN (2026-06-20)

**Status:** ✅ COMPLETE — All EKS and EKS addon configurations are finalized and tested. No further template changes needed.

## Configuration Locked

### 1. EKS Cluster Base Configuration
**File:** `infrastructure/crossplane/eks/composition.yaml`

✅ **Access Control (Complete)**
- EKS cluster `accessConfig`:
  - `authenticationMode: API`
  - `bootstrapClusterCreatorAdminPermissions: true`
- Platform-admins break-glass AccessEntry:
  - `type: STANDARD`
  - `allowedNetworks: 0.0.0.0/0` (access from anywhere)
  - `principalArn: arn:aws:iam::{accountId}:role/idp-platform-admins`
- Platform-admins AccessPolicyAssociation:
  - `policyArn: arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy`

✅ **Networking**
- VPC + Subnets (public/private) provisioned via Crossplane
- EKS cluster in existing VPC reference
- Security groups configured for node groups

✅ **Node Group**
- Auto Scaling Group with configurable min/max capacity
- Latest EKS-optimized AMI
- IAM roles with EC2 permissions

✅ **Addons Infrastructure**
- OIDC provider auto-provisioned
- Account ID derived from cluster ARN (status field)
- IAM permissions boundaries set (dev/staging-specific)

### 2. EKS Addon Deployments
**File:** `infrastructure/argocd/appsets/eks-addons-appset.yaml`

#### Cluster Autoscaler
✅ **Chart Version:** 9.37.0 (stable)
✅ **IRSA:** Role created, pod service account annotated
✅ **No manual setup required**

#### External DNS
✅ **Chart Version:** 1.15.2 (fixed from broken 1.15.0)
✅ **IRSA:** Role created, pod service account annotated
✅ **DNS Zone:** Auto-detected from Route53
✅ **No manual setup required**

#### Velero (Backup/Restore)
✅ **Chart Version:** 12.0.0 (fixed from obsolete 7.2.1)
✅ **S3 Backup Storage:** Auto-provisioned per cluster (`{cluster}-velero-backups`)
  - Server-side encryption (AES256)
  - Public access blocked
  - Versioning enabled
✅ **EBS Volume Snapshots:** AWS plugin configured (v1.13.1)
✅ **IRSA:** Role with EC2 + S3 permissions, pod annotated
✅ **Backup Configuration:** BackupStorageLocation + VolumeSnapshotLocation fully configured
✅ **Zero manual setup:** Backups work immediately on cluster provisioning

#### EBS CSI Driver
✅ **Chart Version:** 2.x (AWS maintained)
✅ **Enabled by default** on all clusters
✅ **IRSA:** Role created, daemonset annotated
✅ **No additional config needed**

### 3. Infrastructure as Code
**Files:**
- `infrastructure/crossplane/providers/provider-aws-s3.yaml` — S3 bucket management
- `infrastructure/iam/boundaries/{dev,staging}-boundary.json` — IAM permission ceilings
- `infrastructure/scripts/setup-iam-roles.sh` — Idempotent role provisioning
- `infrastructure/scripts/setup-platform-admins-role.sh` — Break-glass admin role
- `infrastructure/scripts/migrate-cluster-access.sh` — Access entry migration tool

✅ **All scripts tested and idempotent**
✅ **IAM boundaries include S3 permissions** for velero bucket operations
✅ **All changes committed** to idp-gitops

### 4. ArgoCD Integration
**Files:**
- `infrastructure/argocd/projects/idp-platform-dev.yaml` — AppProject with CRD whitelist
- `infrastructure/argocd/appsets/team-infra-appset.yaml` — Team repo discovery
- AppSets auto-synced to registered clusters with label selectors

✅ **Private repos supported** — ArgoCD has GitHub token with `repo` scope
✅ **CRD whitelist added** — CustomResourceDefinition sync enabled
✅ **Automated addon deployment** — Triggered by cluster annotations

### 5. Backstage Integration
**File:** `infrastructure/backstage/app-config.yaml`

✅ **GitHub integration:** Token with `repo` + `workflow` scopes
✅ **Catalog discovery:** Auto-discovers `*-infra` repos (public or private)
✅ **Scaffolder:** Can create repos and push workflows
✅ **Works with private repos** — No additional setup needed

---

## What's NOT Needed Anymore

❌ **Manual EKS access entry commands** — AccessEntry created automatically
❌ **Manual S3 bucket creation** — Velero bucket provisioned per cluster
❌ **Manual Velero configuration** — BackupStorageLocation + VolumeSnapshotLocation configured
❌ **Manual IRSA setup** — All addon IAM roles created, pod annotations applied
❌ **Public repos requirement** — All `team*` repos are now PRIVATE, still discoverable
❌ **Further EKS template modifications** — All configurations complete

---

## Testing & Validation

✅ **Task B:** ArgoCD velero/external-dns sync failures fixed
  - external-dns: 1.15.0 → 1.15.2 (repo index corrected)
  - velero: 7.2.1 → 12.0.0 (chart upgraded, out-of-box functionality added)
  - Both applications: Synced/Healthy

✅ **Task A:** EKS access entries fully functional
  - Platform-admins role created with break-glass permissions
  - AccessEntry with 0.0.0.0/0 network scope allowing admin access
  - AccountId derivation from cluster ARN works
  - S3 bucket auto-provisioning confirmed (alpha-dev-general-1-velero-backups exists)

✅ **Infrastructure Security:**
  - All `team*` repos made PRIVATE
  - ArgoCD/Backstage configured for private repo access
  - No public exposure of internal cluster definitions

---

## Next Steps (Out of Scope)

- **Team cluster provisioning:** Use Backstage EKS template → auto-deploys with all addons
- **Monitoring/Observability:** Add Prometheus/Grafana as separate task
- **Multi-region expansion:** Repeat cluster provisioning in other regions
- **Addon version bumps:** Only after upstream Helm repo stability confirmed

---

## Modification Log

| Date       | Change                                                       | Status |
|------------|--------------------------------------------------------------|--------|
| 2026-06-20 | Freeze EKS composition, addons, and XRD configs              | ✅ DONE |
| 2026-06-20 | Fix velero/external-dns ArgoCD sync (Task B)                | ✅ DONE |
| 2026-06-20 | Complete EKS access entries (Task A)                        | ✅ DONE |
| 2026-06-20 | Make all team* repos private, validate tool access          | ✅ DONE |
| 2026-06-19 | Decommission alpha-dev-general-1 cluster                    | ✅ DONE |

---

**DO NOT MODIFY EKS/ADDON TEMPLATES WITHOUT EXPLICIT REQUIREMENTS**

If changes are needed, document the requirement, validate in dev, and update this file.
