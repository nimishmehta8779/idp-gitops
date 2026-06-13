#!/usr/bin/env bash
#
# emergency-cleanup.sh
# Emergency cleanup script to tear down all Crossplane-managed AWS resources.
# Overrides any Orphan deletion policies to Delete and deletes all claims and managed resources.
#

set -euo pipefail

echo "====================================================="
echo "   EMERGENCY CLEANUP: TEARING DOWN AWS RESOURCES     "
echo "====================================================="

# 1. Delete all EKSCluster claims to initiate graceful teardown
echo "Step 1: Deleting all EKSCluster claims..."
if kubectl get ekscluster -A >/dev/null 2>&1; then
  kubectl delete ekscluster --all -A --timeout=15s || echo "Warning: Timeout or error deleting EKS claims, proceeding..."
else
  echo "No EKSCluster claims found or custom resource definition is not registered."
fi

# 2. Patch all managed resources to ensure deletionPolicy is set to 'Delete'
echo "Step 2: Overriding deletionPolicy to 'Delete' on all Crossplane managed resources..."
if kubectl get managed >/dev/null 2>&1; then
  MANAGED_RESOURCES=$(kubectl get managed -o name 2>/dev/null || true)
  if [ -n "$MANAGED_RESOURCES" ]; then
    for res in $MANAGED_RESOURCES; do
      echo "Patching deletionPolicy for $res..."
      kubectl patch "$res" --type merge -p '{"spec":{"deletionPolicy":"Delete"}}' 2>/dev/null || echo "Could not patch $res (it might already be deleting or does not support deletionPolicy)"
    done
  else
    echo "No managed resources found."
  fi
else
  echo "Crossplane managed resources are not available."
fi

# 3. Delete all Crossplane managed resources to trigger AWS deletion
echo "Step 3: Deleting all Crossplane managed resources..."
if kubectl get managed >/dev/null 2>&1; then
  kubectl delete managed --all --timeout=30s || echo "Warning: Timeout or error deleting managed resources, proceeding..."
else
  echo "No managed resources found to delete."
fi

echo "====================================================="
echo "Emergency cleanup initiated successfully."
echo "Please monitor the progress with:"
echo "  kubectl get managed"
echo "====================================================="
