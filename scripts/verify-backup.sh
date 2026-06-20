#!/bin/bash
set -e

echo "=== Pre-Agentic Backup Verification ==="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASS=0
FAIL=0

check() {
  LABEL=$1
  CMD=$2
  if eval "$CMD" &>/dev/null; then
    echo -e "${GREEN}✅${NC} $LABEL"
    PASS=$((PASS+1))
  else
    echo -e "${RED}❌${NC} $LABEL"
    FAIL=$((FAIL+1))
  fi
}

# Git checks
echo "Git Backups:"
check "Backup branch exists locally" "git branch | grep -q 'backup/pre-agentic'"
check "Backup branch on GitHub" "git branch -r | grep -q 'backup/pre-agentic'"
check "Backup tag exists" "git tag -l | grep -q 'backup-pre-agentic'"
check "Current working tree is clean" "! git status --porcelain | grep -q ."

# Filesystem checks
echo ""
echo "Filesystem Backups:"
check "Backup directory exists" "test -d .backups/pre-agentic-*"
check "Kubernetes state exported" "test -f .backups/pre-agentic-*/kubernetes-state.yaml"
check "Crossplane compositions exported" "test -f .backups/pre-agentic-*/crossplane-compositions.yaml"
check "Crossplane XRDs exported" "test -f .backups/pre-agentic-*/crossplane-xrds.yaml"
check "ArgoCD apps exported" "test -f .backups/pre-agentic-*/argocd-apps.yaml"
check "ArgoCD projects exported" "test -f .backups/pre-agentic-*/argocd-projects.yaml"
check "ArgoCD appsets exported" "test -f .backups/pre-agentic-*/argocd-appsets.yaml"
check "Kyverno policies exported" "test -f .backups/pre-agentic-*/kyverno-policies.yaml"
check "AWS state exported" "test -f .backups/pre-agentic-*/aws-iam-roles.json"
check "Recovery runbook exists" "test -f .backups/RECOVERY.md"

# Kubernetes checks
echo ""
echo "Kubernetes Access:"
check "kind cluster running" "kubectl cluster-info &>/dev/null"
check "Can access Crossplane resources" "kubectl get compositions &>/dev/null"
check "Can access ArgoCD resources" "kubectl get applications -A &>/dev/null"
check "Can access Kyverno policies" "kubectl get clusterpolicies &>/dev/null"

# AWS checks
echo ""
echo "AWS Access:"
check "AWS CLI working" "aws sts get-caller-identity &>/dev/null"
check "Can list IAM roles" "aws iam list-roles &>/dev/null"
check "Can list EKS clusters" "aws eks list-clusters &>/dev/null"

# Summary
echo ""
echo "=== Verification Summary ==="
TOTAL=$((PASS+FAIL))
echo "Passed: $PASS / $TOTAL"

if [ $FAIL -eq 0 ]; then
  echo -e "${GREEN}All backups verified ✅${NC}"
  echo "Safe to proceed with agentic development."
  exit 0
else
  echo -e "${RED}$FAIL checks failed ❌${NC}"
  echo "Please fix before proceeding."
  exit 1
fi
