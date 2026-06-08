#!/bin/bash

# Load NVM if it exists to ensure we pick up NVM-managed Node/Yarn in non-interactive shells (like make)
export NVM_DIR="$HOME/.nvm"
if [ -s "$NVM_DIR/nvm.sh" ]; then
    . "$NVM_DIR/nvm.sh"
fi

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check tracker
FAILED_CHECKS=0

print_header() {
    echo -e "\n${BLUE}=== Checking Backstage Local Prerequisites ===${NC}"
}

print_result() {
    local status=$1
    local name=$2
    local details=$3
    if [ "$status" = "PASS" ]; then
        echo -e "[ ${GREEN}PASS${NC} ] $name - $details"
    else
        echo -e "[ ${RED}FAIL${NC} ] $name - $details"
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
    fi
}

check_node() {
    if ! command -v node &> /dev/null; then
        print_result "FAIL" "Node.js" "Node.js is not installed. Please run './scripts/setup-node.sh' to install Node.js v20.x."
        return
    fi

    local version
    version=$(node -v)
    if [[ "$version" =~ ^v20\. ]]; then
        print_result "PASS" "Node.js" "Version $version is 20.x"
    else
        print_result "FAIL" "Node.js" "Current version is $version, but 20.x is required. Please run './scripts/setup-node.sh' to install."
    fi
}

check_yarn() {
    if ! command -v yarn &> /dev/null; then
        print_result "FAIL" "Yarn" "Yarn is not installed. Please run './scripts/setup-node.sh' to configure Yarn v4 (Berry)."
        return
    fi

    local version
    version=$(yarn -v)
    if [[ "$version" =~ ^4\. ]]; then
        print_result "PASS" "Yarn" "Version $version is v4 (Berry)"
    else
        print_result "FAIL" "Yarn" "Current version is $version, but 4.x (Berry) is required. Please run './scripts/setup-node.sh' to activate."
    fi
}

check_docker() {
    local docker_ok=true

    # 1. Verify Docker CLI
    if ! command -v docker &> /dev/null; then
        print_result "FAIL" "Docker CLI" "Docker command is not available."
        docker_ok=false
    else
        local version
        version=$(docker -v | awk '{print $3}' | tr -d ',')
        print_result "PASS" "Docker CLI" "Version $version is available."
    fi

    # 2. Verify Docker Compose v2+
    if ! docker compose version &> /dev/null; then
        print_result "FAIL" "Docker Compose" "Docker Compose is not available or compose command failed."
        docker_ok=false
    else
        local compose_version
        compose_version=$(docker compose version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        local major_version
        major_version=$(echo "$compose_version" | cut -d'.' -f1)
        if [ "$major_version" -ge 2 ]; then
            print_result "PASS" "Docker Compose" "Compose v$compose_version is available (v2+)."
        else
            print_result "FAIL" "Docker Compose" "Compose version is v$compose_version, but v2+ is required."
            docker_ok=false
        fi
    fi

    # 3. Verify Docker Daemon is running
    if [ "$docker_ok" = true ]; then
        if ! docker info &> /dev/null; then
            print_result "FAIL" "Docker Daemon" "Docker daemon is NOT running. Please start Docker Desktop/Daemon."
        else
            print_result "PASS" "Docker Daemon" "Docker daemon is running."
        fi
    else
        print_result "FAIL" "Docker Daemon" "Skipping daemon check because Docker CLI/Compose check failed."
    fi
}

check_kubernetes_tools() {
    # 1. kubectl
    if ! command -v kubectl &> /dev/null; then
        print_result "FAIL" "kubectl" "kubectl is not installed."
        echo -e "${YELLOW}   ↳ Install instruction: brew install kubernetes-cli${NC}"
    else
        local version
        version=$(kubectl version --client --output=yaml | grep gitVersion | head -n1 | awk '{print $2}' | tr -d '"')
        print_result "PASS" "kubectl" "Version $version is installed."
    fi

    # 2. helm
    if ! command -v helm &> /dev/null; then
        print_result "FAIL" "helm" "helm is not installed."
        echo -e "${YELLOW}   ↳ Install instruction: brew install helm${NC}"
    else
        local helm_version
        helm_version=$(helm version --short 2>/dev/null)
        # Parse major version
        local helm_major
        helm_major=$(echo "$helm_version" | grep -oE 'v[0-9]+' | head -n1 | tr -d 'v')
        if [ -n "$helm_major" ] && [ "$helm_major" -ge 3 ]; then
            print_result "PASS" "helm" "Version $helm_version is installed (v3+)."
        else
            print_result "FAIL" "helm" "Version is $helm_version, but Helm v3+ is required."
            echo -e "${YELLOW}   ↳ Install instruction: brew install helm${NC}"
        fi
    fi

    # 3. kind
    if ! command -v kind &> /dev/null; then
        print_result "FAIL" "kind" "kind is not installed."
        echo -e "${YELLOW}   ↳ Install instruction: brew install kind${NC}"
    else
        local version
        version=$(kind version | awk '{print $2}')
        print_result "PASS" "kind" "Version $version is installed."
    fi
}

check_aws_cli() {
    local aws_ok=true

    # 1. Verify AWS CLI v2
    if ! command -v aws &> /dev/null; then
        print_result "FAIL" "AWS CLI" "AWS CLI is not installed."
        echo -e "${YELLOW}   ↳ Install instruction: brew install awscli${NC}"
        aws_ok=false
    else
        local version
        version=$(aws --version | awk '{print $1}')
        local major_version
        major_version=$(echo "$version" | cut -d'/' -f2 | cut -d'.' -f1)
        if [ "$major_version" -ge 2 ]; then
            print_result "PASS" "AWS CLI" "Version $version is installed (v2+)."
        else
            print_result "FAIL" "AWS CLI" "Version is $version, but AWS CLI v2+ is required."
            echo -e "${YELLOW}   ↳ Install instruction: brew install awscli${NC}"
            aws_ok=false
        fi
    fi

    # 2. Verify aws sts get-caller-identity
    if [ "$aws_ok" = true ]; then
        if ! aws sts get-caller-identity &> /dev/null; then
            print_result "FAIL" "AWS Authentication" "aws sts get-caller-identity failed. Please check AWS configuration / credentials."
        else
            local caller_arn
            caller_arn=$(aws sts get-caller-identity --query "Arn" --output text)
            print_result "PASS" "AWS Authentication" "Succeeded. ARN: $caller_arn"
        fi
    else
        print_result "FAIL" "AWS Authentication" "Skipping authentication check because AWS CLI check failed."
    fi
}

# Run all checks
print_header
check_node
check_yarn
check_docker
check_kubernetes_tools
check_aws_cli

echo -e "\n-----------------------------------------------"
if [ "$FAILED_CHECKS" -eq 0 ]; then
    echo -e "${GREEN}All checks passed successfully!${NC}"
    exit 0
else
    echo -e "${RED}$FAILED_CHECKS check(s) failed. Please resolve the issues above.${NC}"
    exit 1
fi
