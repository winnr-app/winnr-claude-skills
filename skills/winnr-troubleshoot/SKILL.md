---
name: winnr-troubleshoot
description: >
  DNS and deliverability diagnostic tool for Winnr email infrastructure. Uses
  decision trees to diagnose common cold email issues: DNS misconfigurations,
  warming problems, inbox rate drops, spam placement. Use when user says
  "troubleshoot", "debug", "diagnose", "fix", "DNS issue", "deliverability
  problem", "spam", "inbox rate dropping", or reports email infrastructure issues.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Winnr Troubleshoot

> Systematic diagnosis for cold email infrastructure problems.
> Decision trees encode the diagnostic reasoning that takes experts years to learn.

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

If the user specifies a domain or mailbox, start there. Otherwise, run a quick health scan:

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

---

## Decision Tree A: DNS Issues

**Tools**: `winnr_get_dns_status`, `winnr_get_dns_records`, `winnr_verify_dns`

```
START → Call winnr_get_dns_status for the domain
  │
  ├─ All records OK → DNS is fine. Problem is elsewhere. Go to Tree B or C.
  │
  ├─ NS records missing ("No NS records found")
  │   → Domain may not be registered at any registrar.
  │   ├─ Check domain's `registrar` field in Firestore:
  │   │   ├─ registrar = "external" (BYOD) → Domain was added, NOT purchased through Winnr.
  │   │   │   → Verify WHOIS: `whois {domain}` — if "No match", domain is unregistered.
  │   │   │   → Customer likely confused "add domain" with "purchase domain".
  │   │   │   → Fix: Customer must register domain with a registrar (Namecheap, GoDaddy,
  │   │   │     Cloudflare, etc.) then point NS to the CloudDNS nameservers shown in Winnr.
  │   │   │   → OR: Delete external domains and re-add via the purchase flow.
  │   │   │   → Check Stripe for domain charges — if none, purchase was never attempted.
  │   │   └─ registrar = "dynadot" → Domain was purchased but may have failed silently.
  │   │       → Check WHOIS to confirm registration.
  │   │       → Check CloudWatch logs for `should_register` and Dynadot API errors.
  │   │       → Check Stripe for a "Domain registration:" invoice line item.
  │   └─ If NS exist but wrong → Nameservers not pointed to CloudDNS.
  │       → Provide the correct NS records (ns1-4.programessentials.com for clouddns3, etc.)
  │       → Propagation: 24-72 hours for nameserver changes.
  │
  ├─ MX missing/wrong
  │   ├─ Winnr-managed DNS → Check if domain setup job completed (winnr_get_job)
  │   │   ├─ Job still running → Wait. DNS setup takes 1-5 minutes.
  │   │   ├─ Job failed → Check error. Common: zone conflict, registrar lock.
  │   │   └─ Job completed → MX should be set. Wait 15 min for propagation.
  │   └─ External DNS → User needs to add MX records manually.
  │       → Call winnr_get_dns_records for exact values.
  │       → Provide step-by-step for their DNS provider.
  │
  ├─ SPF missing/wrong
  │   ├─ Winnr-managed → Should be auto-set. Check job status.
  │   └─ External → User must add TXT record: v=spf1 include:_spf.winnr.app ~all
  │       → IMPORTANT: If user has existing SPF, they must MERGE, not replace.
  │       → Multiple SPF records = SPF failure. Only one TXT record for SPF allowed.
  │
  ├─ DKIM missing
  │   ├─ Winnr-managed → Auto-configured. May take 5-15 min to propagate.
  │   │   → Check: DKIM records are CNAME records, not TXT.
  │   └─ External → Call winnr_get_dns_records for the DKIM CNAME value.
  │       → Add as CNAME record at their DNS provider.
  │
  └─ DMARC missing
      → Recommended record: v=DMARC1; p=none; rua=mailto:dmarc@{domain}
      → For cold email, p=none is fine (don't use p=reject initially).
      → DMARC is a TXT record on _dmarc.{domain}.
```

