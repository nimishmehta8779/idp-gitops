# Getting Started with the IDP

This guide covers the prerequisites and quickstart steps to run the Internal Developer Platform (IDP) locally for development.

## Prerequisites

Ensure you have the following tools installed on your local machine:

1. **Docker / Docker Desktop**: Make sure Docker is running and has at least 4 CPU cores and 8GB RAM allocated.
2. **Kind (Kubernetes in Docker)**: Used to spin up the local Kubernetes management cluster.
3. **Helm**: Kubernetes package manager used for installing ArgoCD, Crossplane, and Backstage.
4. **Node.js (v20 or newer)** & **Yarn**: Needed for running the Backstage frontend/backend locally outside of Docker (if doing host-level development).
5. **AWS CLI**: Pre-configured with credentials that have access to EKS, EC2, IAM, etc.
6. **GitHub Account & PAT**: A Personal Access Token (PAT) with `repo` and `workflow` scopes.

## Local Quickstart

### 1. Clone the Repository
```bash
git clone https://github.com/nimishmehta8779/idp-gitops.git
cd idp-gitops
```

### 2. Configure Environment Variables
Create a `.env` file in the backstage folder:
```bash
cp infrastructure/backstage/.env.example infrastructure/backstage/.env
```
Fill in your `GITHUB_TOKEN`, `GITHUB_APP_CLIENT_ID`, `GITHUB_APP_CLIENT_SECRET`, and `GITHUB_APP_PRIVATE_KEY_PATH`.

### 3. Spin Up Local Management Cluster
Create the Kind cluster and deploy control plane components:
```bash
make cluster-up
make install-crossplane
make install-argocd
```

### 4. Run Backstage Locally
You can run Backstage using Docker Compose or directly in development mode on the host:

**Option A: Run inside Docker Compose**
```bash
docker compose -f infrastructure/docker-compose.yml up --build -d
```

**Option B: Host Development Mode**
```bash
make backstage-dev
```

Backstage will be accessible at [http://localhost:3000](http://localhost:3000).

## Score Workload Specification

Every service created via the IDP includes a `score.yaml` file that defines its workload requirements in a platform-agnostic way.

### What is Score?

[Score](https://score.dev) is an open-source specification for describing workload requirements (resources, health checks, environment variables) that translates into platform-specific manifests (Docker Compose, Kubernetes, Helm).

### Score in the IDP

- **Every new service repository** includes a `score.yaml` file
- **CI validates** score.yaml syntax on every pull request
- **Platform translates** score.yaml to deployment manifests automatically
- **Environment overrides** allow local dev vs. staging/prod differences

### Key Files

- `score.yaml` - Primary workload specification (required)
- `score-overrides.dev.yaml` - Local development overrides
- `.score/README.md` - Documentation and examples

### Generating Manifests Locally

```bash
# Docker Compose for local development
score-compose generate score.yaml
docker-compose up

# Kubernetes for staging/production
score-k8s init
score-k8s generate score.yaml --image myregistry/myservice:latest
kubectl apply -f manifests/
```

### Catalog Annotations

Every service is tagged with score metadata for discovery:
- `score.dev/workload-spec: score.yaml` - Specifies the score file location
- `score.dev/spec-version: v1b1` - Score specification version
- `idp.platform.io/score-validated: "true"` - CI validation passed

See the [Score documentation](https://score.dev/docs) for the complete specification.
