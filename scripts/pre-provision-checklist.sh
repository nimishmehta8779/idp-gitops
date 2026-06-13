#!/usr/bin/env bash
#
# pre-provision-checklist.sh
# Validation script to ensure all prerequisites are met before EKS cluster provisioning.
#

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

echo -e "${BOLD}Running Pre-provision Checklist Checks...${NC}"
echo ""

GO_STATUS=true

# 1. AWS Budget Alert Acknowledgment
echo -e "${BOLD}[1/7] AWS Budget Alert Configuration${NC}"
echo -ne "Have you set up the manual AWS Budget alerts (\$10/month and stray resource catch-all) in the AWS Console? (y/n): "
read -r budget_ack
if [[ "$budget_ack" =~ ^[yY](e[sS])?$ ]]; then
  BUDGET_OK=true
  echo -e "AWS Budget configuration: ${GREEN}Acknowledged${NC}"
else
  BUDGET_OK=false
  GO_STATUS=false
  echo -e "AWS Budget configuration: ${RED}NOT configured${NC}"
fi
echo ""

# Load any env files if they exist to get credentials and token
for env_file in .env ../.env infrastructure/backstage/.env backstage/.env ../infrastructure/backstage/.env; do
  if [ -f "$env_file" ]; then
    # Filter comments and blank lines, then export
    export $(grep -v '^#' "$env_file" | xargs)
  fi
done

AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# 2. Unexpected AWS Resources Check
echo -e "${BOLD}[2/7] Checking for unexpected running AWS resources...${NC}"
UNEXPECTED_RESOURCES=false

# Query EKS Clusters
EKS_CLUSTERS=$(aws eks list-clusters --region "${AWS_DEFAULT_REGION}" --query "clusters" --output text 2>/dev/null || echo "")
if [ -n "$EKS_CLUSTERS" ] && [ "$EKS_CLUSTERS" != "None" ]; then
  echo -e "${RED}- Found running EKS clusters: $EKS_CLUSTERS${NC}"
  UNEXPECTED_RESOURCES=true
fi

# Query VPCs
VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:managed-by,Values=crossplane" --region "${AWS_DEFAULT_REGION}" --query "Vpcs[*].VpcId" --output text 2>/dev/null || echo "")
if [ -n "$VPCS" ] && [ "$VPCS" != "None" ]; then
  echo -e "${RED}- Found Crossplane-managed VPCs: $VPCS${NC}"
  UNEXPECTED_RESOURCES=true
fi

# Query EC2 Instances
INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:managed-by,Values=crossplane" "Name=instance-state-name,Values=running,pending" --region "${AWS_DEFAULT_REGION}" --query "Reservations[*].Instances[*].InstanceId" --output text 2>/dev/null || echo "")
if [ -n "$INSTANCES" ] && [ "$INSTANCES" != "None" ]; then
  echo -e "${RED}- Found running Crossplane-managed EC2 instances: $INSTANCES${NC}"
  UNEXPECTED_RESOURCES=true
fi

# Query IAM Roles
ROLES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `idp-`) || contains(RoleName, `crossplane-`)].RoleName' --output text 2>/dev/null || echo "")
if [ -n "$ROLES" ] && [ "$ROLES" != "None" ]; then
  echo -e "${RED}- Found Crossplane-managed IAM Roles: $ROLES${NC}"
  UNEXPECTED_RESOURCES=true
fi

if [ "$UNEXPECTED_RESOURCES" = true ]; then
  GO_STATUS=false
  RESOURCES_OK=false
  echo -e "AWS Resources: ${RED}Unexpected resources found${NC}"
else
  RESOURCES_OK=true
  echo -e "AWS Resources: ${GREEN}None found (Clean)${NC}"
fi
echo ""

# 3. GITHUB_TOKEN Check
echo -e "${BOLD}[3/7] Validating GITHUB_TOKEN...${NC}"
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo -e "${RED}- GITHUB_TOKEN is not set in environment or .env file.${NC}"
  TOKEN_OK=false
  GO_STATUS=false
else
  # Test connection using GitHub rate_limit endpoint
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/rate_limit)
  if [ "$HTTP_CODE" = "200" ]; then
    TOKEN_OK=true
    echo -e "GitHub Token: ${GREEN}Valid${NC}"
  else
    TOKEN_OK=false
    GO_STATUS=false
    echo -e "GitHub Token: ${RED}Invalid (HTTP Code $HTTP_CODE)${NC}"
  fi
fi
echo ""

