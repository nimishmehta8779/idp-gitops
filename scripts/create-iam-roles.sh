#!/usr/bin/env bash
#
# create-iam-roles.sh
# Script to create the Dev and Staging simulated multi-account IAM roles and permission boundaries in AWS.
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}Simulating Multi-Account Isolation: Creating IAM Boundaries and Roles...${NC}"
echo -e "NOTE: Before running this script, ensure you have replaced the placeholders (ACCOUNT_ID and YOUR_IAM_USER) in the trust policy template file: infrastructure/iam/trust-policies/crossplane-trust.json with your actual AWS values."
echo ""

# Check for AWS CLI
if ! command -v aws &>/dev/null; then
  echo -e "${RED}Error: AWS CLI is not installed.${NC}"
  exit 1
fi

# Load parent .env only if we do not already have working AWS credentials
if aws sts get-caller-identity &>/dev/null; then
  echo "Using existing active AWS credentials..."
else
  if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
  elif [ -f ../.env ]; then
    export $(grep -v '^#' ../.env | xargs)
  fi
fi

# Fetch AWS Account ID
echo "Fetching AWS Caller Identity..."
ACCOUNT_ID=$(aws sts get-caller-identity --query "Account" --output text 2>/dev/null || echo "")
if [ -z "$ACCOUNT_ID" ]; then
  echo -e "${RED}Error: Could not retrieve AWS Account ID. Please verify your AWS credentials are configured.${NC}"
  exit 1
fi
echo "Active AWS Account: $ACCOUNT_ID"

# Policy paths
DEV_BOUNDARY_FILE="infrastructure/iam/boundaries/dev-boundary.json"
STAGING_BOUNDARY_FILE="infrastructure/iam/boundaries/staging-boundary.json"

if [ ! -f "$DEV_BOUNDARY_FILE" ] || [ ! -f "$STAGING_BOUNDARY_FILE" ]; then
  echo -e "${RED}Error: Boundary JSON files not found. Run from the workspace root directory.${NC}"
  exit 1
fi

# 1. Create permission boundary policies in AWS
echo "Creating/Updating IAM Permission Boundary policies in AWS..."

# Dev Boundary Policy
DEV_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/idp-dev-boundary"
if aws iam get-policy --policy-arn "$DEV_POLICY_ARN" &>/dev/null; then
  echo "Policy idp-dev-boundary exists. Creating new version..."
  aws iam create-policy-version --policy-arn "$DEV_POLICY_ARN" --policy-document "file://$DEV_BOUNDARY_FILE" --set-as-default &>/dev/null
else
  echo "Creating policy idp-dev-boundary..."
  aws iam create-policy --policy-name "idp-dev-boundary" --policy-document "file://$DEV_BOUNDARY_FILE" &>/dev/null
fi
echo -e "${GREEN}✓ Dev boundary policy configured: $DEV_POLICY_ARN${NC}"

# Staging Boundary Policy
STAGING_POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/idp-staging-boundary"
if aws iam get-policy --policy-arn "$STAGING_POLICY_ARN" &>/dev/null; then
  echo "Policy idp-staging-boundary exists. Creating new version..."
  aws iam create-policy-version --policy-arn "$STAGING_POLICY_ARN" --policy-document "file://$STAGING_BOUNDARY_FILE" --set-as-default &>/dev/null
else
  echo "Creating policy idp-staging-boundary..."
  aws iam create-policy --policy-name "idp-staging-boundary" --policy-document "file://$STAGING_BOUNDARY_FILE" &>/dev/null
fi
echo -e "${GREEN}✓ Staging boundary policy configured: $STAGING_POLICY_ARN${NC}"

# 2. Create trust policy from template
TRUST_POLICY_TEMPLATE="infrastructure/iam/trust-policies/crossplane-trust.json"
TRUST_POLICY_FILE="/tmp/idp-trust-policy.json"

if [ ! -f "$TRUST_POLICY_TEMPLATE" ]; then
  echo -e "${RED}Error: Trust policy template not found at $TRUST_POLICY_TEMPLATE${NC}"
  exit 1
fi

# Ensure placeholders are replaced
if grep -q "YOUR_IAM_USER" "$TRUST_POLICY_TEMPLATE"; then
  echo -e "${RED}Error: Before running this script, you must replace the placeholders (ACCOUNT_ID and YOUR_IAM_USER) in $TRUST_POLICY_TEMPLATE with real values.${NC}"
  exit 1
fi

echo "Generating trust policy from template..."
sed "s/ACCOUNT_ID/${ACCOUNT_ID}/g" "$TRUST_POLICY_TEMPLATE" > "$TRUST_POLICY_FILE"

# 3. Create dev and staging roles
ADMIN_POLICY_ARN="arn:aws:iam::aws:policy/AdministratorAccess"

create_iam_role() {
  local role_name="$1"
  local boundary_arn="$2"
  
  echo "Checking role $role_name..."
  if aws iam get-role --role-name "$role_name" &>/dev/null; then
    echo "Role $role_name exists. Updating trust policy and boundary..."
    aws iam update-assume-role-policy --role-name "$role_name" --policy-document "file://$TRUST_POLICY_FILE"
    aws iam put-role-permissions-boundary --role-name "$role_name" --permissions-boundary "$boundary_arn"
  else
    echo "Creating role $role_name..."
    aws iam create-role \
      --role-name "$role_name" \
      --assume-role-policy-document "file://$TRUST_POLICY_FILE" \
      --permissions-boundary "$boundary_arn" &>/dev/null
  fi
  
  # Attach AdministratorAccess policy (effective permission is the intersection of Admin and the Boundary)
  aws iam attach-role-policy --role-name "$role_name" --policy-arn "$ADMIN_POLICY_ARN"
  echo -e "${GREEN}✓ IAM Role $role_name configured and policy attached.${NC}"
}

create_iam_role "idp-dev-role" "$DEV_POLICY_ARN"
create_iam_role "idp-staging-role" "$STAGING_POLICY_ARN"

# Clean up
rm -f "$TRUST_POLICY_FILE"

echo ""
echo -e "${GREEN}${BOLD}Simulated Multi-Account Roles successfully configured!${NC}"
echo "--------------------------------------------------------"
echo "Dev Role ARN:     arn:aws:iam::${ACCOUNT_ID}:role/idp-dev-role"
echo "Staging Role ARN: arn:aws:iam::${ACCOUNT_ID}:role/idp-staging-role"
echo "--------------------------------------------------------"
