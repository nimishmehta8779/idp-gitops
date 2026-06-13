# Network Claims Directory

This directory is managed and controlled by the **platform team only**.

## Key Guidelines

1. **Platform Team Ownership**: Only the platform team should commit to this directory. Codeowner rules are configured to restrict access.
2. **One Network Per Environment**: Network claims (instances of `Network` claim resources) are provisioned once per environment (e.g. `dev`, `staging`).
3. **Consumption Model**: Application development teams do not create their own network claims. Instead, they consume the shared VPC/Subnet infrastructure by referencing the corresponding network name in their EKS cluster claims (via `networkRef`).
