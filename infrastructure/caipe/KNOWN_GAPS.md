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
