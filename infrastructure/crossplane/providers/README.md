# Crossplane AWS Providers

This directory contains the Crossplane provider manifests required for provisioning AWS resources in the IDP environment.

## Providers installed

| Provider | Manifest | Purpose |
|----------|----------|---------|
| `provider-aws-eks` | `provider-aws-eks.yaml` | Supplies the Crossplane `EKSCluster` resource. |
| `provider-aws-ec2` | `provider-aws-ec2.yaml` | Required for VPC, subnet, security‑group resources that an EKS cluster depends on. |
| `provider-aws-iam` | `provider-aws-iam.yaml` | Provides IAM roles and policies for the EKS node‑group. |

All three providers must be **Healthy** before any EKS compositions can be used.

## How to set up AWS credentials

1. Export the required environment variables:
   ```bash
   export AWS_ACCESS_KEY_ID=YOUR_KEY_ID
   export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_KEY
   export AWS_DEFAULT_REGION=us-east-1   # or your preferred region
   ```
2. Run the helper target:
   ```bash
   make -C ../ aws-creds
   ```
   This will execute `scripts/setup-aws-creds.sh`, which creates (or updates) a
   Kubernetes secret named **aws-credentials** in the `crossplane-system`
   namespace. The secret stores the credentials in the INI‑style format required
   by Crossplane.

> **Important:** The credentials secret is never committed to the repository.
> It is generated locally from the environment variables.

## Installing the providers

Run the following Make target to apply all provider manifests and wait until each
provider reports a `Ready` condition:
```bash
make -C ../ install-crossplane-providers
```

## Verifying provider health

After installation, you can view a summary table of provider status with:
```bash
make -C ../ check-crossplane
```
The output shows the provider name, installed package version, and health status.

## Next steps

Once the providers are healthy and the `aws-credentials` secret exists, you can
use the existing Backstage EKS scaffolder template to request clusters. The
compositions will automatically reference the `default` `ProviderConfig`.
