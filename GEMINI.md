# Gemini Memory

## Project Context
- **Project Name:** idp (Internal Developer Platform)
- **Core Stack:** Backstage, Docker, Kind (Kubernetes), PostgreSQL, GitHub API.
- **GitHub Account:** `nimishmehta8779`

## User Preferences & Memory
- Prefer Gemini models for internal agent logic and memory management.
- Do not use Claude-related memory commands (`claude_mem`).
- Native memory files: `GEMINI.md` and `MEMORY.md`.

## Active Configurations
- **Backstage Template Location:** `development/templates/new-service/template.yaml`
- **Catalog Registration Location:** `development/catalog/all.yaml`
- **Backstage Local App Path:** `infrastructure/backstage/`
- **GitHub Token Requirements:** The Personal Access Token (PAT) used as `GITHUB_TOKEN` in `infrastructure/backstage/.env` requires both `repo` and `workflow` scopes to successfully push template-generated workflow files (`.github/workflows/ci.yaml`).

## Completed Features
- [x] Backstage Software Template for backend services (supports `nodejs`, `python`, `golang`).
- [x] Dockerfile templates for Node.js, Python, and Go with conditional Nunjucks rendering.
- [x] GitHub Action workflows (`ci.yaml`) with conditional lint/test steps.
- [x] Automatic catalog registration of the newly created service Component under system `idp-core`.
- [x] Template registered under `development/catalog/all.yaml` using `Location` with kind targeting the template configuration.
- [x] Updated instructions in the local `.env` configuration file to require the `workflow` scope.