# 4. Crossplane Providers Check
echo -e "${BOLD}[4/7] Checking Crossplane providers health...${NC}"
PROVIDERS_OK=true
for p in provider-aws-ec2 provider-aws-eks provider-aws-iam; do
  STATUS=$(kubectl get provider "$p" -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null || echo "False")
  if [ "$STATUS" = "True" ]; then
    echo -e "- $p: ${GREEN}Healthy${NC}"
  else
    echo -e "- $p: ${RED}Unhealthy or missing${NC}"
    PROVIDERS_OK=false
    GO_STATUS=false
  fi
done
echo ""

# 5. ProviderConfigs Check
echo -e "${BOLD}[5/7] Checking ProviderConfigs presence...${NC}"
CONFIGS_OK=true
for pc in aws-dev aws-staging; do
  if kubectl get providerconfig.aws.upbound.io "$pc" >/dev/null 2>&1; then
    echo -e "- $pc: ${GREEN}Present${NC}"
  else
    echo -e "- $pc: ${RED}Missing${NC}"
    CONFIGS_OK=false
    GO_STATUS=false
  fi
done
echo ""

# 6. Namespaces Check
echo -e "${BOLD}[6/7] Checking target namespaces...${NC}"
NAMESPACES_OK=true
for ns in clusters-dev clusters-staging; do
  if kubectl get namespace "$ns" >/dev/null 2>&1; then
    echo -e "- namespace/$ns: ${GREEN}Ready${NC}"
  else
    echo -e "- namespace/$ns: ${RED}Missing${NC}"
    NAMESPACES_OK=false
    GO_STATUS=false
  fi
done
echo ""

# 7. Kyverno Policies Check
echo -e "${BOLD}[7/7] Checking Kyverno admission control status...${NC}"
KYVERNO_OK=true

# Check if Kyverno pods are running
KYVERNO_PODS=$(kubectl get pods -n kyverno -o jsonpath='{.items[*].status.phase}' 2>/dev/null || echo "")
if echo "$KYVERNO_PODS" | grep -q "Running"; then
  echo -e "- Kyverno controller pods: ${GREEN}Running${NC}"
else
  echo -e "- Kyverno controller pods: ${RED}Not running${NC}"
  KYVERNO_OK=false
  GO_STATUS=false
fi

# Check policy count (should be 6)
POLICY_COUNT=$(kubectl get clusterpolicy -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null | wc -l | xargs)
if [ "$POLICY_COUNT" -ge 6 ]; then
  echo -e "- Kyverno policies applied: ${GREEN}$POLICY_COUNT policies${NC}"
else
  echo -e "- Kyverno policies applied: ${RED}Only $POLICY_COUNT policies found (expected 6)${NC}"
  KYVERNO_OK=false
  GO_STATUS=false
fi
echo ""

# Final Summary
echo "Pre-provision checklist"
echo "─────────────────────────────────────────"

if [ "$BUDGET_OK" = true ]; then
  echo -e "AWS budget alert configured    ✅ (acknowledged)"
else
  echo -e "AWS budget alert configured    ❌ (unacknowledged)"
fi

if [ "$RESOURCES_OK" = true ]; then
  echo -e "No unexpected AWS resources    ✅"
else
  echo -e "No unexpected AWS resources    ❌ (unexpected resources running)"
fi

if [ "$TOKEN_OK" = true ]; then
  echo -e "GitHub token valid             ✅"
else
  echo -e "GitHub token valid             ❌ (invalid token)"
fi

if [ "$PROVIDERS_OK" = true ]; then
  echo -e "Crossplane providers healthy   ✅"
else
  echo -e "Crossplane providers healthy   ❌ (unhealthy providers)"
fi

if [ "$CONFIGS_OK" = true ]; then
  echo -e "ProviderConfigs present        ✅"
else
  echo -e "ProviderConfigs present        ❌ (missing dev/staging config)"
fi

if [ "$NAMESPACES_OK" = true ]; then
  echo -e "Namespaces ready               ✅"
else
  echo -e "Namespaces ready               ❌ (missing clusters-dev/staging)"
fi

if [ "$KYVERNO_OK" = true ]; then
  echo -e "Kyverno enforcing policies     ✅"
else
  echo -e "Kyverno enforcing policies     ❌ (Kyverno or policies unhealthy)"
fi

echo "─────────────────────────────────────────"

if [ "$GO_STATUS" = true ]; then
  echo -e "Status: GO ✅ — safe to provision"
  exit 0
else
  echo -e "Status: NO-GO ❌ — unsafe to provision. Please resolve failures above."
  exit 1
fi
