---
name: wrap-up
topic: Meta / self-improvement
description: >-
  Capture phase of the learning loop. At session end, scan the conversation for
  friction and learnings the passive Stop-hook regex misses (silent wrong-guesses,
  re-prompt loops, tool/config mismatches, ad-hoc scripts worth promoting) and
  write model-curated candidates to /tmp/claude-wrapup-<id>.jsonl. In proactive
  mode, auto-chains into /learning-loop:eval and surfaces its verdicts alongside
  the candidates — still capture only, never codifies, never edits
  CLAUDE.md/skills/hooks itself. Context-aware: degrades to write-only when
  tokens are scarce. Usage - /wrap-up | /wrap-up --emergency | /wrap-up --quick
user-invocable: true
allowed-tools: Read, Glob, Grep, Bash(jq *), Bash(wc *), Bash(grep *), Bash(ls *), Bash(cat *), Bash(date *), Bash(git -C *), Bash(git log *), Bash(git rev-parse *), Bash(gh pr view *), Write, AskUserQuestion
argument-hint: "(no args = full) | --quick | --emergency"
---

# Wrap-up — capture the loop before the session dies

You are the **capture phase** of the learning loop. `/learn` is the apply phase. Your job is to scan *this* conversation for what should be codified and write it to a candidate file that survives `/clear`, `/compact`, and token exhaustion — so the learning isn't lost when the session ends. You do **not** codify. You do **not** edit CLAUDE.md, skills, hooks, or docs. You write candidates and stop.

## Why this exists (don't duplicate the hook)

The Stop hook `learn-suggest.sh` already writes `/tmp/claude-pending-learn-<id>.jsonl` passively — but it only greps the *user's* text for correction patterns and tool-failure rate. It is blind to friction that left no scolding quote: a wrong guess you self-corrected, a re-prompt loop, a tool chosen where another was right, an ad-hoc command debugged across three tries. **Your added value is judgment** — you read the actual exchange and name the friction the regex can't see, with a root-cause hypothesis and a proposed destination that pre-fill `/learn`'s steps 2 and 6.

## Mode resolution (do this first)

| Trigger | Mode | Behavior |
|---|---|---|
| `--emergency`, or context-pressure system-reminders indicate near-exhaustion | `emergency` | Write candidates only. No ranking, no summary, no offer. One jq pass, then stop. |
| `--quick`, or approaching `/compact` | `quick` | Write + a one-line summary of what was captured. No offer to chain. |
| no args, healthy budget | `proactive` | Write, auto-chain into eval for a verdict table (see Closing behavior below), then tell the user to run `/learn` (which auto-finds the file). |

You cannot read your own token budget directly. Self-assess from any context-window pressure reminders present; default to `proactive` when unsure, but if the conversation is clearly long and near a limit, prefer `quick` — a written candidate is the whole point; a pretty summary that never gets written is failure.

## Active work comes first

If meaningful in-progress work exists (uncommitted changes, open PR mid-review, a half-applied plan), surface it in one line — but **do not build a new-session handoff prompt here.** If the user's CLAUDE.md (or repo-local rules) defines a handoff protocol, point to it instead of reproducing it. If no such protocol exists, a one-line note of the open state is enough — don't invent a handoff format. Wrap-up is about learnings, not project state.

## Scanning for learnings

Read this session's exchange and look for these signals. Each maps to a proposed `scope` tag that pre-fills `/learn`'s routing (step 6):

| Signal | Proposed scope |
|---|---|
| Re-prompt loop on a standing instruction (you had to be told twice) | `[CLAUDE.md]` — a behavioral rule didn't fire or doesn't exist |
| Repeated corrections on the same topic | `[SKILL:<name>]` or `[CLAUDE.md]` — principle/procedure gap |
| You guessed/assumed and were wrong (even if self-caught, no user scold) | `[CLAUDE.md]` or `[DOC]` — verify-don't-assume gap |
| Tool failure or unexpected output | `[HOOK]` or config mismatch |
| Ad-hoc command debugged in-session, re-invoked, or solving a recurring chore | `[SCRIPT]` — capture iteration history, failed versions, discovered edge cases (not just the final working line) |
| Wrong tool chosen (Bash where a skill/Edit existed, raw `gh api` where a skill fits) | `[SKILL:<name>]` or `[CLAUDE.md]` |
| Cross-session operational fact learned (a path, an API quirk, an account id) | `[DOC]` → a topic doc under your docs destination |

**Capture backlog only.** Resolved work is excluded unless the *outcome itself* is a reusable learning. One signal = one candidate. Do not pre-judge generalizability — `/learn` step 3 owns the one-off filter. Your bar is "is this friction real," not "is this rule-worthy."

**Scope tags are proposals, not decisions.** You never write to any of these destinations. `/learn` applies its own routing + refusal rules from the user's `learn-destinations.md` manifest. A `[SCRIPT]` tag in your file is a hint, not a commitment.

## Validate before writing (quality gate)

Scanning surfaces candidates by pattern-matching against the signal table above — a pattern match is not proof of a real gap. Before writing any **model-observed** candidate (no verbatim user quote backing it), run it through three checks and drop or downgrade anything that fails:

