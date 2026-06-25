# CAIPE Known Gaps and Limitations (as of 2026-06-24)

## Confirmed Working (verified against independent ground truth)
- EKS cluster status/health queries (real clusters, not kind-mocked)
- EKS pod/workload listing
- AWS Cost Explorer queries
- Multi-step planning and tool orchestration via A2A protocol
- Profile-based account routing (profile='default' confirmed working)

## Confirmed Gaps (failing loudly, not silently — by design, left as-is)
- Komodor: requires KOMODOR_TOKEN (not configured) — third-party
  SaaS credential, not yet obtained
- Jira, Confluence: require ATLASSIAN_TOKEN (not configured)
- Webex: requires WEBEX_TOKEN (not configured)
- PagerDuty: requires PAGERDUTY_API_KEY (not configured)
- Splunk: requires SPLUNK_TOKEN (not configured)
- Slack: real network ConnectError to localhost:3001/mcp — nothing
  listening there in this deployment
- Backstage agent: requires BACKSTAGE_API_TOKEN (not configured)

## Known But Low-Priority
- AWS agent_aws/tools.py hardcodes allow_write_operations=False,
  ignoring AWS_CLI_ALLOW_WRITE env var. Low priority: agent is
  intentionally read-only by design anyway (system prompt explicitly
  restricts to describe-*/list-*/get-*).

## Built But Dormant (not yet exercised with real data)
- Multi-account support via AWS_ACCOUNT_LIST env var and the
  caipe-read-only cross-account IAM role pattern. Code path exists
  and is well-designed (setup_aws_profiles() in tools.py), but:
    - AWS_ACCOUNT_LIST is currently unset
    - The "caipe-read-only" IAM role does not yet exist in any account
    - Current real-cluster access works ONLY because IAM user
      "nimish" has a DIRECT EKS access entry — NOT via this
      cross-account mechanism
  Action needed before adding a second AWS account: create
  caipe-read-only role + trust policy + EKS access entries, set
  AWS_ACCOUNT_LIST, and test the assume-role path for real.

## Architectural Note: Local Kind vs Real EKS Routing
infrastructure/caipe/fixed-scripts/aws-mock-VERIFIED-2026-06-24.sh
distinguishes real EKS clusters from local-only test clusters by
calling `aws eks list-clusters` and checking if the requested cluster
name appears in the real account. Real clusters get real AWS
authentication; anything else falls back to the local kind cluster's
kubeconfig. This check currently only sees clusters visible to
whatever single credential set is active in the container — it is
NOT yet account-aware (see Dormant section above).

## Resolved: False-Positive Cluster Status for Decommissioned Clusters
**Found & fixed:** 2026-06-24. aws-mock previously hardcoded
"alpha-dev-general-01" as a permanently simulated-ACTIVE cluster,
causing false ACTIVE/DEGRADED reports for this decommissioned
cluster. Fixed by removing all hardcoded cluster-name exceptions —
mock now always checks real AWS first; ResourceNotFoundException
passes through honestly with no local fallback substitution.
**Verified:** Direct grep confirms zero hardcoded names remain.
Conversational test confirms honest "not found" response.

## New: Native Full-Page CAIPE UI
**Added:** 2026-06-24. Replaced third-party
@backstage-community/plugin-agent-forge ChatAssistantPage (hardcoded
floating-overlay popup, zero configurable props, no embed mode) with
a custom full-page component at
packages/app/src/components/agent-forge/, using Backstage's native
<Page>/<Header>/<Content> primitives and theme system. Talks directly
to CAIPE's A2A JSON-RPC endpoint. Renders final_result as markdown,
tool_notification events as status lines, and UserInputMetaData as
real input forms.

## Open Items (Known, Not Blocking)
- Real-cluster query path was validated extensively earlier on
  2026-06-24 (multiple independent kubectl cross-checks against
  alpha-dev-general-10) but NOT re-confirmed after the false-positive
  fix above, since no live cluster was available at fix time. The
  fix only touched the not-found branch of aws-mock; the real-cluster
  passthrough branch was not modified. Low risk, but worth a fresh
  end-to-end check next time a real cluster is provisioned.
- Orchestrator occasionally routes cluster-status questions to the
  Komodor agent (which has no configured credentials) instead of the
  AWS agent for certain phrasings, producing a confusing "I don't
  have a tool for that" response instead of the AWS agent's cleaner
  not-found/clarification flow. Workaround: explicitly say "use the
  AWS agent" in the query. Not yet root-caused.


## Resolved: GitHub Agent Owner/Repo Confusion (2026-06-25)
**Found:** Model repeatedly constructed "owner/repo" as
"username/username" when asked to list the user's own repos,
causing 404s on list_branches/list_releases and empty results from
search_repositories (missing query param).
**Fix:** Added explicit WRONG/CORRECT examples to the github agent's
system_prompt in prompt_config.deep_agent.yaml.
**Verified:** Real query now returns correct repos with accurate
metadata (names, descriptions, languages, update dates) matching
ground truth from /user/repos API.

## Model Change: gpt-4o → gpt-4o-mini (2026-06-24)
**Reason:** gpt-4o hit organization TPM rate limits causing 60s+
query latency. gpt-4o-mini has higher TPM headroom on the same tier.
**Verified:** Same queries complete without rate-limit errors,
correct scoping maintained from earlier prompt fix.

