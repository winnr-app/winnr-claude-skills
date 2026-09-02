---
name: winnr
description: >
  Manage cold email infrastructure through Winnr. Provision domains, create
  mailboxes, control warming, monitor deliverability, and export data. Use when
  user says "winnr", "cold email", "email infrastructure", "domains", "mailboxes",
  "warming", "email accounts", "outreach setup", "deliverability", or asks to
  manage email sending infrastructure. Requires winnr-mcp MCP server to be
  configured with a valid Winnr API token.
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
---

# Winnr — Cold Email Infrastructure Management Skill

> **Philosophy:** The MCP server gives your AI the tools. This skill gives it the expertise.
> Every workflow encodes cold email best practices so you don't have to remember them.

---

## Quick Reference

| Command | What It Does |
|---------|-------------|
| `/winnr setup` | Buy new domains + set up DNS, mailboxes, warming from scratch |
| `/winnr connect` | Bring your own domains (BYOD): nameserver or manual-DNS mode |
| `/winnr inbox` | Triage replies across every mailbox, draft responses |
| `/winnr health` | Traffic-light health report across all domains and mailboxes |
| `/winnr troubleshoot` | DNS and deliverability diagnostic decision tree |
| `/winnr scale <N>` | Scale infrastructure up or down with best-practice ratios |
| `/winnr export <format>` | Export credentials for sequencers (Smartlead, Instantly, etc.) |
| `/winnr status` | Quick account snapshot (inline, no file output) |

---

## Prerequisites

This skill requires the **winnr-mcp** MCP server to be configured and running. If MCP tools prefixed with `winnr_` are not available, guide the user through setup:

