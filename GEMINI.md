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
- [x] Configured TechDocs locally with mkdocs and mkdocs-techdocs-core dependencies inside the container.
- [x] Created IDP platform documentation (index, getting-started, requesting-clusters, decommissioning, onboarding) and annotated idp-core.
- [x] Updated service and cluster template skeletons with starter docs and mkdocs.yml.
- [x] Switched Backstage Search backend to Lunr search engine and verified indexers.
- [x] Configured custom GitHub sign-in resolver matching users via 'github.com/user-login' annotation or metadata name.
- [x] Mapped nimishmehta8779 GitHub account to platform-team member alice in users.yaml.
- [x] Enabled permission framework and registered custom permission policy (catalog read/delete, techdocs read) in permission-policy.ts.
- [x] Updated decommission-cluster template validation to check platform-team override and cluster ownership.
- [x] Enriched catalog with Component/Resource interactive navigable relations graph cards with a max depth of 2.
- [x] Integrated MultiEntityPicker into new-service and eks-cluster templates to allow optional multi-select dependencies and APIs.
- [x] Configured and verified CAIPE AWS mock script to dynamically query and route real EKS cluster status (alpha-dev-general-10) vs local kind clusters.
- [x] Integrated Ecosystem Status Monitor in Agent Forge sidebar drawer, showing live health checks for CAIPE, RAG (including server URL), subagents, and PostgreSQL.


