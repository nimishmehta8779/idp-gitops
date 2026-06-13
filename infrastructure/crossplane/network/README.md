# Centralized Network Infrastructure (XNetwork)

This directory defines the centralized network architecture (`XNetwork`) for the Internal Developer Platform (IDP). It decouples network provisioning (VPC, subnets, gateways) from individual EKS Cluster resources, reducing cost and management overhead.

## Hub-and-Spoke Network Model

```text
Platform team provisions (once per environment):
─────────────────────────────────────────────────
XNetwork Claim (dev)
      │
      └── VPC: 10.0.0.0/16
            ├── Subnet-a: 10.0.1.0/24 (us-east-1a)
            ├── Subnet-b: 10.0.2.0/24 (us-east-1b)
            ├── Internet Gateway
            └── Route Table

Teams consume (per cluster request):
─────────────────────────────────────────────────
XEKSCluster Claim (team-alpha, dev)
      │
      └── References dev VPC subnets via label selector
          Does NOT create its own VPC
```

## How to Manage the Network

### How to Provision the Platform Network
To spin up or configure the platform network:
```bash
make provision-platform-network
```
This applies the base Network claims and provisions the VPC and subnets inside AWS using Crossplane.

### How to Check Network Status
To monitor and inspect the status of the network claims and underlying managed resources:
```bash
make network-status
```

## Cost Breakdown & Optimization

- **VPC, Subnets, Internet Gateway, and Route Tables**: **Free** in AWS (no base charge).
- **Data Transfer**: Standard AWS data transfer fees apply only when traffic flows across network boundaries.
- **NAT Gateway (Disabled by Default)**:
  - AWS charges **$32.40/month** per NAT Gateway as a flat idle fee, plus hourly usage.
  - To keep default costs at **$0**, NAT Gateways are disabled by default (`enableNatGateway: false`).
  - To enable a NAT Gateway for workloads requiring outbound internet connectivity from private subnets, set `enableNatGateway: true` on your Network claim.

## Production/Migration Note

In a real enterprise multi-account AWS environment, this `XNetwork` composite resource would be provisioned within a dedicated **Network/Transit AWS Account** instead of the local developer environment. Spoke accounts (e.g. `dev`, `staging`, `production`) would then hook into these VPCs using VPC Sharing (Resource Access Manager) or Transit Gateways.
