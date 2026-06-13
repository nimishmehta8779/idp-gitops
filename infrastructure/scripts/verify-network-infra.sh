#!/usr/bin/env bash
#
# verify-network-infra.sh
# Verification script for Separated Network Infrastructure task.
#

set -uo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "${BOLD}Starting Separated Network Infrastructure Verification...${NC}"
echo "----------------------------------------------------------------------"

# Resolve absolute paths relative to script location
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

NETWORK_CLAIM_FILE="$PROJECT_ROOT/infrastructure/crossplane/network/claim-example.yaml"
EKS_CLAIM_FILE="$PROJECT_ROOT/infrastructure/crossplane/eks/claim-example.yaml"

# 1. XNetwork XRD is Established
echo -n "Checking XNetwork XRD Established... "
STATUS_NET_XRD=$(kubectl get xrd xnetworks.platform.io -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null || echo "False")
if [ "$STATUS_NET_XRD" = "True" ]; then
  echo -e "${GREEN}PASSED${NC}"
  NET_XRD_OK=true
else
  echo -e "${RED}FAILED${NC} (Status: $STATUS_NET_XRD)"
  NET_XRD_OK=false
fi

# 2. Network Composition exists
echo -n "Checking Network Composition... "
if kubectl get composition network-infra &>/dev/null; then
  echo -e "${GREEN}PASSED${NC}"
  NET_COMP_OK=true
else
  echo -e "${RED}FAILED${NC} (network-infra not found)"
  NET_COMP_OK=false
fi

# 3. XEKSCluster XRD still Established
echo -n "Checking XEKSCluster XRD Established... "
STATUS_EKS_XRD=$(kubectl get xrd xeksclusters.platform.io -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null || echo "False")
if [ "$STATUS_EKS_XRD" = "True" ]; then
  echo -e "${GREEN}PASSED${NC}"
  EKS_XRD_OK=true
else
  echo -e "${RED}FAILED${NC} (Status: $STATUS_EKS_XRD)"
  EKS_XRD_OK=false
fi

# 4. EKS Composition references network not creates VPC
echo -n "Checking EKS Composition decoupled VPC... "
EKS_COMP_YAML=$(kubectl get composition eks-cluster -o yaml 2>/dev/null || echo "")
if [ -n "$EKS_COMP_YAML" ]; then
  # Should not create VPC
  if echo "$EKS_COMP_YAML" | grep -q "kind: VPC"; then
    echo -e "${RED}FAILED${NC} (EKS Composition still defines VPC)"
    EKS_DECOUPLED_OK=false
  # Should reference networkRef in subnet patches
  elif ! echo "$EKS_COMP_YAML" | grep -q "networkRef"; then
    echo -e "${RED}FAILED${NC} (EKS Composition does not reference networkRef)"
    EKS_DECOUPLED_OK=false
  else
    echo -e "${GREEN}PASSED${NC}"
    EKS_DECOUPLED_OK=true
  fi
else
  echo -e "${RED}FAILED${NC} (eks-cluster composition not found)"
  EKS_DECOUPLED_OK=false
fi

# 5. EnvironmentConfig exists per environment
echo -n "Checking EnvironmentConfigs... "
if kubectl get environmentconfig dev-environment &>/dev/null && kubectl get environmentconfig staging-environment &>/dev/null; then
  echo -e "${GREEN}PASSED${NC}"
  ENV_CONFIG_OK=true
else
  echo -e "${RED}FAILED${NC} (Missing dev-environment or staging-environment)"
  ENV_CONFIG_OK=false
fi

# 6. Example Network claim applies without error
echo -n "Validating Example Network claim... "
if [ -f "$NETWORK_CLAIM_FILE" ]; then
  if kubectl apply -f "$NETWORK_CLAIM_FILE" --dry-run=server &>/dev/null; then
    # Actually apply it to ensure no validation error
    kubectl apply -f "$NETWORK_CLAIM_FILE" &>/dev/null
    echo -e "${GREEN}PASSED${NC}"
    NET_CLAIM_OK=true
  else
    echo -e "${RED}FAILED${NC} (Failed dry-run apply)"
    NET_CLAIM_OK=false
  fi
