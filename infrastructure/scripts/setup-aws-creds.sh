#!/usr/bin/env bash
set -euo pipefail

# Verify required environment variables
missing=""
if [[ -z "${AWS_ACCESS_KEY_ID:-}" ]]; then
  missing+="AWS_ACCESS_KEY_ID "
fi
if [[ -z "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  missing+="AWS_SECRET_ACCESS_KEY "
fi
if [[ -z "${AWS_DEFAULT_REGION:-}" ]]; then
  missing+="AWS_DEFAULT_REGION "
fi

if [[ -n "$missing" ]]; then
  echo "Error: the following required environment variables are not set: $missing"
  exit 1
fi

# Create temporary credentials file in INI format
cat <<EOF > /tmp/aws-credentials.ini
[default]
aws_access_key_id=${AWS_ACCESS_KEY_ID}
aws_secret_access_key=${AWS_SECRET_ACCESS_KEY}
aws_default_region=${AWS_DEFAULT_REGION}
EOF

if [[ -n "${AWS_SESSION_TOKEN:-}" ]]; then
  echo "aws_session_token=${AWS_SESSION_TOKEN}" >> /tmp/aws-credentials.ini
fi


# Create or update the Kubernetes secret in the crossplane-system namespace
# The secret must contain a "credentials" key with the INI file contents
if kubectl get secret aws-credentials -n crossplane-system >/dev/null 2>&1; then
  echo "Secret 'aws-credentials' exists – updating..."
  kubectl create secret generic aws-credentials \
    -n crossplane-system \
    --from-file=credentials=/tmp/aws-credentials.ini \
    --dry-run=client -o yaml | kubectl apply -f -
else
  echo "Creating secret 'aws-credentials'..."
  kubectl create secret generic aws-credentials \
    -n crossplane-system \
    --from-file=credentials=/tmp/aws-credentials.ini
fi

echo "AWS credentials secret 'aws-credentials' successfully created/updated in namespace 'crossplane-system'."
