# claude-learning-loop

Claude Code plugin: self-improvement feedback loop that captures friction at
session end and codifies it as durable principles.

## Conventions

- This repo IS the plugin — `.claude-plugin/plugin.json` lives at the root,
  alongside a self-referencing `.claude-plugin/marketplace.json` so it can be
  installed directly with `/plugin marketplace add`.
- No personal-machine paths (`/Users/`, `~/`, `.dotfiles`), personal Google Drive references, or hardcoded company-internal identifiers (account IDs, tenant IDs, internal service names) — this is meant to be installed by anyone, on any machine. Anything person-specific belongs in `examples/learn-destinations.example.md`, never hardcoded into a skill/hook body.
- Run `claude plugin validate .` locally before opening a PR — CI re-runs it but don't rely on CI to catch a manifest typo.
