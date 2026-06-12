# Onboarding a New Team

This guide outlines the steps required to onboard a new engineering team onto the Internal Developer Platform (IDP).

## Onboarding Steps

### 1. Define Team and Users in Org Catalog
Engineering teams are modeled as `Group` entities and developers as `User` entities in the Backstage catalog.

Add your group and users inside `development/catalog/org/org.yaml` or a dedicated organizational file:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: team-gamma
  description: The Gamma engineering team
spec:
  type: team
  parent: engineering
  members:
    - jdoe
    - jsmith
---
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: jdoe
spec:
  profile:
    displayName: John Doe
    email: jdoe@company.com
  memberOf: [team-gamma]
```

### 2. Set Up a Team GitHub Repository
Ensure your team has a GitHub repository under the organization. The team must grant the Backstage Gitea/GitHub app or user access to write to that repository.

### 3. Grant AWS IAM Permissions
Map your team's IAM Roles to the corresponding Kubernetes RBAC group in the management cluster to allow team members to deploy workloads or view logs of their provisioned resources.

### 4. Log in to Backstage
Once the catalog registers your team, team members can log in using GitHub OAuth. Under their Profile, they will automatically see the services and clusters owned by their group.

## Catalog Ownership Policy

To maintain a healthy developer portal, the platform enforces a strict ownership policy:
* **Every entity** (Component, System, API, Resource, or Template) registered in the catalog **must have a valid Group owner** defined.
* Individual users are not allowed to directly own software components; ownership must always map to a Group.
* The owner is specified via the `spec.owner` field referencing the group (e.g., `group:default/team-name` or `group:default/platform-team`).
* Validation pipelines automatically reject any `catalog-info.yaml` changes that lack the `spec.owner` field.
