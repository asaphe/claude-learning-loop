#!/usr/bin/env bash
# Batch /learn miner — scans sessions across all projects from the last N days (default 7), writes consolidated candidates for /learn. Usage: learn-scan.sh [DAYS]

set -u
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/learn-detect.lib.sh"
[ -r "$LIB" ] || { echo "missing $LIB" >&2; exit 1; }
# shellcheck source=learn-detect.lib.sh
. "$LIB"

DAYS=${1:-7}
TOOL_FAIL_MIN=${LEARN_TOOL_FAIL_MIN:-6}
TOOL_FAIL_RATE=${LEARN_TOOL_FAIL_RATE:-25}
OUT="/tmp/claude-pending-learn-batch-$(date -u +%Y%m%d).jsonl"
: > "$OUT"
TS=$(date -u +%FT%TZ)

seen=0
flagged=0
while IFS= read -r f; do
  seen=$((seen + 1))
  sid=$(basename "$f" .jsonl)
  proj=$(basename "$(dirname "$f")")
  utext=$(learn_user_text "$f")
  cc=$(printf '%s' "$utext" | grep -ciE "$LEARN_CORRECTION_PATTERN" || true)
  lc=$(printf '%s' "$utext" | grep -ciE "$LEARN_LEARN_PATTERN" || true)
  total=$(learn_total_tools "$f")
  failed=$(learn_failed_tools "$f")

  trig=0
  tooltrig=0
  [ "${cc:-0}" -ge 2 ] && trig=1
  [ "${lc:-0}" -ge 1 ] && trig=1
  if [ "${failed:-0}" -ge "$TOOL_FAIL_MIN" ] && [ "${total:-0}" -gt 0 ]; then
    [ $(( failed * 100 / total )) -ge "$TOOL_FAIL_RATE" ] && { trig=1; tooltrig=1; }
  fi
  [ "$trig" -eq 0 ] && continue
  flagged=$((flagged + 1))

  printf '%s' "$utext" | grep -iE "$LEARN_CORRECTION_PATTERN|$LEARN_LEARN_PATTERN" | head -5 | while IFS= read -r line; do
    [ -z "$line" ] && continue
    jq -nc --arg q "$line" --arg sid "$sid" --arg p "$proj" --arg ts "$TS" '{quote: $q, session_id: $sid, project: $p, timestamp: $ts}' >> "$OUT"
  done

  if [ "$tooltrig" -eq 1 ]; then
    sample=$(learn_sample_errors "$f" 3)
    jq -nc --arg sid "$sid" --arg p "$proj" --arg ts "$TS" --argjson n "$failed" --argjson t "$total" --arg s "$sample" \
      '{signal: "tool_failures", failed: $n, total: $t, session_id: $sid, project: $p, timestamp: $ts, sample_errors: $s}' >> "$OUT"
  fi
done < <(find "$HOME"/.claude/projects -maxdepth 2 -name '*.jsonl' -type f -mtime -"$DAYS" 2>/dev/null)

cnt=$(wc -l < "$OUT" | tr -d ' ')
echo "learn-scan: ${seen} session(s) over ${DAYS}d, ${flagged} flagged, ${cnt} candidate(s)" >&2
[ "$cnt" -eq 0 ] && { rm -f "$OUT"; echo "no candidates" >&2; exit 0; }
echo "$OUT"
