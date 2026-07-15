---
description: Batch-scan recent sessions for /learn-worthy correction patterns across all projects, not just the current one.
argument-hint: "[days] (default 7)"
---

# learn-scan — batch miner

Run the bundled batch scanner and report its result.

1. Execute `"${CLAUDE_PLUGIN_ROOT}"/hooks/learn-scan.sh $ARGUMENTS` (omit the argument for the default 7-day window).
2. The script prints a one-line summary (`sessions scanned`, `flagged`, `candidates`) to stderr and, if any candidates were found, the output file path to stdout.
3. If a candidate file path was produced, tell the user to run `/learning-loop:learn` next — it will pick up that file automatically. If the script reported no candidates, say so and stop.

This command only surfaces candidates; it never codifies anything itself.
