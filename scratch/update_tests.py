import os
import yaml

tests_dir = "/Users/nm/devel/idp/infrastructure/kyverno/tests"

for filename in os.listdir(tests_dir):
    if filename.endswith(".yaml"):
        file_path = os.path.join(tests_dir, filename)
        with open(file_path, 'r') as f:
            content = yaml.safe_load(f)
        
        # Check if it has spec.parameters
        if "spec" in content and "parameters" in content["spec"]:
            params = content["spec"]["parameters"]
            if "networkRef" not in params:
                print(f"Adding networkRef: dev-network to {filename}")
                params["networkRef"] = "dev-network"
                # If writeConnectionSecretToRef has namespace, remove it
                if "writeConnectionSecretToRef" in content["spec"]:
                    ref = content["spec"]["writeConnectionSecretToRef"]
                    if "namespace" in ref:
                        del ref["namespace"]
                
                with open(file_path, 'w') as f:
                    yaml.dump(content, f, sort_keys=False, default_flow_style=False)
