# Score Workload Specification

This service uses [Score](https://score.dev) to define its workload requirements in a platform-agnostic way.

## What is Score?

Score is an open-source YAML specification for defining workload requirements and translating them into platform-specific manifests (Docker Compose, Kubernetes, Helm, etc.).

## Files

- `score.yaml` - The primary workload specification for this service
- `score-overrides.dev.yaml` - Environment-specific overrides for local development

## Generating Manifests

### Docker Compose (Local Development)

```bash
# Install score-compose (one-time)
curl -fsSL https://github.com/score-spec/score-compose/releases/latest/download/score-compose_linux_amd64.tar.gz | tar -xz

# Generate docker-compose.yaml
./score-compose generate score.yaml
docker-compose up
```

### Kubernetes (Staging/Production)

```bash
# Install score-k8s (one-time)
curl -fsSL https://github.com/score-spec/score-k8s/releases/latest/download/score-k8s_linux_amd64.tar.gz | tar -xz

# Generate Kubernetes manifests
./score-k8s init
./score-k8s generate score.yaml --image myregistry/myservice:latest
kubectl apply -f manifests/
```

## How the Platform Uses Score

1. **Resource Requirements**: The platform reads `resources.requests` to schedule pods efficiently
2. **Health Checks**: `livenessProbe` and `readinessProbe` are translated to Kubernetes probes
3. **Environment Variables**: All variables are injected at deployment time
4. **Service Dependencies**: The `resources` section declares what this service needs

## Editing score.yaml

When modifying `score.yaml`:
- Keep `apiVersion: score.dev/v1b1` unchanged
- Add new containers in the `containers` section
- Declare dependencies under `resources`
- Probes are validated by CI before merge

See [score.dev documentation](https://score.dev/docs) for full specification.