## Security: GitHub PAT rotated (2026-06-25)
Old token was exposed in plaintext during debugging. Rotated.

## Added: AWS Documentation MCP Tool for AWS Agent (2026-06-25)
**What:** Added `aws_docs_search` tool to the AWS subagent, backed by
the official `awslabs.aws-documentation-mcp-server`. This replaces
the need for a RAG/Milvus stack for general AWS knowledge — the agent
can now pull live, authoritative AWS docs instead of relying on
possibly stale model knowledge.
**How:** The upstream `awslabs.aws-documentation-mcp-server` package
only supports stdio transport (`mcp.run()` with no transport arg) —
it cannot run as an always-up HTTP sidecar like mcp-argocd/mcp-jira.
Instead, `agent_aws/tools.py` spawns it as a short-lived stdio
subprocess per call via `uv run --with awslabs.aws-documentation-mcp-server`
(package stays cached in the image's uv cache after first call).
**Where:** This required patching vendored upstream code, not just
docker-compose env vars, because the AWS subagent (built in
`deep_agent.py`'s `create_aws_subagent_def`) only wires up
`aws_cli_execute` and `eks_kubectl_execute` — there's no generic
`AWS_MCP_HOST`-style attachment point like the other domain agents
have. Patches are bind-mounted over the image's files (same pattern
as `prompt_config.deep_agent.yaml`) so they survive container
recreation without rebuilding the image:
- `infrastructure/caipe/patches/agent_aws_tools.py` → adds
  `AWSDocsSearchTool` / `get_aws_docs_search_tool()`
- `infrastructure/caipe/patches/agent_aws_agent_langgraph.py` → wires
  the tool in for standalone/multi-node mode, adds the known-issues
  prompt section (below)
- `infrastructure/caipe/patches/deep_agent.py` → wires the tool in
  for the all-in-one mode actually used by this deployment
**Verified:** Real query ("search AWS documentation for S3 bucket
naming rules") returned live `docs.aws.amazon.com` URLs with correct
content; trace confirmed the `aws_docs_search` tool was invoked (not
a `curl` fallback). Memory footprint unchanged (~310-340MB).

## Investigated: Amazon EKS MCP Server's Runbook Knowledge Base (2026-06-25)
**Finding:** `awslabs.eks-mcp-server` is self-hostable via the same
`uvx`/stdio pattern as the docs server — NOT an AWS-account-managed
remote-only feature. (A separate "fully managed EKS MCP Server" is
in AWS preview and is a different, console-managed thing — not what
was investigated here.) Its `search_eks_troubleshoot_guide` tool
exposes a knowledge base of runbooks bundled into the package itself
(built from AWS's own operational experience), not an external
Bedrock KB requiring setup.
**Recommendation:** Go, not defer — same low-effort integration path
as the docs server above. Not implemented in this session (kept
scope to the AWS Documentation MCP server); follow the same patch
pattern in `agent_aws/tools.py` if/when this is prioritized.

## Added: Known-Issues Guidance in AWS Agent System Prompt (2026-06-25)
**What:** Appended a short "KNOWN ISSUES IN THIS DEPLOYMENT" section
to the AWS subagent's system prompt (in
`patches/agent_aws_agent_langgraph.py`, `get_system_instruction()`),
condensed from this file's "Resolved: False-Positive Cluster Status"
and AWS over-scoping entries above — a few bullet points, not the
full file, to keep per-call token cost low.
**Verified:** Asked about a known-decommissioned cluster name
(`alpha-dev-general-01`); agent correctly reported
`ResourceNotFoundException` / "does not exist" rather than fabricating
status, matching the guidance.

## Resolved: AWS Documentation Routing Gap (2026-06-25)
**Found:** The `aws_docs_search` tool added earlier worked correctly
when a query explicitly said "delegate this to the AWS sub-agent",
but natural unprompted phrasing (e.g. "Search AWS documentation for
Amazon S3 Vectors and explain what it is") was instead handled by the
supervisor itself using its own generic `curl` tool. The supervisor
hit a 302 redirect on the docs URL and looped on it 20/20 times
without ever following the redirect or trying `aws_docs_search`,
returning nothing.
**Root cause:** Routing gap, not a tool defect — nothing in the
supervisor's `agent_prompts.aws` routing-hint block (in
`prompt_config.deep_agent.yaml`) told it that documentation lookups
should be delegated rather than handled directly.
**Fix:** Added a "CRITICAL - AWS Documentation Questions" rule to the
`agent_prompts.aws` block instructing the supervisor to always
delegate documentation/limits/naming-rule/"what is X" questions to
the AWS sub-agent's `aws_docs_search` tool instead of using `curl`.
**Verified:**
- Re-ran the exact failing unprompted query post-fix: now correctly
  fires `aws_docs_search` (2 calls) with zero `curl` calls, and
  returns genuine content (real S3 Vectors description + a real
  `docs.aws.amazon.com/.../s3-vectors.html` link).
- Regression check: "List all EKS clusters in my account" still
  correctly uses `aws_cli_execute`, not misrouted to
  `aws_docs_search`.
