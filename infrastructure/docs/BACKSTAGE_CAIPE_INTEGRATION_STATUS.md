# Backstage Chat Assistant + CAIPE Integration Status

**Last Updated**: 2026-06-21  
**Status**: ⚠️ KNOWN ISSUE — Chat Widget Stuck in Loading

---

## Summary

The Backstage Chat Assistant widget gets stuck in a **perpetual loading state** when trying to query CAIPE/AWS tools, even though:
- ✅ CAIPE backend is healthy and responding
- ✅ AWS CLI credentials work
- ✅ CAIPE is correctly configured in `app-config.yaml`
- ✅ Direct API calls to CAIPE work fine

**Root Cause**: Backstage Chat plugin → CAIPE response format mismatch or timeout issue.

---

## Workarounds

### ✅ Use AWS CLI Directly (Recommended)
```bash
aws sts get-caller-identity
aws iam list-roles --query 'Roles[?contains(RoleName, `idp-`)].RoleName'
aws ec2 describe-vpcs
aws eks list-clusters
```

### ✅ Use Claude Code Agent
Ask Claude Code to execute AWS queries directly — this works perfectly.

### ⚠️ Backstage Chat Widget (Not Working)
Do NOT rely on Chat Assistant for AWS queries — will hang indefinitely.

---

## Testing Performed

✅ CAIPE health check: `curl http://localhost:8082/health` → OK  
✅ AWS CLI direct: `aws sts get-caller-identity` → Works  
✅ Backstage server logs: No CAIPE errors  
❌ Chat widget query: Stuck in loading forever  

---

## Recommendation

**Skip the Chat widget for now.** Use AWS CLI or Claude Code agent directly.
The underlying tools work perfectly — this is just a UI integration issue.
