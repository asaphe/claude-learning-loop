---
name: learn
topic: Meta / self-improvement
description: >-
  Close the feedback loop. Gathers every pending learning candidate — from
  /wrap-up's file, the Stop-hook's pending file, /learn-scan's batch file, an
  explicit /learn <description>, and/or --from-history Nd mining — auto-runs
  /learning-loop:eval against all of them, and presents ONE consolidated
  report (verdict, calibrated severity, destination, principle draft per
  candidate) gated behind ONE approval before codifying everything approved.
  Codifies each as a *principle* (not a rule) in the right place — your
  personal rules file, a skill body, an agent body, or a docs directory — per
  your `learn-destinations.md` manifest. Enforces anti-bloat: every addition
  to your anti-bloat-target file forces an existing compression. Usage -
  /learn [description] | /learn --from-history Nd | /learn (no args =
  gather everything pending, score it, report, approve once, codify).
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash(jq *), Bash(wc *), Bash(grep *), Bash(ls *), Bash(cat *), Bash(date *), Bash(git -C *), Bash(git diff*), Bash(git log *), Bash(git worktree *), Bash(gh *), Edit, Write, AskUserQuestion, BashOutput, Agent
argument-hint: "[description] | --from-history Nd | (no args)"
---

# Learn — close the feedback loop

You are the **apply phase** of the learning loop. `/wrap-up` captures, `/learning-loop:eval` scores, you gather everything pending across every source, consolidate it into one report, get one approval, and codify what's approved.

Two diagrams govern this skill:

1. **Inner loop** — gather → auto-eval → consolidated report → resolve ambiguity → one approval → route → edit.
2. **Outer loop (architecture)** — base skill executes → eval → self-improvement (this skill) → loop back with improved base skill.

The base skill may be `/pr-review`, `/pr-finalize`, an agent, or the unstructured default behavior governed by your personal-universal rules file. Your output updates *that* artifact, not always the same file every time.

## Destinations manifest (resolve this first)

This skill routes by **tier**, not by hardcoded path — where a principle actually lands depends on your `learn-destinations.md` manifest. Resolve it now, before continuing:

1. Look for `<repo-root>/.claude/learn-destinations.md` if you're inside a repo.
2. Else look for `~/.claude/learn-destinations.md`.
3. If neither exists, tell the user no manifest was found, offer to scaffold one from this plugin's `examples/learn-destinations.example.md`, and use `AskUserQuestion` to get at least a `personal-universal` destination before continuing. Don't guess a path.

Read whichever manifest resolves and keep it in mind for Steps B, F, and G — it defines the tiers, their paths, PR requirements, and the anti-bloat target.

## Behavioral contract

- **Batch, don't drip.** Every run gathers and reports on ALL pending candidates in one pass — see the note under Step E for why this supersedes the older one-at-a-time discipline.
- **Eval is mandatory, not advisory.** Every candidate gets scored by `/learning-loop:eval` before it reaches the report. You do not hand-roll recurrence/coverage/severity/principle judgment when eval is available — that duplication is exactly what eval exists to centralize.
- **Refuse to write a rule without a principle.** A candidate eval marked `INCIDENT_NOTE` (no principle draft) does not get written as a rule, no matter how the user feels about it in the moment — record it as an incident note instead, or ask the user to help articulate the principle so it can be re-scored.
- **Anti-bloat is non-optional.** Every addition to the manifest's anti-bloat-target file forces an existing compression, computed once against the *combined* batch delta for that file — see Step G.
- **No autonomous PR creation.** For destinations the manifest marks `pr-required`, produce the diff in a worktree and stop. Leave `gh pr create` to the user.

## Step A — Gather every pending source

Collect ALL of the following into one candidate set before scoring anything. An explicit description or `--from-history` run does not preclude also picking up pending files — merge everything into the same batch unless the user explicitly said to ignore pending files.

| Source | How |
|---|---|
| `/learn <description>` | The user named one incident directly. Quote it **verbatim** — no paraphrasing. |
| `/learn --from-history Nd` | Spawn a `general-purpose` agent to scan `~/.claude/history.jsonl` for the last N days for recurring user-correction patterns. Cap at top 5 patterns; each becomes a candidate. |
| `/tmp/claude-wrapup-*.jsonl` | Every matching file, not just the newest. |
| `/tmp/claude-pending-learn-*.jsonl` (excluding `-batch-`) | Stop-hook candidates from prior sessions. |
| `/tmp/claude-pending-learn-batch-*.jsonl` | `/learn-scan`'s cross-session batch file. |

**Candidates come from user-authored text only** (transcript role `user`, content type `text` — the same scope the Stop hook uses). Do NOT harvest candidates from assistant output, subagent returns (`tool_result` items / `<result>…</result>` blocks), or review/adversarial-sweep prose — a reviewer writing "No BLOCKING findings" or "you assumed X" is not the user correcting you. This applies to the `--from-history` mining agent's search scope too.

