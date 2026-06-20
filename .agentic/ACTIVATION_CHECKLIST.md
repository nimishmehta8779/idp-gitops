# Pre-Activation Checklist for Agentic Development

**Status**: Ready to activate ✅

Before switching to agentic mode, verify ALL of these:

---

## Backups ✅

- [x] Git backup branch created: `git branch | grep backup/pre-agentic`
- [x] Git backup branch pushed to GitHub: `git push origin backup/pre-agentic-*`
- [x] Git backup tag created: `git tag -l | grep backup-pre-agentic`
- [x] Filesystem backups exported: `.backups/pre-agentic-*/` directory present
- [x] Recovery runbook created: `.backups/RECOVERY.md` exists
- [x] Backup verification script created: `scripts/verify-backup.sh` exists
- [x] Backup verification PASSES: `bash scripts/verify-backup.sh` → all green
- [x] Tag reference created: `.backups/TAG_REFERENCE.md` exists

---

## System State ✅

- [x] All current work committed: `git status` shows clean working tree
- [x] EKS configuration frozen: `infrastructure/crossplane/eks/composition.yaml` marked frozen
- [x] EKS addon templates frozen: `infrastructure/argocd/appsets/eks-addons-appset.yaml` marked frozen
- [x] kind cluster healthy: `kubectl get nodes` shows all nodes Ready
- [x] Crossplane healthy: `kubectl get providers` shows all Healthy
- [x] ArgoCD healthy: `kubectl get applications -A` shows Synced/Healthy
- [x] AWS credentials working: `aws sts get-caller-identity` returns identity
- [x] All Crossplane resources synced: `kubectl get xeksclusters -A`

---

## Configuration State ✅

- [x] EKS access entries configured: platform-admins role with 0.0.0.0/0 allowed networks
- [x] Velero backups: 12.0.0 with out-of-the-box S3 + EBS snapshot support
- [x] External DNS: 1.15.2 (fixed from broken 1.15.0)
- [x] All addon IRSA roles created and annotated
- [x] Platform-admins break-glass IAM role: idp-platform-admins
- [x] Private repos supported: ArgoCD/Backstage have GitHub tokens
- [x] S3 provider installed: provider-aws-s3 healthy in Crossplane
- [x] Velero backup buckets provisioned: `{cluster}-velero-backups` per cluster

---

## Documentation ✅

- [x] Architecture docs frozen: `EKS_CONFIGURATION_FROZEN.md` created
- [x] Recovery runbook: `.backups/RECOVERY.md` detailed with 5 scenarios
- [x] Backup inventory: `.backups/pre-agentic-2026-06-20/INVENTORY.md`
- [x] Git tag reference: `.backups/TAG_REFERENCE.md`
- [x] This checklist: `.agentic/ACTIVATION_CHECKLIST.md`

---

## Final Verification

```bash
#!/bin/bash
echo "Final pre-activation checks..."
echo ""

# Backups
echo "Backups:"
git branch | grep -q backup/pre-agentic && echo "✅ Backup branch exists" || echo "❌ No backup branch"
git tag -l | grep -q backup-pre-agentic && echo "✅ Backup tag exists" || echo "❌ No backup tag"
test -d .backups/pre-agentic-* && echo "✅ Filesystem backup exists" || echo "❌ No filesystem backup"

# System state
echo ""
echo "System State:"
git status --porcelain | grep -q . && echo "❌ Uncommitted changes" || echo "✅ Working tree clean"
kubectl cluster-info &>/dev/null && echo "✅ kind cluster healthy" || echo "❌ kind cluster down"
kubectl get providers | grep -q Healthy && echo "✅ Crossplane healthy" || echo "❌ Crossplane unhealthy"

# Agentic setup
echo ""
echo "Agentic Setup:"
test -f .agentic/ACTIVATION_CHECKLIST.md && echo "✅ Activation checklist exists" || echo "❌ No activation checklist"
test -f .backups/RECOVERY.md && echo "✅ Recovery runbook exists" || echo "❌ No recovery runbook"
bash scripts/verify-backup.sh &>/dev/null && echo "✅ Backup verification passes" || echo "❌ Backup verification fails"

echo ""
echo "If all checks above show ✅, you're ready to activate agentic mode."
```

---

## Agentic Mode Activation

Once all checks pass ✅:

1. **Commit this checklist**
   ```bash
   git add .agentic/ACTIVATION_CHECKLIST.md
   git commit -m "chore: pre-activation checklist — all verifications passed"
   git push origin main
   ```

2. **Create GitHub issue** (for team visibility)
   ```
   Title: Activating agentic development mode
   Label: operational-change
   Description:
   - All backups verified
   - All system checks passing
   - Recovery procedures documented
   - Ready to proceed with agentic tasks
   ```

3. **Start agentic work** — queue tasks in Claude Code or use Agent tool

---

## Deactivation (if needed)

If agentic mode must be paused:

1. **Stop queuing new agentic tasks**
2. **Wait for in-progress tasks** to complete or escalate
3. **Merge or close** any open agentic PRs
4. **Document what went wrong** in a GitHub issue
5. **Review logs** in `.agentic/logs/` to understand failures
6. **Update config or skills** if needed
7. **Restart** from "Agentic Mode Activation" above

---

## Support & Escalation

**If something goes wrong:**

1. Check `.backups/RECOVERY.md` for your scenario
2. Run recovery commands
3. Document in GitHub issue
4. Review `.agentic/logs/` for root cause
5. Update skills/config to prevent recurrence

**Emergency recovery:**
```bash
git reset --hard backup-pre-agentic-2026-06-20
git push origin main --force-with-lease
```

---

## Sign-Off

**Date Activated**: 2026-06-20  
**Activated By**: agentic-mode  
**Status**: READY ✅  

**Next Major Milestones**:
- [ ] Phase 1 complete — create `backup-after-phase-1` tag
- [ ] Phase 2 complete — create `backup-after-phase-2` tag
- [ ] Phase 3 complete — create `backup-after-phase-3` tag

---

**All checks passing. Ready to proceed with agentic development.**
