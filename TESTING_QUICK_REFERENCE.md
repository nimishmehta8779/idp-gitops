# Testing Quick Reference Guide

## Run Automated Tests

```bash
cd /Users/nm/devel/idp
bash test-templates.sh
```

**Expected Output:** 26/26 tests pass ✅

---

## Test Each Template in 5 Minutes

### Template 1: new-service (5 min)
```bash
# 1. Go to Backstage
open http://localhost:3000/create

# 2. Select "Create New Backend Service"
# 3. Fill in:
#    - Service Name: test-api-svc
#    - Description: Test service
#    - Owner: platform-team
#    - Language: nodejs
# 4. Click Create

# 5. Verify output shows 3 links:
#    ✅ "Open in Catalog" → http://localhost:3000/catalog/...
#    ✅ "View GitHub repo" → https://github.com/nimishmehta8779/test-api-svc
#    ✅ "CI/CD Pipeline" → https://github.com/nimishmehta8779/test-api-svc/actions

# 6. Check GitHub repo
gh repo view nimishmehta8779/test-api-svc
ls -la /tmp/test-repo/.github/workflows/

# 7. Verify files
test -f /tmp/test-repo/score.yaml && echo "✅ score.yaml exists"
test -f /tmp/test-repo/.github/workflows/init-setup.yaml && echo "✅ init-setup.yaml exists"
```

**Checklist:**
- [ ] Template output shows 3 links with correct ports (3000, not 7007)
- [ ] GitHub repo created
- [ ] score.yaml exists with score.dev/v1b1
- [ ] init-setup.yaml & initial-config.yaml exist
- [ ] ci.yaml has validate-score job
- [ ] catalog-info.yaml has score.dev annotations

---

### Template 2: eks-cluster (5 min)
```bash
# 1. Go to Backstage Create
open http://localhost:3000/create

# 2. Select "Request EKS Cluster"
# 3. Fill in:
#    - Team Name: team-alpha
#    - Cluster Name: alpha-dev-test-01
#    - Environment: dev
#    - AWS Region: us-east-1
#    - Node Count: 2
#    - Instance Type: t3.medium
#    - K8s Version: 1.34
# 4. Click Create

# 5. Verify output shows 4 links with correct ports:
#    ✅ "Open in Catalog" → http://localhost:3000/catalog/...
#    ✅ "ArgoCD sync status" → http://localhost:8080/applications/...
#    ✅ "GitOps claim" → https://github.com/.../eks/alpha-dev-test-01.yaml
#    ✅ "Track provisioning" → http://localhost:3000/catalog/...

# 6. Verify files in team repo
gh api repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml | jq '.content' | base64 -d | head -10
```

**Checklist:**
- [ ] Template shows 4 output links
- [ ] All links use correct ports (3000, 8080)
- [ ] GitOps claim created in team-alpha-infra
- [ ] Resource appears in Backstage catalog
- [ ] score.yaml exists with kubernetes-cluster type
- [ ] Catalog annotations present (score.dev/spec-type: infrastructure)

---

### Template 3: decommission-cluster (3 min)
```bash
# 1. Go to Backstage Create
open http://localhost:3000/create

# 2. Select "Decommission EKS Cluster"
# 3. Fill in:
#    - Team Name: team-alpha
#    - Cluster Name: alpha-dev-test-01 (from picker)
#    - Environment: dev
#    - Confirm Name: alpha-dev-test-01
#    - Reason: Testing decommission workflow
#    - Cost Saving: $144
# 4. Click Create

# 5. Verify output shows 3 links:
#    ✅ "Decommission audit record" → GitHub link
#    ✅ "ArgoCD pruning status" → http://localhost:8080/...
#    ✅ "Verify AWS cleanup" → http://localhost:3000/catalog/...

# 6. Check files deleted
gh api repos/nimishmehta8779/team-alpha-infra/contents/eks/alpha-dev-test-01.yaml 2>&1 | grep -q "404" && echo "✅ Deleted"
```

**Checklist:**
- [ ] Template shows 3 output links
- [ ] All links use correct ports
- [ ] Cluster claim file deleted from team repo
- [ ] Audit record created in idp-gitops
- [ ] Decommission issue created in GitHub

