
## Freeze boundary (active as of freeze-baseline tag)

The following are FROZEN — read-only unless explicitly told otherwise
in a specific task, even if a task seems to require touching them:
  - infrastructure/backstage/app-config.yaml (auth/permission sections)
  - infrastructure/backstage/packages/backend/src/plugins/permission-policy.ts
  - infrastructure/crossplane/eks/composition.yaml
  - infrastructure/iam/
  - development/templates/ (all 4 templates)
  - All team-*-infra repos' existing structure

OPEN for active work:
  - infrastructure/caipe/
  - New MCP server work (new files/directories)
  - New, additive files anywhere — not edits to the frozen list above

If a task seems to require modifying something on the frozen list,
stop and say so explicitly rather than proceeding — that needs
deliberate human sign-off, not silent assumption that it's fine.
