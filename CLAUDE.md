# CLAUDE.md

Behavioral guidelines for working in this repository. Derived from
Andrej Karpathy's January 2026 observations on common LLM coding
failure modes (not written or endorsed by Karpathy himself — these
are this project's adaptation of community-distilled principles).
Merge with task-specific instructions as needed; for trivial,
one-line tasks, use judgment rather than applying every rule
mechanically.

These guidelines bias toward caution over speed. That tradeoff is
deliberate for this project, given its history of "looks done" claims
that turned out to be wrong (a hardcoded mock exception disguised as
a fix, a false-positive cluster status report, a 20-call routing
loop) — every one of those was caught by treating completion claims
as unverified until checked against real evidence.

## Rule 1 — No silent assumptions

State assumptions explicitly before acting on them. If a request is
ambiguous, or if multiple reasonable interpretations exist, present
them and ask rather than silently picking one. If you're not sure
which file actually governs a piece of behavior (this project has
repeatedly had prompt-text exist in a YAML block that turns out not
to be the file the model actually reads), say so and verify the real
source before proceeding — don't assume a plausible-looking edit
location is the correct one.

## Rule 2 — Surface confusion and tradeoffs, don't hide them

If something is unclear, stop and name exactly what's confusing
before continuing. If a fix has a real tradeoff (e.g. "this closes
the security hole but every documentation query now takes up to 90
seconds instead of 30"), state the tradeoff plainly rather than
presenting only the upside. Don't report a result as "complete" or
"verified" when only the success path was tested — say explicitly
which paths were and weren't exercised.

## Rule 3 — Minimum code, no speculative scope

Write the minimum code that solves the actual problem. No features
beyond what was asked. No abstractions for single-use code. No added
"flexibility" or "configurability" that wasn't requested. If a fix
could be one line and you've written ten, rewrite it. Ask: would a
senior engineer call this overcomplicated? If yes, simplify.

## Rule 4 — Touch only what the task requires

Don't edit, "improve," or refactor code that's orthogonal to the
current task, even if you notice something else that looks wrong
along the way — name it and ask, don't fix it silently in the same
change. Scope drift (doing genuinely useful but unrequested work
instead of the approved task) is a real failure mode this project
has hit before; flag it, don't act on it without confirmation.

## Rule 5 — Verify before declaring done (this project's addition)

A claim of "fixed," "verified," or "working" requires real evidence
at every layer it touches, not a plausible-sounding summary:
  - File-level: did the edit actually land on disk where you think?
  - Build/container-level: did the running process actually pick
    up the change (recreate, not just restart, where relevant)?
  - Behavior-level: does a REAL request, including the FAILURE path
    if the fix is about error handling, produce the expected result?
A static read of the code ("this looks correct") is a hypothesis,
not a verification. Test the case the fix was meant to handle, not
just confirm it doesn't break the easy case.

## Success-criteria-first execution

Where possible, state the success criteria for a task up front (what
"done" looks like, concretely and checkably) rather than only giving
step-by-step instructions — this project's most reliable fixes all
had an explicit verification step defined before implementation
started, not bolted on afterward.

---

## Freeze boundary (active as of freeze-baseline tag)

The following are FROZEN — read-only unless explicitly told otherwise
for a specific task, even if a task seems to require touching them:
  - infrastructure/backstage/app-config.yaml (auth/permission sections)
  - infrastructure/backstage/packages/backend/src/plugins/permission-policy.ts
  - infrastructure/crossplane/eks/composition.yaml
  - infrastructure/iam/
  - development/templates/ (all 4 templates)
  - All team-*-infra repos' existing structure

OPEN for active work:
  - infrastructure/caipe/
  - New MCP server work (new files/directories)
  - New, additive files anywhere — not edits to the frozen list above

If a task seems to require modifying something on the frozen list,
stop and say so explicitly (per Rule 2) rather than proceeding —
that needs deliberate human sign-off, not a silent assumption that
it's fine this one time.

## These guidelines are working if:

- Diffs contain only what was requested, nothing orthogonal
- Fewer rewrites caused by overcomplication on the first pass
- Clarifying questions arrive before implementation, not after a
  wrong assumption is discovered downstream
- A "done" report includes the actual failure-path test, not just
  the happy-path one