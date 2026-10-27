#!/usr/bin/env bash
# Batch /learn miner — scans sessions across all projects from the last N days (default 7), writes consolidated candidates for /learn. Usage: learn-scan.sh [DAYS]

set -u
LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/learn-detect.lib.sh"
[ -r "$LIB" ] || { echo "missing $LIB" >&2; exit 1; }
# shellcheck source=SCRIPTDIR/learn-detect.lib.sh
. "$LIB"

DAYS=${1:-7}
TOOL_FAIL_MIN=${LEARN_TOOL_FAIL_MIN:-6}
TOOL_FAIL_RATE=${LEARN_TOOL_FAIL_RATE:-25}
OUT="/tmp/claude-pending-learn-batch-$(date -u +%Y%m%d).jsonl"
: > "$OUT"
TS=$(date -u +%FT%TZ)
# mtime only preselects files; a resumed old transcript is newer than its messages, so the window is applied per message.
SINCE=$(date -u -v-"${DAYS}"d +%FT%TZ 2>/dev/null || date -u -d "-${DAYS} days" +%FT%TZ)
LEARN_EXCLUDE_PATTERN=$(learn_exclude_pattern)
export LEARN_EXCLUDE_PATTERN
printf '' | grep -qE -- "${LEARN_EXCLUDE_PROJECT_PATTERN--scratchpad(-|$)}" 2>/dev/null; [ $? -eq 2 ] && echo "learning-loop: invalid LEARN_EXCLUDE_PROJECT_PATTERN, no project is skipped" >&2

seen=0
flagged=0
skipped=0
while IFS= read -r f; do
  seen=$((seen + 1))
  sid=$(basename "$f" .jsonl)
  proj=$(basename "$(dirname "$f")")
  learn_excluded_project "$proj" && { skipped=$((skipped + 1)); continue; }
  recs=$(learn_user_records "$f" "$SINCE")
  cc=$(printf '%s\n' "$recs" | cut -f3- | grep -ciE "$LEARN_CORRECTION_PATTERN" || true)
  lc=$(printf '%s\n' "$recs" | cut -f3- | grep -ciE "$LEARN_LEARN_PATTERN" || true)
  total=$(learn_total_tools "$f" "$SINCE")
  failed=$(learn_failed_tools "$f" "$SINCE")

  trig=0
  tooltrig=0
  [ "${cc:-0}" -ge 2 ] && trig=1
  [ "${lc:-0}" -ge 1 ] && trig=1
  if [ "${failed:-0}" -ge "$TOOL_FAIL_MIN" ] && [ "${total:-0}" -gt 0 ]; then
    [ $(( failed * 100 / total )) -ge "$TOOL_FAIL_RATE" ] && { trig=1; tooltrig=1; }
  fi
  [ "$trig" -eq 0 ] && continue
  flagged=$((flagged + 1))

  printf '%s\n' "$recs" | while IFS=$'\t' read -r qts qline text; do
    [ -z "$text" ] && continue
    printf '%s\n' "$text" | grep -qiE "$LEARN_CORRECTION_PATTERN|$LEARN_LEARN_PATTERN" || continue
    printf '%s\t%s\t%s\n' "$qts" "$qline" "$text"
  done | head -5 | while IFS=$'\t' read -r qts qline text; do
    jq -nc --arg q "$text" --arg sid "$sid" --arg p "$proj" --arg ts "$qts" --arg src "$f:$qline" --arg now "$TS" \
      '{quote: ($q | gsub("\\\\(?<c>[tnr\\\\])"; {"t": "\t", "n": "\n", "r": "\r", "\\": "\\"}[.c])), session_id: $sid, project: $p, timestamp: $ts, source: $src, scanned_at: $now}' >> "$OUT"
  done

  if [ "$tooltrig" -eq 1 ]; then
    sample=$(learn_sample_errors "$f" 3 "$SINCE")
    last=$(learn_last_failure "$f" "$SINCE")
    jq -nc --arg sid "$sid" --arg p "$proj" --arg ts "${last:-$TS}" --arg now "$TS" --argjson n "$failed" --argjson t "$total" --arg s "$sample" \
      '{signal: "tool_failures", failed: $n, total: $t, session_id: $sid, project: $p, timestamp: $ts, scanned_at: $now, sample_errors: $s}' >> "$OUT"
  fi
done < <(find "$HOME"/.claude/projects -maxdepth 2 -name '*.jsonl' -type f -mtime -"$DAYS" 2>/dev/null)

cnt=$(wc -l < "$OUT" | tr -d ' ')
echo "learn-scan: ${seen} session(s) over ${DAYS}d, ${skipped} skipped as scratchpad probes, ${flagged} flagged, ${cnt} candidate(s)" >&2
[ "$cnt" -eq 0 ] && { rm -f "$OUT"; echo "no candidates" >&2; exit 0; }
echo "$OUT"
