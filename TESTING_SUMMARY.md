# Testing Recommendations Summary

## Overview

Three testing documents have been created to guide you through validating all template enhancements:

1. **`test-templates.sh`** — Automated validation (5 min)
2. **`TESTING_QUICK_REFERENCE.md`** — Quick manual testing (20 min per template)
3. **`TESTING_RECOMMENDATIONS.md`** — Comprehensive test plan (2-3 hours total)

---

## Testing Flow

```
START
  ↓
Run automated tests (test-templates.sh)
  ↓
  ├─ All pass? → Continue
  └─ Failures? → Fix issues, re-run
  ↓
Quick manual tests per template (QUICK_REFERENCE.md)
  ↓
  ├─ All pass? → Continue
  └─ Issues? → Debug, document
  ↓
Full comprehensive tests (TESTING_RECOMMENDATIONS.md)
  ↓
  ├─ All pass? → SUCCESS! ✅
  └─ Issues? → File issues, create follow-ups
```

---

## Getting Started: The 30-Minute Test Path

### Step 1: Run Automated Tests (5 min)
```bash
cd /Users/nm/devel/idp
bash test-templates.sh
```

**Expected:** `26 passed, 0 failed` ✅

### Step 2: Test new-service Template (5 min)
1. Go to http://localhost:3000/create
2. Select "Create New Backend Service"
3. Fill form: `test-api-svc`, nodejs, platform-team
4. Click Create
5. Verify output shows 3 links with correct URLs

**Key Checks:**
- ✅ Output shows "Open in Catalog" link
- ✅ Link uses `localhost:3000` (not 7007)
- ✅ GitHub repo created
- ✅ score.yaml exists with `score.dev/v1b1`

### Step 3: Test eks-cluster Template (5 min)
1. Go to http://localhost:3000/create
2. Select "Request EKS Cluster"
3. Fill: `alpha-dev-test-01`, team-alpha, dev, t3.medium x 2
4. Verify output shows 4 links (Catalog, ArgoCD, GitOps, Provisioning)

**Key Checks:**
- ✅ All 4 links appear
- ✅ ArgoCD link uses `localhost:8080`
- ✅ Catalog links use `localhost:3000`
- ✅ GitOps claim created in team repo

### Step 4: Test onboard-team Template (5 min)
1. Go to http://localhost:3000/create
2. Select "Onboard Team"
3. Fill: `team-delta`, Delta Team, delta@company.com
4. Verify output shows 3 links

**Key Checks:**
- ✅ Team infra repo created
- ✅ Directory structure exists (eks, rds, s3, etc.)
- ✅ score.yaml with platform-quota
- ✅ GitHub Actions init-setup runs

### Step 5: Decommission Test (5 min)
1. Go to http://localhost:3000/create
2. Select "Decommission EKS Cluster"
3. Select the cluster you just created
4. Confirm decommission

**Key Checks:**
- ✅ Cluster claim deleted
- ✅ Audit record created
- ✅ Issue created in idp-gitops

---

## Testing Matrix

### Quick Reference: What to Test

