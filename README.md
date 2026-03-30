# Winnr Claude Code Skills

Guided AI workflows for cold email infrastructure. These [Claude Code](https://claude.ai/claude-code) skills add cold email expertise on top of the [Winnr MCP server](https://github.com/winnr-app/winnr-mcp) — turning 36 raw API tools into intelligent, best-practice workflows.

**MCP gives your AI the tools. Skills give it the expertise.**

## What you get

| Command | What it does |
|---------|-------------|
| `/winnr setup` | Full infrastructure wizard: domains, DNS, mailboxes, warming |
| `/winnr health` | Traffic-light health report with 0-100 scoring |
| `/winnr troubleshoot` | DNS and deliverability diagnostic decision trees |
| `/winnr scale <N>` | Scale up or down with best-practice ratios |
| `/winnr export <format>` | Export credentials for 15+ sequencers |
| `/winnr status` | Quick account snapshot |

## Install

### One-liner

```bash
curl -sL https://raw.githubusercontent.com/winnr-app/winnr-claude-skills/main/install.sh | bash
```

### Manual

```bash
git clone https://github.com/winnr-app/winnr-claude-skills.git
cp -r winnr-claude-skills/skills/* ~/.claude/skills/
```

### Prerequisites

1. **Claude Code** — [Install Claude Code](https://claude.ai/claude-code) if you haven't already
2. **Winnr account** — [Sign up at app.winnr.app](https://app.winnr.app) and create an API token (Settings → API Tokens)
3. **winnr-mcp** — Add the MCP server to Claude Code:

```bash
claude mcp add winnr -- env WINNR_API_TOKEN=wnr_your_token_here uvx winnr-mcp
```

## Usage examples

### Set up 30 mailboxes from scratch

```
/winnr setup

> "I need 30 mailboxes for cold outreach. My company is called Acme."

The skill will:
1. Search for available domains matching "acme" keywords
2. Purchase domains (with your confirmation)
3. Wait for DNS to propagate
4. Create mailboxes with professional names
5. Enable warming on all mailboxes
6. Generate a setup report with all credentials
```

### Morning health check

```
/winnr health

Output:
  Health: 87/100 [OK]
  DNS: 8/8 domains fully verified
  Warming: 30/32 active, avg inbox 93%, avg health 85
  Issues: 0 critical, 2 warnings
```

### Diagnose a problem

```
/winnr troubleshoot acmehq.io

The skill runs DNS checks, warming metrics analysis,
and follows diagnostic decision trees to find the root cause.
```

### Export to your sequencer

```
/winnr export smartlead

The skill checks mailbox readiness first (14+ days warming,
health >75, inbox rate >85%), then exports to Smartlead CSV format.
```

### Scale up

```
/winnr scale 20

Adds 20 new mailboxes across 5 new domains,
with warming enabled and staggered for large batches.
```

## How skills work with the MCP server

```
You (Claude Code) → /winnr setup
                      ↓
              Winnr Skill (SKILL.md)
              - Workflow sequencing
              - Domain knowledge (ratios, timelines, naming)
              - Error recovery guidance
              - Output formatting
                      ↓
              Winnr MCP Server (winnr-mcp)
              - 36 API tools
              - Authentication
              - Rate limiting
                      ↓
              Winnr API (api.winnr.app)
              - Domains, mailboxes, warming, inbox
```

Skills encode *what to do and in what order*. The MCP server handles *how to talk to the API*. Together, they give Claude the tools and the expertise to manage your email infrastructure.

## Skill reference

| Skill | File | Purpose |
|-------|------|---------|
| `winnr` | `skills/winnr/SKILL.md` | Parent orchestrator — routes commands, shared knowledge |
| `winnr-setup` | `skills/winnr-setup/SKILL.md` | Infrastructure setup wizard |
| `winnr-health` | `skills/winnr-health/SKILL.md` | Health scoring and monitoring |
| `winnr-troubleshoot` | `skills/winnr-troubleshoot/SKILL.md` | Diagnostic decision trees |
| `winnr-scale` | `skills/winnr-scale/SKILL.md` | Scale up/down operations |
| `winnr-export` | `skills/winnr-export/SKILL.md` | Export and readiness checks |

## Export formats

The `/winnr export` command supports these sequencer formats:

`default` `smartlead` `instantly` `snov` `saleshandy` `quickmail` `lemlist` `woodpecker` `reply` `mailshake` `gmass` `yesware` `mixmax` `outreach` `salesloft`

## Links

- [Winnr](https://winnr.app) — Cold email infrastructure
- [winnr-mcp](https://github.com/winnr-app/winnr-mcp) — MCP server (36 tools)
- [Skills landing page](https://winnr.app/skills.html) — Full documentation
- [API docs](https://app.winnr.app/docs) — REST API reference

## License

MIT
