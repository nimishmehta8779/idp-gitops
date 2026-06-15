# EKS Clusters — ${{ values.teamName }}

This directory contains EKS cluster claims for ${{ values.teamName }}.

## How to request a new cluster
Use Backstage: http://localhost:3000/create → Request EKS Cluster

## How to decommission a cluster
Use Backstage: http://localhost:3000/create → Decommission EKS Cluster

## Naming convention
Format: `<team>-<env>-<purpose>-<index>`
Example: `alpha-dev-general-01`

## Network
Clusters use the shared platform VPC managed by the platform team.
- VPC CIDR dev: `10.0.0.0/16`
- VPC CIDR staging: `10.1.0.0/16`

## Clusters in this repo
| Cluster | Environment | Nodes | Instance | Status |
|---|---|---|---|---|
| ${{ values.clusterName }} | ${{ values.environment }} | ${{ values.nodeCount }} | ${{ values.instanceType }} | Provisioning |
