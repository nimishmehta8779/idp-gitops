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
- **Supervisor aws eks list-clusters post-not-found loop (REPORTED,
  NOT YET REPRODUCED LIVE IN THIS PASS)**
  Symptom: after `eks_kubectl_execute` receives a real AWS
  `ResourceNotFoundException` for the queried cluster, the supervisor
  enters a loop calling `aws eks list-clusters` with the same arguments
  roughly every ~10s, unable to surface the not-found answer to the user.
  Source: session memory observations 1138–1139 ("Agent Stuck in
  Looping Pattern: Repeated EKS Listing Without Progress"; "Task
  Creation Missing Task ID Return Value"), 2026-06-28. Not independently
  reproduced in the current session — the regression close-out test
  (same date) observed the loop but attributed it to "documented in
  Open Items above," which was checked and found incorrect: no such
  entry existed before this one. That cross-reference was wrong;
  this entry is the first formal record.
  Suspected root cause (HYPOTHESIS from obs 1138–1139, not confirmed
  against code): task creation in the supervisor failed to return a
  Task ID, leaving the planning chain with no valid handle to poll for
  the result and causing it to re-query instead. Not verified directly
  against the planning/task-state code.
  Fix path: not yet investigated. Requires reproducing with a live
  trace to confirm the task-ID hypothesis before any code change.


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
exposes a knowledge base of runbooks. **[CORRECTED below — see 'Added:
EKS Troubleshoot Guide MCP Tool' entry: this is actually a LIVE
AWS-managed API call, not a bundled local KB, and the beta endpoint
currently returns HTTP 500.]**
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

## Added: EKS Troubleshoot Guide MCP Tool for AWS Agent (2026-06-25)
**CURRENT STATUS (as of 2026-06-25): NOT FUNCTIONAL.** Tool is correctly
built, correctly routed, fails loudly and honestly as designed — but
returns zero real content because AWS's own beta backend
(`mcpserver.eks-beta.us-west-2.api.aws`) currently returns HTTP 500.
Re-test when AWS's beta service is confirmed healthy.

**What:** Added `search_eks_troubleshoot_guide` tool to the AWS
subagent, backed by the official `awslabs.eks-mcp-server`, as a
sibling to the `aws_docs_search` tool added earlier today. Lets the
agent consult AWS's own EKS troubleshooting runbooks (CrashLoopBackOff,
ImagePullBackOff, node group failures, etc.) instead of generic
ad-hoc diagnosis.
**Correction to earlier investigation note:** The "Investigated"
entry above stated the knowledge base was "bundled into the package
itself ... not an external Bedrock KB requiring setup." Reading the
installed package source (`eks_kb_handler.py`) during implementation
showed this was wrong — the tool's own docstring requires "Internet
connectivity to access the EKS Knowledge Base API" and IAM permission
`eks-mcpserver:QueryKnowledgeBase`. It is a live AWS-side managed API
call (`https://mcpserver.eks-beta.us-west-2.api.aws/`), not a static
bundled KB.
**How:** Same pattern as `aws_docs_search` — `EKSTroubleshootTool` in
`patches/agent_aws_tools.py` spawns `awslabs.eks-mcp-server` as a
short-lived stdio subprocess per call via
`uv run --with awslabs.eks-mcp-server awslabs.eks-mcp-server
--no-allow-write --no-allow-sensitive-data-access`. Wired into both
`patches/deep_agent.py` (all-in-one mode, actually used) and
`patches/agent_aws_agent_langgraph.py` (multi-node mode, kept in
sync), via `get_eks_troubleshoot_tool()`.
**Proactive routing rule (added in the same change, not as a
follow-up fix):** Added a "CRITICAL - EKS/Kubernetes Troubleshooting
Questions" rule to the `agent_prompts.aws` block in
`prompt_config.deep_agent.yaml`, instructing the supervisor to
delegate any "why is this failing/unhealthy" EKS/Kubernetes question
to the AWS sub-agent so it checks `search_eks_troubleshoot_guide`
before ad-hoc kubectl diagnosis — applying the lesson from the
AWS-docs routing-gap fix above before shipping, not after a failure
was observed.
**Verified — explicit delegation phrasing:** "Delegate to the AWS
sub-agent: search the EKS troubleshoot guide once for guidance on a
pod stuck in CrashLoopBackOff. Do not retry." → fired
`search_eks_troubleshoot_guide` exactly once.
**Verified — natural/unprompted phrasing (the exact test that caught
the curl-loop bug last time; not skipped):** "Why is my pod stuck in
CrashLoopBackOff?" → fired `search_eks_troubleshoot_guide` directly,
with zero generic-tool fallback. Confirms the proactive routing rule
worked without needing a reactive fix.
**Finding — external beta endpoint returns 500:** Both verification
calls above received `❌ Error searching EKS troubleshoot guide: ...`
from the live AWS API. Isolated root cause with a standalone
diagnostic script run directly inside the container (bypassing the
LLM/agent stack) calling the MCP tool via the stdio client directly:
the AWS-managed beta endpoint itself
(`https://mcpserver.eks-beta.us-west-2.api.aws/`) returns a genuine
HTTP 500 Internal Server Error, reproducible independent of
`AWS_REGION`/`AWS_DEFAULT_REGION` (`.env` has `us-east-1`; the beta
endpoint URL is hardcoded `us-west-2` regardless). This is an external
AWS-side service issue (the EKS MCP Server's hosted KB API is in
beta), not a defect in our integration, IAM permissions, or prompt
wiring — same "fail loudly, not silently" pattern as other unconfigured
gaps in this file: the tool surfaces the real error rather than
fabricating guide content, and the supervisor correctly explained the
failure to the user and offered clearly-labeled general (non-guide)
troubleshooting steps instead of inventing guide content.
**Regression checks:**
- `aws_cli_execute` ("List all EKS clusters in my account") — still
  correct, single tool call.
