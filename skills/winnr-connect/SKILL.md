---
name: winnr-connect
description: >
  Bring your own domains to Winnr. Walks through connecting existing domains
  registered anywhere (Namecheap, GoDaddy, Cloudflare, Porkbun, Squarespace,
  Google Domains, etc.) — either by pointing nameservers to Winnr (default,
  Winnr manages MX/SPF/DKIM/DMARC) or by adding DNS records manually at the
  user's current DNS host. Then creates mailboxes and enables warming. Use
  when the user says "connect domain", "BYOD", "I already own", "external
  domain", "point nameservers", "add my domain", or has domains from another
  registrar they want to use with Winnr.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Winnr Connect — Bring Your Own Domain

> `/winnr setup` is for **buying** new domains through Winnr.
> `/winnr connect` is for **using domains you already own**.

If the user wants to purchase new domains, hand off to `/winnr setup`.

---

## Workflow

```
Phase 1: Discovery      → what domains? are they in use? which registrar?
Phase 2: Safety gate    → warn about impact on existing email/websites
Phase 3: Choose mode    → nameserver mode (default) vs manual-DNS mode
Phase 4: DNS setup      → nameserver-change instructions OR record list
Phase 5: Verify         → poll until DNS is live
Phase 6: Mailboxes      → create per domain (3-5 per domain)
Phase 7: Warming        → enable, staggered if large batch
Phase 8: Report         → WINNR-CONNECT-REPORT.md
```

---

## Phase 1: Discovery

Ask the user:

1. **Which domains** do you want to connect? (list)
2. **Where are they registered?** (Namecheap / GoDaddy / Cloudflare /
   Porkbun / Squarespace / Google Domains / other) — determines the exact
   NS-change steps you'll give them later
3. **Are any of them currently sending or receiving email?** (critical —
   see safety gate)
4. **Do any host a website?** (also relevant — see safety gate)

Take one pass through `winnr_get_usage` to make sure they have capacity for
the domain count. If not, tell them how many they can connect on their
current plan.

---

## Phase 2: Safety Gate

**This is the most important step of the skill.** Getting it wrong breaks
the customer's existing email.

### If a domain currently sends or receives email

Pointing nameservers at Winnr will change the MX records, which **stops
mail flowing to the current mailboxes**. Present these options:

- **Recommended**: buy a fresh domain instead (`/winnr setup`). Cold
  outreach shouldn't come from your primary business domain anyway — a
  spam complaint on a cold sequence can hurt your main inbox reputation.
- **Manual-DNS mode**: keep the current nameservers, add Winnr's DNS
  records alongside your existing ones. Works if your DNS host supports
  multiple MX records with priority (most do) — but be careful, mixing
  mail servers for one domain rarely goes well.
- **Proceed with nameserver mode**: only if the user confirms they're
  fine losing the existing mail flow.

### If a domain hosts a website

Nameserver-mode: the website's A / CNAME records need to be recreated
inside Winnr. If the user isn't comfortable managing this, recommend
manual-DNS mode instead so their existing web DNS keeps working.

### DNSSEC

If DNSSEC is enabled on the domain, **it must be disabled at the current
registrar before changing nameservers**, otherwise resolvers will refuse
the new NS pair and mail will fail silently. Tell the user to check for
"DNSSEC" or "DS records" in their registrar's DNS settings and turn it
off before proceeding.

Do not proceed to Phase 3 until every domain in the batch has cleared
this gate.

---

## Phase 3: Choose Mode

**Nameserver mode (default)** — Winnr manages all DNS. Simplest, best
deliverability, but the user gives up DNS control for that domain.

**Manual-DNS mode** — the user's current DNS host keeps managing DNS;
they add Winnr's MX / SPF / DKIM / DMARC records themselves. More work,
but leaves web hosting and other records untouched.

If the user has no reason to keep DNS control (fresh domain, no website,
no other email), pick nameserver mode. Otherwise ask.

---

## Phase 4A: Nameserver Mode

**Tools**: `winnr_connect_domains`, `winnr_check_nameservers`

1. Call `winnr_connect_domains` with the domain list. The response
   includes the **nameserver pair** the user needs to set at their
   current registrar.
2. Present per-registrar instructions (see registrar cheatsheets below).
3. **Wait for the user to make the change**, then poll
   `winnr_check_nameservers` every 60-120 seconds up to ~30 minutes. If
   still not resolving after 30 minutes, tell them propagation can take
   up to 48 hours — check back later with `/winnr troubleshoot {domain}`.
4. Once `winnr_check_nameservers` returns success, call
   `winnr_setup_domain` to trigger MX / SPF / DKIM / DMARC configuration.
5. Poll `winnr_verify_dns` until all records verify (usually 1-5 minutes
   after `setup_domain` completes).

### Registrar cheatsheets (nameserver change)

**Namecheap**
1. Log in → Domain List → Manage (next to the domain)
2. Nameservers section → change from "Namecheap BasicDNS" to "Custom DNS"
3. Enter the two nameservers Winnr returned; save
4. Propagation: usually 15 min – 2 h, up to 48 h

