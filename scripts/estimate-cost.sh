#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 <instanceType> <nodeCount>"
  exit 1
fi

INSTANCE_TYPE="$1"
NODE_COUNT="$2"

# Validation
if [[ ! "$NODE_COUNT" =~ ^[0-9]+$ ]] || [ "$NODE_COUNT" -lt 1 ]; then
  echo "Error: nodeCount must be a positive integer."
  exit 1
fi

case "$INSTANCE_TYPE" in
  t3.medium|t3.large|m5.large)
    ;;
  *)
    echo "Error: instanceType must be one of t3.medium, t3.large, m5.large."
    exit 1
    ;;
esac

python3 - "$INSTANCE_TYPE" "$NODE_COUNT" << 'EOF'
import sys

instance_type = sys.argv[1]
node_count = int(sys.argv[2])

eks_hourly = 0.10
eks_monthly = 73.00

rates = {
    "t3.medium": (0.20, 144.0),
    "t3.large": (0.278, 200.0),
    "m5.large": (0.389, 280.0)
}

node_hourly, node_monthly = rates[instance_type]

total_node_hourly = node_hourly * node_count
total_node_monthly = node_monthly * node_count

total_hourly = eks_hourly + total_node_hourly
total_monthly = eks_monthly + total_node_monthly

print("==========================================")
print("         EKS Cost Estimation Report")
print("==========================================")
print(f"Instance Type:  {instance_type}")
print(f"Node Count:     {node_count}")
print("------------------------------------------")
print("1. EKS Control Plane Cost:")
print(f"   - Hourly:     ${eks_hourly:.2f}")
print(f"   - Monthly:    ${eks_monthly:.2f}")
print("")
print("2. Worker Node Cost (per node):")
print(f"   - Hourly:     ${node_hourly:.3f}")
print(f"   - Monthly:    ${node_monthly:.2f}")
print("")
print(f"3. Total Worker Node Cost ({node_count} nodes):")
print(f"   - Hourly:     ${total_node_hourly:.3f}")
print(f"   - Monthly:    ${total_node_monthly:.2f}")
print("------------------------------------------")
print("4. Total Estimated Cost:")
print(f"   - Hourly:     ${total_hourly:.3f}")
print(f"   - Monthly:    ${total_monthly:.2f}")
print("==========================================")

if total_monthly > 50.0:
    print(f"⚠️  WARNING: Estimated monthly cost (${total_monthly:.2f}) exceeds the limit of $50.00!")
EOF
