# Template Enhancement Testing Guide

## Overview
This guide provides comprehensive testing recommendations for all 4 IDP templates and their new features (output links, GitHub Actions workflows, score.yaml, provisioning cards).

---

## Phase 1: Pre-Testing Setup

### 1.1 Verify Local Environment
```bash
# Check all services are running
lsof -i :3000    # Backstage frontend
lsof -i :7007    # Backstage backend
lsof -i :8080    # ArgoCD
lsof -i :5432    # PostgreSQL (if applicable)

# Verify Docker is running
docker ps | grep -E "backstage|argocd|kind"

# Check Kind cluster
kubectl cluster-info
kubectl get nodes
```

### 1.2 Validate GitHub Configuration
```bash
# Test GitHub App connection
curl -s http://localhost:7007/api/auth/github/status | jq .

# Verify GitHub token
echo $GITHUB_TOKEN | wc -c  # Should be > 10

# Test GitHub CLI
gh auth status
gh repo view nimishmehta8779/idp-gitops
```

### 1.3 Clear Stale Data
```bash
# Clean Backstage PostgreSQL (optional - if you want fresh state)
# docker exec backstage-db psql -U backstage -d backstage -c "DELETE FROM entities;"

# Clear template cache (if applicable)
rm -rf ~/.backstage/cache/*
```

---

## Phase 2: Template 1 - new-service

### Test 2.1: Create Service via UI

**Steps:**
1. Navigate to http://localhost:3000/create
2. Select "Create New Backend Service" template
3. Fill in form:
   - Service Name: `test-api-service`
   - Description: `Test service for validating template enhancements`
   - Owner: `platform-team`
   - Language: `nodejs`
   - Repository Name: `test-api-service` (auto-filled)
4. Click "Create"

**Expected Results:**
- ✅ Template renders successfully
- ✅ Skeleton files downloaded with templating applied
- ✅ "Open in Catalog" link appears in output
- ✅ "View GitHub repo" link appears
- ✅ "CI/CD Pipeline" link appears
- ✅ All links have correct localhost:3000 and localhost:8080 ports

**Verify Output Links:**
```bash
# Check if the output section shows all three links
# Screenshot the template output screen
# Verify URLs:
# - Open in Catalog: http://localhost:3000/catalog/default/component/test-api-service
# - View GitHub repo: https://github.com/nimishmehta8779/test-api-service
# - CI/CD Pipeline: https://github.com/nimishmehta8779/test-api-service/actions
```

### Test 2.2: Verify GitHub Repository Created

**Steps:**
```bash
# Check GitHub repo exists
gh repo view nimishmehta8779/test-api-service

# Verify file structure
gh repo view nimishmehta8779/test-api-service --json nameWithOwner,files

# Clone and verify files
git clone https://github.com/nimishmehta8779/test-api-service /tmp/test-repo
cd /tmp/test-repo
ls -la
```

**Expected Files:**
- ✅ `score.yaml` exists
- ✅ `score-overrides.dev.yaml` exists
- ✅ `.score/README.md` exists
- ✅ `catalog-info.yaml` with score annotations
- ✅ `.github/workflows/init-setup.yaml`
- ✅ `.github/workflows/initial-config.yaml`
- ✅ `.github/workflows/ci.yaml` with validate-score job
- ✅ `README.md`, `Dockerfile`, `package.json`

### Test 2.3: Verify score.yaml Content

**Steps:**
```bash
# Check score.yaml structure
cd /tmp/test-repo
cat score.yaml | head -20

# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('score.yaml'))"

# Check required fields
grep -E "apiVersion|metadata|containers" score.yaml
```

**Expected:**
- ✅ `apiVersion: score.dev/v1b1`
- ✅ Contains `metadata.name: test-api-service`
- ✅ Has `containers.main` section
- ✅ Contains `livenessProbe` and `readinessProbe`
- ✅ Has resource requests/limits
- ✅ score-overrides.dev.yaml exists with LOG_LEVEL: debug

