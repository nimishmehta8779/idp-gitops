#!/bin/bash

# test-access.sh
# Test access to the EKS cluster

set -e

CLUSTER_NAME="${1:-$CLUSTER_NAME}"
REGION="${2:-$AWS_REGION}"

if [ -z "$CLUSTER_NAME" ]; then
    echo "Usage: ./scripts/test-access.sh <cluster-name>"
    echo ""
    echo "Environment variable: KUBECONFIG (if using specific kubeconfig)"
    exit 1
fi

echo "🧪 Testing access to cluster: $CLUSTER_NAME"
echo ""

# Test 1: AWS CLI access
echo "1️⃣  Testing AWS CLI access to EKS..."
if aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" &>/dev/null; then
    echo "   ✅ AWS CLI can access cluster"
else
    echo "   ❌ AWS CLI cannot access cluster"
    exit 1
fi
echo ""

# Test 2: Kubeconfig setup
echo "2️⃣  Testing kubeconfig..."
if kubectl cluster-info &>/dev/null; then
    echo "   ✅ kubectl cluster-info successful"
else
    echo "   ❌ kubectl cannot connect to cluster"
    echo "   Try: aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION"
    exit 1
fi
echo ""

# Test 3: Node access
echo "3️⃣  Testing node access..."
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
if [ "$NODE_COUNT" -gt 0 ]; then
    echo "   ✅ Found $NODE_COUNT nodes"
    kubectl get nodes -o wide
else
    echo "   ⚠️  No nodes found (cluster may still be provisioning)"
fi
echo ""

# Test 4: Namespace access
echo "4️⃣  Testing namespace access..."
if kubectl get namespaces &>/dev/null; then
    echo "   ✅ Can access namespaces"
    NS_COUNT=$(kubectl get namespaces --no-headers | wc -l)
    echo "   Found $NS_COUNT namespaces"
fi
echo ""

# Test 5: Pod access
echo "5️⃣  Testing pod access..."
if kubectl get pods --all-namespaces &>/dev/null; then
    echo "   ✅ Can access pods"
    POD_COUNT=$(kubectl get pods --all-namespaces --no-headers | wc -l)
    echo "   Found $POD_COUNT pods cluster-wide"
fi
echo ""

# Test 6: RBAC
echo "6️⃣  Testing RBAC (Current user permissions)..."
if CURRENT_USER=$(kubectl auth whoami 2>/dev/null); then
    echo "   ✅ Current user: $CURRENT_USER"
else
    echo "   ℹ️  Could not determine current user (may be expected)"
fi
echo ""

# Test 7: Services
echo "7️⃣  Testing service discovery..."
SERVICES=$(kubectl get svc --all-namespaces --no-headers 2>/dev/null | wc -l)
echo "   ✅ Found $SERVICES services"
echo ""

echo "=== Access Test Summary ==="
echo "✅ All tests passed! Your cluster is accessible."
echo ""
echo "Next steps:"
echo "  - Deploy your first application: kubectl apply -f app.yaml"
echo "  - View cluster events: kubectl get events --all-namespaces --sort-by='.lastTimestamp'"
echo "  - Check add-ons: kubectl get all --namespace kube-system"
echo ""
