#!/usr/bin/env bash
#
# setup-iam-roles.sh
# Automation script to create EKS/EC2 permission boundaries and IAM roles in AWS.
#

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}Configuring AWS Simulated Multi-Account Isolation...${NC}"

# Check for AWS CLI
if ! command -v aws &>/dev/null; then
  echo -e "${RED}Error: AWS CLI is not installed.${NC}"
  exit 1
fi

# Load parent .env only if we do not already have working AWS credentials
if [ -z "${AWS_ACCESS_KEY_ID:-}" ]; then
  if [ -f .env ]; then
    export $(grep -v '^#' .env | xargs)
  elif [ -f ../.env ]; then
    export $(grep -v '^#' ../.env | xargs)
  elif [ -f ../../.env ]; then
    export $(grep -v '^#' ../../.env | xargs)
  fi
fi

# 1. Resolve Account ID
echo "Resolving AWS Account ID..."
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
if [ -z "$AWS_ACCOUNT_ID" ]; then
  AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
  echo -e "${RED}Error: Could not retrieve AWS Account ID. Check your AWS credentials configuration.${NC}"
  exit 1
fi
echo "Using AWS Account ID: $AWS_ACCOUNT_ID"

# 2. Resolve IAM User
echo "Resolving AWS IAM User..."
AWS_IAM_USER="${AWS_IAM_USER:-}"
if [ -z "$AWS_IAM_USER" ]; then
  CALLER_ARN=$(aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo "")
  # Check if the caller is an IAM user
  if echo "$CALLER_ARN" | grep -q ":user/"; then
    AWS_IAM_USER=$(echo "$CALLER_ARN" | awk -F'/' '{print $NF}')
  fi
fi

# If we resolved root or nothing, ask to set AWS_IAM_USER
if [ -z "$AWS_IAM_USER" ] || [ "$AWS_IAM_USER" = "root" ]; then
  # Try to fall back to 'nimish' as the default real user name since we know that's the username
  echo "Active credential caller is root or could not be mapped to a specific IAM user."
  echo "Defaulting to user name: nimish"
  AWS_IAM_USER="nimish"
fi
echo "Using AWS IAM User name: $AWS_IAM_USER"

# Relative paths for json policies
DEV_BOUNDARY_FILE="infrastructure/iam/boundaries/dev-boundary.json"
STAGING_BOUNDARY_FILE="infrastructure/iam/boundaries/staging-boundary.json"
TRUST_POLICY_TEMPLATE="infrastructure/iam/boundaries/../trust-policies/crossplane-trust.json"

# Adjust paths if run from the script folder
if [ ! -f "$DEV_BOUNDARY_FILE" ]; then
  DEV_BOUNDARY_FILE="../iam/boundaries/dev-boundary.json"
  STAGING_BOUNDARY_FILE="../iam/boundaries/staging-boundary.json"
  TRUST_POLICY_TEMPLATE="../iam/trust-policies/crossplane-trust.json"
fi

if [ ! -f "$DEV_BOUNDARY_FILE" ]; then
  # Try sibling/parent paths from project root
  DEV_BOUNDARY_FILE="boundaries/dev-boundary.json"
  STAGING_BOUNDARY_FILE="boundaries/staging-boundary.json"
  TRUST_POLICY_TEMPLATE="trust-policies/crossplane-trust.json"
fi

# 3. Create Permission Boundary Policies in AWS
create_boundary_policy() {
  local name="$1"
  local file="$2"
  local desc="$3"
  local arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${name}"

  echo "Checking policy $name..."
  if aws iam get-policy --policy-arn "$arn" &>/dev/null; then
    echo "Policy $name exists. Creating new version..."
    aws iam create-policy-version \
      --policy-arn "$arn" \
      --policy-document "file://$file" \
      --set-as-default &>/dev/null || echo "Warning: could not create new policy version for $name."
  else
    echo "Creating policy $name..."
    aws iam create-policy \
      --policy-name "$name" \
      --policy-document "file://$file" \
      --description "$desc" &>/dev/null
  fi
  echo -e "${GREEN}✓ Boundary policy configured: $arn${NC}"
}

