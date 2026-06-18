# Cluster-Specific Repository Setup Guide
## Creating Your EKS Cluster Infrastructure Repository

**Quick Version**: 5 minutes
**Full Version**: 10 minutes
**Status**: Production Ready

---

## Overview

After provisioning an EKS cluster via Backstage template, you need to create a cluster-specific GitHub repository to store:
- GitHub Actions workflows for accessing the cluster
- Cluster configuration and documentation
- Infrastructure as code for the cluster

This guide walks you through the process.

---

## Quick Setup (5 minutes)

### Step 1: Create Repository on GitHub

1. Go to: https://github.com/new
2. Fill in repository details:
   - **Owner**: Select your team (e.g., `team-alpha`)
   - **Repository name**: `<cluster-name>-infra`
     - Example: `alpha-dev-general-01-infra`
   - **Description**: `Infrastructure repository for EKS cluster <cluster-name>`
   - **Visibility**: `Private` (important!)
   - **Add .gitignore**: Select `Go`
   - **License**: (optional)
3. Click **"Create repository"**

### Step 2: Clone Repository Locally

```bash
git clone https://github.com/<team>/<cluster-name>-infra.git
cd <cluster-name>-infra
```

### Step 3: Add Files from Backstage Workspace

The Backstage template prepared cluster files in your workspace:

```bash
# Copy from Backstage-generated files
# Location: ./cluster-repo/ (from template execution)

# Copy GitHub workflows
mkdir -p .github/workflows
cp /path/to/cluster-repo/.github/workflows/*.yml .github/workflows/

# Copy documentation
mkdir -p docs scripts
cp /path/to/cluster-repo/docs/*.md docs/
cp /path/to/cluster-repo/scripts/*.sh scripts/

# Copy configuration files
cp /path/to/cluster-repo/.gitignore .
cp /path/to/cluster-repo/README.md .
cp /path/to/cluster-repo/.github/CODEOWNERS .github/
```

### Step 4: Push to GitHub

```bash
# Add all files
git add .

# Create initial commit
git commit -m "chore: initialize cluster repository with workflows and documentation"

# Push to main branch
git push -u origin main

# Verify files are on GitHub
open https://github.com/<team>/<cluster-name>-infra
```

### Step 5: Configure GitHub Secrets

1. Go to: https://github.com/<team>/<cluster-name>-infra/settings/secrets/actions
2. Add secret: **AWS_ACCOUNT_ID**
   - Value: Your AWS account ID (e.g., `123456789012`)
3. Click **"Add secret"**

### Step 6: Verify Workflows

1. Go to: https://github.com/<team>/<cluster-name>-infra/actions
2. You should see 4 workflows:
   - ✅ Get Kubeconfig
   - ✅ Cluster Information
   - ✅ Addon Status Check
   - ✅ Provisioning Status

All should show as enabled (green checkmark).

---

## Step-by-Step Details

### Step 1: Create Repository - Detailed

**Via GitHub Web UI:**

1. **Log in to GitHub**: https://github.com
2. **Click "+" in top right** → **"New repository"**
3. **Fill in form**:
   ```
   Owner:           [Select: team-alpha]
   Repository name: alpha-dev-general-01-infra
   Description:     Infrastructure repository for EKS cluster alpha-dev-general-01
   Visibility:      ● Private
   
   Initialize with:
   ☑ Add a README file
   ☑ Add .gitignore (select: Go)
   ☐ Choose a license
   ```
4. **Click "Create repository"**
5. You'll see: "We've initialized your repository with a README for you."

**Via GitHub CLI:**

```bash
# If you prefer command line
gh repo create <team>/<cluster-name>-infra \
  --private \
  --description "Infrastructure repository for EKS cluster <cluster-name>" \
  --template https://github.com/github/gitignore/blob/main/Go.gitignore \
  --confirm
```

### Step 2: Clone Locally - Detailed

```bash
# Method 1: HTTPS
git clone https://github.com/<team>/<cluster-name>-infra.git

# Method 2: SSH (if SSH keys configured)
git clone git@github.com:<team>/<cluster-name>-infra.git

# Navigate to repo
cd <cluster-name>-infra

# Verify you're in the right place
pwd  # Should show: .../cluster-name-infra
ls -la  # Should show: README.md, .gitignore, .git folder
```

### Step 3: Find & Copy Files - Detailed

