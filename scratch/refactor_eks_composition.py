import sys
import os
import yaml

# Path to EKS composition
comp_path = "/Users/nm/devel/idp/infrastructure/crossplane/eks/composition.yaml"

with open(comp_path, 'r') as f:
    data = yaml.safe_load(f)

# Resources to remove
resources_to_remove = {
    "vpc", "subnet-a", "subnet-b", "igw", "route-table",
    "route-to-igw", "rta-subnet-a", "rta-subnet-b"
}

# Filter resources
all_resources = data["spec"]["pipeline"][0]["input"]["resources"]
filtered_resources = []

for res in all_resources:
    if res["name"] in resources_to_remove:
        print(f"Removing resource: {res['name']}")
        continue
    
    # If it is eks-cluster or node-group, update subnet references
    if res["name"] in ["eks-cluster", "node-group"]:
        print(f"Updating patches for resource: {res['name']}")
        for patch in res.get("patches", []):
            # If patch targets subnet name, change fromFieldPath to spec.parameters.networkRef
            to_path = patch.get("toFieldPath", "")
            if "subnetIdRefs" in to_path or "vpcConfig[0].subnetIdRefs" in to_path:
                if patch.get("fromFieldPath") == "spec.parameters.clusterName":
                    print(f"  Updating patch: {patch['fromFieldPath']} -> {to_path}")
                    patch["fromFieldPath"] = "spec.parameters.networkRef"
                    
    filtered_resources.append(res)

data["spec"]["pipeline"][0]["input"]["resources"] = filtered_resources

# Save back to file
with open(comp_path, 'w') as f:
    yaml.dump(data, f, sort_keys=False, default_flow_style=False)

print("EKS composition refactored successfully.")
