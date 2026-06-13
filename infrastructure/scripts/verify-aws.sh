#!/usr/bin/env bash
#
# verify-aws.sh
# Verification script to ensure AWS IAM roles can be assumed with correct permissions
# and Crossplane ProviderConfigs are correctly configured in the Kind cluster.
#

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}Starting AWS and Crossplane Multi-Account Simulation Verification...${NC}"
echo "----------------------------------------------------------------------"

# 1. Source credentials and Role ARNs
# Search for .env file
ENV_FOUND=false
for env_file in .env ../.env infrastructure/backstage/.env backstage/.env ../infrastructure/backstage/.env; do
  if [ -f "$env_file" ]; then
    echo "Loading env file: $env_file"
    export $(grep -v '^#' "$env_file" | xargs)
    ENV_FOUND=true
    break
  fi
done

if [ "$ENV_FOUND" = false ]; then
  echo -e "${RED}Warning: No .env file found. Proceeding with existing environment variables.${NC}"
fi

# Check variables
AWS_DEV_ROLE_ARN="${AWS_DEV_ROLE_ARN:-}"
AWS_STAGING_ROLE_ARN="${AWS_STAGING_ROLE_ARN:-}"

if [ -z "$AWS_DEV_ROLE_ARN" ]; then
  echo -e "${RED}Error: AWS_DEV_ROLE_ARN is not set in environment or .env.${NC}"
  exit 1
fi

if [ -z "$AWS_STAGING_ROLE_ARN" ]; then
  echo -e "${RED}Error: AWS_STAGING_ROLE_ARN is not set in environment or .env.${NC}"
  exit 1
fi

echo "Dev Role ARN:     $AWS_DEV_ROLE_ARN"
echo "Staging Role ARN: $AWS_STAGING_ROLE_ARN"
echo ""

# 2. Check AWS STS role assumption
check_sts_assume() {
  local role_arn="$1"
  local env_name="$2"

  echo -e "Testing role assumption for ${BOLD}$env_name${NC}..."
  
  if ASSUME_OUT=$(aws sts assume-role \
    --role-arn "$role_arn" \
    --role-session-name "verify-${env_name}-session" \
    --external-id "crossplane-idp" \
    --query "AssumedRoleUser.Arn" \
    --output text 2>&1); then
    echo -e "${GREEN}✓ Successfully assumed $env_name role!${NC}"
    echo "Assumed identity: $ASSUME_OUT"
    return 0
  else
    echo -e "${RED}✗ Failed to assume $env_name role.${NC}"
    echo "Error detail: $ASSUME_OUT"
    return 1
  fi
}

DEV_OK=0
check_sts_assume "$AWS_DEV_ROLE_ARN" "dev" || DEV_OK=1

STAGING_OK=0
check_sts_assume "$AWS_STAGING_ROLE_ARN" "staging" || STAGING_OK=1

echo ""

# 3. Check Crossplane ProviderConfig in Kubernetes
check_provider_config() {
  local pc_name="$1"
  local expected_arn="$2"

  echo -e "Verifying Kubernetes ProviderConfig ${BOLD}$pc_name${NC}..."

  if ! kubectl get providerconfig.aws.upbound.io "$pc_name" &>/dev/null; then
    echo -e "${RED}✗ ProviderConfig '$pc_name' does not exist in cluster.${NC}"
    return 1
  fi

  # Extract the roleARN and externalID
  local actual_arn
  actual_arn=$(kubectl get providerconfig.aws.upbound.io "$pc_name" -o jsonpath='{.spec.assumeRoleChain[0].roleARN}' 2>/dev/null || echo "")
  local actual_ext_id
  actual_ext_id=$(kubectl get providerconfig.aws.upbound.io "$pc_name" -o jsonpath='{.spec.assumeRoleChain[0].externalID}' 2>/dev/null || echo "")

  if [ "$actual_arn" = "$expected_arn" ] && [ "$actual_ext_id" = "crossplane-idp" ]; then
    echo -e "${GREEN}✓ ProviderConfig '$pc_name' matches expected role and externalID configuration.${NC}"
    return 0
  else
    echo -e "${RED}✗ ProviderConfig '$pc_name' has incorrect config.${NC}"
    echo "  Expected Role ARN: $expected_arn"
    echo "  Actual Role ARN:   $actual_arn"
    echo "  Expected Ext ID:  crossplane-idp"
    echo "  Actual Ext ID:   $actual_ext_id"
    return 1
  fi
}

PC_DEV_OK=0
check_provider_config "aws-dev" "$AWS_DEV_ROLE_ARN" || PC_DEV_OK=1

PC_STAGING_OK=0
check_provider_config "aws-staging" "$AWS_STAGING_ROLE_ARN" || PC_STAGING_OK=1

echo ""
echo "----------------------------------------------------------------------"
echo -e "${BOLD}Verification Summary:${NC}"

if [ $DEV_OK -eq 0 ]; then
  echo -e "  AWS idp-dev-role assume-role:      ${GREEN}PASSED${NC}"
else
  echo -e "  AWS idp-dev-role assume-role:      ${RED}FAILED${NC}"
fi

if [ $STAGING_OK -eq 0 ]; then
  echo -e "  AWS idp-staging-role assume-role:  ${GREEN}PASSED${NC}"
else
  echo -e "  AWS idp-staging-role assume-role:  ${RED}FAILED${NC}"
fi

if [ $PC_DEV_OK -eq 0 ]; then
  echo -e "  Kubernetes aws-dev config:         ${GREEN}PASSED${NC}"
else
  echo -e "  Kubernetes aws-dev config:         ${RED}FAILED${NC}"
fi

if [ $PC_STAGING_OK -eq 0 ]; then
  echo -e "  Kubernetes aws-staging config:     ${GREEN}PASSED${NC}"
else
  echo -e "  Kubernetes aws-staging config:     ${RED}FAILED${NC}"
fi

echo "----------------------------------------------------------------------"

if [ $DEV_OK -eq 0 ] && [ $STAGING_OK -eq 0 ] && [ $PC_DEV_OK -eq 0 ] && [ $PC_STAGING_OK -eq 0 ]; then
  echo -e "${GREEN}${BOLD}Verification SUCCESSFUL! All AWS and Crossplane isolation checks passed.${NC}"
  exit 0
else
  echo -e "${RED}${BOLD}Verification FAILED. Please see failures above.${NC}"
  exit 1
fi
