# CAIPE (CNOE AI Platform Engineering) Integration

CAIPE is an agentic AI developer platform designed to assist engineers with developer tasks and GitOps management. It runs alongside Backstage and coordinates specialized agents via a central supervisor.

## Enabled Agents
- **ArgoCD Agent**: Enabled. Interacts with ArgoCD for checking application sync and health status. Restricted from creating/deleting applications.
- **GitHub Agent**: Enabled. Watches repository PRs, commits, and actions. Restricted from merging, pushing, or deleting.
- **Kubernetes Agent**: Enabled. Connects to `kind-local` to inspect workloads, namespace pods, and events. Restricted from namespace deletions or applying manifests.
- **Jira Agent**: Disabled.

## Access
- **Backstage UI**: Accessible under `/agent-forge` in the sidebar or via widgets on Component/Resource entity pages.
- **Direct API**: The JSON-RPC endpoint is hosted at `http://localhost:8082/`.

## Security Model
- **ArgoCD**: Access limited to a custom `caipe` role with get and sync permissions only.
- **GitHub**: Token scoped to watched repositories only.
- **Kubernetes**: Token context inherited from local Kubeconfig credentials.