**Deduplicate across sources before Step B.** `/learn-scan`'s batch file can re-mine a session whose own Stop-hook pending file is still sitting unprocessed in `/tmp` — the same correction then appears in both `/tmp/claude-pending-learn-<id>.jsonl` and the batch file. Before scoring, collapse candidates that share the same `session_id` and the same or near-identical `quote` into one row; when merging, keep the richer shape (a `/wrap-up` candidate's `why`/`scope`/`severity` over a bare `quote`).

If nothing exists in any source and no description/`--from-history` was given: tell the user there's nothing pending and stop.

## Step B — Auto-eval (mandatory)

Do NOT invoke the `Skill` tool for `learning-loop:eval` — a skill's own instructions asking the model to self-chain into another skill via the `Skill` tool is not a reliable composition mechanism. Instead, `Read` the sibling skill's file directly — `<this skill's base directory>/../eval/SKILL.md` — and apply its Step 0 normalization and four checks yourself, against everything gathered in Step A. Eval's methodology produces one verdict per candidate (`READY` / `INCIDENT_NOTE` / `DUPLICATE` / `NEEDS_INPUT` / `NOISE`) with calibrated severity, resolved destination, and a principle draft where applicable. Do not hand-roll a different recurrence/coverage/severity/principle judgment — apply the checks exactly as eval's file defines them, so the two entry points (this skill and `/learning-loop:eval` run standalone) always agree. If that file reports no manifest found, resolve that first (see above) — you can't route without one either.

## Step C — Consolidated report

Present eval's verdict table as ONE report — every candidate from every source in Step A, one row each, regardless of count. This is the single point where the user sees everything pending across the whole backlog, not a per-candidate trickle.

## Step D — Resolve `NEEDS_INPUT` rows

For every row eval flagged `NEEDS_INPUT`, ask the question eval attached to it. Batch these into as few `AskUserQuestion` calls as the tool's 4-questions-per-call limit allows — one call covering up to 4 ambiguous rows, `multiSelect` where the ambiguity is "which of these destinations" rather than a single pick. If more than 4 rows need input, use the fewest additional calls needed; never one call per row when several fit together.

Apply each answer to its row immediately — resolve the destination (and re-derive the verdict: a resolved ambiguity with a `principle_draft` present becomes `READY`; without one, `INCIDENT_NOTE`) before Step E. Step E's approval list and Step F's routing operate on these resolved rows, never on eval's original pre-answer `NEEDS_INPUT` state.

## Step E — ONE approval gate

