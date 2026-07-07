---
name: winnr-troubleshoot
description: >
  DNS and deliverability diagnostic tool for Winnr email infrastructure. Uses
  decision trees to diagnose common cold email issues: DNS misconfigurations,
  warming problems, inbox rate drops, spam placement, bounces. Use when user
  says "troubleshoot", "debug", "diagnose", "fix", "DNS issue", "deliverability
  problem", "spam", "inbox rate dropping", "bounces", or reports email
  infrastructure issues.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Winnr Troubleshoot

> Systematic diagnosis for cold email infrastructure problems.
> Decision trees encode the diagnostic reasoning that takes experts years to learn.

**Everything in this skill runs through Winnr MCP tools.** If a diagnostic
step needs infrastructure access a customer wouldn't have, it doesn't belong
here — surface the finding, hand it off to Winnr support with a clear
description of what you observed.

---

## Workflow

```
Step 1: Identify symptoms  → Ask user or detect from health data
Step 2: Run diagnostics    → Follow the appropriate decision tree
Step 3: Identify root cause → Narrow down from symptoms to cause
Step 4: Prescribe fix      → Exact steps with expected timeline
Step 5: Generate report    → WINNR-DIAGNOSTIC-REPORT.md
```

---

## Step 1: Identify Symptoms

If the user specifies a domain or mailbox, start there. Otherwise, run a quick
health scan:

1. `winnr_get_warming_overview` — check for aggregate problems
2. `winnr_list_warming` — find mailboxes with low health/inbox rate
3. `winnr_list_domains` — check for domains with issues

Classify the problem into one of these categories:

| Symptom | Category | Decision Tree |
|---------|----------|--------------|
| DNS records not resolving | DNS | Tree A |
| Warming not progressing | Warming | Tree B |
| Inbox rate dropping | Deliverability | Tree C |
| High spam rate | Deliverability | Tree C |
| Mailbox creation failed | Provisioning | Tree D |
| Domain setup stuck | Provisioning | Tree D |
| Emails not sending | Sending | Tree E |
| Emails bouncing | Deliverability | Tree C |

---

## Decision Tree A: DNS Issues

**Tools**: `winnr_get_dns_status`, `winnr_get_dns_records`, `winnr_verify_dns`,
`winnr_check_nameservers`, `winnr_get_domain`

```
START → Call winnr_get_dns_status for the domain
  │
  ├─ All records OK → DNS is fine. Problem is elsewhere. Go to Tree B or C.
  │
  ├─ NS records missing or wrong ("No NS records found" / "NS mismatch")
  │   → Nameservers aren't pointed at Winnr yet, or the domain isn't
  │     registered.
  │   ├─ Call winnr_get_domain to see how this domain got into Winnr:
  │   │   ├─ Purchased via Winnr → registration may have failed or not
  │   │   │   propagated yet. Give it up to 60 minutes from setup, then
  │   │   │   escalate to Winnr support if still failing (they can inspect
  │   │   │   the registrar side).
  │   │   └─ Connected / BYOD → the user still needs to point their
  │   │       nameservers at Winnr, OR they're using manual-DNS mode and
  │   │       need to add the records themselves.
  │   │       → Call winnr_check_nameservers to see the current NS state.
  │   │       → If they're mid-change: propagation is 15 min – 48 h.
  │   │       → If they haven't started: hand off to /winnr connect for
  │   │         registrar-specific step-by-step instructions.
  │   └─ Fully unregistered (WHOIS says no such domain) → the domain
  │      was never actually registered. Only possible on BYOD when
  │      the user typed a domain they don't own; recommend /winnr setup
  │      to purchase it, or /winnr connect for a domain they do own.
  │
  ├─ MX missing/wrong
  │   ├─ Winnr-managed DNS (nameserver mode) → check setup job with
  │   │   winnr_get_job / winnr_list_jobs.
  │   │   ├─ Job still running → Wait. DNS setup takes 1-5 minutes.
  │   │   ├─ Job failed → Read the error. If it looks like a Winnr-side
  │   │   │   issue (zone conflict, provisioning error), escalate to
  │   │   │   Winnr support with the job id.
  │   │   └─ Job completed but records still wrong → propagation delay,
  │   │      wait 15 min and re-check winnr_verify_dns.
  │   └─ Manual DNS mode → user needs to add MX records themselves.
  │       → Call winnr_get_dns_records for the exact values.
  │       → Provide step-by-step for their DNS provider.
  │
  ├─ SPF missing/wrong
  │   ├─ Winnr-managed → should be auto-set. Check job status.
  │   └─ Manual DNS → user must add the SPF TXT record shown by
  │       winnr_get_dns_records.
  │       → CRITICAL: if the domain already has an SPF record (starts
  │         with v=spf1), the user MUST MERGE, not duplicate. Two SPF
  │         records at the same host break SPF authentication.
  │
  ├─ DKIM missing
  │   ├─ Winnr-managed → auto-configured. 5-15 min to propagate.
  │   │   → DKIM records are CNAME records (not TXT). If the user's DNS
  │   │     tool created it as TXT, it will fail.
  │   └─ Manual DNS → call winnr_get_dns_records for the DKIM CNAME
  │       host + target and have the user add it.
  │
  └─ DMARC missing
      → Call winnr_get_dns_records for the recommended DMARC value.
      → DMARC is a TXT record on _dmarc.{domain}.
      → For cold email, p=none is fine to start (don't jump to p=reject).
```