1. **Get an API token**: Sign up at [app.winnr.app](https://app.winnr.app), go to Settings → API Tokens, create a token
2. **Add MCP server** (Claude Code): `claude mcp add winnr -- uvx winnr-mcp`
   - Set `WINNR_API_TOKEN` environment variable, or pass inline:
   - `claude mcp add winnr -- env WINNR_API_TOKEN=wnr_xxx uvx winnr-mcp`
3. **Verify**: Call `winnr_get_account` — if it returns account data, you're ready

---

## MCP Tool Inventory (54 tools in winnr-mcp 0.5.0; core ones below)

### Account (2)
| Tool | Type | Description |
|------|------|-------------|
| `winnr_get_account` | read | Account details, plan, limits |
| `winnr_get_usage` | read | Domains/users used vs. plan limits |

### Domains (14)
| Tool | Type | Description |
|------|------|-------------|
| `winnr_list_domains` | read | List all domains with status and user counts |
| `winnr_get_domain` | read | Detailed info for one domain |
| `winnr_search_domains` | read | Check single domain availability + price |
| `winnr_search_domains_bulk` | read | Check up to 100 domains at once |
| `winnr_check_dns_provider` | read | Where a domain's DNS/registrar lives today (before connect) |
| `winnr_get_dns_status` | read | DNS record propagation status |
| `winnr_get_dns_records` | read | Expected DNS records for manual setup |
| `winnr_purchase_domains` | write | Purchase + setup domains (charges Stripe) |
| `winnr_setup_domain` | write | Setup DNS/email for an owned domain |
| `winnr_connect_domains` | write | Connect external domains, get nameservers |
| `winnr_delete_domain` | write | Delete domain and all its users (async) |
| `winnr_verify_dns` | write | Live DNS verification |
| `winnr_check_nameservers` | write | Verify NS pointing for connected domains |

### Email Users (6)
| Tool | Type | Description |
|------|------|-------------|
| `winnr_list_email_users` | read | List mailboxes, filterable by domain |
| `winnr_get_email_user` | read | Details for one mailbox |
| `winnr_create_email_user` | write | Create single mailbox (async) |
| `winnr_update_email_user` | write | Update name or password |
| `winnr_delete_email_user` | write | Delete mailbox (async) |
| `winnr_bulk_create_email_users` | write | Create up to 100 mailboxes on ONE domain (`domain` + `users`) |

### Inbox (5)
| Tool | Type | Description |
|------|------|-------------|
| `winnr_list_inbox` | read | List emails across all mailboxes |
| `winnr_get_message_body` | read | Full body — needs `uid` + `mailbox` from the inbox row |
| `winnr_send_email` | write | Send email from a mailbox |
| `winnr_refresh_inbox` | write | Trigger inbox sync |
| `winnr_delete_message` | write | Delete a message (`uid` + `mailbox`) |

### Warming (8)
| Tool | Type | Description |
|------|------|-------------|
| `winnr_list_warming` | read | All warming mailboxes with stats |
| `winnr_get_warming_overview` | read | Aggregate warming statistics |
| `winnr_get_warming_metrics` | read | Daily metrics for one mailbox |
| `winnr_enable_warming` | write | Enable warming ($0.60/mailbox/month), takes `emails_per_day` + `rampup_speed` |
| `winnr_disable_warming` | write | Disable warming and stop billing |
| `winnr_pause_warming` | write | Temporarily pause warming |
| `winnr_resume_warming` | write | Resume paused warming |
| `winnr_update_warming_settings` | write | `emails_per_day` (1-20), `rampup_enabled`, `rampup_speed` |

### Jobs (2)
| Tool | Type | Description |
|------|------|-------------|
| `winnr_list_jobs` | read | List recent async operations |
| `winnr_get_job` | read | Status/progress of one job |

### Export (2)
| Tool | Type | Description |
|------|------|-------------|
| `winnr_list_export_formats` | read | Supported CSV formats |
| `winnr_export_email_users` | write | Export to CSV (22 sequencer formats; needs `domains`, `emails` or `all_domains`; write scope because the CSV has passwords) |

Also available (see the winnr-mcp README): 7 pre-warmed marketplace tools
(`winnr_browse_prewarmed`, `winnr_purchase_prewarmed`, ...) and 8 webhook tools
(`winnr_list_webhooks`, `winnr_create_webhook`, ...).

---

## Cold Email Domain Knowledge

### Key ratios and thresholds
- **Mailboxes per domain**: 3-5 (optimal for cold outreach reputation distribution)
- **Warming timeline**: 14-21 days minimum before sending campaigns
- **Healthy inbox rate**: >90% (green), 80-90% (yellow), <80% (red)
- **Healthy health score**: >80 (green), 60-80 (yellow), <60 (red)
- **Daily sending limit**: 10-15 cold emails/mailbox/day recommended; 50/day is the hard cap per mailbox (help: https://winnr.app/help/)

### TLD strategy
- **Avoid for cold email**: .com of your main brand (protect it)
- **Best for outreach**: .com first, then .net / .org / .co (different keyword, not your brand)
- **Acceptable**: .io, .app, .dev when the brand fits
- **Avoid entirely**: .xyz, .info, .biz, .click, .top, .icu (blacklist-prone)

### Naming conventions for mailboxes
- Use realistic first.last format (john.smith, sarah.jones)
- Vary patterns: first.last, firstlast, first_last, flast
- Match the display name to the username
- Avoid generic usernames: info@, sales@, contact@, noreply@

### Plan limits
| Plan | Price | Domains | Email Users | Emails/Day |
|------|-------|---------|-------------|------------|
| Startup | $69/mo | 10 | 50 | 2,500 |
| Enterprise | $189/mo | 40 | 200 | 10,000 |

---

## Command Routing

### `/winnr status` (inline — no sub-skill)

Quick account snapshot. Call these tools and format a summary:
1. `winnr_get_account` → plan, name
2. `winnr_get_usage` → domains used/limit, users used/limit
3. `winnr_get_warming_overview` → warming count, avg health, avg inbox rate

Output format:
```
## Winnr Account Status

**Account**: {name} ({plan} plan)
**Domains**: {used}/{limit} used
**Mailboxes**: {used}/{limit} used
**Warming**: {active} active, avg health {score}, avg inbox rate {rate}%
```

### `/winnr setup` → Delegate to `winnr-setup` sub-skill (buy new domains)
### `/winnr connect` → Delegate to `winnr-connect` sub-skill (bring your own domains)
### `/winnr inbox` → Delegate to `winnr-inbox` sub-skill (reply triage & response)
### `/winnr health` → Delegate to `winnr-health` sub-skill
### `/winnr troubleshoot` → Delegate to `winnr-troubleshoot` sub-skill
### `/winnr scale` → Delegate to `winnr-scale` sub-skill
### `/winnr export` → Delegate to `winnr-export` sub-skill

### Setup vs. Connect — pick the right one

- User is starting fresh, wants Winnr to **buy** domains → `/winnr setup`
- User **already owns** domains, wants to use them with Winnr → `/winnr connect`

---

## Error Recovery Guide

When MCP tools return errors, provide actionable next steps:

| Error | Cause | Next Step |
|-------|-------|-----------|
| "Authentication failed" | Invalid or expired token | "Create a new token at app.winnr.app → Settings → API Tokens" |
| "Rate limit exceeded" | Too many requests | "Wait 60 seconds and retry. Startup: 300 req/min, Enterprise: 500 req/min" |
| "Insufficient permissions" | Read-only token used for write op | "Create a new token with read+write permissions" |
| "Plan limit reached" | At capacity for domains or users | "Upgrade your plan at app.winnr.app → Settings → Billing, or delete unused resources" |
| "Domain not found" | Invalid domain ID | "Run winnr_list_domains to find the correct domain ID" |
| "Payment required" | No card on file or card declined | "Update payment method at app.winnr.app → Settings → Billing" |
| "Job failed" | Async operation error | "Check winnr_get_job for the error message. Common: DNS zone conflict, mailbox already exists" |

---

## Output Files

| Command | Output |
|---------|--------|
| `/winnr setup` | `WINNR-SETUP-REPORT.md` |
| `/winnr connect` | `WINNR-CONNECT-REPORT.md` |
| `/winnr inbox` | `WINNR-INBOX-REPORT.md` (or inline for small volumes) |
| `/winnr health` | `WINNR-HEALTH-REPORT.md` |
| `/winnr troubleshoot` | `WINNR-DIAGNOSTIC-REPORT.md` |
| `/winnr scale` | `WINNR-SCALE-REPORT.md` |
| `/winnr export` | Download URL (no local file) |
| `/winnr status` | Inline summary (no file) |