**GoDaddy**
1. Log in → My Products → DNS (next to the domain)
2. Nameservers section → Change → "I'll use my own nameservers"
3. Enter the two nameservers Winnr returned; save
4. Confirm on the popup that you understand DNS changes
5. Propagation: usually 15 min – 4 h

**Cloudflare** (as registrar, not just DNS)
1. Log in → select the domain
2. Nameservers section — Cloudflare-registered domains **cannot use
   external nameservers on some plans**. If the option is greyed out, the
   user must either upgrade or use manual-DNS mode.
3. If available: change to custom nameservers, enter Winnr's pair, save

**Porkbun**
1. Log in → Domain Management → Details (next to the domain)
2. Authoritative Nameservers → edit
3. Replace with Winnr's pair; save
4. Propagation: usually 15 min – 2 h

**Squarespace Domains** (formerly Google Domains)
1. Log in → Domains → select the domain → DNS
2. Nameservers → "Use custom nameservers"
3. Enter Winnr's pair; save
4. Propagation: usually 30 min – 4 h

**Other / generic**
1. Find the "Nameservers" or "DNS" section for the domain at the current
   registrar
2. Switch from "default" / "registrar's nameservers" to "custom" or
   "external"
3. Enter both nameservers Winnr returned, in order
4. Save. Propagation: 15 min – 48 h

---

## Phase 4B: Manual-DNS Mode

**Tools**: `winnr_get_dns_records`, `winnr_verify_dns`

1. Call `winnr_get_dns_records` for each domain. The response lists the
   MX / SPF (TXT) / DKIM (CNAME) / DMARC (TXT) records the user needs to
   add at their current DNS host.
2. Present the record list clearly:
   ```
   Add these 4 records at {registrar/DNS host}:

   1. MX record
      Host: @
      Value: {mx.target from response}
      Priority: 10

   2. TXT record (SPF)
      Host: @
      Value: {spf value}

   3. CNAME record (DKIM)
      Host: {selector}._domainkey
      Value: {dkim target}

   4. TXT record (DMARC)
      Host: _dmarc
      Value: {dmarc value}
   ```
3. **SPF merge warning**: if the domain already has an SPF record (starts
   with `v=spf1`), the user MUST merge, not add a second one. Two SPF
   records break SPF authentication. If unsure, ask them to paste their
   existing SPF and combine it manually before saving.
4. Wait for the user to confirm the records are added. Poll
   `winnr_verify_dns` every 60 seconds up to ~15 minutes. External DNS
   propagation is usually fast (5-15 min) but can take up to 48 h at
   slow providers.

---

## Phase 5: Verify

For every domain in the batch, `winnr_verify_dns` must return success
before mailboxes can be created. If a domain fails verification after
the polling window, offer to:

- Keep polling in the background
- Move on and finish the successful domains now, revisit failures with
  `/winnr troubleshoot {domain}`
- Abort the connect for that domain

---

## Phase 6: Mailboxes

**Tools**: `winnr_bulk_create_email_users`, `winnr_list_email_users`

Same conventions as `/winnr setup`:

- **3-5 mailboxes per domain** (optimal for cold outreach reputation)
- Realistic first.last usernames (john.smith, sarah.jones) — vary
  patterns across the batch: first.last, firstlast, first_last, flast
- Ask the user for a name pool or generate suggestions
- Bulk-create per domain, then poll `winnr_get_job` for completion

---

## Phase 7: Warming

**Tools**: `winnr_enable_warming`

- Enable warming on every new mailbox. Default settings are safe.
- For batches **>20 mailboxes**, stagger over 2-3 days (10 per day) so
  warming pool ramp-up doesn't spike suspicion.
- Warming takes 14-21 days minimum before the mailboxes are campaign-ready.

---

## Phase 8: Report

Write `WINNR-CONNECT-REPORT.md`:

```markdown
# Winnr Connect Report

**Date**: {date}
**Mode**: nameserver | manual-DNS
**Domains connected**: {n}

## Domains
| Domain | Registrar | Verified | Mailboxes | Warming |
|---|---|---|---|---|
| acme.io | Namecheap | Yes | 4 | Active (0/14 days) |

## Credentials
See `/winnr export default` when warming is complete (14+ days).

## What's next
- **Day 1-14**: Warming builds reputation. Do not send campaigns yet.
- **Day 15+**: Run `/winnr health` to confirm the mailboxes are
  campaign-ready, then `/winnr export {sequencer}` to import into your
  outreach tool.
- If any domain shows warming health issues over the next week, run
  `/winnr troubleshoot {domain}`.
```

---

## Guardrails

1. **Never change nameservers on a domain that's actively sending or
   receiving mail** without a very explicit confirmation. This is the
   fastest way to break a customer's email.
2. **Always warn about DNSSEC** before an NS change.
3. **Merge SPF, don't duplicate.** Two SPF records = broken SPF.
4. **One-shot verification** — don't skip the `winnr_verify_dns` step
   just because the user is impatient. Creating mailboxes on an unverified
   domain wastes warming time and generates support tickets.
5. **Hand off correctly**: buying new domains → `/winnr setup`. Diagnosing
   a connected domain that isn't verifying → `/winnr troubleshoot`.