---

### Template 4: onboard-team (5 min)
```bash
# 1. Go to Backstage Create
open http://localhost:3000/create

# 2. Select "Onboard Team"
# 3. Fill in:
#    - Team Name: team-delta
#    - Display Name: Delta Team
#    - Email: delta@company.com
#    - Cost Center: CC-4001
#    - Members: alice, bob, nimishmehta8779
#    - Primary Region: us-east-1
# 4. Click Create

# 5. Verify output shows 3 links:
#    ✅ "Open Team in Catalog" → http://localhost:3000/catalog/default/group/team-delta
#    ✅ "Team infra repo" → https://github.com/nimishmehta8779/team-delta-infra
#    ✅ "Platform onboarding issue" → GitHub issue

# 6. Verify repo structure
gh repo view nimishmehta8779/team-delta-infra
gh api repos/nimishmehta8779/team-delta-infra/contents | jq '.[] | .name'

# 7. Check score.yaml and init-setup.yaml
gh api repos/nimishmehta8779/team-delta-infra/contents/score.yaml
gh api repos/nimishmehta8779/team-delta-infra/contents/.github/workflows/init-setup.yaml
```

**Checklist:**
- [ ] Template shows 3 output links with correct ports (3000)
- [ ] Team infra repo created (private)
- [ ] Directory structure: eks, rds, s3, etc.
- [ ] score.yaml exists with platform-quota spec
- [ ] init-setup.yaml exists and runs
- [ ] Group registered in catalog
- [ ] Onboarding issue created
- [ ] catalog-info.yaml has score.dev annotations

---

## Verify Critical Features

### Score.yaml Validation in CI

```bash
# Create service and trigger CI
cd /tmp && git clone https://github.com/nimishmehta8779/test-api-svc
cd test-api-svc

# Break score.yaml to test validation
cat > score.yaml << 'EOF'
broken: yaml
EOF

git add score.yaml
git commit -m "test: break score.yaml"
git push origin main

# Check GitHub Actions - validate-score job should FAIL
gh run list --repo nimishmehta8779/test-api-svc --limit 1
```

**Expected:**
- ✅ validate-score job appears in workflow
- ✅ Job fails with clear error message
- ✅ Shows which fields are missing

---

### Catalog Hygiene Check

```bash
cd /Users/nm/devel/idp

# Run catalog hygiene script
bash scripts/catalog-hygiene.sh

# Should show no issues for new entities with score.yaml
```

**Expected:**
- ✅ All components with score.dev annotations pass
- ✅ No missing score.yaml warnings for new services
- ✅ GitHub issue updated with status

---

### Provisioning Cards (When Implemented)

1. Go to EKS resource in Backstage: http://localhost:3000/catalog/default/resource/alpha-dev-test-01
2. Overview tab should show:
   - ✅ "Provisioning Details" card with: status, node-count, instance-type, region, cost
   - ✅ "Provisioning Timeline" card with: created-at timestamp, status with color

---

## Verify Annotations

```bash
# Check new-service has annotations
curl -s http://localhost:7007/api/catalog/entities/component/default/test-api-service \
  | jq '.metadata.annotations | keys' | grep score

# Expected:
# "score.dev/spec-version"
# "score.dev/workload-spec"
# "idp.platform.io/score-validated"

# Check eks-cluster resource
curl -s http://localhost:7007/api/catalog/entities/resource/default/alpha-dev-test-01 \
  | jq '.metadata.annotations | keys' | grep score

# Expected:
# "score.dev/spec-type"
# "score.dev/workload-spec"

# Check team group
curl -s http://localhost:7007/api/catalog/entities/group/default/team-delta \
  | jq '.metadata.annotations | keys' | grep score

# Expected:
# "score.dev/spec-type"
# "score.dev/workload-spec"
```

---

## Test Template Output Links

```bash
# Verify ports in template.yaml files
grep "localhost" /Users/nm/devel/idp/development/templates/*/template.yaml

# Expected outputs:
# ✅ localhost:3000 for Backstage catalog links
# ✅ localhost:8080 for ArgoCD links
# ✅ NO 7007 in output links (that's backend only)
```

---

