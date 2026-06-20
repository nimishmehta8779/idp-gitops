# AWS Agent Testing Plan — CAIPE Native Tools

## Quick Reference: Real vs Empty Queries

| Query | Real Data? | Expected Result |
|-------|-----------|-----------------|
| List IAM roles matching "idp-*" | ✅ YES | 3 roles returned |
| Get AWS account ID | ✅ YES | 415703161648 |
| List all VPCs | ✅ YES | 2 VPCs returned |
| List security groups | ✅ YES | 3 SGs returned |
| Get IAM user details | ✅ YES | Root user, created 2012 |
| **List EKS clusters** | ❌ EMPTY | No clusters (decommissioned) |
| **Describe alpha-dev-general-1** | ❌ EMPTY | Cluster doesn't exist |
| **AWS cost analysis (30 days)** | ✅ YES | Should return spend data |

---

## Test Queries (Use These for CAIPE Testing)

### Non-Empty Queries (Will Return Data)

1. **"List all my IAM roles that start with 'idp-'"**
   - Expected: 3 roles (idp-dev-role, idp-staging-role, idp-platform-admins)
   - Tool: `aws_cli_execute`
   - Command: `aws iam list-roles --query 'Roles[?contains(RoleName, \`idp-\`)].RoleName'`

2. **"What is my AWS account ID?"**
   - Expected: 415703161648
   - Tool: `aws_cli_execute`
   - Command: `aws sts get-caller-identity`

3. **"Show me all my VPCs"**
   - Expected: 2 VPCs with their names
   - Tool: `aws_cli_execute`
   - Command: `aws ec2 describe-vpcs`

4. **"List my security groups"**
   - Expected: 3 security groups
   - Tool: `aws_cli_execute`
   - Command: `aws ec2 describe-security-groups`

5. **"Tell me about my IAM user"**
   - Expected: User ARN and creation date
   - Tool: `aws_cli_execute`
   - Command: `aws iam get-user`

6. **"What have I spent on AWS in the last 30 days?"**
   - Expected: Cost breakdown by service
   - Tool: `aws_cli_execute`
   - Command: `aws ce get-cost-and-usage`
   - Skill: `aws-cost-analysis`

### Empty Queries (Will Return Nothing - Expected Behavior)

These will return empty because resources don't exist:

1. **"List all my EKS clusters"**
   - Expected: Empty list (no clusters)
   - Reason: alpha-dev-general-1 was decommissioned on 2026-06-20
   - Command: `aws eks list-clusters`

2. **"Describe the alpha-dev-general-1 cluster"**
   - Expected: Cluster not found error
   - Reason: Cluster decommissioned
   - Command: `aws eks describe-cluster --name alpha-dev-general-1`

---

## How to Test

### Via Claude Agent (Recommended)
```
Use the @aws tool or ask questions naturally:
"What IAM roles do I have for IDP?"
"What's my AWS account ID?"
"List my VPCs"
```

### Via CAIPE Skills
CAIPE exposes high-level skills:
- `aws-cost-analysis` — AWS spending
- `check-deployment-status` — ArgoCD health
- `cluster-resource-health` — Cluster metrics

### Via Direct API (if needed)
```bash
# CAIPE is available on port 8082
curl http://localhost:8082/skills | jq '.skills[].id'
```

---

## Success Criteria

✅ **CAIPE Native Tools Are Sufficient If:**
- Queries 1-5 return real, accurate AWS data
- Data matches direct AWS CLI output
- `aws_cli_execute` is being used (check logs)
- Response formatting is clear and actionable

❌ **CAIPE Native Tools Are Insufficient If:**
- Any query returns hallucinated data
- Tool invocation fails or times out
- Response formatting is confusing
- Cost analysis doesn't work

---

## Decision

**Current Status**: ✅ Ready for testing
- CAIPE has `aws_cli_execute` and `eks_kubectl_execute` tools
- AWS CLI credentials are working
- Skills are loaded and synced

**Next Step**: Run the 6 non-empty queries above through CAIPE/agent interface and verify real data is returned.

**If All Pass**: Document decision to use native CAIPE tools, skip AWS Labs MCP servers.
**If Any Fail**: Identify specific gap and consider minimal MCP server for that capability only.

---

## Related Files
- `.backups/RECOVERY.md` — System recovery procedures
- `EKS_CONFIGURATION_FROZEN.md` — EKS configuration frozen state
- `.agentic/ACTIVATION_CHECKLIST.md` — Pre-agentic activation checklist
