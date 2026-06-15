#!/bin/bash
set -e

# Load GITHUB_TOKEN from env or local .env
if [ -z "$GITHUB_TOKEN" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ENV_FILE="${SCRIPT_DIR}/../backstage/.env"
  if [ -f "$ENV_FILE" ]; then
    echo "Loading GITHUB_TOKEN from ${ENV_FILE}..."
    export $(grep -v '^#' "$ENV_FILE" | xargs)
  fi
fi

if [ -z "$GITHUB_TOKEN" ]; then
  echo "Error: GITHUB_TOKEN is not set"
  exit 1
fi

TEAM_NAME=$1
if [ -z "$TEAM_NAME" ]; then
  echo "Usage: $0 <team-name>"
  echo "Example: $0 team-alpha"
  exit 1
fi

REPO="${TEAM_NAME}-infra"
OWNER="nimishmehta8779"

# Determine variables for substitution
TEAM_SUFFIX=${TEAM_NAME#team-}
TEAM_CAP=$(echo "$TEAM_SUFFIX" | awk '{print toupper(substr($0,1,1))substr($0,2)}')
DISPLAY_NAME="$TEAM_CAP Team"
COST_CENTER="CC-$(echo "$TEAM_SUFFIX" | tr '[:lower:]' '[:upper:]')"
PRIMARY_REGION="us-east-1"
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TEAM_EMAIL="${TEAM_NAME}@platform.io"

echo "=== Bootstrapping $REPO ==="
echo "Display Name: $DISPLAY_NAME"
echo "Cost Center: $COST_CENTER"
echo "Region: $PRIMARY_REGION"
echo "Date: $CURRENT_DATE"

# 1. Create repository
echo "Creating repository ${OWNER}/${REPO} on GitHub..."
CREATE_RES=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/user/repos \
  -d "{\"name\":\"${REPO}\",\"private\":true,\"auto_init\":true}")

if [ "$CREATE_RES" -eq 201 ]; then
  echo "Repository ${REPO} created successfully."
  # Give GitHub a moment to initialize the repo
  sleep 2
elif [ "$CREATE_RES" -eq 422 ]; then
  echo "Repository ${REPO} already exists."
else
  echo "Warning/Error: Repository creation response code: $CREATE_RES"
fi

# Helper function to upload file
upload_file() {
  local dest_path="$1"
  local src_file="$2"
  local commit_msg="$3"

  local content
  if [ -f "$src_file" ]; then
    export PY_TEAM_NAME="$TEAM_NAME"
    export PY_DISPLAY_NAME="$DISPLAY_NAME"
    export PY_COST_CENTER="$COST_CENTER"
    export PY_PRIMARY_REGION="$PRIMARY_REGION"
    export PY_CURRENT_DATE="$CURRENT_DATE"
    export PY_TEAM_EMAIL="$TEAM_EMAIL"

    content=$(python3 -c "
import os, sys
team_name = os.environ['PY_TEAM_NAME']
display_name = os.environ['PY_DISPLAY_NAME']
cost_center = os.environ['PY_COST_CENTER']
primary_region = os.environ['PY_PRIMARY_REGION']
current_date = os.environ['PY_CURRENT_DATE']
team_email = os.environ['PY_TEAM_EMAIL']

with open('$src_file', 'r') as f:
    text = f.read()

text = text.replace('\${{ values.teamName }}', team_name)
text = text.replace('\${{ values.displayName }}', display_name)
text = text.replace('\${{ values.costCenter }}', cost_center)
text = text.replace('\${{ values.primaryRegion }}', primary_region)
text = text.replace('\${{ values.currentDate }}', current_date)
text = text.replace('\${{ values.teamEmail }}', team_email)

# also handle double brace versions just in case
text = text.replace('\${{values.teamName}}', team_name)
text = text.replace('\${{values.displayName}}', display_name)
text = text.replace('\${{values.costCenter}}', cost_center)
text = text.replace('\${{values.primaryRegion}}', primary_region)
text = text.replace('\${{values.currentDate}}', current_date)
text = text.replace('\${{values.teamEmail}}', team_email)

if 'members:' in text:
    lines = text.split('\n')
    out_lines = []
    skip = False
    for line in lines:
        if line.strip().startswith('members:'):
            out_lines.append('  members:')
            out_lines.append('    - nimishmehta8779')
            skip = True
            continue
        if skip:
            continue
        out_lines.append(line)
    text = '\n'.join(out_lines)

sys.stdout.write(text)
")
  else
    content="$src_file"
  fi

  # Base64 encode using Python to avoid OS-specific base64 wrapping issues
  local b64_content=$(python3 -c "import base64; print(base64.b64encode('''$content'''.encode('utf-8')).decode('utf-8'))")

  # Fetch existing file SHA if it exists
  local existing_sha=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/${OWNER}/${REPO}/contents/${dest_path}?ref=main" \
    | jq -r '.sha // empty')

  local body
  if [ -n "$existing_sha" ] && [ "$existing_sha" != "null" ]; then
    body=$(jq -n --arg msg "$commit_msg" --arg cnt "$b64_content" --arg sha "$existing_sha" \
      '{message: $msg, content: $cnt, sha: $sha, branch: "main"}')
  else
    body=$(jq -n --arg msg "$commit_msg" --arg cnt "$b64_content" \
      '{message: $msg, content: $cnt, branch: "main"}')
  fi

  local upload_res=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    "https://api.github.com/repos/${OWNER}/${REPO}/contents/${dest_path}" \
    -d "$body")

  if [ "$upload_res" -eq 200 ] || [ "$upload_res" -eq 201 ]; then
    echo "  Uploaded $dest_path successfully."
  else
    echo "  Failed to upload $dest_path: HTTP $upload_res"
  fi
}

# 2. Upload directories .gitkeeps
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKELETON_DIR="${SCRIPT_DIR}/../../development/templates/onboard-team/skeleton"

echo "Uploading repository directory structure..."
upload_file "eks/.gitkeep" "# Keep directory" "chore: add eks directory"
upload_file "rds/.gitkeep" "# Keep directory" "chore: add rds directory"
upload_file "s3/.gitkeep" "# Keep directory" "chore: add s3 directory"
upload_file "ec2/.gitkeep" "# Keep directory" "chore: add ec2 directory"
upload_file "opensearch/.gitkeep" "# Keep directory" "chore: add opensearch directory"
upload_file "elasticache/.gitkeep" "# Keep directory" "chore: add elasticache directory"

# 3. Upload templated files
echo "Uploading templated files from skeleton..."
upload_file "README.md" "${SKELETON_DIR}/README.md" "chore: add README"
upload_file "catalog-info.yaml" "${SKELETON_DIR}/catalog-info.yaml" "chore: add catalog-info"
upload_file ".github/CODEOWNERS" "${SKELETON_DIR}/.github/CODEOWNERS" "chore: add CODEOWNERS"
upload_file ".github/workflows/validate-claims.yaml" "${SKELETON_DIR}/.github/workflows/validate-claims.yaml" "chore: add validation workflow"
upload_file ".github/workflows/register-catalog.yaml" "${SKELETON_DIR}/.github/workflows/register-catalog.yaml" "chore: add registration workflow"

# 4. Set up branch protection
echo "Applying branch protection to main branch..."
protection_body='{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "validate-claims"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1
  },
  "restrictions": null
}'

protect_res=$(curl -s -o /dev/null -w "%{http_code}" -X PUT \
  -H "Authorization: token $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/${OWNER}/${REPO}/branches/main/protection" \
  -d "$protection_body")

if [ "$protect_res" -eq 200 ]; then
  echo "Branch protection applied successfully."
else
  echo "Failed to apply branch protection: HTTP $protect_res"
fi

echo "=== Bootstrapped $REPO successfully ==="
