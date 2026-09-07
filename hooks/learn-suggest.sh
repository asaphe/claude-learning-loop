#!/usr/bin/env bash
# Stop hook — flags /learn-worthy sessions (correction patterns + rate-gated tool failures) to /tmp/claude-pending-learn-<id>.jsonl.

set -u
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/learn-detect.lib.sh"
[ -r "$LIB" ] || exit 0
# shellcheck source=SCRIPTDIR/learn-detect.lib.sh
. "$LIB"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "unknown" ] && exit 0

# additionalContext continues the conversation; this is the harness's own re-entrancy flag, not a stamp
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null)

# /wrap-up already produced model-curated candidates for this session — don't double-flag.
[ -s "/tmp/claude-wrapup-${SESSION_ID}.jsonl" ] && exit 0

SESSION_FILE=""
for proj_dir in "$HOME"/.claude/projects/*/; do
  candidate="${proj_dir}${SESSION_ID}.jsonl"
  if [ -f "$candidate" ]; then
    SESSION_FILE="$candidate"
    break
  fi
done
[ -z "$SESSION_FILE" ] && exit 0

TOTAL_TOOLS=$(learn_total_tools "$SESSION_FILE")
FAILED_TOOLS=$(learn_failed_tools "$SESSION_FILE")
USER_TEXT=$(learn_user_text "$SESSION_FILE")

CORRECTION_COUNT=$(echo "$USER_TEXT" | grep -ciE "$LEARN_CORRECTION_PATTERN" || true)
LEARN_COUNT=$(echo "$USER_TEXT" | grep -ciE "$LEARN_LEARN_PATTERN" || true)

TOOL_FAIL_MIN=${LEARN_TOOL_FAIL_MIN:-6}
TOOL_FAIL_RATE=${LEARN_TOOL_FAIL_RATE:-25}
TOOL_TRIGGERED=0
TRIGGER=0
[ "${CORRECTION_COUNT:-0}" -ge 2 ] && TRIGGER=1
[ "${LEARN_COUNT:-0}" -ge 1 ] && TRIGGER=1
if [ "${FAILED_TOOLS:-0}" -ge "$TOOL_FAIL_MIN" ] && [ "${TOTAL_TOOLS:-0}" -gt 0 ]; then
  [ $(( FAILED_TOOLS * 100 / TOTAL_TOOLS )) -ge "$TOOL_FAIL_RATE" ] && { TRIGGER=1; TOOL_TRIGGERED=1; }
fi
# No regex signal, but a large session may still hold model-observed learnings the regex can't see → nudge /wrap-up.
WRAPUP_MIN_TOOLS=${LEARN_WRAPUP_MIN_TOOLS:-40}
if [ "$TRIGGER" -eq 0 ]; then
  # systemMessage not additionalContext: this branch fires in every ordinary long session, and would spend a forced model turn on the plugin's weakest signal
  if [ "${TOTAL_TOOLS:-0}" -ge "$WRAPUP_MIN_TOOLS" ] && [ "$STOP_HOOK_ACTIVE" != "true" ]; then
    jq -n --arg msg "[wrap-up] Substantial session (${TOTAL_TOOLS} tool calls), no correction signals. Run /wrap-up before ending to capture model-observed learnings the auto-scan misses." \
      '{systemMessage: $msg}'
  fi
  exit 0
fi

CANDIDATES_FILE="/tmp/claude-pending-learn-${SESSION_ID}.jsonl"
: > "$CANDIDATES_FILE"

TS=$(date -u +%FT%TZ)
echo "$USER_TEXT" | grep -iE "$LEARN_CORRECTION_PATTERN|$LEARN_LEARN_PATTERN" | head -10 | while IFS= read -r line; do
  [ -z "$line" ] && continue
  jq -nc --arg q "$line" --arg sid "$SESSION_ID" --arg ts "$TS" '{quote: $q, session_id: $sid, timestamp: $ts}' >> "$CANDIDATES_FILE"
done

if [ "$TOOL_TRIGGERED" -eq 1 ]; then
  SAMPLE=$(learn_sample_errors "$SESSION_FILE" 3)
  jq -nc --arg sid "$SESSION_ID" --arg ts "$TS" --argjson n "$FAILED_TOOLS" --argjson t "$TOTAL_TOOLS" --arg sample "$SAMPLE" \
    '{signal: "tool_failures", failed: $n, total: $t, session_id: $sid, timestamp: $ts, sample_errors: $sample}' >> "$CANDIDATES_FILE"
fi

[ ! -s "$CANDIDATES_FILE" ] && { rm -f "$CANDIDATES_FILE"; exit 0; }

NUM=$(wc -l < "$CANDIDATES_FILE" | tr -d ' ')
if [ "$TOOL_TRIGGERED" -eq 1 ]; then
  SUMMARY="${NUM} signal(s) this session (incl. ${FAILED_TOOLS}/${TOTAL_TOOLS} tool failures)"
else
  SUMMARY="${NUM} correction-signal(s) this session"
fi

# Path deliberately omitted: /learn globs for it, and naming it in-context points the model at attacker-influenceable tool-error text
[ "$STOP_HOOK_ACTIVE" != "true" ] && jq -n --arg ctx "LEARNING LOOP: ${SUMMARY} captured. Tell the user they can run /learn to codify these, or /wrap-up for a fuller model-observed scan." \
  '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $ctx}}'

exit 0
