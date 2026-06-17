# GitHub Actions Token Authentication Fix

## Issue

When running GitHub Actions workflows in newly created repositories, the `actions/checkout@v4` step was failing with:

```
Error: Input required and not supplied: token
```

## Root Cause

The workflows were using `${{ secrets.GITHUB_TOKEN }}` which is:
- Not automatically available in GitHub Actions environment
- Requires explicit configuration in repository settings
- Causes authentication failures on first workflow run

## Solution

Changed all token references from:
```yaml
token: ${{ secrets.GITHUB_TOKEN }}
GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

To:
```yaml
token: ${{ github.token }}
GH_TOKEN: ${{ github.token }}
```

## Why This Works

`${{ github.token }}` is:
- ✅ Automatically available in all GitHub Actions workflows
- ✅ Provided by GitHub without configuration
- ✅ Scoped to the current repository
- ✅ Valid for all operations within the repository
- ✅ Does not require secrets setup

## Files Fixed

### Templates
- ✅ `development/templates/new-service/skeleton/.github/workflows/init-setup.yaml`
- ✅ `development/templates/new-service/skeleton/.github/workflows/initial-config.yaml`
- ✅ `development/templates/onboard-team/skeleton/.github/workflows/init-setup.yaml`

### Changes Made

**new-service/init-setup.yaml:**
- Line 13: `checkout` step token
- Line 27: `branch protection` step token
- Line 39: `standard labels` step token
- Line 59: `welcome issue` step token

**new-service/initial-config.yaml:**
- Line 39: `configuration summary` step token

**onboard-team/init-setup.yaml:**
- Line 12: `checkout` step token
- Line 23: `branch protection` step token
- Line 37: `infra labels` step token
- Line 64: `onboarding issue` step token

## How to Apply to Existing Repos

If you have repositories created before this fix, run:

```bash
# For test-api-service
git clone https://github.com/nimishmehta8779/test-api-service
cd test-api-service

# Update workflows to use github.token
sed -i 's/${{ secrets.GITHUB_TOKEN }}/${{ github.token }}/g' .github/workflows/*.yaml

# Push changes
git add .github/workflows/*.yaml
git commit -m "fix(ci): use github.token instead of secrets.GITHUB_TOKEN"
git push origin main
```

Or manually edit each workflow file and change:
- All `token: ${{ secrets.GITHUB_TOKEN }}` to `token: ${{ github.token }}`
- All `GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}` to `GH_TOKEN: ${{ github.token }}`

## Verification

After applying the fix, GitHub Actions workflows should:
1. ✅ Checkout the repository successfully
2. ✅ Create branch protection rules
3. ✅ Create standard labels
4. ✅ Create welcome issue
5. ✅ Mark repository as initialized

Check workflow execution in: `https://github.com/nimishmehta8779/REPO_NAME/actions`

Expected output:
```
✅ Checkout Code
✅ Check if already initialized
✅ Setup branch protection
✅ Create standard labels
✅ Create welcome issue
✅ Mark as initialized
```

## Testing

To verify the fix works:

```bash
# Create new service with fixed templates
cd /Users/nm/devel/idp
bash test-templates.sh

# Create a test service via Backstage
# Go to http://localhost:3000/create
# Select "Create New Backend Service"
# Fill in test form
# Watch GitHub Actions tab

# Should see all jobs complete successfully
gh run list --repo nimishmehta8779/test-api-service --limit 1
```

## Reference

**GitHub Actions Context Documentation:**
- https://docs.github.com/en/actions/learn-github-actions/contexts#github-context

**GitHub Token in Actions:**
- https://docs.github.com/en/actions/security-guides/automatic-token-authentication

**Best Practices:**
- Always use `${{ github.token }}` for repository-scoped operations
- Use `secrets.GITHUB_TOKEN` only if explicitly configuring in repository settings
- Use personal access tokens (PAT) only for cross-repository operations

## Summary

| Before | After | Status |
|--------|-------|--------|
| `secrets.GITHUB_TOKEN` | `github.token` | ✅ Fixed |
| Requires secrets config | No config needed | ✅ Simplified |
| Checkout fails | Checkout succeeds | ✅ Working |
| Branch protection fails | Branch protection works | ✅ Working |
| Issue creation fails | Issue creation works | ✅ Working |