| Feature | Where to Test | Expected | Time |
|---------|---------------|----------|------|
| Output Links | Template output screen | 3-4 working links | 1 min |
| Port Numbers | Click links in browser | localhost:3000 & 8080 | 2 min |
| GitHub Files | `gh repo view` | score.yaml, workflows exist | 1 min |
| Catalog Entity | Navigate to catalog | Component/Resource/Group shows | 1 min |
| Annotations | API check | score.dev/* annotations | 1 min |
| CI Pipeline | GitHub Actions tab | validate-score job | 1 min |
| score.yaml | Cat file | Valid YAML structure | 1 min |

---

## Port Reference (Critical for Success)

```
Frontend/Catalog:     localhost:3000  ← Use in output links
Backstage Backend:    localhost:7007  ← Don't expose in output
ArgoCD UI:            localhost:8080  ← Use in ArgoCD links
```

**Common Error:** Links showing `localhost:7007` instead of `localhost:3000`
- **Fix:** Check template.yaml files use correct ports
- **Verify:** `grep "localhost" development/templates/*/template.yaml`

---

## Testing by Phase

### Phase 1: Files & Structure (10 min)
- ✅ score.yaml exists in all skeletons
- ✅ GitHub Actions workflows created
- ✅ Catalog annotations present
- ✅ React components exist

**Run:** `bash test-templates.sh`

### Phase 2: UI & Output (15 min)
- ✅ Template UI loads without errors
- ✅ Output shows correct links
- ✅ Links use correct ports
- ✅ Links navigate to correct pages

**Run:** Create each template in Backstage UI

### Phase 3: GitHub Integration (15 min)
- ✅ Repos created with correct files
- ✅ Workflows run automatically
- ✅ Branch protection configured
- ✅ Issues created with checklists

**Run:** Check GitHub repos and Actions

### Phase 4: Catalog Integration (10 min)
- ✅ Entities register in catalog
- ✅ Annotations are present
- ✅ Hygiene script passes
- ✅ TechDocs renders

**Run:** Query catalog API or browse UI

### Phase 5: Edge Cases (10 min)
- ✅ Invalid score.yaml fails CI
- ✅ Missing owner flagged by hygiene
- ✅ Pattern validation prevents bad names
- ✅ Non-existent clusters unavailable

**Run:** Intentionally break things, verify they fail correctly

---

## Success Criteria

### Minimum (Must Pass)
- ✅ Automated tests: 26/26 pass
- ✅ All 4 templates create without errors
- ✅ Output links appear in correct order
- ✅ All links use correct ports (3000, 8080, not 7007)
- ✅ GitHub repos created with score.yaml
- ✅ Catalog entities registered with score.dev annotations

### Recommended (Should Pass)
- ✅ GitHub Actions workflows run automatically
- ✅ CI validates score.yaml on PR
- ✅ Catalog hygiene script runs without errors
- ✅ TechDocs score section renders correctly
- ✅ Provisioning cards display in catalog

### Nice to Have (Would Be Good)
- ✅ Performance tests pass (entities index < 3s)
- ✅ Full end-to-end flow: create service → CI → catalog → resource
- ✅ All documentation links work
- ✅ No regressions in existing templates

---

## Common Issues & Fixes

### Issue: "Link shows localhost:7007"
```bash
# Fix: Check template.yaml
grep "7007" development/templates/new-service/template.yaml
# Should be: grep "3000" development/templates/new-service/template.yaml
```

### Issue: "score.yaml not found in repo"
```bash
# Verify template rendered correctly
gh api repos/nimishmehta8779/test-api-svc/contents/score.yaml
# If missing: manually create it or re-run template
```

### Issue: "GitHub Actions doesn't run"
```bash
# Check workflow file is valid YAML
yamllint development/templates/new-service/skeleton/.github/workflows/init-setup.yaml

# Verify file exists in pushed repo
git ls-tree -r --name-only HEAD | grep init-setup.yaml
```

### Issue: "Entity not in catalog"
```bash
# Wait 3 seconds for indexing
sleep 3

# Check if registered
curl -s http://localhost:7007/api/catalog/entities | jq '.[] | select(.metadata.name=="test-api-svc")'

# Check Backstage logs
docker logs backstage-backend | grep -i "catalog"
```

### Issue: "Hygiene script shows errors"
```bash
# Check score annotations in all entities
curl -s http://localhost:7007/api/catalog/entities | jq '.[] | select(.kind=="Component") | {name: .metadata.name, hasScore: (.metadata.annotations["score.dev/workload-spec"] != null)}'

# Should all be true
```

---

## Documentation Files

```
/Users/nm/devel/idp/
├── TESTING_SUMMARY.md (this file)
├── TESTING_QUICK_REFERENCE.md (quick testing guide)
├── TESTING_RECOMMENDATIONS.md (comprehensive 10-phase plan)
├── test-templates.sh (automated validation script)
│
└── development/templates/
    ├── new-service/skeleton/
    │   ├── score.yaml
    │   ├── score-overrides.dev.yaml
    │   ├── .score/README.md
    │   └── .github/workflows/
    │       ├── init-setup.yaml
    │       ├── initial-config.yaml
    │       └── ci.yaml (with validate-score job)
    │
    ├── eks-cluster/skeleton/
    │   └── score.yaml (infrastructure spec)
    │
    ├── onboard-team/skeleton/
    │   ├── score.yaml (platform-quota)
    │   └── .github/workflows/init-setup.yaml
    │
    └── decommission-cluster/
        (no new files, uses existing structure)