### DNS Propagation Timeframes

| Record Type | Winnr-managed | External DNS |
|------------|---------------|-------------|
| MX | 1-5 minutes | 15 min - 48 hours |
| SPF (TXT) | 1-5 minutes | 15 min - 48 hours |
| DKIM (CNAME) | 5-15 minutes | 15 min - 48 hours |
| DMARC (TXT) | 1-5 minutes | 15 min - 48 hours |
| Nameservers | N/A | 24-72 hours |

---

## Decision Tree B: Warming Issues

**Tools**: `winnr_get_warming_metrics`, `winnr_list_warming`, `winnr_get_warming_overview`

```
START → Call winnr_list_warming, find problematic mailboxes
  │
  ├─ Warming status = "paused"
  │   → Someone paused it. Resume with winnr_resume_warming.
  │   → If it was auto-paused, health score was critically low.
  │   → Check metrics before resuming — may need to wait 48-72 hours.
  │
  ├─ Warming status = "disabled"
  │   → Re-enable with winnr_enable_warming.
  │   → Warning: re-enabling starts warming from scratch (no history).
  │
  ├─ Health score declining over time
  │   → Call winnr_get_warming_metrics for daily trend data
  │   ├─ Sudden drop → Check if domain DNS changed (Tree A)
  │   ├─ Gradual decline → Domain reputation issue
  │   │   ├─ Domain age <30 days → Normal. New domains take time.
  │   │   ├─ Domain age >30 days → Possible blacklisting.
  │   │   │   → Check MXToolbox / Google Postmaster for the domain.
  │   │   └─ Multiple domains declining → Account-level issue.
  │   │       → Check if all on same mailcow instance.
  │   └─ Stagnant (not improving) → Warming settings may be too aggressive
  │       → Reduce daily_limit to 10-15
  │       → Ensure ramp_up is enabled
  │
  ├─ Daily volume = 0 despite being "active"
  │   → Warming pool may be full. Usually resolves within 24 hours.
  │   → Check if it's a new mailbox (first 24-48 hours may have low volume).
  │
  └─ Warming emails going to spam at high rate (>15%)
      → This is the most serious warming issue.
      ├─ Check DNS first (Tree A) — missing SPF/DKIM = instant spam.
      ├─ Domain very new (<7 days) → Normal. Spam rate decreases over time.
      ├─ Domain aged but high spam → Possible domain reputation issue.
      │   → Consider pausing warming for 72 hours, then resuming.
      └─ All mailboxes on domain affected → Domain-level problem.
          → Pause all warming on the domain.
          → Check DNS, wait 72 hours, re-enable with conservative settings.
```

---

## Decision Tree C: Deliverability Issues

**Tools**: `winnr_get_warming_metrics`, `winnr_list_warming`, `winnr_get_dns_status`

```
START → Identify affected mailboxes from warming data
  │
  ├─ Inbox rate <80% on specific mailboxes
  │   ├─ Is it a new mailbox (<14 days)? → Normal. Still building reputation.
  │   ├─ Was it recently used for campaigns? → Campaign content may be hurting.
  │   │   → Pause campaigns for 48 hours. Let warming recover reputation.
  │   ├─ DNS changed recently? → Run Tree A.
  │   └─ Domain reputation declined? → Check warming metrics trend.
  │       → If declining over 7+ days, domain may be burned.
  │       → Recovery: disable warming, wait 7 days, re-enable with
  │         daily_limit=5, ramp_up=true.
  │
  ├─ Inbox rate <80% across ALL mailboxes
  │   → Account-level or infrastructure issue.
  │   ├─ Check if all domains share the same DNS provider → DNS issue.
  │   ├─ Check if all on same mailcow instance → Server IP issue.
  │   └─ Recent plan change or billing issue? → Check account status.
  │
  ├─ Spam rate >15% on specific domain
  │   → Domain-level reputation problem.
  │   ├─ DNS fully configured? (Tree A)
  │   ├─ Domain age? (<30 days = patience, >30 days = concern)
  │   ├─ Sending volume too high? → Reduce daily_limit.
  │   └─ Consider: this domain may be burned. Create new domains instead.
  │
  └─ Emails bouncing
      → Not directly visible in warming data.
      → Check inbox for bounce notifications: winnr_list_inbox with
        date filter for recent messages.
      → Common causes: recipient doesn't exist, recipient server blocking.
```

