#!/usr/bin/env bash
#
# setup-platform-admins-role.sh
# One-time, account-wide setup of the idp-platform-admins IAM role.
# This role is granted EKS access (via AccessEntry/AccessPolicyAssociation)
# by the Crossplane EKS Composition on every cluster it creates, giving
# operators a stable break-glass admin identity that works automatically
# on every cluster without per-cluster manual access-entry commands.
#

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

ROLE_NAME="idp-platform-admins"

echo -e "${BOLD}Configuring ${ROLE_NAME} IAM role...${NC}"

if ! command -v aws &>/dev/null; then
  echo -e "${RED}Error: AWS CLI is not installed.${NC}"
  exit 1
fi

if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
  if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
  elif [ -f ../.env ]; then
    export $(grep -v '^#' ../.env | xargs)
  elif [ -f ../../.env ]; then
    export $(grep -v '^#' ../../.env | xargs)
  fi
fi

AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
if [ -z "$AWS_ACCOUNT_ID" ]; then
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
fi
if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo -e "${RED}Error: Could not retrieve AWS Account ID. Check your AWS credentials configuration.${NC}"
  exit 1
fi
echo "Using AWS Account ID: $AWS_ACCOUNT_ID"

AWS_IAM_USER="${AWS_IAM_USER:-}"
if [ -z "$AWS_IAM_USER" ]; then
  CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "")
  if echo "$CALLER_ARN" | grep -q ":user/"; then
    AWS_IAM_USER=$(echo "$CALLER_ARN" | awk -F'/' '{print $NF}')
  fi
fi
if [ -z "$AWS_IAM_USER" ] || [ "$AWS_IAM_USER" = "root" ]; then
  echo "Active credential caller is root or could not be mapped to a specific IAM user."
  echo "Defaulting to user name: nimish"
  AWS_IAM_USER="nimish"
fi
echo "Using AWS IAM User name: $AWS_IAM_USER"

TRUST_POLICY_TEMPLATE="infrastructure/iam/trust-policies/platform-admins-trust.json"
if [ ! -f "$TRUST_POLICY_TEMPLATE" ]; then
  TRUST_POLICY_TEMPLATE="../iam/trust-policies/platform-admins-trust.json"
fi
if [ ! -f "$TRUST_POLICY_TEMPLATE" ]; then
  TRUST_POLICY_TEMPLATE="trust-policies/platform-admins-trust.json"
fi

TRUST_POLICY_FILE="/tmp/idp-platform-admins-trust-policy.json"
sed -e "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" -e "s/YOUR_IAM_USER/${AWS_IAM_USER}/g" "$TRUST_POLICY_TEMPLATE" > "$TRUST_POLICY_FILE"

echo "Checking role $ROLE_NAME..."
if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
  echo "Role $ROLE_NAME already exists. Updating trust policy..."
  aws iam update-assume-role-policy --role-name "$ROLE_NAME" --policy-document "file://$TRUST_POLICY_FILE"
else
  echo "Creating role $ROLE_NAME..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "file://$TRUST_POLICY_FILE" \
    --tags Key=managed-by,Value=crossplane Key=purpose,Value=eks-break-glass &>/dev/null
fi

rm -f "$TRUST_POLICY_FILE"

echo -e "${GREEN}${BOLD}idp-platform-admins role configured.${NC}"
echo "Role ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME}"