## Cleanup Test Repos (Optional)

```bash
# Delete test repos after testing
gh repo delete nimishmehta8779/test-api-service --confirm
gh repo delete nimishmehta8779/team-delta-infra --confirm

# Or keep them for regression testing
```

---

## Common Port Issues

**Problem:** "Link shows 7007 instead of 3000"

**Solution:**
```bash
# Check template.yaml uses localhost:3000
grep "localhost:3000" /Users/nm/devel/idp/development/templates/new-service/template.yaml
grep "localhost:7007" /Users/nm/devel/idp/development/templates/new-service/template.yaml

# Frontend: 3000
# Backend: 7007 (internal API only)
# ArgoCD: 8080
```

---

## Test Summary Table

| Template | Files Created | Workflows | Catalog | Checks | Notes |
|----------|-------|-----------|---------|--------|-------|
| new-service | score.yaml, .score/README.md, init-setup, initial-config | ci.yaml with validate-score | Component with score.dev annotations | ✅ All links 3000/8080 | Creates GitHub repo & issues |
| eks-cluster | score.yaml with kubernetes-cluster | None (direct GitOps) | Resource with infrastructure spec | ✅ ArgoCD sync, catalog, claims | GitOps-driven provisioning |
| decommission-cluster | None (deletes) | None | None (unregisters) | ✅ Audit record, GitHub issue | GitOps-driven cleanup |
| onboard-team | score.yaml with platform-quota, init-setup | init-setup for branch protection | Group with platform-quota spec | ✅ All repo structure, annotations | Creates team infra repo |

---

## Success Criteria Checklist

### All Templates
- [ ] Automated test script passes (26/26)
- [ ] All output links appear in template output
- [ ] All links use correct ports (3000 for Backstage, 8080 for ArgoCD)
- [ ] No links use port 7007 in output (internal backend only)

### new-service Template
- [ ] GitHub repo created with all files
- [ ] score.yaml valid and matches skeleton
- [ ] init-setup.yaml creates branch protection & labels
- [ ] initial-config.yaml validates score.yaml
- [ ] ci.yaml has validate-score job
- [ ] Component registered in catalog with annotations
- [ ] CI fails when score.yaml is invalid

### eks-cluster Template
- [ ] GitOps claim files created in team repo
- [ ] score.yaml has kubernetes-cluster type
- [ ] Resource registered in catalog
- [ ] ArgoCD syncs the claim
- [ ] Catalog shows provisioning details

### onboard-team Template
- [ ] Team infra repo created with directory structure
- [ ] score.yaml with platform-quota exists
- [ ] init-setup.yaml runs and creates labels
- [ ] Group registered in catalog
- [ ] ApplicationSet picks up new team

### Cross-Template
- [ ] Catalog hygiene finds no issues
- [ ] TechDocs score section renders
- [ ] All catalog annotations present
- [ ] Gallery of templates loads without errors

---

## Debug Commands

```bash
# Check Backstage logs
docker logs backstage-backend | grep -i "error\|catalog\|entity"

# Check ArgoCD status
argocd app list
argocd app get team-alpha-eks-clusters

# Check Kind cluster
kubectl get all -n crossplane-system
kubectl get xekscluster

# Check GitHub workflows
gh run list --repo <REPO> --limit 5
gh run view <RUN_ID> --log

# Check catalog entities
curl -s http://localhost:7007/api/catalog/entities | jq '.[] | {name: .metadata.name, kind: .kind}'
```

---

## Next Steps

1. **Run automated tests:** `bash test-templates.sh`
2. **Read full guide:** See `TESTING_RECOMMENDATIONS.md`
3. **Manual testing:** Follow Phase 2-5 in full guide
4. **Document results:** Note any issues or differences
5. **Fix & iterate:** Address any failures found

---

## Support

For more details on each test phase:
- See: `TESTING_RECOMMENDATIONS.md` (comprehensive guide)
- See: Individual template docs in `development/templates/*/README.md`
- See: `.score/README.md` in each template skeleton

Questions? Check:
- Backstage logs: `docker logs backstage-backend`
- GitHub Actions: `gh run view <ID> --log`
- ArgoCD: `argocd app get <APP_NAME>`