### Domain Reputation Recovery Protocol

When a domain's inbox rate drops below 60% or health score below 40:

1. **Immediate**: Pause all warming on the domain (`winnr_pause_warming`)
2. **Wait 72 hours**: Let the domain cool down
3. **Check DNS**: Run full DNS verification (Tree A)
4. **Resume conservatively**: Re-enable with `daily_limit=5`, `ramp_up=true`
5. **Monitor daily**: Check metrics for 7 days
6. **If no improvement after 14 days**: Consider retiring the domain and purchasing a new one

---

## Decision Tree D: Provisioning Issues

**Tools**: `winnr_list_jobs`, `winnr_get_job`

```
START → Get the job ID from the failed operation
  │
  ├─ Job status = "queued"
  │   → Still waiting to be processed. Check again in 30 seconds.
  │
  ├─ Job status = "in_progress"
  │   → Currently running. Check again in 30 seconds.
  │
  ├─ Job status = "error"
  │   → Read the error message from the job.
  │   ├─ "Zone already exists" → Domain was previously set up. Delete first.
  │   ├─ "Mailbox already exists" → Mailbox already created. Skip or rename.
  │   ├─ "Registration failed" → Dynadot registration issue. Check domain availability.
  │   ├─ "Payment failed" → Stripe card issue. Update at app.winnr.app.
  │   └─ Other → Report the error message to user. May need manual fix in dashboard.
  │
  ├─ Job status = "completed" but resource not visible
  │   → Eventual consistency. Wait 30 seconds and re-query.
  │   → If still not visible after 2 minutes, check for errors in job details.
  │
  └─ Domain status = "complete" but DNS failing / warming paused
      → This is the "false complete" scenario. Check these in order:
      ├─ 1. Check `registrar` field:
      │   ├─ "external" → Domain was added as BYOD, not purchased.
      │   │   → Run `whois {domain}` — if unregistered, go to Tree A (NS missing).
      │   └─ "dynadot" → Should be registered. Check WHOIS to confirm.
      ├─ 2. Check Stripe for domain charges:
      │   → Search invoices for "Domain registration:" line items.
      │   → No charges = purchase never attempted (BYOD confusion).
      ├─ 3. Check CloudWatch SQS consumer logs:
      │   → Look for `should_register` flag in the domain create job.
      │   → `should_register: False` = BYOD path (no registration attempted).
      └─ 4. Check `dns_health_status`:
          → "failing" with "No NS records" = domain not registered or NS not pointed.
          → "failing" with specific record errors = DNS misconfiguration (Tree A).
```

---

## Decision Tree E: Sending Issues

**Tools**: `winnr_list_inbox`, `winnr_send_email`

```
START → User reports emails not sending
  │
  ├─ Using winnr_send_email tool?
  │   ├─ Error "user not found" → Wrong user_id. List users first.
  │   ├─ Error "authentication failed" → Token issue. Check API token permissions.
  │   └─ Error "rate limited" → Sending too fast. Wait and retry.
  │
  ├─ Sending via sequencer (Smartlead, Instantly, etc.)?
  │   → Problem is likely SMTP credentials, not Winnr.
  │   → Verify the credentials from the export match the sequencer config.
  │   → Common: wrong SMTP port (use 587), wrong server hostname.
  │
  └─ Emails sent but not arriving?
      → Check recipient's spam folder.
      → Check warming metrics — if health is low, emails may be filtered.
      → Run DNS check (Tree A) to ensure authentication records are correct.
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
