# Decommissioning EKS Clusters

When an EKS cluster is no longer needed, it must be decommissioned using the standardized decommissioning golden path.

## How to Decommission a Cluster

1. Navigate to the **Create...** tab in Backstage.
2. Select the **Decommission EKS Cluster** template.
3. Select your **Team Name** and choose the **Cluster Name** from the dropdown list.
4. Type the cluster name exactly in the **Confirm Cluster Name** field to prevent accidental deletion.
5. Click **Run** to launch the decommission workflow.

## Orphan Deletion Policy Warning (Staging / Production)

> [!WARNING]
> **Staging and Production Deletion Policy**
> Under the hood, the Crossplane Composition defines a deletion policy for backing resources. In the **staging** and **production** environments, the deletion policy is set to `Orphan` on certain underlying persistent resources (such as DB backups or persistent EBS volumes).
>
> When you delete a staging cluster, the EKS control plane is destroyed, but resources marked as `Orphan` will remain in your AWS account. You must manually clean up these orphaned resources to avoid ongoing AWS billing charges. 
>
> Always verify the resources in the AWS Console after the decommission pipeline has completed.
