# learn-destinations.md

Read by `/learn` (and by `/wrap-up`'s proposed `scope` tags) to decide where a codified principle goes. `/learn` looks for this file at, in order:

1. `<repo-root>/.claude/learn-destinations.md` — repo-specific overrides, checked in, shared with that repo's team.
2. `~/.claude/learn-destinations.md` — your personal, user-level manifest.
3. Neither exists → `/learn` asks you interactively and offers to scaffold a copy of this example at the user-level path.

Copy this file to `~/.claude/learn-destinations.md` and fill in the bracketed placeholders for your own setup. Repos that want their own rules can check in a `.claude/learn-destinations.md` that overrides any row below.

## Destination tiers

| Tier | Destination path | PR required? | Sync command |
|---|---|---|---|
| `personal-universal` — behavior that should apply to any task, any session | `~/.claude/CLAUDE.md` | no | — |
| `skill:<name>` — specific to one skill's own body | `~/.claude/skills/<name>/SKILL.md` | no | — |
| `agent:<name>` — specific to one agent's own definition | `~/.claude/agents/<name>.md` | no | — |
| `doc:<topic>` — a cross-session operational fact (a path, an API quirk, an account id) that doesn't belong in a rule | `~/.claude/docs/<topic>.md` | no | — |
| `repo:<name>` — a rule specific to one repository | `<repo-root>/.claude/rules/<file>.md` | yes | — |
| `team-universal` — a principle every team member's session should carry, in every repo | `<path to your team's shared rules file>` | yes | `<command that propagates this file to other repos, if you have one>` |

## Refusal rules

- Team/repo-scoped content → never write it into your `personal-universal` file. Route to `repo:<name>` or `team-universal` instead.
- Personal-context content → never write it into a repo's `.claude/` directory. Route to `personal-universal` or `doc:<topic>` instead.
- Memory-style content → never `~/.claude/projects/*/memory/` (reserved for Claude Code's own auto-memory system). Route to `doc:<topic>` instead.
- A signal that doesn't fit any row above → don't invent a new path. Ask, or add a new row to this manifest first.

## Anti-bloat target

The file `/learn` treats as size-constrained enough to require a compression before every addition (see the skill's step 7):

```
anti-bloat-target: ~/.claude/CLAUDE.md
```

Change this if your personal-universal file lives somewhere else, or set it to a different frequently-edited file (e.g. a heavily-loaded skill body) if that's your actual bottleneck.
