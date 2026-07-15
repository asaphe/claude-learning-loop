---
name: eval
topic: Meta / self-improvement
description: >-
  Quality gate for the learning loop. Scores every pending learning candidate
  — from /wrap-up's file, the Stop-hook's pending file, or /learn-scan's batch
  file — against four checks: pattern recurrence, existing-coverage, severity
  calibration, and principle-quality. Returns one verdict per candidate (READY,
  INCIDENT_NOTE, DUPLICATE, NEEDS_INPUT, NOISE). Read-only — never writes,
  edits, or codifies. /wrap-up (proactive mode) and /learn call this
  automatically; standalone use just prints the verdict table. Usage -
  /learning-loop:eval [path] | /learning-loop:eval (no args = auto-discover
  all pending files).
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash(jq *), Bash(wc *), Bash(grep *), Bash(ls *), Bash(cat *), Bash(date *)
argument-hint: "[path to candidate file] | (no args = auto-discover)"
---

# Eval — score pending candidates before they reach codification

You are the **quality gate** of the learning loop. `/wrap-up` captures, you score, `/learn` codifies. Take every pending candidate from whichever files exist and score each on four dimensions, so `/wrap-up` and `/learn` can build one consolidated report instead of asking the user to judge each raw candidate themselves.

You never write, edit, or codify anything, and you never call `git`/`gh`. Read-only, in every mode.

## Mode resolution

| Trigger | Behavior |
|---|---|
| `/learning-loop:eval <path>` | Score only the candidates in that one file. |
| `/learning-loop:eval` (no args) | Auto-discover and score every pending file: `/tmp/claude-wrapup-*.jsonl`, `/tmp/claude-pending-learn-*.jsonl` (excluding `-batch-`), `/tmp/claude-pending-learn-batch-*.jsonl`. |
| These instructions applied inline by `/wrap-up` or `/learn` | `/wrap-up` (proactive mode) and `/learn` (Step B) don't invoke this skill through the `Skill` tool — self-chaining a skill call from inside another skill's own instructions isn't reliable. They `Read` this file directly and apply the same normalization and checks below against whatever they name. When this file is being applied that way, the output is still the verdict table below — no separate narration. |

## Step 0 — Normalize input

Three candidate-file shapes exist. Normalize every record to one canonical shape before scoring anything:

| Source | Raw shape | Normalize |
|---|---|---|
| `/tmp/claude-wrapup-<id>.jsonl` (`/wrap-up`) | Leading `{header:true,...}` line, then `{quote, why, scope, severity, source, session_id, timestamp}` | Skip the header line. Carry `why`/`scope`/`severity` through as hints — checks 1-4 below confirm or revise them, they are not final. |
| `/tmp/claude-pending-learn-<id>.jsonl` (Stop hook) | `{quote, session_id, timestamp}` | No `why`/`scope`/`severity` — derive all three during checks 1-4. |
| `/tmp/claude-pending-learn-batch-<date>.jsonl` (`/learn-scan`) | `{quote, session_id, project, timestamp}` or `{signal:"tool_failures", failed, total, session_id, project, timestamp, sample_errors}` | The `tool_failures` shape has no `quote` — synthesize one, e.g. `"<failed>/<total> tool calls failed — sample: <first line of sample_errors>"`. No `why`/`scope`/`severity` — derive. |
| Inline `/learn <description>` or `/learn --from-history Nd` candidate — no backing file, only reachable when these checks are applied inline by `/learn`, never via standalone `/learning-loop:eval <path>` | Bare quote/pattern text, no `why`/`scope`/`severity`/`session_id`/`timestamp` | Derive `why`/`scope`/`severity` fully during checks 1-4, same as the Stop-hook shape. Use `source_file: "inline"` and the current session's `session_id`/`project`/`timestamp`. |

Canonical candidate: `{id: "<source_file>:<line>", quote, why, scope, severity, source_file, source_format, session_id, project, timestamp}`.

## Resolve the destinations manifest

Same resolution `/learn` uses — the coverage and severity checks below depend on it:

