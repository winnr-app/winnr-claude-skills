# winnr-claude-skills

Guided AI workflows for Winnr email infrastructure management. Built on top of `winnr-mcp` (36 API tools).

## Skills

| Skill | Command | Purpose |
|-------|---------|---------|
| `winnr` | `/winnr` | Quick account status snapshot |
| `winnr-setup` | `/winnr setup` | Full infrastructure wizard (domains, mailboxes, warming) |
| `winnr-health` | `/winnr health` | Traffic-light health report (0-100 scoring) |
| `winnr-troubleshoot` | `/winnr troubleshoot` | DNS/deliverability diagnostics |
| `winnr-scale` | `/winnr scale <N>` | Scale up/down with best-practice ratios |
| `winnr-export` | `/winnr export <format>` | Export to 15+ sequencer formats |

## Structure
- Each skill is a directory under `skills/` containing a prompt file
- Skills reference `winnr-mcp` tools by name — they don't call the API directly
- Install: `sh install.sh` (symlinks skills into Claude Code config)

## Testing
Test a skill by invoking it in Claude Code: e.g. `/winnr health`
Skills require `WINNR_API_TOKEN` env var (same as winnr-mcp).