Present the full action list from the report — everything proposed across the whole batch — as one approval: codify these `READY` rows at these destinations, file these `INCIDENT_NOTE` rows, sharpen these `DUPLICATE` rows eval flagged as stale or wrong (per eval's one-line suggested edit), skip the rest of the `DUPLICATE` rows and all `NOISE` rows. Let the user deselect individual rows before approving. Get ONE explicit approval for the entire batch before touching any file.

**This supersedes the earlier "one incident per run" rule.** That rule existed to keep codification deliberate when nothing else enforced rigor. The same discipline now lives in the eval verdicts (nothing reaches `READY` without passing recurrence, coverage, and principle checks) and in this single gate (nothing gets written without explicit, reviewable sign-off) — so batching multiple candidates into one run no longer trades rigor for speed.

## Step F — Route each approved candidate

Route by the tier eval already resolved (recheck against the manifest — it doesn't change mid-run):

| Signal scope | Tier |
|---|---|
| Universal behavior (any task, any session) | `personal-universal` |
| Specific to a base skill | `skill:<name>` |
| Specific to an agent | `agent:<name>` |
| Cross-session operational fact | `doc:<topic>` |
| Repo-specific rule | `repo:<name>` — PR required if your manifest says so |
| Universal team-rigor principle | `team-universal` — PR required if your manifest says so; run its sync command afterward if one is defined |

**`INCIDENT_NOTE` rows don't go through this table** — they aren't codified as principles, so they carry no tier. Route each to `doc:incidents` per your manifest, or `~/.claude/docs/incidents/<date>-<slug>.md` if the manifest defines no dedicated row.

**Refusal rules** (generalized — see your manifest for the exact guarded paths):
- Team/repo-scoped content → never your `personal-universal` file. Route to `repo:<name>` or `team-universal`.
- Personal-context content → never a repo's `.claude/` directory. Route to `personal-universal` or `doc:<topic>`.
- Memory-style content → never `~/.claude/projects/*/memory/` (reserved for Claude Code's own auto-memory system, and some setups block writes there). Route to `doc:<topic>`.
- A signal that fits no tier in the manifest → don't invent a path. Ask, or propose a new manifest row first.

## Step G — Edit and commit (batched per destination file)

**Approved `INCIDENT_NOTE` rows write first, separately.** Each is a plain append to its Step F destination — quote, `why`, source, timestamp — not a principle codification: no anti-bloat computation, no diff-and-approval cycle beyond Step E's batch sign-off, no PR (incident-note destinations are never `pr-required`). Write them, then continue with the principle-tier edits below.

**Anti-bloat invariant (always-on, no fixed ceiling).** When multiple approved candidates target the same anti-bloat-target file, treat their combined addition as ONE delta against that file — not one anti-bloat check per candidate. Measure the file with `wc -c` before editing. You MUST pair the total addition with compression(s) elsewhere in that same file yielding a net-neutral-or-negative size delta for the combined batch — compute both numbers with `wc -c`, don't estimate. If no approved candidate targets the anti-bloat file this run, skip this check entirely.

If you cannot find enough compression to net the combined addition to neutral-or-negative, the excess does NOT go into the anti-bloat-target file — propose `doc:<topic>` destinations for whichever candidates don't fit, and say so plainly in the closing report.

**Diff and approval:**

- Non-`pr-required` destinations (`personal-universal`, `skill:<name>`, `agent:<name>`, `doc:<topic>`): construct all approved edits for that destination file together, show the combined before/after. Step E's approval already covers this — do not re-ask per file.
- `pr-required` destinations (`repo:<name>`, `team-universal`): group approved candidates by target repo. One worktree per repo (`git -C <repo-root> worktree add /tmp/learn-<slug> -b <ticket>-learn main`), apply all of that repo's approved edits there in one pass, run `git -C /tmp/learn-<slug> diff main` once and show it. Print the `gh pr create` command. **Do not run it.** The user opens the PR. If a repo's batch has no obvious ticket to hang the branch name on, ask before naming the branch.

## Closing the loop (emit once, for the whole batch)

```
codified: N principle(s) across M destination(s)
  - <principle line> → <tier>: <path>
  - ...
incident notes filed: K
  - <path>
skipped (NOISE / DUPLICATE / user-declined): J
pending files cleared: <list, or "none left pending">
next-loop expectation: <what the next session should do differently, across the whole batch>
```

This makes the loop visible for the whole run, not just one candidate. The user sees everything that changed in one place, and the next session's first action confirms whether the principles actually fired.

## Pending file format

`/tmp/claude-pending-learn-<session_id>.jsonl` (Stop hook), one JSON object per line:

```json
{"quote": "<user correction text>", "session_id": "<id>", "timestamp": "<iso8601>"}
```

`/tmp/claude-wrapup-<id>.jsonl` (`/wrap-up`) is a superset: a leading `{"header": true, ...}` session-metadata line, then candidates carrying extra `why`, `scope`, `severity`, and `source` fields. `/tmp/claude-pending-learn-batch-<date>.jsonl` (`/learn-scan`) adds a `project` field and an alternate `signal: "tool_failures"` shape. `/learning-loop:eval`'s Step 0 normalizes all three into one canonical shape — you don't need to hand-parse these; read eval's output instead.

After the batch is processed, delete every pending file that was fully resolved (codified, filed as an incident note, or explicitly skipped). If the user declined specific rows without a full-file decision, rewrite that file with `skipped: true` set on just those candidates so they don't re-surface next session, and leave the rest of the file's still-pending rows intact.

## Worked example (for the agent's reference)

This shows one row of what is now a batch report — the real report has one row per pending candidate, this is just the shape of a single `READY` row and its resolution.

Candidate: "stop putting code snippets in PR bodies — the diff IS the diff" (from `/tmp/claude-wrapup-<id>.jsonl`, `why: missing principle`, `scope: [CLAUDE.md]`, `severity: medium`).

- **Eval (Step B)** returns: recurrence 2+ (grep of `history.jsonl` shows 5+ similar corrections), coverage `partial` (personal-universal's PR-body item covers scope abstractly but not code snippets specifically), calibrated severity `medium→medium`, principle draft: "PR body describes the change; it doesn't duplicate the change. The diff is the source of truth — the body is the cover letter." Verdict: `READY`, destination `personal-universal` → `~/.claude/CLAUDE.md`.
- **Report (Step C)** shows this as one row among however many other candidates were pending.
- **Approval (Step E)** — user approves this row along with the rest of the batch.
- **Route (Step F)** — `personal-universal`, no PR required.
- **Edit (Step G)** — `wc -c ~/.claude/CLAUDE.md` reads 21,400. This candidate's addition is 600 chars; combined with any other approved candidates also targeting this file, find compression(s) netting the whole batch to neutral-or-negative before editing. Show the combined diff (already covered by Step E's approval), then `Edit`.

(This is a genericized version of the example that originally motivated this skill — the loop closing on itself.)