### Test 2.4: Verify GitHub Actions Workflows

**Steps:**
```bash
# Check init-setup.yaml content
cat /tmp/test-repo/.github/workflows/init-setup.yaml | grep -A 5 "branch protection"
cat /tmp/test-repo/.github/workflows/init-setup.yaml | grep -A 5 "standard labels"
cat /tmp/test-repo/.github/workflows/init-setup.yaml | grep ".initialized"

# Check initial-config.yaml
cat /tmp/test-repo/.github/workflows/initial-config.yaml | grep "score.yaml"

# Check ci.yaml has validate-score
cat /tmp/test-repo/.github/workflows/ci.yaml | grep -A 10 "validate-score"
```

**Expected:**
- ✅ init-setup.yaml has all required steps
- ✅ Branch protection configured for main
- ✅ Standard labels (bug, enhancement, security, etc.) defined
- ✅ .initialized flag check implemented
- ✅ initial-config.yaml validates score.yaml
- ✅ ci.yaml has validate-score job with score-k8s validation

### Test 2.5: Trigger GitHub Actions

**Steps:**
```bash
# Wait for GitHub Actions to run automatically (first push)
# OR manually trigger
gh workflow run init-setup.yaml --repo nimishmehta8779/test-api-service

# Check workflow status
gh run list --repo nimishmehta8779/test-api-service --limit 5

# View specific run
gh run view <RUN_ID> --repo nimishmehta8779/test-api-service --log
```

**Expected:**
- ✅ init-setup.yaml runs successfully
- ✅ Branch protection is applied (verify in GitHub UI)
- ✅ Labels are created (check in GitHub Issues page)
- ✅ Welcome issue #1 is created with checklist
- ✅ .github/.initialized file is created
- ✅ initial-config.yaml runs after init-setup.yaml

**Verify in GitHub UI:**
1. Go to https://github.com/nimishmehta8779/test-api-service
2. Settings → Branches → Branch protection rules
   - ✅ Should have main branch protection
   - ✅ Require 1 approval
   - ✅ Status checks: ci, security
3. Issues tab
   - ✅ Issue #1 "🚀 Service onboarding checklist" exists
4. Labels section
   - ✅ bug, enhancement, security, dependencies, etc.

### Test 2.6: Verify Catalog Integration

**Steps:**
```bash
# Wait for Backstage to index the new entity (2-3 seconds)
sleep 3

# Check if component is registered
curl -s http://localhost:7007/api/catalog/entities?filter=kind=component | jq '.[] | select(.metadata.name=="test-api-service")'

# Verify annotations
curl -s http://localhost:7007/api/catalog/entities/component/default/test-api-service | jq '.metadata.annotations'
```

**Expected:**
- ✅ Component registered in catalog
- ✅ `score.dev/workload-spec: score.yaml` annotation present
- ✅ `score.dev/spec-version: v1b1` annotation present
- ✅ `idp.platform.io/score-validated: "true"` annotation present

**Verify in Backstage UI:**
1. Go to http://localhost:3000/catalog
2. Search for `test-api-service`
3. Click on the component
   - ✅ Overview tab shows entity details
   - ✅ GitHub link works
   - ✅ TechDocs visible (if README.md exists)
4. Click "Open in Catalog" link from template output
   - ✅ Should redirect to http://localhost:3000/catalog/default/component/test-api-service

### Test 2.7: Test CI Pipeline

**Steps:**
```bash
# Create a PR to trigger CI
cd /tmp/test-repo
git checkout -b test/add-feature
echo "# New Feature" >> README.md
git add README.md
git commit -m "docs: add new feature section"
git push origin test/add-feature

# Open PR via GitHub CLI
gh pr create --title "Test CI Pipeline" --body "Testing CI with validate-score job"
```