**Where are the files?**

After Backstage template completes, prepared files are in your workspace directory at:
```
./cluster-repo/
├── .github/
│   ├── workflows/
│   │   ├── get-kubeconfig.yml
│   │   ├── cluster-info.yml
│   │   ├── addon-status.yml
│   │   └── provisioning-status.yml
│   ├── CODEOWNERS
│   └── workflows/
├── docs/
│   ├── CLUSTER_INFO.md
│   └── ADDON_STATUS.md
├── scripts/
│   ├── get-cluster-info.sh
│   └── test-access.sh
├── README.md
└── .gitignore
```

**Copy files to your cloned repo:**

```bash
# Assume you're in the cloned repository directory
cd ~/github/<team>/<cluster-name>-infra

# Copy from the Backstage workspace
BACKSTAGE_WORKSPACE="/path/to/backstage/workspace"  # Ask your team for path

# Create directories
mkdir -p .github/workflows docs scripts

# Copy files
cp $BACKSTAGE_WORKSPACE/cluster-repo/.github/workflows/*.yml .github/workflows/
cp $BACKSTAGE_WORKSPACE/cluster-repo/.github/CODEOWNERS .github/
cp $BACKSTAGE_WORKSPACE/cluster-repo/docs/*.md docs/
cp $BACKSTAGE_WORKSPACE/cluster-repo/scripts/*.sh scripts/
chmod +x scripts/*.sh

# Update files (they may have template placeholders)
# Edit README.md to replace <cluster-name>, <team-name>, etc. with actual values
nano README.md

# Verify files copied correctly
find . -type f -name "*.yml" -o -name "*.md" -o -name "*.sh"
```

### Step 4: Push to GitHub - Detailed

```bash
# Check status (should show all files as untracked)
git status

# Expected output:
# Untracked files:
#   .github/workflows/addon-status.yml
#   .github/workflows/cluster-info.yml
#   .github/workflows/get-kubeconfig.yml
#   .github/workflows/provisioning-status.yml
#   docs/ADDON_STATUS.md
#   docs/CLUSTER_INFO.md
#   scripts/get-cluster-info.sh
#   scripts/test-access.sh
#   README.md

# Stage all files
git add -A

# Verify staging
git status
# Expected: "Changes to be committed" section shows all files

# Create commit
git commit -m "chore: initialize cluster repository with workflows

- Add 4 GitHub Actions workflows for cluster access and monitoring
- Add cluster documentation templates
- Add helper scripts for local operations
- Configure CODEOWNERS for code review policy

This repository provides:
- One-click kubeconfig retrieval via get-kubeconfig.yml
- Hourly cluster status updates via cluster-info.yml
- Real-time add-on monitoring via addon-status.yml
- Provisioning progress tracking via provisioning-status.yml"

# Push to GitHub
git push -u origin main

# Verify push succeeded
# You should see: "Create pull request for 'main' on GitHub"

# Check on GitHub
open https://github.com/<team>/<cluster-name>-infra
# Should show all files in the repo
```

### Step 5: Configure Secrets - Detailed

**Why we need AWS_ACCOUNT_ID:**
- GitHub Actions workflows need to authenticate with AWS
- They use OIDC (OpenID Connect) - no long-lived credentials
- AWS_ACCOUNT_ID tells GitHub which AWS account to access

**How to find your AWS Account ID:**

```bash
# Via AWS CLI
aws sts get-caller-identity --query Account --output text
# Output: 123456789012

# Via AWS Console
# 1. Log in to AWS
# 2. Click your account name (top right) → "Account"
# 3. Account ID shows at the top
```

**Add the secret:**

1. Go to: `https://github.com/<team>/<cluster-name>-infra/settings/secrets/actions`
2. Click **"New repository secret"**
3. Fill in:
   - **Name**: `AWS_ACCOUNT_ID`
   - **Value**: `123456789012` (your actual AWS account ID)
4. Click **"Add secret"**

**Verify:**
- Secret should now appear in the "Repository secrets" list
- Shows as: `AWS_ACCOUNT_ID` (value hidden as `●●●●●●●●●●●●`)

### Step 6: Verify Workflows - Detailed

**Check that workflows are enabled:**

1. Go to: `https://github.com/<team>/<cluster-name>-infra/actions`
2. On the left sidebar, you should see:
   - ✅ **Get Kubeconfig** (enabled)
   - ✅ **Cluster Information** (enabled)
   - ✅ **Addon Status Check** (enabled)
   - ✅ **Provisioning Status** (enabled)