1. **Designed vs. defective** — Is this the system/hook/tool behaving exactly as its own trigger condition specifies, or did it actually misfire? A hook that fires on every turn matching its stated trigger, and gets answered correctly every time, is not friction — it's the safety net's designed cost, not a gap.
2. **Real cost vs. resolved ambiguity** — Did this produce a wrong action, a stall, or a bad outcome — or did you infer correctly on the first attempt with zero downstream impact? Reasoning through an apparent tension in the rules and getting it right is not the same signal as guessing wrong.
3. **Already guarded, and is this isolated or recurring** — Is there an existing mechanism (a harness block, a hook, an existing rule) that already caught or prevented this before it could cause harm? If so, was it a single isolated slip, or has the same guard fired repeatedly this session? A guard existing means harm was prevented *this time* — it doesn't mean the upstream behavior driving the hits is fine. A guard firing once is the guard working; a guard firing repeatedly is the guard compensating for something that should be fixed at the source.

Failing check 1 means it isn't friction — drop it. Failing check 2 with zero cost and no recurrence risk — drop it, or downgrade to `severity: low` with a one-line note on why it's borderline. Check 3: a single isolated guard-catch with no recurrence — drop it, the guard is the answer. A guard that fired more than once, or that caught something high-risk even on a single hit, is not dropped — capture it with severity scaled to recurrence count and risk, since the guard's repeated activation is itself the signal that the upstream behavior needs fixing.

Apply this gate to your own reasoning before writing, not as a question back to the user — dropping a weak candidate is exactly the judgment this skill exists to apply. Verbatim user-authored corrections bypass this gate entirely: an actual quote of the user telling you something was wrong is ground truth by construction, not your own pattern-matched inference.

## Candidate file format

Write to `/tmp/claude-wrapup-<session_id>.jsonl` (distinct from the hook's `claude-pending-learn-<id>.jsonl` — the Stop hook truncates that path at session end and would clobber you). Get the session id from the current session's jsonl filename under `~/.claude/projects/*/`.

First line is a session-metadata header; each subsequent line is one candidate:

```jsonl
{"header": true, "session_id": "<id>", "timestamp": "<iso8601>", "repo": "<name|->", "branch": "<branch|->", "commit": "<sha|->", "ticket": "<DEV-###|->", "pr": "<#|->"}
{"quote": "<verbatim user signal, OR your one-line description if model-observed>", "why": "<one-line root-cause hypothesis>", "scope": "[CLAUDE.md]|[SKILL:x]|[HOOK]|[SCRIPT]|[DOC]|[ADR]|[MEMORY]", "severity": "critical|high|medium|low", "source": "<session jsonl path:line | model-observed>", "session_id": "<id>", "timestamp": "<iso8601>"}
```

Field rules:
- `quote` — verbatim when user-originated (no paraphrase); for model-observed friction, a crisp one-line description.
- `why` — your root-cause hypothesis. This pre-fills `/learn` step 2; if you can't state one, the signal is probably noise — drop it.
- `severity` — drives `/learn`'s ranked presentation. A re-prompt on a safety/destructive rule is `critical`; a stylistic nit is `low`.
- The `quote`/`session_id`/`timestamp` keys are a **superset** of the hook's format, so `/learn` reads this file with no change to its existing reader; `why`/`scope`/`severity`/`source` are extra fields it can use when present.

For `[SCRIPT]` candidates, put the iteration history in `why` (or an extra `notes` field): what the first version got wrong, what edge case forced the fix, why the final form works. The debugging path is the learning — not just the command.

## Closing behavior by mode

- **emergency** — after writing, emit only: `wrapped: N candidate(s) → /tmp/claude-wrapup-<id>.jsonl`. Stop. No eval chain — token budget is the constraint eval exists to respect.
- **quick** — the above plus a one-line-per-candidate list (severity + quote). Stop. No eval chain, same reason.
- **proactive** — after writing, do NOT invoke the `Skill` tool for `learning-loop:eval` — a skill's own instructions asking the model to self-chain into another skill via the `Skill` tool is not a reliable composition mechanism. Instead, `Read` the sibling skill's file directly — `<this skill's base directory>/../eval/SKILL.md` — and apply its Step 0 normalization and four checks yourself, scoped to the file you just wrote. If eval's manifest-resolution step finds no `learn-destinations.md`, don't halt the whole close-out on eval's "stop" instruction — that instruction is written for eval's own standalone use, not for a caller with a capture already safely on disk. Fall back to your own severity-ranked candidate list (no verdicts) plus a one-line note: `eval skipped: no learn-destinations.md found — run /learn to scaffold one, then re-run /wrap-up or /learning-loop:eval for verdicts.` Otherwise, present the resulting verdict table (not just your own severity-ranked list) as the closing output, then:
  ```
  N candidate(s) captured → /tmp/claude-wrapup-<id>.jsonl
  M scored READY, K INCIDENT_NOTE, ... (from eval)
  Run /learn to review the consolidated report and approve codification.
  ```
  Do **not** auto-invoke `/learn` or codify/edit anything yourself — eval is read-only and so are you. `/learn` still owns the approval gate and the actual edits; you and eval only get the report in front of the user faster.

If zero real candidates: write nothing, emit `wrap-up: no learnings worth capturing this session.` Do not create an empty file, and skip the eval chain (nothing to score).

## Hard boundaries

- Capture only. No edits to CLAUDE.md, skills, agents, hooks, docs, or repo files. No `git`/`gh` writes. No PR creation.
- Never write to `~/.claude/projects/*/memory/` — that directory belongs to Claude Code's own auto-memory system, not this loop, and some setups actively block writes there. You have no reason to write there anyway; your output goes to `/tmp`.
- Never decide a destination — only propose a `scope` tag. Routing + refusal rules live in `/learn` and its `learn-destinations.md` manifest.
- Do not reproduce a new-session handoff prompt; that's the user's separate protocol, if one exists.