### DNS Propagation Timeframes

| Record Type | Winnr-managed | Manual / External DNS |
|-------------|---------------|-----------------------|
| MX          | 1-5 minutes   | 15 min – 48 h         |
| SPF (TXT)   | 1-5 minutes   | 15 min – 48 h         |
| DKIM (CNAME)| 5-15 minutes  | 15 min – 48 h         |
| DMARC (TXT) | 1-5 minutes   | 15 min – 48 h         |
| Nameservers | N/A           | 15 min – 48 h         |

If `winnr_verify_dns` and `winnr_get_dns_status` disagree, trust
`winnr_verify_dns` — it runs a live lookup, `winnr_get_dns_status` may
show a cached result.

---

## Decision Tree B: Warming Issues

**Tools**: `winnr_get_warming_metrics`, `winnr_list_warming`,
`winnr_get_warming_overview`, `winnr_pause_warming`, `winnr_resume_warming`

```
START → Call winnr_list_warming, find problematic mailboxes
  │
  ├─ Warming status = "paused"
  │   → Resume with winnr_resume_warming.
  │   → If it auto-paused, health was critically low — check metrics
  │     before resuming; may need to wait 48-72 hours.
  │
  ├─ Warming status = "disabled"
  │   → Re-enable with winnr_enable_warming.
  │   → Warning: re-enabling starts from scratch (no history).
  │
  ├─ Health score declining over time
  │   → winnr_get_warming_metrics for daily trend data
  │   ├─ Sudden drop → check if DNS changed (Tree A)
  │   ├─ Gradual decline → domain reputation issue
  │   │   ├─ Domain age <30 days → Normal. New domains take time.
  │   │   ├─ Domain age >30 days → Possible blocklisting. Check
  │   │   │   MXToolbox and Google Postmaster Tools for the domain.
  │   │   └─ Multiple domains declining together → could be a shared
  │   │       infrastructure issue on Winnr's side. Escalate to Winnr
  │   │       support with the domain list and the metrics dates.
  │   └─ Stagnant (not improving) → warming settings too aggressive
  │       → winnr_update_warming_settings: daily_limit=10-15,
  │         ramp_up=true
  │
  ├─ Daily volume = 0 despite being "active"
  │   → Warming pool may still be ramping. First 24-48 h can be low.
  │
  └─ Warming emails going to spam at high rate (>15%)
      ├─ Check DNS first (Tree A) — missing SPF/DKIM = instant spam
      ├─ Domain very new (<7 days) → Normal. Spam rate decreases over time.
      ├─ Domain aged but high spam → possible domain reputation issue.
      │   → Pause warming for 72 hours, then resume with conservative
      │     settings (daily_limit=5, ramp_up=true).
      └─ All mailboxes on the domain affected → domain-level problem.
          → Pause all warming on the domain.
          → Verify DNS, wait 72 h, re-enable conservatively.
```

---

## Decision Tree C: Deliverability Issues

**Tools**: `winnr_get_warming_metrics`, `winnr_list_warming`,
`winnr_get_dns_status`, `winnr_list_inbox`

```
START → Identify affected mailboxes from warming data
  │
  ├─ Inbox rate <80% on specific mailboxes
  │   ├─ New mailbox (<14 days)? → Normal. Still building reputation.
  │   ├─ Recently used for campaigns? → Campaign content may be hurting.
  │   │   → Pause campaigns for 48 h. Let warming recover reputation.
  │   ├─ DNS changed recently? → Run Tree A.
  │   └─ Reputation declined 7+ days? → Domain may be burned.
  │       → Recovery: disable warming 7 days, re-enable with
  │         daily_limit=5, ramp_up=true.
  │
  ├─ Inbox rate <80% across ALL mailboxes
  │   → Account-level. Verify DNS on every domain (Tree A).
  │   → If DNS is fine and the drop is sudden, escalate to Winnr
  │     support — could be shared infrastructure.
  │
  ├─ Spam rate >15% on a specific domain
  │   → Domain-level reputation problem.
  │   ├─ DNS fully configured? (Tree A)
  │   ├─ Domain age? (<30 days = patience, >30 days = concern)
  │   ├─ Sending volume too high? → Reduce daily_limit.
  │   └─ Consider: this domain may be burned. Retire and create a new
  │     one via /winnr scale or /winnr setup.
  │
  └─ Emails bouncing
      → Check inbox for bounce notifications: winnr_list_inbox with
        a recent date filter — bounce messages come from mailer-daemon@
        or postmaster@ with subject "Undeliverable" / "Delivery Status
        Notification".
      ├─ Bounces from ONE recipient → address doesn't exist or that
      │   recipient's server rejects you specifically. Suppress that
      │   address.
      ├─ Bounces from ONE recipient DOMAIN → their mail server may be
      │   blocking your sending domain. Check MXToolbox for your
      │   sending domain's blocklist status.
      └─ Bounces from MANY recipient domains → your sending domain or
          IP reputation is degraded. Pause campaigns, check DNS (Tree A),
          check MXToolbox / Google Postmaster, and escalate to Winnr
          support if reputation looks fine externally.
```

