#!/usr/bin/env bash
set -euo pipefail

# Verify base default region (defaults to us-east-1 if not set)
AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

# Retrieve env-specific key variables
dev_access_key="${AWS_ACCESS_KEY_ID_DEV:-}"
dev_secret_key="${AWS_SECRET_ACCESS_KEY_DEV:-}"
staging_access_key="${AWS_ACCESS_KEY_ID_STAGING:-}"
staging_secret_key="${AWS_SECRET_ACCESS_KEY_STAGING:-}"

# Retrieve fallback generic key variables
gen_access_key="${AWS_ACCESS_KEY_ID:-}"
gen_secret_key="${AWS_SECRET_ACCESS_KEY:-}"

# Determine mode
if [[ -n "$dev_access_key" && -n "$dev_secret_key" ]] || [[ -n "$staging_access_key" && -n "$staging_secret_key" ]]; then
  mode="multi-account"
else
  mode="single-account simulation"
fi

echo "==========================================="
echo " AWS Credentials Setup: $mode mode"
echo "==========================================="

if [[ "$mode" == "single-account simulation" ]]; then
  # In single-account simulation mode, generic variables must be present
  if [[ -z "$gen_access_key" || -z "$gen_secret_key" ]]; then
    echo "Error: single-account simulation mode active, but generic AWS_ACCESS_KEY_ID or AWS_SECRET_ACCESS_KEY is not set."
    echo "Please set either generic AWS variables or environment-specific (DEV/STAGING) AWS variables."
    exit 1
  fi
  
  dev_access_key="$gen_access_key"
  dev_secret_key="$gen_secret_key"
  staging_access_key="$gen_access_key"
  staging_secret_key="$gen_secret_key"
else
  # In multi-account mode, fall back to generic keys for each environment if they are not explicitly set
  if [[ -z "$dev_access_key" || -z "$dev_secret_key" ]]; then
    if [[ -n "$gen_access_key" && -n "$gen_secret_key" ]]; then
      echo "Dev credentials not set - falling back to generic credentials."
      dev_access_key="$gen_access_key"
      dev_secret_key="$gen_secret_key"
    else
      echo "Error: Dev credentials not set and no generic credentials available."
      exit 1
    fi
  fi

  if [[ -z "$staging_access_key" || -z "$staging_secret_key" ]]; then
    if [[ -n "$gen_access_key" && -n "$gen_secret_key" ]]; then
      echo "Staging credentials not set - falling back to generic credentials."
      staging_access_key="$gen_access_key"
      staging_secret_key="$gen_secret_key"
    else
      echo "Error: Staging credentials not set and no generic credentials available."
      exit 1
    fi
  fi
fi

create_aws_secret() {
  local env="$1"
  local key_id="$2"
  local secret_key="$3"
  local region="$4"
  local secret_name="aws-credentials-$env"
  local ini_file="/tmp/aws-credentials-$env.ini"

  # Create temp credentials file in INI format
  cat <<EOF > "$ini_file"
[default]
aws_access_key_id=${key_id}
aws_secret_access_key=${secret_key}
aws_default_region=${region}
EOF

  # Append session token if available
  # First check environment-specific session token, then fallback to generic
  local env_upper
  env_upper=$(echo "$env" | tr '[:lower:]' '[:upper:]')
  local token_var="AWS_SESSION_TOKEN_$env_upper"
  local token="${!token_var:-${AWS_SESSION_TOKEN:-}}"

  if [[ -n "$token" ]]; then
    echo "aws_session_token=${token}" >> "$ini_file"
  fi

  # Create or update the Kubernetes secret in the crossplane-system namespace
  if kubectl get secret "$secret_name" -n crossplane-system >/dev/null 2>&1; then
    echo "Secret '$secret_name' exists – updating..."
    kubectl create secret generic "$secret_name" \
      -n crossplane-system \
      --from-file=credentials="$ini_file" \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    echo "Creating secret '$secret_name'..."
    kubectl create secret generic "$secret_name" \
      -n crossplane-system \
      --from-file=credentials="$ini_file"
  fi

  # Clean up temp file
  rm -f "$ini_file"
}

# Clean up stale generic secret if present
if kubectl get secret aws-credentials -n crossplane-system >/dev/null 2>&1; then
  echo "Removing stale generic secret 'aws-credentials'..."
  kubectl delete secret aws-credentials -n crossplane-system
fi

# Create Dev and Staging secrets
create_aws_secret "dev" "$dev_access_key" "$dev_secret_key" "${AWS_DEFAULT_REGION_DEV:-$AWS_DEFAULT_REGION}"
create_aws_secret "staging" "$staging_access_key" "$staging_secret_key" "${AWS_DEFAULT_REGION_STAGING:-$AWS_DEFAULT_REGION}"

echo "AWS credentials successfully set up for both 'dev' and 'staging' environments."