create_boundary_policy "idp-dev-boundary" "$DEV_BOUNDARY_FILE" "Permission boundary for IDP dev environment role"
create_boundary_policy "idp-staging-boundary" "$STAGING_BOUNDARY_FILE" "Permission boundary for IDP staging environment role"

# 4. Generate Trust Policy using sed
TRUST_POLICY_FILE="/tmp/idp-trust-policy.json"
echo "Generating trust policy from template..."
sed -e "s/ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" -e "s/YOUR_IAM_USER/${AWS_IAM_USER}/g" "$TRUST_POLICY_TEMPLATE" > "$TRUST_POLICY_FILE"

# 5. Create dev and staging roles in AWS
attach_role_policies() {
  local role_name="$1"

  echo "Attaching scoped AWS policies to $role_name..."
  # EKS policies needed by Crossplane
  aws iam attach-role-policy \
    --role-name "$role_name" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"

  aws iam attach-role-policy \
    --role-name "$role_name" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"

  aws iam attach-role-policy \
    --role-name "$role_name" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"

  aws iam attach-role-policy \
    --role-name "$role_name" \
    --policy-arn "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"

  # Inline policy for EC2 and IAM operations Crossplane needs
  echo "Putting inline crossplane-ec2-iam-access policy on $role_name..."
  aws iam put-role-policy \
    --role-name "$role_name" \
    --policy-name "crossplane-ec2-iam-access" \
    --policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "ec2:*",
            "iam:CreateRole",
            "iam:DeleteRole",
            "iam:AttachRolePolicy",
            "iam:DetachRolePolicy",
            "iam:PutRolePolicy",
            "iam:DeleteRolePolicy",
            "iam:GetRole",
            "iam:ListRoles",
            "iam:PassRole",
            "iam:CreateOpenIDConnectProvider",
            "iam:DeleteOpenIDConnectProvider",
            "iam:GetOpenIDConnectProvider",
            "iam:TagRole",
            "iam:UntagRole",
            "iam:ListAttachedRolePolicies",
            "iam:ListRolePolicies",
            "iam:GetRolePolicy",
            "iam:ListInstanceProfilesForRole",
            "iam:RemoveRoleFromInstanceProfile",
            "sts:GetCallerIdentity",
            "sts:AssumeRole"
          ],
          "Resource": "*"
        }
      ]
    }'
}

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

  # Detach AdministratorAccess if attached to prevent bypass of boundaries/privileges
  if aws iam list-attached-role-policies --role-name "$role_name" --query "AttachedPolicies[?PolicyArn=='arn:aws:iam::aws:policy/AdministratorAccess'].PolicyArn" --output text 2>/dev/null | grep -q "AdministratorAccess"; then
    echo "Detaching legacy AdministratorAccess policy from $role_name..."
    aws iam detach-role-policy --role-name "$role_name" --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess" || true
  fi

  # Attach scoped policies
  attach_role_policies "$role_name"

  echo -e "${GREEN}✓ IAM Role $role_name configured with boundary and scoped policies.${NC}"
}

DEV_BOUNDARY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/idp-dev-boundary"
STAGING_BOUNDARY_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/idp-staging-boundary"

create_iam_role "idp-dev-role" "$DEV_BOUNDARY_ARN"
create_iam_role "idp-staging-role" "$STAGING_BOUNDARY_ARN"

# Clean up
rm -f "$TRUST_POLICY_FILE"

echo ""
echo -e "${GREEN}${BOLD}Simulated Multi-Account Roles successfully configured!${NC}"
echo "--------------------------------------------------------"
echo "Dev Role ARN:     arn:aws:iam::${AWS_ACCOUNT_ID}:role/idp-dev-role"
echo "Staging Role ARN: arn:aws:iam::${AWS_ACCOUNT_ID}:role/idp-staging-role"
echo "--------------------------------------------------------"