1. `<repo-root>/.claude/learn-destinations.md` if you're inside a repo, else `~/.claude/learn-destinations.md`.
2. Neither exists → tell the caller no manifest was found and stop; there's nothing to check coverage or severity against. Don't guess a path.

## The four checks

Run all four for every candidate — this is what makes the batch report trustworthy instead of just a re-listing of raw candidates.

### 1. Pattern recurrence

`Grep` the candidate's phrasing/keywords against `~/.claude/history.jsonl` (last 30 days) and against the manifest-resolved destination file(s) implied by `scope`. Record the count as `0`, `1`, or `2+`.

### 2. Existing-coverage check

`Grep` the resolved destination file for whether the concept is already covered. Decide one of `none` (nothing related exists), `partial` (related content exists but doesn't cover this specific form), or `full` (already covered — this candidate is a duplicate).

### 3. Severity calibration

Cross-check the candidate's self-reported `severity` (or your own first estimate, if none was given) against objective signals in the resolved destination:
- Mandatory/safety language present in that section (`MUST`, `NEVER`, `Safety`, `Dangerous`, `destructive`, `production`) → floor `calibrated_severity` at `high`.
- Blast radius: `team-universal` or cross-repo tiers (every session, every repo) → never calibrate down from the self-reported value. A single personal skill/doc with self-reported `critical`/`high` and no safety language → flag as a candidate for downgrade, with a one-line reason.
- Emit `calibrated_severity` and, whenever it differs from the self-reported value, the one-line reason why.

### 4. Principle-quality check

Try to state one generalizable sentence describing *how to think*, not *what command to run* — same bar as `/learn`'s principle step.
- Can state one → `principle_draft: "<sentence>"` plus 1-3 concrete-form bullets.
- Cannot (the signal only supports a single narrow bullet, no underlying principle) → `principle_draft: null`. This forces a verdict of at best `INCIDENT_NOTE`, regardless of recurrence count.

## Verdict

Evaluate top-to-bottom — first matching row wins. The last row is a catch-all: every candidate resolves to a verdict, none fall through.

| Verdict | Condition |
|---|---|
| `DUPLICATE` | coverage `full`. Recommend skip, or a one-line "sharpen existing" edit if the existing entry is stale or wrong. |
| `NEEDS_INPUT` | 2+ plausible root causes, or 2+ plausible destinations, and guessing wrong would misfile it. Name the specific ambiguity — don't resolve it yourself. |
| `NOISE` | recurrence `0`, coverage `none`/`partial`, no safety-language floor, self-reported severity `low`, AND no `principle_draft` (or its draft isn't clearly generalizable on its face — a generalizable draft qualifies for `READY` instead, never `NOISE`). Genuinely not worth acting on. |
| `READY` | `principle_draft` present, coverage `none`/`partial`, one clear destination, AND (recurrence `2+` OR clearly generalizable on its face). |
| `INCIDENT_NOTE` | Everything else — including `principle_draft` `null`, recurrence `1`, or a self-reported severity above `low` that doesn't clear the `READY` bar. Real friction, not (yet) rule-worthy. |

For every `READY` row, attach the `principle_draft`, its concrete-form bullets, and the resolved destination (tier + path, PR-required flag). For every `NEEDS_INPUT` row, attach the specific question the caller should put to the user.

## Output (return this — it IS your output, not a summary of it)

```
| # | Quote (truncated) | Severity (self→calibrated) | Verdict | Destination | Principle draft |
|---|---|---|---|---|---|
| 1 | "always ask before force-push..." | high→high | READY | skill:pr-review (ci-workflows-repo) | "Treat force-push as requiring explicit per-use consent, not standing authorization." |
| 2 | "used jq instead of --jq flag" | low→low | NOISE | — | — |
| 3 | "stop duplicating the diff in..." | critical→critical | NEEDS_INPUT | ambiguous: personal-universal vs skill:pr-review | Which — a universal PR-body rule, or specific to this skill's own PR flow? |
```

Do not ask for approval, write anything, or codify. That is `/learn`'s job, with this table as its input.
