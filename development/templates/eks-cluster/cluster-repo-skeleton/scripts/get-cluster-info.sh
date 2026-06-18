#!/bin/bash

# get-cluster-info.sh
# Local script to fetch cluster information without needing GitHub Actions

set -e

CLUSTER_NAME="${1:-$CLUSTER_NAME}"
REGION="${2:-$AWS_REGION}"

if [ -z "$CLUSTER_NAME" ] || [ -z "$REGION" ]; then
    echo "Usage: ./scripts/get-cluster-info.sh <cluster-name> [region]"
    echo ""
    echo "Environment variables:"
    echo "  CLUSTER_NAME - EKS cluster name"
    echo "  AWS_REGION   - AWS region"
    exit 1
fi

echo "📊 Fetching cluster information..."
echo ""

# Check if cluster exists
if ! aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &>/dev/null; then
    echo "❌ Cluster not found: $CLUSTER_NAME in $REGION"
    exit 1
fi

# Get cluster details
CLUSTER_INFO=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION")

ENDPOINT=$(echo "$CLUSTER_INFO" | jq -r '.cluster.endpoint')
ARN=$(echo "$CLUSTER_INFO" | jq -r '.cluster.arn')
STATUS=$(echo "$CLUSTER_INFO" | jq -r '.cluster.status')
VERSION=$(echo "$CLUSTER_INFO" | jq -r '.cluster.version')
CREATED_AT=$(echo "$CLUSTER_INFO" | jq -r '.cluster.createdAt')
OIDC_ISSUER=$(echo "$CLUSTER_INFO" | jq -r '.cluster.identity.oidc.issuer // "Not configured"')

echo "=== Cluster Information ==="
echo "Name:             $CLUSTER_NAME"
echo "Status:           $STATUS"
echo "Kubernetes:       $VERSION"
echo "Region:           $REGION"
echo "Created:          $CREATED_AT"
echo ""

echo "=== Endpoints & ARNs ==="
echo "Endpoint:         $ENDPOINT"
echo "ARN:              $ARN"
echo "OIDC Issuer:      $OIDC_ISSUER"
echo ""

# Get node groups
echo "=== Node Groups ==="
NODE_GROUPS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --region "$REGION" --query 'nodegroups' --output text)

if [ -z "$NODE_GROUPS" ]; then
    echo "No node groups found"
else
    for ng in $NODE_GROUPS; do
        NG_INFO=$(aws eks describe-nodegroup \
            --cluster-name "$CLUSTER_NAME" \
            --nodegroup-name "$ng" \
            --region "$REGION")

        NG_STATUS=$(echo "$NG_INFO" | jq -r '.nodegroup.status')
        NG_VERSION=$(echo "$NG_INFO" | jq -r '.nodegroup.version')
        DESIRED=$(echo "$NG_INFO" | jq -r '.nodegroup.scalingConfig.desiredSize')
        CURRENT=$(echo "$NG_INFO" | jq -r '.nodegroup.scalingConfig.minSize')
        MAX=$(echo "$NG_INFO" | jq -r '.nodegroup.scalingConfig.maxSize')

        echo "  $ng:"
        echo "    Status:   $NG_STATUS"
        echo "    K8s:      $NG_VERSION"
        echo "    Nodes:    desired=$DESIRED, current=$CURRENT, max=$MAX"
    done
fi
echo ""

# Get addons
echo "=== Add-ons ==="
ADDONS=$(aws eks list-addons --cluster-name "$CLUSTER_NAME" --region "$REGION" --query 'addons' --output text)

if [ -z "$ADDONS" ]; then
    echo "No add-ons deployed"
else
    for addon in $ADDONS; do
        ADDON_INFO=$(aws eks describe-addon \
            --cluster-name "$CLUSTER_NAME" \
            --addon-name "$addon" \
            --region "$REGION")

        ADDON_VERSION=$(echo "$ADDON_INFO" | jq -r '.addon.addonVersion')
        ADDON_STATUS=$(echo "$ADDON_INFO" | jq -r '.addon.addonHealth.issues | if length == 0 then "ACTIVE" else "DEGRADED" end')
        echo "  $addon: $ADDON_VERSION ($ADDON_STATUS)"
    done
fi
echo ""

echo "✅ Done!"
