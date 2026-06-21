# Backstage RBAC Permission Policy

> **Location in runtime**: `infrastructure/backstage/packages/backend/src/plugins/permission-policy.ts`
>
> This file documents the production permission policy. The Backstage runtime directory
> (`infrastructure/backstage/`) is gitignored, so this doc preserves the policy logic in git history.

## Policy Rules (in precedence order)

| Priority | Who | What | Decision |
|----------|-----|------|----------|
| 1 | `group:default/platform-team` members | Everything | ALLOW |
| 2 | Unauthenticated (`user == null`) | Everything | DENY |
| 3 | All authenticated users | `catalog.entity.read` on `decommission-eks-cluster`, `onboard-team` templates | DENY (conditional) |
| 4 | All authenticated users | `techdocs.read` | ALLOW |
| 5 | All authenticated users | `catalog.entity.delete` | CONDITIONAL (owner only) |
| 6 | All authenticated users | Everything else | ALLOW (default) |

## Auth Configuration

Provider: **GitHub OAuth** (sole provider as of 2026-06-21)

```yaml
auth:
  providers:
    # Guest auth removed — GitHub OAuth is the sole auth provider.
    # To re-enable guest access for local dev/testing, uncomment below:
    # guest: {}
    github:
      development:
        clientId: ${GITHUB_APP_CLIENT_ID}
        clientSecret: ${GITHUB_APP_CLIENT_SECRET}
```

## Source Code Reference

```typescript
export class CustomPermissionPolicy implements PermissionPolicy {
  async handle(request, user?) {
    // 1. Platform team → full access
    const isPlatformTeam = user?.info?.ownershipEntityRefs?.some(
      (ref) => ref.toLowerCase() === 'group:default/platform-team',
    );
    if (isPlatformTeam) return { result: AuthorizeResult.ALLOW };

    // 2. Unauthenticated → deny all
    if (!user) return { result: AuthorizeResult.DENY };

    // 3. catalog.entity.read → hide sensitive templates from standard users
    if (request.permission.name === 'catalog.entity.read') {
      return createCatalogConditionalDecision(request.permission, {
        anyOf: [
          { not: catalogConditions.isEntityKind({ kinds: ['template'] }) },
          {
            allOf: [
              catalogConditions.isEntityKind({ kinds: ['template'] }),
              { not: catalogConditions.hasMetadata({ key: 'name', value: 'decommission-eks-cluster' }) },
              { not: catalogConditions.hasMetadata({ key: 'name', value: 'onboard-team' }) },
            ]
          }
        ]
      });
    }

    // 4. TechDocs → open for all authenticated
    if (request.permission.name === 'techdocs.read') return { result: AuthorizeResult.ALLOW };

    // 5. Entity delete → owner only
    if (isPermission(request.permission, catalogEntityDeletePermission)) {
      return createCatalogConditionalDecision(request.permission,
        catalogConditions.isEntityOwner({ claims: user.info.ownershipEntityRefs ?? [] })
      );
    }

    // 6. Default → allow
    return { result: AuthorizeResult.ALLOW };
  }
}
```

## Validation Record

| Test Case | User | Expected | Result |
|-----------|------|----------|--------|
| Platform team full access | alice (platform-team) | ALLOW all | ✅ Verified 2026-06-21 |
| Standard user: new-service template | Standard GitHub user | ALLOW | ✅ Verified on test instance |
| Standard user: eks-cluster template | Standard GitHub user | ALLOW | ✅ Verified on test instance |
| Standard user: decommission-eks-cluster | Standard GitHub user | DENY (hidden) | ✅ Verified on test instance |
| Standard user: onboard-team | Standard GitHub user | DENY (hidden) | ✅ Verified on test instance |
| Unauthenticated | None | DENY all | ✅ Verified on test instance |

## Sign-In Resolver

GitHub username → Backstage Group is resolved via catalog lookup (personal account, no GitHub Teams).
The resolver matches `github.com/user-login` annotation or metadata name, mapping
`nimishmehta8779` → `user:default/alice` → `group:default/platform-team`.
