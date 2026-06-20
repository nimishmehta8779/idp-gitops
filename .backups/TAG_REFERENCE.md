# Git Tag Reference for Recovery

## Current Backup Point
- **Tag**: `backup-pre-agentic-2026-06-20`
- **Branch**: `backup/pre-agentic-2026-06-20`
- **Date**: 2026-06-20
- **Commit Hash**: Run `git rev-parse backup-pre-agentic-2026-06-20` to see

```bash
$ git rev-parse backup-pre-agentic-2026-06-20
2ef2b5e...
```

## To restore to this exact point:
```bash
git reset --hard backup-pre-agentic-2026-06-20
```

## To see what changed since this backup:
```bash
# See all commits
git log backup-pre-agentic-2026-06-20..main

# See the complete diff
git diff backup-pre-agentic-2026-06-20 main

# See just file names that changed
git diff --name-only backup-pre-agentic-2026-06-20 main

# See detailed stats
git diff --stat backup-pre-agentic-2026-06-20 main
```

## What This Tag Includes
- ✅ EKS composition with access entries (0.0.0.0/0 allowed networks)
- ✅ Velero 12.0.0 (fixed from 7.2.1) with out-of-the-box S3 backups
- ✅ External DNS 1.15.2 (fixed from 1.15.0)
- ✅ All addon IRSA roles configured
- ✅ Platform-admins break-glass IAM role
- ✅ ArgoCD/Backstage with private repo support
- ✅ All Kubernetes resources and AWS state backed up

## Future Backup Timeline

Create additional tags as you reach major milestones:

```bash
# Example for future backups:
git tag -a backup-after-phase-1-2026-06-25 -m "After agentic phase 1 complete"
git tag -a backup-after-phase-2-2026-07-02 -m "After agentic phase 2 complete"
```

This creates a timeline you can jump back to at any point.

---

**Created**: 2026-06-20  
**Status**: Ready for agentic development