### Domain Reputation Recovery Protocol

When a domain's inbox rate drops below 60% or health score below 40:

1. **Immediate**: pause warming on the domain (`winnr_pause_warming`)
2. **Wait 72 hours**: let the domain cool down
3. **Verify DNS**: full DNS check (Tree A)
4. **Resume conservatively**: `winnr_enable_warming` +
   `winnr_update_warming_settings` daily_limit=5, ramp_up=true
5. **Monitor daily**: check metrics for 7 days
6. **If no improvement after 14 days**: retire the domain and buy a new
   one via `/winnr scale` or `/winnr setup`

---

## Decision Tree D: Provisioning Issues

**Tools**: `winnr_list_jobs`, `winnr_get_job`, `winnr_get_domain`

```
START → Get the job ID from the failed operation
  │
  ├─ Job status = "queued"
  │   → Still waiting. Check again in 30 seconds.
  │
  ├─ Job status = "in_progress"
  │   → Currently running. Check again in 30 seconds.
  │
  ├─ Job status = "error"
  │   → Read the error message from the job.
  │   ├─ "Zone already exists" → Domain was previously set up. Delete
  │   │   with winnr_delete_domain, wait 30s, retry.
  │   ├─ "Mailbox already exists" → skip or rename.
  │   ├─ "Registration failed" → domain wasn't available at the
  │   │   registrar. Try a different name via winnr_search_domains.
  │   ├─ "Payment failed" → card issue. Update at app.winnr.app →
  │   │   Settings → Billing.
  │   └─ Other → surface the error to the user and escalate to Winnr
  │     support with the job id if it looks infrastructure-side.
  │
  ├─ Job status = "completed" but resource not visible
  │   → Eventual consistency. Wait 30 seconds and re-query.
  │
  └─ Domain shows "complete" but DNS is failing / warming won't enable
      → Call winnr_get_domain — check the domain type (purchased vs
        connected/BYOD) and its dns_health status.
      ├─ Connected/BYOD with "No NS records" → user never pointed
      │   nameservers. Hand off to /winnr connect.
      ├─ Purchased but no MX/SPF/DKIM → provisioning race; retry setup
      │   via winnr_verify_dns or escalate to Winnr support.
      └─ Any other "false complete" pattern → escalate with the domain
          id + dns_health payload.
```

---

## Decision Tree E: Sending Issues

**Tools**: `winnr_list_inbox`, `winnr_send_email`, `winnr_get_email_user`

```
START → User reports emails not sending
  │
  ├─ Using winnr_send_email?
  │   ├─ "user not found" → wrong user_id. winnr_list_email_users first.
  │   ├─ "authentication failed" → token issue. Check permissions.
  │   └─ "rate limited" → sending too fast. Wait and retry.
  │
  ├─ Sending via sequencer (Smartlead, Instantly, etc.)?
  │   → Problem is likely SMTP credentials, not Winnr.
  │   → Re-export via /winnr export and re-import to the sequencer.
  │   → Common: wrong SMTP port (use 587), wrong hostname.
  │
  └─ Emails sent but not arriving?
      → Check recipient spam folder.
      → Check warming health — low health = spam-foldered.
      → Run DNS check (Tree A) to confirm auth records.
```

---

## Step 5: Generate Report

Write `WINNR-DIAGNOSTIC-REPORT.md`:

```markdown
# Winnr Diagnostic Report

**Date**: {date}
**Scope**: {domain or "all domains"}

## Symptoms Investigated
- {symptom 1}
- {symptom 2}

## Root Cause
{Clear explanation of what's wrong and why}

## Evidence
| Check | Result | Expected |
|-------|--------|----------|
| {what was checked} | {actual value} | {expected value} |

## Fix
1. {Step 1 — exact action to take}
2. {Step 2}
3. {Step 3}

## Expected Recovery Timeline
{When the user should expect to see improvement}

## Prevention
{What to do differently to avoid this in the future}
```

---

## Escalation to Winnr support

Some problems live on the Winnr infrastructure side (a specific
provisioning job's internal state, shared-IP reputation, registrar
account status). If a decision tree ends with "escalate to Winnr
support", give the user:

- The domain id(s) affected
- The job id (from `winnr_list_jobs`) if provisioning-related
- What you already checked and what came back
- Contact: support@winnr.app or the in-app help widget
