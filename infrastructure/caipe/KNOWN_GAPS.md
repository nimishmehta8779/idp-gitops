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
