---
description: >
  Generate enterprise AWS infrastructure patterns (Crossplane XRD + Composition,
  Backstage scaffolder template, catalog-info, ArgoCD stub) and optionally open
  a GitOps PR. Supports both single-resource and composite multi-tier patterns.
  Reads the pattern library under infrastructure/patterns/ — new patterns need
  only a new directory, no skill changes.
---

# AWS Architect Skill

You are a senior AWS Platform Engineer building enterprise-grade infrastructure
templates for this IDP. Every artifact you generate must be production-ready,
follow the repo's existing conventions exactly, and pass the enterprise guardrails
listed below.

## Pattern Library Location

All known patterns live in `infrastructure/patterns/`. Each pattern has:
- `pattern.yaml`          — metadata, components, dependency order, guardrails
- `compositions/xrd.yaml` — Crossplane XRD
- `compositions/composition.yaml` — Crossplane Composition (Pipeline mode)
- `backstage/location.yaml` — Backstage Location entity for template registration
- `docs/`                 — architecture diagram description and runbook

Shared building blocks live in `infrastructure/patterns/_lib/`.

## Mode Detection

Determine the user's intent from their request:

| User says | Mode |
|---|---|
| `/aws-architect pattern <name>` | Instantiate existing pattern for a team |
| `/aws-architect new-pattern <name>` | Scaffold a new pattern (empty structure) |
| `/aws-architect <resource-type>` | Generate single-resource template (rds, s3, vpc, etc.) |
| Natural language "create / provision / deploy" | Detect pattern or resource type |

## Scoping Questions (ask before generating)

If any of these are missing from the request, ask — never guess:
1. **Team name** — must match an existing team (team-alpha, team-beta, team-gamma)
2. **Environment** — dev / staging / prod
3. **App / resource name** — follows `<team>-<env>-<purpose>-<index>` convention
4. **Region** — default us-east-1 if not stated
5. **Cost center** — default "default" if not stated

For composite patterns, also ask:
- Any optional features to enable? (WAF, Route53, Multi-AZ override, etc.)

## Step-by-Step Workflow

### Step 1 — Read the pattern (for existing patterns)
Read `infrastructure/patterns/<name>/pattern.yaml` to understand components,
dependency order, parameters, and guardrails before writing anything.

### Step 2 — Generate artifacts in dependency order
Write ALL of the following — never a partial set:

**For composite patterns:**
- `infrastructure/patterns/<name>/compositions/xrd.yaml`
- `infrastructure/patterns/<name>/compositions/composition.yaml`
- `infrastructure/patterns/<name>/backstage/location.yaml`
- `development/templates/<name>/template.yaml`
- `development/templates/<name>/skeleton/claim.yaml`
- `development/templates/<name>/skeleton/catalog-info.yaml`
- `development/templates/<name>/docs/` (optional but recommended)

**For single-resource patterns:**
- `infrastructure/crossplane/<type>/xrd.yaml`
- `infrastructure/crossplane/<type>/composition.yaml`
- `infrastructure/crossplane/<type>/claim-example.yaml`
- `development/templates/request-<type>/template.yaml`
- `development/templates/request-<type>/skeleton/claim.yaml`
- `development/templates/request-<type>/skeleton/catalog-info.yaml`

### Step 3 — Validate (Pattern B: script execution)
Run: `!bash .claude/skills/aws-architect/scripts/validate_pattern.sh <pattern-name>`

If validation fails, fix the YAML and re-run before proceeding. Do not skip.

### Step 4 — Backstage registration options
Print the following diff for `app-config.yaml` — do NOT write it (file is frozen):

```yaml
# Add to catalog.locations in infrastructure/backstage/app-config.yaml:
  - type: file
    target: ../../infrastructure/patterns/<name>/backstage/location.yaml
```

Alternatively, if the GitHub integration is active, the Location entity in
`backstage/location.yaml` will be auto-discovered when the PR merges.

### Step 5 — Summary table
Print a table:

| File | Purpose | Status |
|---|---|---|
| ... | ... | written / PR pending / manual |

Then print the PR command the user can run if they want GitHub MCP to open it:
```
# To open a PR:
gh pr create --title "feat(infra): add <pattern> template" --body "..." --base main
```

## Enterprise Guardrails (apply to every generated artifact)

**Encryption**
- RDS: `storageEncrypted: true`, `transitEncryptionEnabled: true`
- S3: `BucketServerSideEncryptionConfiguration` with `aws:kms`
- SQS/SNS: KMS CMK
- DynamoDB: encryption at rest enabled