- `eks_kubectl_execute` — see "Known Gap: AWS Docs Routing
  Non-Determinism" entry below for the full regression matrix, and
  the kubectl result specifically.
- `aws_docs_search` — **not fully deterministic.** See dedicated entry
  below.
**Memory footprint:** unchanged from prior phases (~310-340MB,
`docker stats --no-stream caipe-supervisor`), well within the 32GB
budget.

## Known Gap: AWS Documentation Routing Non-Determinism (2026-06-25)
**Symptom:** The supervisor does not consistently delegate AWS
documentation lookups to the AWS sub-agent's `aws_docs_search` tool.
Re-running identical documentation queries across sessions:
- 2026-06-25 (4 runs of "Search AWS documentation for S3 bucket naming
  rules"): 2/4 correctly fired `aws_docs_search`, 2/4 fell back to
  supervisor's `curl` tool (single call, returned correct content).
- 2026-06-26 (2 runs of "What is Amazon S3 Vectors?"): both misrouted
  to `curl`, both triggered additional `read_file` calls against
  `/large_tool_results/call_XXX` paths.
**What the read_file calls actually are (investigated 2026-06-26):**
The `read_file` calls are NOT "searching local knowledge" or a separate
issue. They are a direct consequence of the curl fallback: when curl
fetches a large AWS HTML page, the `tool_result_to_file` utility writes
the output to an in-memory filesystem path like
`/large_tool_results/call_GOcaUTeA8oI78CJjGqgv9MmA`. The model then
calls `read_file` repeatedly to paginate through the HTML looking for
the requested information — which it never finds on a product listing
page. Same root cause (non-delegation), different downstream symptom
(pagination spiral instead of single clean curl response).
**Severity:** COST/LATENCY/TOKEN gap, not a correctness gap. The 20×
curl loop from the original routing bug has not recurred. However the
pagination spiral is a meaningfully worse fallback than the 2/4 single-
curl cases: more model calls, more tokens, and no useful output since
HTML product pages don't contain the information the model is seeking.
**Root cause:** The `agent_prompts.aws` routing rule triggers delegation
for explicit "search AWS documentation" phrasing but not for "What is
X?" questions, which the supervisor LLM interprets as general knowledge.
**Fix attempts (2026-06-26) — both failed, reverted:**
1. Advisory guard text ("Never make more than one read_file call
   against a single large curl result") — text reached the model in
   every request payload but was ignored. Advisory prompts cannot
   enforce hard stops once the model is in a paginating loop.
2. Enumerated "What is X?" routing rule replacing the original
   delegation instruction — caused complete regression: "Search AWS
   documentation for..." hit the 20-call curl loop again, and "What
   is X?" queries started routing to the Hello World self-service
   workflow. Both worse than the original 2/4 delegation baseline.
   Reverted to original text.
**Actual fix path:** Requires code-level enforcement, not prompting:
- Option A: Tool wrapper for `tool_result_to_file` / `read_file` that
  tracks calls per large_tool_results path and errors after N=1,
  forcing the model to try a different approach.
- Option B: Fix the routing by preventing curl from being invoked at
  all — requires the routing rule to fire reliably for "What is X?"
  phrasing, which is a separate problem with the Hello World workflow
  interference (see below).
**Do not attempt prompt-only fixes for the read_file pagination
spiral.** Two attempts failed; escalate to code-level enforcement
before trying again.

## Known Gap: "What is X?" → Hello World Self-Service Workflow Misroute (2026-06-26)
**Symptom:** Queries phrased as "What is [AWS service]?" are routed to
the Hello World self-service workflow's user_input subagent ("Collect
greeting details") instead of the AWS sub-agent. Reproducible across
multiple clean requests.
**Root cause:** `tool_choice: "required"` in the OpenAI request forces
the model to always call a tool. The system prompt's MANDATORY BEHAVIOR
section says "when a user's request matches one of these workflows, call
invoke_self_service_task immediately." The only configured workflow is
"Hello World." When the model interprets "What is X?" as potentially
matching a self-service workflow (it shouldn't, but gpt-4o-mini at
temperature 0 is inconsistent), it picks the only available option.
**Not a prompt regression** — this misroute was present before any
changes in this session (it was a named "pending item" in the
investigation spec before this fix attempt began).
**Fix path:** Either remove the Hello World stub workflow from
task_config.yaml (it exists only for local dev/testing and actively
confuses routing), or add an explicit SCOPE comment to the MANDATORY
BEHAVIOR section stating that general knowledge questions ("What is X?")
never match self-service workflows and should not invoke
invoke_self_service_task.

## Resolved: AWS Documentation Routing Non-Determinism (2026-06-26)
**Previous symptom:** `aws_docs_search` fired 2/4 runs with prompt-based routing;
remaining runs fell back to the supervisor's `curl` tool, triggering
`read_file` pagination spirals on large HTML responses. Two prompt-fix
attempts both failed or caused regressions and were reverted.
**Fix (2026-06-26):** Deterministic code-level pre-router added to
`agent_executor.py` (`AIPlatformEngineerA2AExecutor.execute()`). A
module-level `_matches_aws_docs_pattern()` function checks the incoming
query against a narrow regex list before the LangGraph graph is invoked.
On match, `AWSDocsSearchTool()._arun(query)` is called directly and its
result is returned via the same `_send_artifact` + `_send_completion`
path as the normal graph exit — the LLM never runs for these queries.
Prompt-based routing is kept as fallback for phrasings the regex doesn't
catch.
**Safety guards verified:**
- `resume_cmd is None` — skips mid-flow HITL resume messages
- `_task_state != TaskState.input_required` — skips follow-up messages
  while a clarification form is pending (confirmed via `task_manager.py`
  source: framework persists `input_required` to `task_store` via
  `save_task_event()` on every `final=True` status event, so
  `context.current_task.status.state` is authoritative for the next call)
- Graceful degradation: tool failure falls through to the graph
**Verified (2026-06-26):**
- 4/4 runs of "What is Amazon S3 Vectors?" routed via pre-router,
  zero LLM graph invocations (log: `Pre-router: matched AWS docs pattern`)
- Multi-turn regression: follow-up message "aws-docs-test-cluster"
  (contains "aws" substring) sent while task in `input_required` state
  → pre-router correctly skipped, graph ran normally (tool_notification +
  final_result in response, log shows `Starting stream with query:
  aws-docs-test-cluster` bypassing pre-router)
**Files changed:**
- `infrastructure/caipe/patches/agent_executor.py` (new bind-mount)
- `infrastructure/caipe/docker-compose.upstream-trimmed.yaml` (new volume entry)

**NEW GAP: aws_docs_search per-call subprocess latency (stopgap applied, architectural fix pending)**
**Symptom:** 2/4 pre-routed calls returned `❌ AWS documentation search
timed out after 30s`. The `uv run` process itself is warm (0.19s import,
0.38s subprocess launch — uv cache at `/home/appuser/.cache/uv` is
populated and survives within a container run). The 30s timeout is
consumed entirely by the HTTP network round-trip from the MCP server
process to `docs.aws.amazon.com`. Timed directly inside the container:
a full `stdio_client` → `initialize()` → `call_tool()` cycle takes
**51 seconds** end-to-end. **Do not investigate uv cache invalidation —
confirmed not the cause.**
**Stopgap applied (2026-06-26):** `AWS_DOCS_MCP_MAX_EXECUTION_TIME=90`
set in `.env`. This raises the timeout ceiling so slow-but-successful
calls complete rather than being cut off. It does NOT fix the underlying
cause — user-visible latency for docs queries remains up to 51s+.
**Root cause (not yet fixed):** Every call to `AWSDocsSearchTool._arun()`
spawns a fresh `uv run ... python3 -m awslabs.aws_documentation_mcp_server.server`
subprocess, which must: start a new Python interpreter, import the MCP
server module, open a new TCP connection to `docs.aws.amazon.com`, and
then make the search API call — all within the timeout window. This
happens on every single invocation, even when queries are seconds apart.
**Architectural fix (not yet started):** Keep the stdio MCP subprocess
alive between calls — a persistent process the tool reuses via a
long-lived `stdio_client` session rather than spawning fresh on every
`_arun()`. This is structurally similar to how `mcp-argocd` and
`github-mcp-server` already run as persistent sidecars; the difference
is they use HTTP transport while `awslabs.aws-documentation-mcp-server`
only supports stdio. The fix would be a module-level or class-level
held `ClientSession` with reconnect-on-failure, eliminating the
subprocess spawn + TCP handshake cost from the hot path.
This is a separate, not-yet-started item — do not conflate with the
routing determinism fix above.

## Code-Review Deferred Items (2026-06-28)

Found via 8-angle static code review + verification. Items below were
confirmed or plausible but deferred from immediate fix pass.

### Deferred — verified, lower urgency

**#2 reflection-agent phantom reference (CONFIRMED via code review, DORMANT in practice)**
- `agent_aws_agent_langgraph.py:244`: The AWS agent's system prompt instructs the LLM to call
  `task(agent_name='reflection-agent', ...)` as a mandatory Phase 3 validation gate, but
  `reflection-agent` is never registered in `deep_agent.py`'s `create_aws_subagent_def` for
  multi-node mode.
- Verification: Searched all container logs across today's test sessions — no `reflection-agent`
  call was ever attempted at runtime. It appears in the system_prompt template text (printed at
  startup) but was not triggered by any tested query.
- Risk: Only fires for >3-step planning queries in multi-node mode. Never seen in practice.
- Fix when triggered: either register a reflection subagent in `create_aws_subagent_def`, or
  strip the Phase 3 validation block from `_get_system_instruction_with_date()` when called
  from `create_aws_subagent_def`.

**#6 setup_aws_profiles() race condition — FIXED (2026-06-28, commit 27e83a3)**
- Added `_aws_profiles_lock` (asyncio.Lock), `setup_aws_profiles_async()` wrapper, and
  `get_configured_profiles_async()`. Async callers (`AWSCLITool._arun`) now go through the
  locked wrapper; module-import-time call keeps the sync path (no event loop at import time).
- Smoke-tested: clean startup + pre-router docs query still completes successfully post-fix.

**#7 _safe_enqueue_event silent drain (finder-only, no verifier run)**
- `agent_executor.py:178`: Once the event queue closes, all subsequent events (including task
  completion) are silently swallowed with only a log warning. The `execute()` caller has no
  signal that delivery failed.
- Fix: set a `_stream_failed` flag or re-raise so `execute()` can detect and surface the failure.

**#8 _rebuild_graph orphaned thread (finder-only, no verifier run)**
- `deep_agent.py:1396`: `future.result(timeout=120)` raises `TimeoutError` to the caller but the
  background thread continues running and may still mutate `self._graph` and hold `_graph_lock`.
- Fix: use `asyncio.Task.cancel()` or a `threading.Event` cancellation signal instead of
  relying on `future.result()` timeout alone.

### Not yet fixed (low severity, unverified)

**#9 CAIPE base URL triplication (UNVERIFIED — rate limit)**
- Same `config.getOptionalString('agentForge.baseUrl')` + `localhost:8000→8082` rewrite
  copy-pasted in `AgentForgeChat.tsx`, `AgentForgePage.tsx`, `AgentForgeStatusDrawer.tsx`.
- Fix: extract `useCaipeBaseUrl()` hook.

**#10 O(n) setMessages on every SSE chunk (UNVERIFIED — rate limit)**
- `AgentForgeChat.tsx:349`: every streaming token calls `setMessages(prev => prev.map(...))`,
  scanning all messages on each packet. Worsens with long sessions.
- Fix: split last-message state from history, or batch via `useRef` + `flushSync`.

---

## Regression Close-Out: eks_kubectl_execute (2026-06-28)
**Test:** "Run kubectl get nodes on EKS cluster alpha-dev-general-10"
(clean run, 2026-06-28, post code-review fixes)
**Result:** TOOL FIRED CORRECTLY — NOT A REGRESSION.
- Log confirms `eks_kubectl_execute` called: `🔧 EKS Kubectl: cluster=alpha-dev-general-10, command='get nodes'`
- Real AWS returned `ResourceNotFoundException` (cluster does not exist in account)
- Tool then correctly fell back via aws-mock logic
- **Post-tool behavior:** Agent entered a `aws eks list-clusters` verification loop (same-tool-same-args
  repeating every ~10s) rather than surfacing the not-found answer cleanly. Originally attributed to
  "documented in Open Items above" — that cross-reference was checked on 2026-06-28 and found
  incorrect; no such entry existed at that time. Now formally documented as a new Open Item
  ("Supervisor aws eks list-clusters post-not-found loop") in the Open Items section above.
  Not introduced by recent fixes.
**Conclusion:** `eks_kubectl_execute` itself is regression-free. The loop is an upstream supervisor
planning issue (already known) triggered by the cluster genuinely not existing in AWS.
**Next test to close this cleanly:** Re-run once alpha-dev-general-10 (or any real EKS cluster)
exists in the account — the not-found branch confirmed working; the found+kubectl branch needs
a live cluster to validate.