**Expected in GitHub Actions:**
- ✅ CI workflow runs
- ✅ Language-specific build runs (nodejs: npm ci, npm lint, npm test)
- ✅ validate-score job runs
- ✅ validate-score installs score-k8s
- ✅ validate-score validates score.yaml syntax
- ✅ validate-score checks for required fields
- ✅ All jobs pass (or fail appropriately if score.yaml has issues)

**Verify via UI:**
1. Go to https://github.com/nimishmehta8779/test-api-service/actions
2. Click on the PR workflow run
3. Check "validate-score" job output
   - ✅ "score-k8s init" runs
   - ✅ "score-k8s generate" runs
   - ✅ "✅ score.yaml is valid" message appears

### Test 2.8: Test score.yaml Validation with Error

**Steps:**
```bash
# Intentionally break score.yaml
cd /tmp/test-repo
git checkout test/add-feature
cat > score.yaml << 'EOF'
# Broken score.yaml - missing apiVersion
metadata:
  name: test-api-service
containers:
  main:
    image: placeholder
EOF

git add score.yaml
git commit -m "test: break score.yaml to verify CI validation"
git push origin test/add-feature
```

**Expected:**
- ✅ CI validate-score job FAILS
- ✅ Error message: "score.yaml apiVersion must be score.dev/v1b1"
- ✅ PR shows red X on validate-score check
- ✅ Branch protection prevents merge

**Fix it:**
```bash
# Restore score.yaml
git checkout HEAD~1 score.yaml
git add score.yaml
git commit -m "test: fix score.yaml validation"
git push origin test/add-feature
```

---

## Phase 3: Template 2 - eks-cluster

### Test 3.1: Create EKS Cluster (Dev)

**Steps:**
1. Navigate to http://localhost:3000/create
2. Select "Request EKS Cluster" template
3. Fill in form:
   - Team Name: `team-alpha`
   - Cluster Name: `alpha-dev-test-01` (matches pattern)
   - Environment: `dev`
   - AWS Region: `us-east-1`
   - Node Count: `2`
   - Instance Type: `t3.medium`
   - Kubernetes Version: `1.34`
4. Click "Create"

**Expected Results:**
- ✅ "Open in Catalog" link
- ✅ "ArgoCD sync status" link (port 8080)
- ✅ "GitOps claim" link to team-alpha-infra repo
- ✅ "Track provisioning" link (same as Catalog)
- ✅ All links use correct ports (3000 for Backstage, 8080 for ArgoCD)

### Test 3.2: Verify GitOps Files Created

**Steps:**
```bash
# Check team-alpha-infra repo
gh repo view nimishmehta8779/team-alpha-infra

# Verify claim files
gh api repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml | jq '.content' | base64 -d | head -20

gh api repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01-catalog.yaml | jq '.content' | base64 -d | head -20
```

**Expected:**
- ✅ EKS claim file: `eks/alpha-dev-test-01.yaml`
- ✅ Catalog file: `eks/alpha-dev-test-01-catalog.yaml`
- ✅ Both files have correct team/cluster/env values

### Test 3.3: Verify score.yaml in Skeleton

**Steps:**
```bash
# Check if score.yaml exists in eks-cluster skeleton
ls -la /Users/nm/devel/idp/development/templates/eks-cluster/skeleton/score.yaml

# Verify content
cat /Users/nm/devel/idp/development/templates/eks-cluster/skeleton/score.yaml | grep -E "cluster-name|kubernetes-cluster|nodeCount"
```

**Expected:**
- ✅ `score.yaml` exists
- ✅ Contains infrastructure workload spec
- ✅ Has `kubernetes-cluster` type
- ✅ Contains cluster annotations

### Test 3.4: Verify Catalog Integration

**Steps:**
```bash
# Wait for Backstage to sync
sleep 3

# Check if resource is registered
curl -s http://localhost:7007/api/catalog/entities?filter=kind=resource | jq '.[] | select(.metadata.name=="alpha-dev-test-01")'

# Check annotations
curl -s http://localhost:7007/api/catalog/entities/resource/default/alpha-dev-test-01 | jq '.metadata.annotations'
```