else
  echo -e "${RED}FAILED${NC} (claim-example.yaml not found at $NETWORK_CLAIM_FILE)"
  NET_CLAIM_OK=false
fi

# 7. Example EKS claim references network correctly
echo -n "Validating Example EKS claim references network... "
if [ -f "$EKS_CLAIM_FILE" ]; then
  NET_REF=$(grep "networkRef:" "$EKS_CLAIM_FILE" | awk '{print $2}' | xargs || echo "")
  if [ "$NET_REF" = "dev-network" ]; then
    # Dry-run apply
    if kubectl apply -f "$EKS_CLAIM_FILE" --dry-run=server &>/dev/null; then
      echo -e "${GREEN}PASSED${NC}"
      EKS_CLAIM_OK=true
    else
      echo -e "${RED}FAILED${NC} (Dry-run apply rejected: $(kubectl apply -f "$EKS_CLAIM_FILE" --dry-run=server 2>&1))"
      EKS_CLAIM_OK=false
    fi
  else
    echo -e "${RED}FAILED${NC} (Expected networkRef 'dev-network', got '$NET_REF')"
    EKS_CLAIM_OK=false
  fi
else
  echo -e "${RED}FAILED${NC} (claim-example.yaml not found at $EKS_CLAIM_FILE)"
  EKS_CLAIM_OK=false
fi

# 8. All Kyverno policies still pass
echo -n "Testing Kyverno Policies... "
# Run existing kyverno test suite
if make -C "$PROJECT_ROOT" test-kyverno &>/dev/null; then
  echo -e "${GREEN}PASSED${NC}"
  KYVERNO_OK=true
else
  echo -e "${RED}FAILED${NC} (Kyverno test suite failed)"
  KYVERNO_OK=false
fi

# Cleanup applied claim-example if needed
kubectl delete -f "$NETWORK_CLAIM_FILE" --ignore-not-found &>/dev/null

echo "----------------------------------------------------------------------"
echo -e "${BOLD}Verification Summary:${NC}"
echo -e "  1. XNetwork XRD Established:           $( [ "$NET_XRD_OK" = true ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}" )"
echo -e "  2. Network Composition exists:          $( [ "$NET_COMP_OK" = true ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}" )"
echo -e "  3. XEKSCluster XRD Established:        $( [ "$EKS_XRD_OK" = true ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}" )"
echo -e "  4. EKS Composition Decoupled VPC:      $( [ "$EKS_DECOUPLED_OK" = true ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}" )"
echo -e "  5. EnvironmentConfigs exists:          $( [ "$ENV_CONFIG_OK" = true ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}" )"
echo -e "  6. Network claim dry-run:              $( [ "$NET_CLAIM_OK" = true ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}" )"
echo -e "  7. EKS claim network references:       $( [ "$EKS_CLAIM_OK" = true ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}" )"
echo -e "  8. Kyverno policies pass:              $( [ "$KYVERNO_OK" = true ] && echo -e "${GREEN}OK${NC}" || echo -e "${RED}FAIL${NC}" )"
echo "----------------------------------------------------------------------"

if [ "$NET_XRD_OK" = true ] && [ "$NET_COMP_OK" = true ] && [ "$EKS_XRD_OK" = true ] && \
   [ "$EKS_DECOUPLED_OK" = true ] && [ "$ENV_CONFIG_OK" = true ] && [ "$NET_CLAIM_OK" = true ] && \
   [ "$EKS_CLAIM_OK" = true ] && [ "$KYVERNO_OK" = true ]; then
  echo -e "${GREEN}${BOLD}Verification SUCCESSFUL! Separated network infrastructure architecture verified.${NC}"
  exit 0
else
  echo -e "${RED}${BOLD}Verification FAILED. Please resolve issues above.${NC}"
  exit 1
fi
