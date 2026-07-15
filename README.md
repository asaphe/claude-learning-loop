# claude-learning-loop

Self-improvement feedback loop for Claude Code: capture friction at session
end and codify it as durable principles.

## Install

```
/plugin marketplace add asaphe/claude-learning-loop
/plugin install learning-loop@claude-learning-loop
```

## Usage

- `/learning-loop:wrap-up` — capture phase. Scans the current conversation for
  friction the passive Stop hook misses and writes candidates to `/tmp`.
- `/learning-loop:learn` — apply phase. Turns a captured or ad-hoc signal into
  a principle and routes it to the right destination via your
  `learn-destinations.md` manifest.
- `/learning-loop:learn-scan [days]` — batch-scans recent sessions across all
  projects for `/learn`-worthy patterns.
- A `Stop` hook passively flags correction patterns each session; a
  `PreCompact` hook nudges `/wrap-up` before context is summarized away.

First run of `/learning-loop:learn` will offer to scaffold your
`learn-destinations.md` from `examples/learn-destinations.example.md`
— copy it to `~/.claude/learn-destinations.md` and fill in your own paths.

## Contributing

Validate the manifest locally before pushing:

```
claude plugin validate .
```
