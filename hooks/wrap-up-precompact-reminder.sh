#!/usr/bin/env bash
# PreCompact hook — non-blocking nudge to run /wrap-up before about-to-be-summarized detail is lost; silent if /wrap-up already ran this session.

set -u
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null)
[ -z "$SESSION_ID" ] || [ "$SESSION_ID" = "unknown" ] && exit 0

# Already captured this session — don't nag.
[ -s "/tmp/claude-wrapup-${SESSION_ID}.jsonl" ] && exit 0

# PreCompact takes no additionalContext -- systemMessage is its only non-blocking channel to the user
jq -n --arg msg "[wrap-up] Context is about to be compacted — detail the model-observed scan needs may be summarized away. If this session had friction or learnings, run /wrap-up now to capture them first." \
  '{systemMessage: $msg}'
exit 0
