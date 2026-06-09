import sys
import os
import re
import yaml

def estimate_cost(instance_type, node_count):
    eks_monthly = 73.00
    rates = {
        "t3.medium": 144.0,
        "t3.large": 200.0,
        "m5.large": 280.0
    }
    node_monthly = rates.get(instance_type, 0.0)
    total_node_monthly = node_monthly * node_count
    total_monthly = eks_monthly + total_node_monthly
    return total_monthly

def validate_file(filepath):
    errors = []
    try:
        with open(filepath, 'r') as f:
            data = yaml.safe_load(f)
    except Exception as e:
        return {"file": filepath, "valid": False, "errors": [f"Failed to parse YAML: {e}"], "cost": 0.0}

    # Extract fields
    metadata = data.get("metadata", {}) if data else {}
    spec = data.get("spec", {}) if data else {}
    params = spec.get("parameters", {}) if spec else {}

    cluster_name = params.get("clusterName") or metadata.get("name")
    team_name = params.get("teamName")
    env = params.get("environment")
    node_count = params.get("nodeCount")
    instance_type = params.get("nodeInstanceType") or params.get("instanceType")

    # 1. Validate naming convention
    if not cluster_name:
        errors.append("Missing cluster name (metadata.name or spec.parameters.clusterName).")
    else:
        pattern = r"^[a-z]+-[a-z]+-[a-z]+-[0-9]+$"
        if not re.match(pattern, cluster_name):
            errors.append(f"Cluster name '{cluster_name}' does not match naming convention pattern '^[a-z]+-[a-z]+-[a-z]+-[0-9]+$'.")

    # 2. Validate nodeCount
    if node_count is None:
        errors.append("Missing nodeCount.")
    else:
        try:
            nodes = int(node_count)
            if nodes < 1 or nodes > 10:
                errors.append(f"nodeCount {nodes} is out of bounds (must be between 1 and 10).")
        except ValueError:
            errors.append("nodeCount must be an integer.")

    # 3. Validate instanceType
    approved_instances = ["t3.medium", "t3.large", "m5.large"]
    if not instance_type:
        errors.append("Missing instanceType / nodeInstanceType.")
    elif instance_type not in approved_instances:
        errors.append(f"instanceType '{instance_type}' is not in the approved list: {', '.join(approved_instances)}.")

    # 4. Count existing clusters for the team if team_name is present
    dev_count = 0
    staging_count = 0
    if team_name:
        team_dir = f"gitops/cluster-claims/{team_name}"
        if os.path.exists(team_dir):
            for filename in os.listdir(team_dir):
                if filename.endswith(".yaml") or filename.endswith(".yml"):
                    fpath = os.path.join(team_dir, filename)
                    try:
                        with open(fpath, 'r') as f:
                            cdata = yaml.safe_load(f)
                            if cdata:
                                cparams = cdata.get("spec", {}).get("parameters", {})
                                cenv = cparams.get("environment")
                                if cenv == "dev":
                                    dev_count += 1
                                elif cenv == "staging":
                                    staging_count += 1
                    except Exception:
                        pass
        
        # Check quota limits
        if env == "dev" and dev_count > 3:
            errors.append(f"Quota exceeded: Team '{team_name}' has {dev_count} dev clusters (limit: 3).")
        elif env == "staging" and staging_count > 2:
            errors.append(f"Quota exceeded: Team '{team_name}' has {staging_count} staging clusters (limit: 2).")

    cost = 0.0
    if not errors and instance_type in approved_instances and node_count is not None:
        cost = estimate_cost(instance_type, int(node_count))

    return {
        "file": filepath,
        "valid": len(errors) == 0,
        "errors": errors,
        "cluster_name": cluster_name,
        "team_name": team_name,
        "env": env,
        "node_count": node_count,
        "instance_type": instance_type,
        "cost": cost
    }

def main():
    files = sys.argv[1:]
    if not files:
        print("No files to validate.")
        return

    results = []
    has_failures = False

    for filepath in files:
        if not os.path.exists(filepath):
            continue
        res = validate_file(filepath)
        results.append(res)
        if not res["valid"]:
            has_failures = True

    # Generate Markdown comment
    md = []
    md.append("### 🛡️ EKS Cluster Claim Validation Report")
    md.append("")
    
    for res in results:
        md.append(f"#### File: `{res['file']}`")
        if res["valid"]:
            md.append("✅ **Validation Status: PASSED**")
            md.append("")
            md.append("| Metric | Value |")
            md.append("| --- | --- |")
            md.append(f"| **Cluster Name** | `{res['cluster_name']}` |")
            md.append(f"| **Team Name** | `{res['team_name']}` |")
            md.append(f"| **Environment** | `{res['env']}` |")
            md.append(f"| **Node Count** | `{res['node_count']}` |")
            md.append(f"| **Instance Type** | `{res['instance_type']}` |")
            md.append(f"| **Est. Monthly Cost** | `${res['cost']:.2f}` |")
            md.append("")
            if res["cost"] > 50.0:
                md.append(f"⚠️ **Cost Guardrail Warning:** Estimated monthly cost of `${res['cost']:.2f}` exceeds $50.00.")
        else:
            md.append("❌ **Validation Status: FAILED**")
            md.append("")
            md.append("**Errors:**")
            for err in res["errors"]:
                md.append(f"- {err}")
        md.append("")
        md.append("---")

    comment_text = "\n".join(md)
    with open("pr-comment.md", "w") as f:
        f.write(comment_text)

    # Output to stdout
    print(comment_text)

    if has_failures:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
