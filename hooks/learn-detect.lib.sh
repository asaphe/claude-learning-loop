#!/usr/bin/env bash
# Shared /learn detection — sourced by learn-suggest.sh (Stop hook) and learn-scan.sh (batch). Defines vars + fns only, no side effects.

# Anchored to line start + no space in the "no" class, so review prose ("No findings", "you assumed X") no longer matches — user corrections lead with the token.
export LEARN_CORRECTION_PATTERN='^[[:space:]]*(no[,!.]|no (i|that|you|it|don|the)|stop (doing|that)|not that|that.?s (wrong|incorrect|not (what|right))|i (said|told|meant|asked)|why (did|are|would) you|you (assumed|guessed)|did you (actually|even)|wait[,.[:space:]]|don.t (do|assume))'
export LEARN_LEARN_PATTERN='(remember this|codify this|add (to|this).*(rule|claude)|keep happening|every (session|time)|let.s codify|always do|put this in|new rule)'

learn_exclude_pattern() {
  # A bad regex errors every jq select, which reads as "no corrections, ever"; fall back to no exclusion, loudly.
  [ -n "${LEARN_EXCLUDE_PATTERN:-}" ] || return 0
  if jq -n --arg ex "$LEARN_EXCLUDE_PATTERN" '"" | test($ex)' >/dev/null 2>&1; then
    printf '%s' "$LEARN_EXCLUDE_PATTERN"
  else
    echo "learning-loop: ignoring invalid LEARN_EXCLUDE_PATTERN" >&2
  fi
}

# Tool helpers take an optional ISO-8601 UTC lower bound so a batch scan counts only in-window events.
learn_total_tools() {
  jq -r --arg since "${2:-}" 'select(.type=="user" and ((.timestamp // "") >= $since)) | .message.content | (if type=="array" then . else [] end) | map(select(.type=="tool_result")) | length' "$1" 2>/dev/null | awk '{s+=$1} END {print s+0}'
}

learn_failed_tools() {
  jq -r --arg since "${2:-}" 'select(.type=="user" and ((.timestamp // "") >= $since)) | .message.content | (if type=="array" then . else [] end) | map(select(.type=="tool_result" and .is_error==true)) | length' "$1" 2>/dev/null | awk '{s+=$1} END {print s+0}'
}

learn_user_text() {
  # Genuine human input only — promptSource typed/queued; "system"/absent marks injected subagent <result>/tool/skill-body prose that otherwise floods /learn with false positives.
  jq -r --arg ex "$(learn_exclude_pattern)" 'select(.type == "user" and (.promptSource == "typed" or .promptSource == "queued")) | .message.content | (if type == "string" then . elif type == "array" then map(select(.type == "text") | .text) | join("\n") else empty end) | select($ex == "" or (test($ex) | not))' "$1" 2>/dev/null
}

learn_user_records() {
  # learn_user_text, per message at/after $2 (ISO-8601 UTC) as TSV ts/line/text-line; LEARN_EXCLUDE_PATTERN (jq regex) drops agent-relayed prompts, which are also recorded as "typed".
  jq -r --arg since "${2:-}" --arg ex "$(learn_exclude_pattern)" 'select(.type == "user" and (.promptSource == "typed" or .promptSource == "queued") and ((.timestamp // "") >= $since)) | [.timestamp, input_line_number, (.message.content | if type == "string" then . elif type == "array" then map(select(.type == "text") | .text) | join("\n") else "" end)] | select(.[2] != "" and ($ex == "" or (.[2] | test($ex) | not))) | .[2] as $t | .[0:2] as $m | $t | split("\n")[] | ($m + [.]) | @tsv' "$1" 2>/dev/null
}

learn_last_failure() {
  jq -r --arg since "${2:-}" 'select(.type=="user" and ((.timestamp // "") >= $since) and (.message.content | type == "array" and any(.[]; .type=="tool_result" and .is_error==true))) | .timestamp // empty' "$1" 2>/dev/null | sort | tail -1
}

learn_sample_errors() {
  jq -r --arg since "${3:-}" 'select(.type=="user" and ((.timestamp // "") >= $since)) | .message.content | (if type=="array" then . else [] end) | .[] | select(.type=="tool_result" and .is_error==true) | (.content | if type=="array" then (map(.text? // "") | join(" ")) elif type=="string" then . else "" end)' "$1" 2>/dev/null | grep -v '^[[:space:]]*$' | head -"${2:-3}" | tr '\n' ' '
}
