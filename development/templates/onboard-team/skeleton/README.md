# ${{ values.teamName }} Infrastructure

This repository contains all infrastructure claims for ${{ values.displayName }}.
Managed by the IDP platform — do not manually apply these files to AWS.

## Repository structure
- **eks/** — EKS cluster claims
- **rds/** — RDS database instance claims
- **s3/** — S3 bucket claims
- **ec2/** — EC2 instance claims
- **opensearch/** — OpenSearch cluster claims
- **elasticache/** — ElastiCache cluster claims

## How to request infrastructure
Use the Backstage portal: http://localhost:7007/create

## How changes are applied
1. Backstage template pushes claim file to this repo
2. ArgoCD detects the change
3. Crossplane provisions the AWS resource
4. Resource appears in Backstage catalog automatically

## Cost center: ${{ values.costCenter }}
## Primary region: ${{ values.primaryRegion }}
