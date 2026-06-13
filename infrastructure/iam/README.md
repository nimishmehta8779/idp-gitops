# AWS Multi-Account Isolation Simulation

To enforce secure environment separation and simulate multi-account isolation within a single AWS account, the platform developer uses two distinct IAM roles with strict **Permission Boundaries**:
- **`idp-dev-role`**: Scope limited to development resources via `idp-dev-boundary`.
- **`idp-staging-role`**: Scope limited to staging resources via `idp-staging-boundary`.

Crossplane assumes these roles via the environment-specific `ProviderConfig` configurations (`aws-dev` and `aws-staging`) applied in Prompt I2.

---

## 1. Directory Structure

- **[dev-boundary.json](dev-boundary.json)**: Boundary policy JSON for the development environment.
- **[staging-boundary.json](staging-boundary.json)**: Boundary policy JSON for the staging environment.
- **[create-iam-roles.sh](../../scripts/create-iam-roles.sh)**: Automation script to deploy boundaries and roles to your AWS Account.

---

## 2. Boundary Policy Design

AWS Permission Boundaries define the maximum permissions that an identity (User or Role) can have. Even if a role has the `AdministratorAccess` policy attached, it will *only* be allowed to execute actions permitted by the boundary policy.

### Development Boundary (`dev-boundary.json`)
1. **Allowed EKS/EC2 Operations**: Restricted to resources tagged with `environment: dev`.
2. **EC2 Creation Operations**: Allows core networking/security infrastructure commands needed by Crossplane (e.g. `CreateVpc`, `CreateSubnet`, etc.).
3. **IAM Operations Scope**: Allowed to create/manage IAM roles and OIDC providers only if the role name follows the pattern `arn:aws:iam::*:role/idp-dev-*`.
4. **Deny Statement**: Explicitly denies any action against resources tagged with `environment: staging`.

### Staging Boundary (`staging-boundary.json`)
1. **Allowed EKS/EC2 Operations**: Restricted to resources tagged with `environment: staging`.
2. **EC2 Creation Operations**: Allows core infrastructure commands.
3. **IAM Operations Scope**: Allowed to create/manage IAM roles and OIDC providers following the pattern `arn:aws:iam::*:role/idp-staging-*`.
4. **Deny Statement**: Explicitly denies any action against resources tagged with `environment: dev`.

---

## 3. Creating Boundaries and Roles in AWS

An automated setup script is provided in the repository. Make sure your local AWS CLI is configured with administrator credentials:

```bash
# Run the setup script from the root of the repository
./scripts/create-iam-roles.sh
```

### Manual CLI Setup

If you prefer to configure this manually using the AWS CLI, follow these steps:

#### Step 1: Create the Permission Boundary Policies
```bash
# Create dev boundary
aws iam create-policy \
  --policy-name idp-dev-boundary \
  --policy-document file://infrastructure/iam/boundaries/dev-boundary.json

# Create staging boundary
aws iam create-policy \
  --policy-name idp-staging-boundary \
  --policy-document file://infrastructure/iam/boundaries/staging-boundary.json
```

#### Step 2: Create a Trust Relationship Policy File
Create a local file `trust-policy.json` allowing your AWS Account account to assume the roles:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::<YOUR_ACCOUNT_ID>:root"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

#### Step 3: Create the Roles and Attach Boundaries
```bash
# Create Dev Role with Boundary
aws iam create-role \
  --role-name idp-dev-role \
  --assume-role-policy-document file://trust-policy.json \
  --permissions-boundary arn:aws:iam::<YOUR_ACCOUNT_ID>:policy/idp-dev-boundary

# Create Staging Role with Boundary
aws iam create-role \
  --role-name idp-staging-role \
  --assume-role-policy-document file://trust-policy.json \
  --permissions-boundary arn:aws:iam::<YOUR_ACCOUNT_ID>:policy/idp-staging-boundary
```

#### Step 4: Attach Admin Policy (Permissions Intersect with Boundary)
```bash
# Attach Admin to Dev Role
aws iam attach-role-policy \
  --role-name idp-dev-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Attach Admin to Staging Role
aws iam attach-role-policy \
  --role-name idp-staging-role \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

---

## 4. Crossplane Integration

The `ProviderConfigs` deployed in Kubernetes (`aws-dev` and `aws-staging`) can be updated to assume these roles when communicating with AWS, enforcing that VPCs, Subnets, and EKS resources created for `dev` are managed under the restricted `idp-dev-role`, preventing cross-pollution.
