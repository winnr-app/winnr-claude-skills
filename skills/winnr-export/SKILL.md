---
name: winnr-export
description: >
  Export Winnr email credentials and generate reports. Supports 15+ formats
  for popular sales tools. Use when user says "export", "download", "CSV",
  "credentials", "connect to Smartlead", "connect to Instantly", or wants to
  get their mailbox data out of Winnr for use in a sequencer or other tool.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Winnr Export

> Export your email infrastructure credentials to any sequencer or sales tool.
> Includes readiness checks to make sure your mailboxes are ready for campaigns.

---

## Supported Export Formats

| Format | Tool | Command |
|--------|------|---------|
| `default` | Generic CSV (all fields) | `/winnr export` |
| `smartlead` | Smartlead | `/winnr export smartlead` |
| `instantly` | Instantly | `/winnr export instantly` |
| `snov` | Snov.io | `/winnr export snov` |
| `saleshandy` | SalesHandy | `/winnr export saleshandy` |
| `quickmail` | QuickMail | `/winnr export quickmail` |
| `lemlist` | Lemlist | `/winnr export lemlist` |
| `woodpecker` | Woodpecker | `/winnr export woodpecker` |
| `reply` | Reply.io | `/winnr export reply` |
| `mailshake` | Mailshake | `/winnr export mailshake` |
| `gmass` | GMass | `/winnr export gmass` |
| `yesware` | Yesware | `/winnr export yesware` |
| `mixmax` | Mixmax | `/winnr export mixmax` |
| `outreach` | Outreach | `/winnr export outreach` |
| `salesloft` | Salesloft | `/winnr export salesloft` |

---

## Workflow

### Step 1: Readiness Check

Before exporting, verify the mailboxes are ready for campaign use:

**Tools**: `winnr_get_warming_overview`, `winnr_list_warming`

**Readiness criteria:**
- Warming active for **14+ days** (minimum reputation building)
- Health score **>75** (strong enough for campaign sending)
- Inbox rate **>85%** (emails are reaching inboxes)
- Warming status **active** (not paused or disabled)

Classify each mailbox:

| Status | Criteria | Action |
|--------|----------|--------|
| **Ready** | All criteria met | Include in export |
| **Almost ready** | Warming 7-14 days OR health 60-75 | Warn user, let them decide |
| **Not ready** | Warming <7 days OR health <60 OR inbox <70% | Exclude and explain |

**Output to user:**
```
Mailbox readiness for campaign export:

Ready (18 mailboxes):
  james@acmehq.io, sarah@acmehq.io, michael@acmehq.io, ...

Almost ready (4 mailboxes — warming 10-14 days):
  emily@newdomain.xyz, david@newdomain.xyz, ...
  These mailboxes have been warming for 10 days. Ideally wait 4 more days.

Not ready (2 mailboxes — health <60):
  bad@burned.co, low@problem.io
  These mailboxes have deliverability issues. Run `/winnr troubleshoot`.

Export all 18 ready mailboxes to {format}? (or "all 22" to include almost-ready)
```

### Step 2: Export

**Tool**: `winnr_export_email_users`

1. Call `winnr_export_email_users` with the selected format
2. If filtering by domain, use the `domain` parameter
3. The API returns a download URL for the CSV file
4. Present the URL to the user

```
Export complete!

Download your {format} CSV:
{download_url}

This file contains {N} mailboxes with IMAP/SMTP credentials.
The download link expires in 24 hours.
```

### Step 3: Import Instructions

Provide tool-specific import guidance:

#### Smartlead
```
1. Go to Smartlead → Email Accounts → Import
2. Upload the CSV file
3. Smartlead auto-maps the columns
4. Set daily sending limit: start at 20-30/account/day
```

#### Instantly
```
1. Go to Instantly → Accounts → Upload Accounts
2. Upload the CSV file
3. Columns are pre-formatted for Instantly's import
4. Enable "Warm-up" in Instantly if you want to run both
   (Note: Winnr warming + Instantly warm-up is fine to run simultaneously)
```

#### Lemlist
```
1. Go to Lemlist → Settings → Email Accounts → Import
2. Upload the CSV file
3. Map columns if prompted (format matches Lemlist's expected schema)
```

#### Other tools
```
1. Open your tool's email account import feature
2. Upload the CSV file
3. Map columns as needed — the CSV includes:
   - Email address
   - SMTP server + port
   - SMTP username + password
   - IMAP server + port
   - IMAP username + password
   - Display name
```

---

## Reporting Mode

If the user asks for a report instead of a tool export, generate a `WINNR-EXPORT-REPORT.md`:

```markdown
# Winnr Infrastructure Inventory

**Date**: {date}
**Account**: {name} ({plan})

## Summary
- **Total domains**: {n}
- **Total mailboxes**: {n}
- **Campaign-ready**: {n} ({percentage}%)
- **Still warming**: {n}
- **Issues**: {n}

## Domains

| Domain | Status | Mailboxes | DNS | Warming Avg Health |
|--------|--------|-----------|-----|--------------------|
| acmehq.io | Active | 3 | OK | 91 |
| acmelabs.xyz | Active | 3 | OK | 78 |

## Mailboxes by Readiness

### Ready for Campaigns
| Email | Health | Inbox Rate | Warming Days | Domain |
|-------|--------|------------|-------------|--------|
| james@acmehq.io | 92 | 96% | 28 | acmehq.io |
| ... | ... | ... | ... | ... |

### Still Warming
| Email | Health | Inbox Rate | Warming Days | Est. Ready |
|-------|--------|------------|-------------|------------|
| emily@newdomain.xyz | 71 | 88% | 10 | ~4 more days |

### Needs Attention
| Email | Health | Inbox Rate | Issue |
|-------|--------|------------|-------|
| bad@burned.co | 38 | 52% | Domain reputation |

## Capacity
- Domain slots: {used}/{limit} ({remaining} available)
- Mailbox slots: {used}/{limit} ({remaining} available)
- Estimated monthly warming cost: ${cost}
```
