# winnr-claude-skills

Guided AI workflows for Winnr email infrastructure management. Built on top of `winnr-mcp` (55 MCP tools).

## Skills

| Skill | Command | Purpose |
|-------|---------|---------|
| `winnr` | `/winnr` | Quick account status snapshot |
| `winnr-setup` | `/winnr setup` | Buy new domains + set up mailboxes, warming |
| `winnr-connect` | `/winnr connect` | BYOD: connect domains registered elsewhere |
| `winnr-inbox` | `/winnr inbox` | Reply triage + drafted responses |
| `winnr-health` | `/winnr health` | Traffic-light health report (0-100 scoring) |
| `winnr-troubleshoot` | `/winnr troubleshoot` | DNS/deliverability diagnostics |
| `winnr-scale` | `/winnr scale <N>` | Scale up/down with best-practice ratios |
| `winnr-export` | `/winnr export <format>` | Export to 15+ sequencer formats |

**Public/private separation**: this repo is public and MIT-licensed —
skills here only call `winnr_*` MCP tools and describe workflows a
customer can run against their own account. Internal ops skills that
need direct infrastructure access live in the private
`winnr-app/winnr-internal-skills` repo (see that repo's README for the
full "what belongs here vs. there" checklist).

## Structure
- Each skill is a directory under `skills/` containing a prompt file
- Skills reference `winnr-mcp` tools by name — they don't call the API directly
- Install: `install.sh` downloads each `skills/<name>/SKILL.md` from `main` into `~/.claude/skills/<name>/`
  (the README one-liner pipes it from raw.githubusercontent.com). A new skill must be added to its
  `SKILLS` list, or the one-liner silently skips it.

## Testing
Test a skill by invoking it in Claude Code: e.g. `/winnr health`
Skills need the Winnr MCP server connected: the hosted connector (`https://mcp.winnr.app/mcp`, OAuth
sign-in) or the local `uvx winnr-mcp` server with `WINNR_API_TOKEN`.

## Pushing
This repo is public. Commit as `Winnr <engineering@winnr.app>` and push only as the `winnr-team` GitHub
user (the local clone's credential helper does this); never from a personal account, since the repo's
Activity page names whoever pushes.
