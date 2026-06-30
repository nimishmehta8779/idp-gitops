# ${{ values.appName }}-${{ values.environment }}

Three-tier web application provisioned via the IDP platform.

| | |
|---|---|
| **Pattern** | `three-tier-web` v1.0.0 |
| **Team** | `${{ values.teamName }}` |
| **Environment** | `${{ values.environment }}` |
| **Region** | `${{ values.region }}` |
| **Network** | `${{ values.networkRef }}` |
| **Cost center** | `${{ values.costCenter }}` |

## Architecture

![three-tier-web architecture](https://raw.githubusercontent.com/nimishmehta8779/idp/main/infrastructure/patterns/three-tier-web/docs/architecture.svg)

> Diagram shows the pattern topology. VPC and subnets (dashed border) are
> pre-provisioned enterprise infrastructure — not managed by this claim.

## What this instance provisions

| Resource | Notes |
|---|---|
| ALB (HTTPS :443, HTTP→HTTPS redirect) | Public subnets of `${{ values.networkRef }}` |
| ECS Fargate service | ${{ values.ecsTaskCpu }} CPU / ${{ values.ecsTaskMemory }} MiB, `${{ values.desiredCount }}` task(s) |
| RDS PostgreSQL 15.4 (`${{ values.dbInstanceClass }}`) | {% if values.environment != 'dev' %}Multi-AZ enabled{% else %}Single-AZ (dev){% endif %} |
| CloudWatch log group | `/ecs/${{ values.appName }}-${{ values.environment }}` |
| ECS task role + execution role | Least-privilege; extend task role per app needs |
| Security groups (ALB / App / Data) | Three-tier network isolation |

## Outputs

Populated automatically once Crossplane reports `READY` (~10–15 min after PR merge):

| Key | Description |
|---|---|
| `albDnsName` | ALB public DNS — your application endpoint |
| `rdsEndpoint` | RDS hostname |
| `rdsPort` | RDS port (5432) |
| `ecsClusterArn` | ECS Cluster ARN |
| `ecsServiceArn` | ECS Service ARN |
| `taskRoleArn` | Task IAM role ARN |
| `logGroupArn` | CloudWatch log group ARN |

Connection secret: `${{ values.appName }}-${{ values.environment }}-connection`
in namespace `apps-${{ values.environment }}`.

## Well-Architected compliance

This pattern was reviewed against all six AWS Well-Architected Framework pillars
before release. All **high-severity** best practices are **Pass**.

[View full scorecard →](https://github.com/nimishmehta8779/idp/blob/main/infrastructure/patterns/three-tier-web/docs/well-architected-review.md)

| Pillar | High-severity result |
|---|---|
| Security | Pass |
| Reliability | Pass |
| Operational Excellence | Pass |
| Performance Efficiency | Pass |
| Cost Optimization | Pass |
| Sustainability | Pass |

One medium-severity Partial noted: SEC08-BP01 (KMS CMK not enforced; AWS-managed
key used). Acceptable for beta — CMK parameter planned for next pattern revision.

## Runbook

### Check provisioning status

```bash
kubectl get threetierapps ${{ values.appName }}-${{ values.environment }} \
  -n apps-${{ values.environment }} -o wide
```

### Read connection outputs

```bash
kubectl get secret ${{ values.appName }}-${{ values.environment }}-connection \
  -n apps-${{ values.environment }} -o jsonpath='{.data}' | \
  jq 'to_entries[] | {(.key): (.value | @base64d)}'
```

### View application logs

```bash
aws logs tail /ecs/${{ values.appName }}-${{ values.environment }} --follow
```

### Console links

- [ECS Service](https://console.aws.amazon.com/ecs/v2/clusters/${{ values.appName }}-${{ values.environment }}/services)
- [RDS Instance](https://console.aws.amazon.com/rds/home?region=${{ values.region }}#databases:)
- [CloudWatch Logs](https://console.aws.amazon.com/cloudwatch/home?region=${{ values.region }}#logsV2:log-groups/log-group/%2Fecs%2F${{ values.appName }}-${{ values.environment }})
- [Load Balancers](https://console.aws.amazon.com/ec2/v2/home?region=${{ values.region }}#LoadBalancers)
