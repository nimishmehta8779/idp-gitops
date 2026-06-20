#!/usr/bin/env bash
#
# migrate-cluster-access.sh
# One-time migration helper for clusters provisioned before the Composition
# fix that sets accessConfig.authenticationMode=API + bootstrap admin perms
# and the platform-admins AccessEntry/AccessPolicyAssociation.
#
# Usage: bash infrastructure/scripts/migrate-cluster-access.sh <cluster-name> [region]
#

set -uo pipefail

CLUSTER_NAME="${1:-}"
REGION="${2:-us-east-1}"

if [ -z "$CLUSTER_NAME" ]; then
  echo "Usage: $0 <cluster-name> [region]"
  exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo "Error: Could not retrieve AWS Account ID. Check your AWS credentials configuration."
  exit 1
fi

echo "Migrating cluster '$CLUSTER_NAME' (region: $REGION) to API authentication mode + platform-admins access..."

# 1. Check current authentication mode
CURRENT_MODE=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" \
  --query 'cluster.accessConfig.authenticationMode' --output text 2>/dev/null)

echo "Current authentication mode: $CURRENT_MODE"

if [ "$CURRENT_MODE" = "API" ]; then
  echo "Already in API mode, skipping update-cluster-config."
else
  echo "Updating cluster to API authentication mode..."
  UPDATE_ID=$(aws eks update-cluster-config --name "$CLUSTER_NAME" --region "$REGION" \
    --access-config authenticationMode=API --query 'update.id' --output text)
  echo "Waiting for update $UPDATE_ID to complete..."
  while true; do
    UPDATE_STATUS=$(aws eks describe-update --name "$CLUSTER_NAME" --region "$REGION" \
      --update-id "$UPDATE_ID" --query 'update.status' --output text)
    echo "Update status: $UPDATE_STATUS"
    [ "$UPDATE_STATUS" = "Successful" ] && break
    [ "$UPDATE_STATUS" = "Failed" ] || [ "$UPDATE_STATUS" = "Cancelled" ] && { echo "Update did not succeed."; exit 1; }
    sleep 10
  done
fi

# 2. Create access entry for idp-platform-admins (idempotent)
PRINCIPAL_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/idp-platform-admins"

echo "Creating access entry for $PRINCIPAL_ARN..."
aws eks create-access-entry \
  --cluster-name "$CLUSTER_NAME" \
  --region "$REGION" \
  --principal-arn "$PRINCIPAL_ARN" \
  --type STANDARD 2>&1 | grep -v "ResourceInUseException" || true

# 3. Associate the cluster-admin access policy (idempotent)
echo "Associating AmazonEKSClusterAdminPolicy with $PRINCIPAL_ARN..."
aws eks associate-access-policy \
  --cluster-name "$CLUSTER_NAME" \
  --region "$REGION" \
  --principal-arn "$PRINCIPAL_ARN" \
  --policy-arn "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy" \
  --access-scope type=cluster 2>&1 | grep -v "ResourceInUseException" || true

echo ""
echo "Final access entries for $CLUSTER_NAME:"
aws eks list-access-entries --cluster-name "$CLUSTER_NAME" --region "$REGION"