```

---

## Testing Checklist

### Pre-Testing
- [ ] Backstage running on port 3000
- [ ] Backstage backend on port 7007
- [ ] ArgoCD on port 8080
- [ ] Kind cluster accessible
- [ ] GitHub CLI configured
- [ ] This directory is git repo

### Automated Tests
- [ ] `bash test-templates.sh` passes
- [ ] 26/26 checks pass
- [ ] No critical errors

### Template 1: new-service
- [ ] Create service via UI
- [ ] Output shows 3 links
- [ ] All links work and use correct ports
- [ ] GitHub repo created
- [ ] score.yaml exists with correct format
- [ ] CI validates score.yaml
- [ ] Component in catalog
- [ ] Annotations present

### Template 2: eks-cluster
- [ ] Create cluster via UI
- [ ] Output shows 4 links
- [ ] ArgoCD link works (port 8080)
- [ ] Catalog link works (port 3000)
- [ ] GitOps claim created in team repo
- [ ] Resource in catalog
- [ ] score.yaml has kubernetes-cluster type

### Template 3: decommission-cluster
- [ ] Decommission created cluster
- [ ] Output shows 3 links
- [ ] Links work correctly
- [ ] Cluster claim deleted
- [ ] Audit record created
- [ ] Issue created in GitHub

### Template 4: onboard-team
- [ ] Onboard new team
- [ ] Output shows 3 links
- [ ] Team repo created with structure
- [ ] score.yaml with platform-quota
- [ ] init-setup.yaml runs
- [ ] Group in catalog
- [ ] Annotations present

### Integration Tests
- [ ] Catalog hygiene passes
- [ ] TechDocs score section visible
- [ ] All links work end-to-end
- [ ] No regressions in existing features

---

## Time Estimates

| Activity | Time |
|----------|------|
| Run automated tests | 5 min |
| Quick test new-service | 5 min |
| Quick test eks-cluster | 5 min |
| Quick test decommission | 3 min |
| Quick test onboard-team | 5 min |
| Verify annotations & hygiene | 5 min |
| **Total Quick Test** | **28 min** |
| | |
| Full comprehensive tests (Phase 1-10) | 2-3 hours |
| Integration tests | 30 min |
| Documentation review | 20 min |
| **Total Full Test** | **3-4 hours** |

---

## Recommended Testing Schedule

### Day 1 (1.5 hours)
- Run automated tests
- Quick manual tests for all 4 templates
- Document any issues
- Fix critical bugs

### Day 2 (1.5 hours)
- Run comprehensive Phase 2-5 tests (templates)
- Cross-template validation
- Edge case testing
- Performance verification

### Day 3 (1 hour)
- Integration testing (full e2e flows)
- Regression testing (existing templates)
- Documentation verification
- Final sign-off

---

## Next Actions

1. **Right Now:**
   ```bash
   bash test-templates.sh
   ```

2. **In 5 Minutes:**
   - Go to http://localhost:3000/create
   - Test one template

3. **In 30 Minutes:**
   - Complete all 4 templates with QUICK_REFERENCE.md

4. **In 2-3 Hours:**
   - Follow comprehensive plan in TESTING_RECOMMENDATIONS.md

5. **Document Results:**
   - Note any failures
   - Record timing for each phase
   - Identify edge cases
   - File issues for regressions

---

## Questions?

Check the detailed guide:
```bash
cat TESTING_RECOMMENDATIONS.md | less
# Full 10-phase testing plan with detailed steps
```

Or quick reference:
```bash
cat TESTING_QUICK_REFERENCE.md | less
# Fast 5-min testing guide per template
```

Or run automated validation:
```bash
bash test-templates.sh
# 26 automated checks
```

---

## Success Message

When all testing is complete, you should see:

```
✅ All 4 templates work end-to-end
✅ Output links appear and use correct ports (3000, 8080)
✅ GitHub Actions workflows run automatically
✅ score.yaml validation prevents invalid specs
✅ Catalog shows all entities with correct annotations
✅ Provisioning cards display (when implemented)
✅ Audit trails complete in idp-gitops
✅ TechDocs documentation is accurate
✅ No regressions in existing functionality
✅ Performance acceptable (< 5s for e2e operations)

🎉 Template Enhancement Testing: COMPLETE
```