**Expected:**
- ✅ Resource registered
- ✅ `score.dev/workload-spec: score.yaml` annotation
- ✅ `score.dev/spec-type: infrastructure` annotation
- ✅ `idp.platform.io/cluster-name`, `aws-region`, `node-count` annotations

**Verify in Backstage UI:**
1. Go to http://localhost:3000/catalog?filters=kind:resource
2. Find `alpha-dev-test-01`
3. Click on it
   - ✅ Overview shows resource details
   - ✅ GitOps claim link works
   - ✅ ArgoCD link works (http://localhost:8080)

### Test 3.5: Test Provisioning Cards (if implemented in EntityPage)

**Steps:**
1. Open cluster resource in Backstage
2. Check Overview tab
   - ✅ "Provisioning Details" card should appear (if implemented)
   - ✅ Shows cluster-status, node-count, instance-type, aws-region, monthly-cost
   - ✅ "Provisioning Timeline" card should appear
   - ✅ Shows created-at, status with color coding

**Note:** Cards will only appear if EntityPage.tsx is updated to include them. Implementation pending.

### Test 3.6: Verify ArgoCD Sync

**Steps:**
```bash
# Check ArgoCD application
argocd app get team-alpha-eks-clusters

# Check sync status
argocd app sync team-alpha-eks-clusters --dry-run

# Verify Kind cluster gets the resource
kubectl get xekscluster -n crossplane-system
```

**Expected:**
- ✅ ArgoCD application exists for team-alpha
- ✅ Application shows synced status
- ✅ XEKSCluster custom resource appears in Kind cluster
- ✅ Crossplane controller watches for it

### Test 3.7: Test Staging Cluster Request

**Steps:**
1. Repeat Test 3.1 but:
   - Environment: `staging`
   - Cluster Name: `alpha-staging-test-01`
2. Should trigger PR instead of direct commit

**Expected:**
- ✅ PR created in team-alpha-infra repo
- ✅ PR title includes cluster name and team
- ✅ PR description shows checklist for platform team
- ✅ "View Decommission Pull Request" link in output
- ✅ No "Open in Catalog" until PR is merged

**Verify in GitHub:**
1. Go to https://github.com/nimishmehta8779/team-alpha-infra/pulls
2. Should see PR for alpha-staging-test-01
3. PR has labels: `cluster-request`, `needs-review`

---

## Phase 4: Template 3 - decommission-cluster

### Test 4.1: Decommission Dev Cluster

**Steps:**
1. Navigate to http://localhost:3000/create
2. Select "Decommission EKS Cluster" template
3. Fill in form:
   - Team Name: `team-alpha`
   - Cluster Name: (picker should show `alpha-dev-test-01`)
   - Environment: `dev`
   - Confirm Cluster Name: `alpha-dev-test-01`
   - Decommission Reason: `Consolidating to shared cluster for cost savings`
   - Cost Saving: `$144/month`
4. Click "Create"

**Expected:**
- ✅ "Decommission audit record" link
- ✅ "ArgoCD pruning status" link
- ✅ "Verify AWS cleanup" link

### Test 4.2: Verify Files Deleted

**Steps:**
```bash
# Check team-alpha-infra repo
# Files should be deleted (not present on main)
gh api repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml \
  2>&1 | grep -q "404" && echo "✅ Cluster claim deleted" || echo "❌ Still exists"

# Check GitOps commit message
gh api repos/nimishmehta8779/team-alpha-infra/commits/main | jq '.[] | select(.commit.message | contains("decommission"))' | head -1
```

**Expected:**
- ✅ Cluster claim file deleted from main
- ✅ Commit message includes decommission reason
- ✅ ArgoCD auto-syncs and removes resource

### Test 4.3: Verify Audit Record

**Steps:**
```bash
# Check decommission record in idp-gitops
gh api repos/nimishmehta8779/idp-gitops/contents/gitops/decommission-records/team-alpha/alpha-dev-test-01.md | jq '.content' | base64 -d

# Check audit issue
gh issue list --repo nimishmehta8779/idp-gitops | grep -i "decommissioned"
```

**Expected:**
- ✅ Audit record exists with timestamp
- ✅ Record includes reason, cost saving, environment
- ✅ GitHub issue created with `decommission-audit` label
- ✅ Issue shows checklist for cleanup

---

## Phase 5: Template 4 - onboard-team

### Test 5.1: Onboard New Team

**Steps:**
1. Navigate to http://localhost:3000/create
2. Select "Onboard Team" template
3. Fill in form:
   - Team Name: `team-delta` (matches pattern `team-[a-z]+`)
   - Display Name: `Delta Engineering Team`
   - Team Email: `delta@company.com`
   - Cost Center: `CC-4001`
   - Members: `alice, bob, nimishmehta8779` (comma-separated)
   - Primary AWS Region: `us-east-1`
4. Click "Create"

**Expected:**
- ✅ "Open Team in Catalog" link (http://localhost:3000/catalog/default/group/team-delta)
- ✅ "Team infra repo" link (GitHub)
- ✅ "Platform onboarding issue" link

### Test 5.2: Verify Team Infra Repository

**Steps:**
```bash
# Check repo created
gh repo view nimishmehta8779/team-delta-infra

# Verify directory structure
gh api repos/nimishmehta8779/team-delta-infra/contents | jq '.[] | .name' | grep -E "eks|rds|s3|ec2"

# Verify score.yaml
gh api repos/nimishmehta8779/team-delta-infra/contents/score.yaml | jq '.content' | base64 -d | head -10
```

**Expected:**
- ✅ `team-delta-infra` repo created (private)
- ✅ Directory structure: eks, rds, s3, ec2, opensearch, elasticache
- ✅ `score.yaml` exists with platform quota spec
- ✅ `catalog-info.yaml` exists with Group entity

### Test 5.3: Verify GitHub Actions Init

**Steps:**
```bash
# Check init-setup.yaml exists
gh api repos/nimishmehta8779/team-delta-infra/contents/.github/workflows/init-setup.yaml | jq '.content' | base64 -d | head -10

# Check workflow ran
gh run list --repo nimishmehta8779/team-delta-infra --limit 3
```

**Expected:**
- ✅ init-setup.yaml workflow file exists
- ✅ Workflow has run (check GitHub Actions tab)
- ✅ Branch protection applied (Settings → Branches)
- ✅ Infrastructure labels created
- ✅ Onboarding issue #1 created

**Verify in GitHub:**
1. Go to https://github.com/nimishmehta8779/team-delta-infra/settings/branches
   - ✅ main branch has protection
   - ✅ Requires validate-claims check
2. Issues tab
   - ✅ Issue about infra repo ready
3. Labels section
   - ✅ cluster-request, cluster-decommission, policy-violation labels

### Test 5.4: Verify Catalog Integration

**Steps:**
```bash
# Wait for indexing
sleep 3

# Check Group is registered
curl -s http://localhost:7007/api/catalog/entities?filter=kind=group | jq '.[] | select(.metadata.name=="team-delta")'

# Check annotations
curl -s http://localhost:7007/api/catalog/entities/group/default/team-delta | jq '.metadata.annotations'
```

**Expected:**
- ✅ Group registered
- ✅ `score.dev/workload-spec: score.yaml` annotation
- ✅ `score.dev/spec-type: platform-quota` annotation
- ✅ Cost center, region, onboarded-at annotations present

**Verify in Backstage UI:**
1. Go to http://localhost:3000/catalog?filters=kind:group
2. Find `team-delta`
3. Click on it
   - ✅ Profile shows Display Name, Email
   - ✅ Members: alice, bob, nimishmehta8779
   - ✅ Links to infra repo work
4. Click "Open Team in Catalog" from template output
   - ✅ Should navigate to correct URL

### Test 5.5: Verify ArgoCD ApplicationSet Registration

**Steps:**
```bash
# Check ApplicationSet includes new team
argocd appset get team-infra-appset

# Verify team-delta entry
kubectl get applicationset -A | grep team-infra

# Check team-delta-infra AppProject created
argocd appproject get team-delta-infra
```

**Expected:**
- ✅ team-delta entry in ApplicationSet
- ✅ AppProject created for team-delta-infra
- ✅ ApplicationSet controller generates app for team-delta-eks-clusters

---

## Phase 6: Cross-Template Validation

### Test 6.1: Catalog Hygiene Script

**Steps:**
```bash
# Run catalog hygiene check
cd /Users/nm/devel/idp
bash scripts/catalog-hygiene.sh

# Check output for any missing score.yaml annotations
bash scripts/catalog-hygiene.sh | grep -i "score"
```

**Expected:**
- ✅ No errors for test-api-service (has score.yaml annotation)
- ✅ No errors for alpha-dev-test-01 (has score.yaml annotation)
- ✅ No errors for team-delta (has score.yaml annotation)
- ✅ All entities have valid owners

**Verify GitHub Integration:**
1. Check nimishmehta8779/idp-gitops issues
2. Should see "[Catalog Hygiene] Findings" issue
   - ✅ Shows recent scan status

### Test 6.2: TechDocs Score Section

**Steps:**
1. Go to http://localhost:3000/docs
2. Find "Score Workload Specification" section in getting-started.md
3. Verify content includes:
   - ✅ What is Score?
   - ✅ Score in the IDP
   - ✅ Key Files (score.yaml, score-overrides.dev.yaml, .score/README.md)
   - ✅ Generating Manifests (score-compose, score-k8s)
   - ✅ Catalog Annotations
   - ✅ Link to score.dev docs

### Test 6.3: Verify All Catalog Annotations

**Steps:**
```bash
# Check new-service template has annotations
cat /Users/nm/devel/idp/development/templates/new-service/skeleton/catalog-info.yaml | grep "score.dev"

# Check eks-cluster template
cat /Users/nm/devel/idp/development/templates/eks-cluster/skeleton/catalog-info.yaml | grep "score.dev"

# Check onboard-team template
cat /Users/nm/devel/idp/development/templates/onboard-team/skeleton/catalog-info.yaml | grep "score.dev"
```

**Expected:**
- ✅ new-service: `score.dev/workload-spec`, `score.dev/spec-version`, `idp.platform.io/score-validated`
- ✅ eks-cluster: `score.dev/workload-spec`, `score.dev/spec-type: infrastructure`
- ✅ onboard-team: `score.dev/workload-spec`, `score.dev/spec-type: platform-quota`

---

## Phase 7: Edge Cases & Error Handling

### Test 7.1: Invalid score.yaml

**Steps:**
```bash
# Create a service with intentionally bad score.yaml
cd /tmp
git clone https://github.com/nimishmehta8779/test-api-service test-bad-service
cd test-bad-service

# Break score.yaml
cat > score.yaml << 'EOF'
bad: yaml: format: here
EOF

git add score.yaml
git commit -m "test: invalid score.yaml"
git push origin main
```

**Expected:**
- ✅ CI workflow fails at validate-score
- ✅ Error message visible in GitHub Actions logs
- ✅ Branch protection prevents merge if it were a PR

### Test 7.2: Missing Cluster Owner

**Steps:**
```bash
# Try to decommission non-existent cluster
# In template UI, try to select a cluster that doesn't exist
# Should show empty picker or error
```

**Expected:**
- ✅ EntityPicker shows only existing clusters owned by selected team
- ✅ If no clusters exist, picker is empty with helpful message

### Test 7.3: Team Name Pattern Validation

**Steps:**
1. Try to onboard team with invalid name:
   - `Team-Alpha` (uppercase)
   - `team_alpha` (underscore)
   - `alpha` (missing `team-` prefix)

**Expected:**
- ✅ Form validation fails
- ✅ Error message: "Must match pattern ^team-[a-z]+$"

### Test 7.4: Cluster Name Pattern Validation

**Steps:**
1. Try to create EKS cluster with invalid name:
   - `alpha-dev-test` (missing index)
   - `alpha-dev-test-001` (3-digit index)
   - `ALPHA-DEV-TEST-01` (uppercase)

**Expected:**
- ✅ Form validation fails
- ✅ Error message: "Required format: <team>-<env>-<purpose>-<index>"

---

## Phase 8: Performance & Load Testing

### Test 8.1: Backstage Entity Indexing

**Steps:**
```bash
# Create multiple services to test indexing performance
for i in {1..5}; do
  # Create service via API (if endpoint exists) or UI
  # Or use test data
done

# Monitor indexing time
time curl -s http://localhost:7007/api/catalog/entities | jq '.[] | length'

# Check database performance
docker logs backstage-db | grep "slow"
```

**Expected:**
- ✅ Entities indexed within 2-3 seconds
- ✅ No slow queries logged

### Test 8.2: GitHub Actions Parallelization

**Steps:**
1. Create PR to test-api-service
2. Check CI workflow execution
3. Verify validate-score runs in parallel with build-and-test

**Expected:**
- ✅ Jobs run in parallel (both start around same time)
- ✅ Total workflow time is ~max(build-and-test, validate-score)
- ✅ Not ~build-and-test + validate-score time

---

## Phase 9: Integration Testing

### Test 9.1: End-to-End: Create Service → CI → Catalog → Provision Resource

**Steps:**
1. Create new-service (test-full-e2e-service)
2. Push initial commit
3. Wait for init-setup.yaml to run
4. Verify component in catalog
5. Create EKS cluster for team
6. Link service to cluster in dependencies
7. Verify relationship in catalog

**Expected:**
- ✅ All steps complete without errors
- ✅ Catalog shows correct relationships
- ✅ All links work and use correct ports

### Test 9.2: End-to-End: Onboard Team → Create Cluster → Decommission

**Steps:**
1. Onboard new team (team-epsilon)
2. Create dev cluster (epsilon-dev-general-01)
3. Wait for resource to appear in catalog
4. Decommission cluster
5. Verify audit record created

**Expected:**
- ✅ All steps succeed
- ✅ Audit trail complete in idp-gitops
- ✅ GitHub issues created for tracking

---

## Phase 10: Documentation Verification

### Test 10.1: score.yaml README in Templates

**Steps:**
```bash
# Check each template has .score/README.md
test -f /Users/nm/devel/idp/development/templates/new-service/skeleton/.score/README.md && echo "✅ new-service .score/README.md"

# Verify content
cat /Users/nm/devel/idp/development/templates/new-service/skeleton/.score/README.md | grep -i "docker-compose\|kubernetes"
```

**Expected:**
- ✅ File exists
- ✅ Contains instructions for score-compose and score-k8s
- ✅ Explains how platform uses score.yaml
- ✅ Links to score.dev documentation

### Test 10.2: TechDocs Content

**Steps:**
1. Go to http://localhost:3000/docs
2. Navigate to "Score Workload Specification" section
3. Verify all subsections visible:
   - What is Score?
   - Score in the IDP
   - Key Files
   - Generating Manifests
   - Catalog Annotations

**Expected:**
- ✅ All sections visible and properly formatted
- ✅ Code blocks are readable
- ✅ Links to external docs work

---

## Testing Checklist Summary

### Phase 1: Pre-Testing
- [ ] All services running (Backstage, ArgoCD, Kind, etc.)
- [ ] GitHub configuration verified
- [ ] Local environment clean

### Phase 2: new-service Template
- [ ] Template UI loads
- [ ] Output links appear (3 links)
- [ ] GitHub repo created with all files
- [ ] score.yaml is valid
- [ ] GitHub Actions workflows exist and run
- [ ] Component registered in catalog
- [ ] CI pipeline validates score.yaml

### Phase 3: eks-cluster Template
- [ ] Template UI loads
- [ ] Output links appear (4 links with correct ports)
- [ ] GitOps files created in team repo
- [ ] score.yaml exists in skeleton
- [ ] Resource registered in catalog
- [ ] Catalog cards display (if implemented)
- [ ] ArgoCD application syncs

### Phase 4: decommission-cluster Template
- [ ] Template UI loads
- [ ] Cluster picker shows existing clusters
- [ ] Files deleted from team repo
- [ ] Audit record created
- [ ] GitHub issue created

### Phase 5: onboard-team Template
- [ ] Template UI loads
- [ ] Output links appear (3 links)
- [ ] Team infra repo created
- [ ] Directory structure created
- [ ] GitHub Actions runs
- [ ] Group registered in catalog
- [ ] ArgoCD ApplicationSet updated

### Phase 6: Cross-Template
- [ ] Catalog hygiene script runs successfully
- [ ] No missing score.yaml annotations
- [ ] TechDocs renders score section
- [ ] All catalog annotations present

### Phase 7: Error Handling
- [ ] Invalid score.yaml caught by CI
- [ ] Name pattern validation works
- [ ] Missing owner caught by hygiene
- [ ] Non-existent clusters show as unavailable

### Phase 8: Performance
- [ ] Entity indexing < 3 seconds
- [ ] GitHub Actions parallelization works
- [ ] No performance regressions

### Phase 9: Integration
- [ ] Full end-to-end flows work
- [ ] All links use correct ports (3000, 8080, 7007)
- [ ] Relationships in catalog correct

### Phase 10: Documentation
- [ ] .score/README.md exists in skeletons
- [ ] TechDocs score section complete
- [ ] All external links work

---

## Port Reference

When testing, verify these ports are correct:
- **Backstage Frontend**: http://localhost:3000 ✅ Used in all output links
- **Backstage Backend**: http://localhost:7007 ✅ Used by APIs and catalog registration
- **ArgoCD**: http://localhost:8080 ✅ Used for ArgoCD sync status links
- **PostgreSQL**: localhost:5432 (internal)

---

## Troubleshooting Common Issues

### Issue: "Open in Catalog" link shows 404

**Solution:**
```bash
# Verify entity was indexed
curl -s http://localhost:7007/api/catalog/entities | jq '.[] | select(.metadata.name=="SERVICE_NAME")'

# If not found, wait 3 seconds and retry (indexing delay)
# Or check Backstage logs
docker logs backstage-backend | grep -i "catalog"
```

### Issue: GitHub Actions workflow doesn't run

**Solution:**
```bash
# Check GitHub App permissions
# Verify .github/workflows/*.yaml files are valid YAML
yamllint .github/workflows/init-setup.yaml

# Check GitHub App has workflow permission
gh api apps/nimishmehta8779/installations
```

### Issue: ArgoCD links return 404

**Solution:**
```bash
# Verify ArgoCD is running
curl -s http://localhost:8080/api/version | jq .

# Check application exists
argocd app list | grep team-alpha
```

### Issue: score.yaml validation fails in CI

**Solution:**
```bash
# Test score-k8s locally
score-k8s init
score-k8s generate score.yaml --image test:latest

# Check error message in GitHub Actions logs
gh run view <RUN_ID> --repo REPO --log
```

---

## Success Criteria

After completing all tests:
- ✅ All 4 templates work end-to-end
- ✅ Output links appear and use correct ports
- ✅ GitHub Actions workflows run automatically
- ✅ score.yaml validation prevents invalid specs
- ✅ Catalog shows all entities with correct annotations
- ✅ Provisioning cards display (if implemented)
- ✅ Audit trails complete in idp-gitops
- ✅ TechDocs documentation is accurate
- ✅ No regressions in existing functionality
- ✅ Performance acceptable (< 5s for e2e operations)
