# Kyverno Admission Policies & Validation Guardrails

This directory contains the admission control policies enforced in the local Kind cluster to validate, audit, and secure EKS cluster claims before they are synchronized to AWS via Crossplane.

---

## Policy Registry: What & Why

The following policies are active in the cluster under the `kyverno` namespace. All policies use `validationFailureAction: Enforce` to block non-compliant claims at the Kubernetes API level.

| Policy Manifest | Enforced Constraint | Business & Technical Rationale |
| :--- | :--- | :--- |
| **`require-mandatory-labels`** | Validates presence of `team`, `environment`, and `managed-by` in `metadata.labels`. | **Asset Tracking & Ownership**: Identifies which engineering team owns the resources, the lifecycle environment (dev/staging), and marks them as managed by the IDP GitOps platform. |
| **`approved-instance-types`** | Limits EC2 instance type to `t3.medium`, `t3.large`, or `m5.large` in `spec.parameters.nodeInstanceType`. | **Cost Control & Benchmarking**: Restricts instance options to pre-approved sizes, preventing developers from mistakenly requesting highly expensive instances (e.g., `p4d.24xlarge`). |
| **`node-count-limits`** | Restricts `spec.parameters.nodeCount` to **1–10** in `dev` and **1–6** in `staging`. | **Blast Radius & Cost Limits**: Controls the size of clusters to limit cloud spend and prevent resource starvation on shared infrastructure. |
| **`approved-regions`** | Restricts EKS deployment regions to `us-east-1` or `ap-south-1`. | **Data Sovereignty & Compliance**: Ensures compute resource placement aligns with regulatory compliance frameworks and low-latency zones. |
| **`require-cost-acknowledgment`** | Enforces the presence of the `idp.platform.io/cost-acknowledged: "true"` annotation on EKS cluster claims. | **FinOps Awareness**: Compels developers to review estimated costs dynamically calculated by the Scaffolder template before submitting resources. |
| **`staging-requires-approval`** | Blocks staging cluster claims unless they contain the `idp.platform.io/approved-by` annotation. | **Change Management**: Requires platform engineer sign-off on staging environment resources before deployment. |

---

## Dual-Layer Validation: GitHub Actions (Layer 1) vs. Kyverno (Layer 2)

Our platform utilizes a **defense-in-depth** strategy to validate claims at two distinct boundaries:

```
[ Developer PR ] ──> [ Layer 1: GitHub Actions ] ──> [ Git Repository ] ──> [ Layer 2: Kyverno Webhook ] ──> [ AWS ]
                       (Static / CI Validation)        (Source of Truth)        (Runtime Admission Control)
```

### 1. Layer 1: GitHub Actions (Static CI Validation)
* **Execution Boundary**: Runs on pull requests targeting the GitOps repository.
* **Role**: Evaluates resource requests statically via Python scripts (`validate-claim.py`).
* **Feedback Loop**: Fast, interactive feedback via PR comments. If a claim violates naming rules or exceeds team dev/staging quotas, the pipeline fails and blocks merging.

### 2. Layer 2: Kyverno Admission (Runtime Enforcer)
* **Execution Boundary**: Runs inside the Kind cluster as a validating admission webhook.
* **Role**: Acts as a hard gatekeeper. Any YAML applied to the cluster—whether synced by ArgoCD or applied directly by an admin—must pass Kyverno validation.
* **Feedback Loop**: Blocks Kubernetes API requests immediately, returning a detailed webhook rejection message to the caller.

---

## Tagging Strategy & Enterprise SCP Mapping

When Kyverno admits a claim, Crossplane translates the `EKSCluster` claim parameters and applies a mandatory `patchSet` named `mandatory-tags` defined in the Composition. 

These tags are pushed onto **every AWS resource** (VPC, EKS Cluster, NodeGroups, IAM Roles, Subnets, Route Tables, Internet Gateways):

* `environment` ➔ mapped from `spec.parameters.environment`
* `team` ➔ mapped from `spec.parameters.teamName`
* `cluster-name` ➔ mapped from `spec.parameters.clusterName`
* `managed-by` ➔ hardcoded to `crossplane`
* `provisioned-by` ➔ hardcoded to `backstage-idp`
* `cost-center` ➔ mapped from `spec.parameters.costCenter`
* `kubernetes-version` ➔ mapped from `spec.parameters.kubernetesVersion`
* `region` ➔ mapped from `spec.parameters.region`

### Mapping to AWS Service Control Policies (SCPs)
At the AWS Enterprise Account level, administrators enforce strict SCPs that deny resource creation if mandatory tags are missing. Kyverno ensures that EKS claims are validated *before* reaching AWS, guaranteeing that all spawned resources match the required SCP parameters, eliminating deployment failures due to AWS IAM tag-enforcement restrictions.

---

## How to Add a New Policy

1. **Write the Policy**: Create a new `ClusterPolicy` manifest under `infrastructure/kyverno/policies/`. Ensure `validationFailureAction` is set to `Enforce` and kinds target `platform.io/v1alpha1/EKSCluster`.
2. **Write a Test Case**: Add corresponding valid/invalid test claim YAML files in `infrastructure/kyverno/tests/`.
3. **Update the Test Runner**: Append your test scenarios to `scripts/test-kyverno.sh`.
4. **Deploy**: Push your policy to the `main` branch. ArgoCD's `kyverno-policies` app will automatically detect, deploy, and sync the policy to your Kind cluster.

---

## Policy Exemptions via Kyverno Exceptions

In exceptional scenarios (e.g., an EKS cluster requiring more than 10 nodes for load testing), you can temporarily bypass a policy for a specific resource without altering the policy definition itself.

Kyverno supports this via the `PolicyException` CRD.

### Example Exemption Manifest
Apply the following YAML to exempt a specific cluster (`alpha-dev-loadtest-01`) from the `node-count-limits` policy:

```yaml
apiVersion: kyverno.io/v2beta1
kind: PolicyException
metadata:
  name: exempt-loadtest-nodes
  namespace: clusters
spec:
  exceptions:
  - policyName: node-count-limits
    ruleNames:
    - dev-limit
  match:
    any:
    - resources:
        kinds:
        - platform.io/v1alpha1/EKSCluster
        namespaces:
        - clusters
        names:
        - alpha-dev-loadtest-01
```

Once applied, Kyverno will skip evaluation of the `dev-limit` rule only for the `alpha-dev-loadtest-01` resource.
