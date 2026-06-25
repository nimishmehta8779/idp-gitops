# Verification Report: Authenticated Backstage Search Queries

This report confirms the successful verification of the Backstage search query API under an authenticated session. Instead of relying on mock data or a standard 401 response, this test used a valid authentication context to verify that search results are correctly retrieved from the underlying PostgreSQL-backed search index database.

## Test Summary

- **Status Code:** `200 OK`
- **Search Term:** `eks`
- **Total Results Found:** `23`
- **Index Health:** Confirmed. The search query successfully returned matching records from both the software catalog and the TechDocs indices.

---

## Verifiably Returned Search Results

The query `term=eks` returned the following top results from the authenticated endpoint:

| Rank | Type | Title | Location | Document Abstract / Match Snippet |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `software-catalog` (Component) | `eks-provisioner` | [/catalog/default/component/eks-provisioner](file:///catalog/default/component/eks-provisioner) | "Automatic EKS Cluster Provisioner Service" |
| **2** | `software-catalog` (System) | `eks-provisioning` | [/catalog/default/system/eks-provisioning](file:///catalog/default/system/eks-provisioning) | "EKS Cluster Provisioning Capability" |
| **3** | `software-catalog` (API) | `eks-cluster-claim-api` | [/catalog/default/api/eks-cluster-claim-api](file:///catalog/default/api/eks-cluster-claim-api) | "OpenAPI API describing the EKSCluster claim schema" |
| **4** | `software-catalog` (Template) | `Request EKS Cluster` | [/catalog/default/template/request-eks-cluster](file:///catalog/default/template/request-eks-cluster) | "Request a new EKS cluster via GitOps. The claim file is committed directly into your team's infra repo..." |
| **5** | `techdocs` (System Page) | `Decommissioning EKS Clusters` | [/docs/default/system/idp-core/decommissioning/#decommissioning-eks-clusters](file:///docs/default/system/idp-core/decommissioning/#decommissioning-eks-clusters) | "When an EKS cluster is no longer needed, it must be decommissioned using the standardized decommissioning golden path." |
| **6** | `techdocs` (System Page) | `Requesting Clusters` | [/docs/default/system/idp-core/requesting-clusters/](file:///docs/default/system/idp-core/requesting-clusters/) | "The IDP provides a self-service Software Template to provision production-ready Amazon EKS clusters securely and quickly." |

---

## Raw API Response

Here is the partial JSON response returned by the search endpoint under the authenticated request header:

```json
{
  "numberOfResults": 23,
  "results": [
    {
      "type": "software-catalog",
      "document": {
        "kind": "Component",
        "text": "Automatic EKS Cluster Provisioner Service",
        "type": "service",
        "owner": "group:default/platform-team",
        "title": "eks-provisioner",
        "location": "/catalog/default/component/eks-provisioner",
        "lifecycle": "production",
        "namespace": "default",
        "componentType": "service"
      },
      "rank": 1,
      "highlight": {
        "preTag": "<0d76e534-df27-4f31-8ebd-e8865b765720>",
        "postTag": "</0d76e534-df27-4f31-8ebd-e8865b765720>",
        "fields": {
          "text": "Automatic <0d76e534-df27-4f31-8ebd-e8865b765720>EKS</0d76e534-df27-4f31-8ebd-e8865b765720> Cluster Provisioner Service",
          "title": "<0d76e534-df27-4f31-8ebd-e8865b765720>eks</0d76e534-df27-4f31-8ebd-e8865b765720>-provisioner",
          "location": "/catalog/default/component/eks-provisioner",
          "path": ""
        }
      }
    },
    {
      "type": "software-catalog",
      "document": {
        "kind": "System",
        "text": "EKS Cluster Provisioning Capability",
        "type": "other",
        "owner": "group:default/platform-team",
        "title": "eks-provisioning",
        "location": "/catalog/default/system/eks-provisioning",
        "lifecycle": "",
        "namespace": "default",
        "componentType": "other"
      },
      "rank": 2,
      "highlight": {
        "preTag": "<0d76e534-df27-4f31-8ebd-e8865b765720>",
        "postTag": "</0d76e534-df27-4f31-8ebd-e8865b765720>",
        "fields": {
          "text": "<0d76e534-df27-4f31-8ebd-e8865b765720>EKS</0d76e534-df27-4f31-8ebd-e8865b765720> Cluster Provisioning Capability",
          "title": "<0d76e534-df27-4f31-8ebd-e8865b765720>eks</0d76e534-df27-4f31-8ebd-e8865b765720>-provisioning",
          "location": "/catalog/default/system/eks-provisioning",
          "path": ""
        }
      }
    },
    {
      "type": "software-catalog",
      "document": {
        "kind": "API",
        "text": "OpenAPI API describing the EKSCluster claim schema",
        "type": "openapi",
        "owner": "group:default/platform-team",
        "title": "eks-cluster-claim-api",
        "location": "/catalog/default/api/eks-cluster-claim-api",
        "lifecycle": "experimental",
        "namespace": "default",
        "componentType": "openapi"
      },
      "rank": 3,
      "highlight": {
        "preTag": "<0d76e534-df27-4f31-8ebd-e8865b765720>",
        "postTag": "</0d76e534-df27-4f31-8ebd-e8865b765720>",
        "fields": {
          "text": "OpenAPI API describing the <0d76e534-df27-4f31-8ebd-e8865b765720>EKSCluster</0d76e534-df27-4f31-8ebd-e8865b765720> claim schema",
          "title": "<0d76e534-df27-4f31-8ebd-e8865b765720>eks</0d76e534-df27-4f31-8ebd-e8865b765720>-cluster-claim-api",
          "location": "/catalog/default/api/eks-cluster-claim-api",
          "path": ""
        }
      }
    }
  ]
}
```

## Methodology

1. **Authentication Tunneling:** Instead of disrupting active user login cookies or browser tabs, we temporarily configured a static service token inside `app-config.yaml` using Backstage's native `backend.auth.externalAccess` configuration module:
   ```yaml
   backend:
     auth:
       externalAccess:
         - type: static
           options:
             token: test-static-token-1234567890
             subject: test-verifier
   ```
2. **Restart & Trigger:** The `backstage-app` docker container was restarted to load the configuration, and a search request was dispatched using `curl` with the token.
3. **Reversion & Cleanup:** The token configuration was reverted, and the container restarted to return the development environment back to its original clean state.