3. Each should show a green checkmark (enabled)

**If a workflow is disabled:**
1. Click on the disabled workflow name
2. Click **"Enable workflow"** button
3. Confirm

**Test a workflow manually:**
1. Click on "Provisioning Status" workflow
2. Click **"Run workflow"** button
3. Keep default settings
4. Click **"Run workflow"** green button
5. After ~1 minute, it should show a green checkmark (success) or gray (in progress)

---

## Troubleshooting

### Issue: Files don't copy correctly

**Solution:**
```bash
# Find the exact path
find ~ -name "get-kubeconfig.yml" -type f

# Copy from found location
cp /exact/path/get-kubeconfig.yml .github/workflows/

# Or get from documentation (backup option)
# See: EKS_PHASE1_COMPLETION.md - contains full workflow code
```

### Issue: Repository won't let me push

**Solution:**
```bash
# Verify you're in the right directory
pwd
# Should end with: cluster-name-infra

# Verify git is initialized
git remote -v
# Should show: origin https://github.com/<team>/<cluster-name>-infra.git

# If remote is wrong, fix it
git remote set-url origin https://github.com/<team>/<cluster-name>-infra.git

# Try push again
git push -u origin main
```

### Issue: GitHub says "permission denied"

**Solution:**
```bash
# Make sure you have GitHub credentials configured
git config --global user.name "Your Name"
git config --global user.email "your.email@company.com"

# Generate GitHub Personal Access Token
# 1. Go to: https://github.com/settings/tokens
# 2. Click "Generate new token"
# 3. Select scopes: repo (full control of private repositories)
# 4. Click "Generate token"
# 5. Copy the token

# When git asks for password, paste the token instead of your password
```

### Issue: Workflows show "error" status

**Solution:**

Most common cause: Missing `AWS_ACCOUNT_ID` secret

1. Verify secret was added: `https://github.com/<team>/<cluster-name>-infra/settings/secrets`
2. Verify it's named exactly `AWS_ACCOUNT_ID` (case-sensitive)
3. Verify value is correct AWS account ID (12 digits)
4. Click on workflow → "Run workflow" again to retry

---

## Verification Checklist

After setup, verify everything is ready:

```
Repository Setup:
  ☑ Repository created on GitHub (private)
  ☑ Repository cloned locally
  ☑ All files pushed to main branch
  ☑ Files visible on GitHub web UI

GitHub Configuration:
  ☑ AWS_ACCOUNT_ID secret added
  ☑ Secret value correct (12-digit AWS account ID)
  ☑ CODEOWNERS configured

GitHub Actions:
  ☑ 4 workflows present and enabled
  ☑ get-kubeconfig.yml enabled
  ☑ cluster-info.yml enabled
  ☑ addon-status.yml enabled
  ☑ provisioning-status.yml enabled

Ready to Use:
  ☑ Can run workflows manually
  ☑ Workflows have correct permissions
  ☑ Documentation files committed
  ☑ Helper scripts executable (chmod +x)
  
✅ CLUSTER REPO READY FOR USE
```

---

## What's Next

Now that your cluster repository is set up:

1. **Monitor Provisioning** (35 minutes total)
   - Check Crossplane status: `kubectl get xeksclusters -n clusters-dev`
   - Check AWS: `aws eks describe-cluster --name <cluster-name>`
   - Track progress in GitHub Actions workflows

2. **When Cluster is ACTIVE**
   - Run: `gh workflow run get-kubeconfig.yml -R <team>/<cluster-name>-infra`
   - Download kubeconfig artifact
   - Test: `kubectl get nodes`

3. **Deploy Applications**
   - Use: `kubectl apply -f app.yaml`
   - Monitor: `kubectl get pods`
   - Scale: `kubectl scale deployment myapp --replicas=3`

---

## References

- **EKS_QUICK_VALIDATION_CARD.md** - Timeline and checklist
- **EKS_PROVISIONING_OPERATIONAL_GUIDE.md** - Full operational guide
- **EKS_PHASE1_COMPLETION.md** - Implementation details and workflow code

---

**Questions?** See troubleshooting section or contact #platform-team Slack.

**Done!** Your cluster repository is ready. Proceed to provisioning validation. 🚀