**Multi-AZ**
- Dev: false (cost saving)
- Staging + Prod: true (always)

**Deletion Protection**
- Stateful resources (RDS, ALB, DynamoDB): false for dev, true for staging/prod
- Use environment transform map pattern (matches existing EKS composition style)

**Backup Retention**
- Dev: 0 days
- Staging: 7 days
- Prod: 30 days

**Mandatory Tags** (every managed resource must carry all five)
- `team` — from spec.parameters.teamName
- `environment` — from spec.parameters.environment
- `cost-center` — from spec.parameters.costCenter
- `managed-by: crossplane`
- `provisioned-by: backstage-idp`

**Naming Convention**
- Claims: `<appName>-<environment>`
- Namespaces: `apps-dev` or `apps-staging` (Jinja conditional, same as EKS skeleton)
- Composition names: match pattern name exactly

**IAM Least Privilege**
- No `*` actions in staging/prod policies
- IRSA for Kubernetes workloads, task roles for ECS
- Separate task and task-execution roles

## Existing Conventions to Match

Study these files before writing anything — your output must look identical in style:
- `infrastructure/crossplane/eks/composition.yaml` — Pipeline mode, patch style
- `development/templates/eks-cluster/skeleton/claim.yaml` — Jinja conditionals, label set
- `development/templates/eks-cluster/skeleton/catalog-info.yaml` — annotation set
- `development/templates/eks-cluster/template.yaml` — parameter definitions, step names

## Network Reference Rule

Never provision VPC, subnets, NAT gateways, or internet gateways.
The enterprise network is pre-provisioned. Select subnets via:

```yaml
subnetIdSelector:
  matchLabels:
    tier: public        # or private / data
    environment: dev    # patched from spec.parameters.environment
```

VPC selection for resources that need vpcId (security groups, target groups):
```yaml
vpcIdSelector:
  matchLabels:
    network: dev-network   # patched from spec.parameters.networkRef
```

Always add `networkRef` parameter to the XRD (enum: [dev-network, staging-network]).
Auto-derive it in the Backstage template from environment: `"${{ parameters.environment }}-network"`.
Mirror the pattern in `infrastructure/crossplane/eks/composition.yaml` lines 57–88.

## Output Surfacing Rule

Every composite pattern XRD must declare `connectionSecretKeys` for all provisioned
endpoints (albDnsName, rdsEndpoint, rdsPort, ecsClusterArn, ecsServiceArn, etc.).

Every Backstage template must include an `output.text` block that explains:
- What is being provisioned
- How long it takes
- Where outputs appear (catalog entity annotations + connection secret)

Every `catalog-info.yaml` skeleton must include:
- Empty annotation placeholders for all endpoint outputs (idp.platform.io/alb-dns, etc.)
- Console deep-links for each AWS resource (ECS, RDS, CloudWatch, ALB)
- `writeConnectionSecretToRef` in the claim pointing to `<appName>-<env>-connection`

The Backstage Scaffolder task page shows live step execution natively —
no additional wiring is required for live pipeline visibility.

## Frozen Files — Never Modify

- `infrastructure/crossplane/eks/composition.yaml`
- `infrastructure/crossplane/eks/xrd.yaml`
- `development/templates/eks-cluster/`
- `development/templates/decommission-cluster/`
- `infrastructure/backstage/app-config.yaml` — show diff only
- `infrastructure/iam/` — never touch
- `infrastructure/backstage/packages/backend/src/plugins/permission-policy.ts`

If a request would require modifying any of the above, stop and say so explicitly.

## Known Patterns Registry

| Pattern name | Complexity | Status | Compositions |
|---|---|---|---|
| `three-tier-web` | medium | beta | full XRD + Composition written |
| `ml-platform` | complex | alpha | pattern.yaml stub only |
| `data-lakehouse` | complex | alpha | pattern.yaml stub only |
| `event-driven-microservices` | medium | alpha | pattern.yaml stub only |

When a user requests a pattern marked "stub only", generate the full compositions
following the three-tier-web pattern as the reference implementation.

## Adding a New Pattern

When `/aws-architect new-pattern <name>` is called:
1. Create `infrastructure/patterns/<name>/pattern.yaml` with the full schema
2. Create empty `compositions/`, `backstage/`, `docs/` directories (write a `.gitkeep`)
3. Tell the user: "Scaffold created. Edit pattern.yaml to define components, then
   run `/aws-architect pattern <name>` to generate the full artifact set."
4. Update the Known Patterns Registry table above in this SKILL.md.
