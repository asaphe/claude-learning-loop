#!/usr/bin/env bash
# Shared /learn detection — sourced by learn-suggest.sh (Stop hook) and learn-scan.sh (batch). Defines vars + fns only, no side effects.

# Anchored to line start + no space in the "no" class, so review prose ("No findings", "you assumed X") no longer matches — user corrections lead with the token.
export LEARN_CORRECTION_PATTERN='^[[:space:]]*(no[,!.]|no (i|that|you|it|don|the)|stop (doing|that)|not that|that.?s (wrong|incorrect|not (what|right))|i (said|told|meant|asked)|why (did|are|would) you|you (assumed|guessed)|did you (actually|even)|wait[,.[:space:]]|don.t (do|assume))'
export LEARN_LEARN_PATTERN='(remember this|codify this|add (to|this).*(rule|claude)|keep happening|every (session|time)|let.s codify|always do|put this in|new rule)'

learn_total_tools() {
  jq -r 'select(.type=="user") | .message.content | (if type=="array" then . else [] end) | map(select(.type=="tool_result")) | length' "$1" 2>/dev/null | awk '{s+=$1} END {print s+0}'
}

learn_failed_tools() {
  jq -r 'select(.type=="user") | .message.content | (if type=="array" then . else [] end) | map(select(.type=="tool_result" and .is_error==true)) | length' "$1" 2>/dev/null | awk '{s+=$1} END {print s+0}'
}

learn_user_text() {
  # Genuine human input only — promptSource typed/queued; "system"/absent marks injected subagent <result>/tool/skill-body prose that otherwise floods /learn with false positives.
  jq -r 'select(.type == "user" and (.promptSource == "typed" or .promptSource == "queued")) | .message.content | if type == "string" then . elif type == "array" then map(select(.type == "text") | .text) | join("\n") else empty end' "$1" 2>/dev/null
}

learn_sample_errors() {
  jq -r 'select(.type=="user") | .message.content | (if type=="array" then . else [] end) | .[] | select(.type=="tool_result" and .is_error==true) | (.content | if type=="array" then (map(.text? // "") | join(" ")) elif type=="string" then . else "" end)' "$1" 2>/dev/null | grep -v '^[[:space:]]*$' | head -"${2:-3}" | tr '\n' ' '
}
