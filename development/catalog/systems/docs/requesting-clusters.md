# Requesting EKS Clusters

The IDP provides a self-service Software Template to provision production-ready Amazon EKS clusters securely and quickly.

## Naming Conventions
To keep resources organized, every EKS cluster requested must follow this naming convention:
* **Format:** `<team-name>-<environment>-<region>-cluster`
* **Example:** `team-alpha-staging-us-east-1-cluster`

## Environments
We support the following environment tiers:
* **development (dev):** Instantly provisioned for testing. Lower instance sizes and minimal node groups.
* **staging:** Used for pre-production integration testing. Restrictive access controls.
* **production (prod):** High-availability multi-AZ configuration. Requires formal sign-off.

## How to Request a Cluster

1. Navigate to the **Create...** tab in the Backstage sidebar.
2. Select the **EKS Cluster Golden Path** template.
3. Fill out the request form:
   * **Team Name:** Choose your default team/group (e.g., `team-alpha`).
   * **Environment:** Select `dev`, `staging`, or `prod`.
   * **Region:** Standard region defaults to `us-east-1`.
   * **VPC CIDR Range:** Input a non-overlapping CIDR block (e.g., `10.120.0.0/16`).
4. Click **Next Step** and click **Create** to launch the scaffolder pipeline.

## Approval Flow for Staging and Production

While `dev` clusters are provisioned automatically without approval, `staging` and `prod` clusters enforce a gated approval flow:

1. **Pull Request Generation:** The Backstage scaffolder creates a Git Pull Request in the central GitOps repository (`idp-gitops`).
2. **Platform Team Review:** A webhook notifies the Platform Engineering team on Slack.
3. **Approval:** A member of the platform team must review the CIDR allocations and approve/merge the pull request.
4. **Provisioning Sync:** Once the PR is merged into `main`, ArgoCD automatically synchronizes the new cluster manifest to Crossplane, initiating the AWS build.
