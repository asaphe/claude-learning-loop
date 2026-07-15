#!/usr/bin/env bash
# PreCompact hook — non-blocking nudge to run /wrap-up before about-to-be-summarized detail is lost; silent if /wrap-up already ran this session.

set -u
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "unknown" ] && exit 0

# Already captured this session — don't nag.
[ -s "/tmp/claude-wrapup-${SESSION_ID}.jsonl" ] && exit 0

printf '\n\033[33m[wrap-up]\033[0m context is about to be compacted — detail the model-observed scan needs may be summarized away. If this session had friction/learnings, run \033[1m/wrap-up\033[0m now to capture them first.\n' >&2
exit 0
