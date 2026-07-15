#!/usr/bin/env bash
# Stop hook — flags /learn-worthy sessions (correction patterns + rate-gated tool failures) to /tmp/claude-pending-learn-<id>.jsonl.

set -u
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/learn-detect.lib.sh"
[ -r "$LIB" ] || exit 0
# shellcheck source=learn-detect.lib.sh
. "$LIB"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "unknown" ] && exit 0

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
  if [ "${TOTAL_TOOLS:-0}" -ge "$WRAPUP_MIN_TOOLS" ]; then
    printf '\n\033[33m[wrap-up]\033[0m substantial session (%s tool calls), no correction signals. Run \033[1m/wrap-up\033[0m before ending to capture model-observed learnings the auto-scan misses.\n' "$TOTAL_TOOLS" >&2
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
  printf '\n\033[33m[learn]\033[0m %s signal(s) this session (incl. %s/%s tool failures). Type \033[1m/learn\033[0m next session to codify. Candidates: %s\n' "$NUM" "$FAILED_TOOLS" "$TOTAL_TOOLS" "$CANDIDATES_FILE" >&2
else
  printf '\n\033[33m[learn]\033[0m %s correction-signal(s) this session. Type \033[1m/learn\033[0m next session to codify. Candidates: %s\n' "$NUM" "$CANDIDATES_FILE" >&2
fi
printf '\033[33m[wrap-up]\033[0m for a fuller model-observed scan, run \033[1m/wrap-up\033[0m before ending.\n' >&2

exit 0
