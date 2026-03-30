---
name: winnr-setup
description: >
  Full infrastructure setup wizard for Winnr cold email. Guides through domain
  selection, purchase, DNS verification, mailbox creation, and warming activation.
  Encodes cold email best practices at every step. Use when user wants to set up
  new email infrastructure, provision domains, or create mailboxes from scratch.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Winnr Setup Wizard

> Automates the full infrastructure setup: domains → DNS → mailboxes → warming.
> Every step follows cold email best practices so new users get it right the first time.

---

## Workflow Overview

```
Phase 1: Discovery      → Check account, plan limits, current usage
Phase 2: Domain Strategy → Suggest, search, and select domains
Phase 3: Domain Purchase → Purchase and queue DNS setup (charges Stripe)
Phase 4: DNS Verification → Poll until DNS records propagate
Phase 5: Mailbox Creation → Create mailboxes with professional naming
Phase 6: Warming Activation → Enable warming on all new mailboxes
Phase 7: Summary Report  → Generate setup report with all credentials
```

---

## Phase 1: Discovery

**Tools**: `winnr_get_account`, `winnr_get_usage`

1. Call `winnr_get_account` to get plan type, limits, and subscription status
2. Call `winnr_get_usage` to get current domain/user counts
3. Calculate remaining capacity:
   - `remaining_domains = plan_domain_limit - domains_used`
   - `remaining_users = plan_user_limit - users_used`
4. If capacity is zero, inform user and suggest upgrading plan or deleting unused resources
5. Present current state to user before proceeding

**Output to user:**
```
Your account: {plan} plan
Domains: {used}/{limit} ({remaining} available)
Mailboxes: {used}/{limit} ({remaining} available)

Ready to set up new infrastructure. How many domains would you like?
```

**Ask the user** how many domains they want. If they don't specify, recommend based on their remaining capacity and the 3-5 mailboxes/domain ratio.

---

## Phase 2: Domain Strategy

**Tools**: `winnr_suggest_domains`, `winnr_search_domains_bulk`

### Step 1: Generate domain ideas

Ask the user for their brand keyword, industry, or target audience. Then:

1. Call `winnr_suggest_domains` with their keyword to get AI-generated suggestions
2. Apply cold email domain naming best practices:
   - **DO**: Use keyword variations, industry terms, action words
   - **DO**: Mix TLDs (.io, .co, .xyz, .email, .app, .dev)
   - **DON'T**: Use the user's primary brand domain for cold email
   - **DON'T**: Use spam-associated TLDs (.info, .biz, .click, .top)
   - **DON'T**: Use domains that look too similar to the main brand
3. If suggestions are insufficient, generate additional candidates:
   - Pattern: `{keyword}{suffix}.{tld}` where suffix is: hq, team, mail, labs, works, sends, reach, go, try, get
   - Example keyword "acme": acmehq.io, acmeteam.co, acmelabs.xyz, acmeworks.email

### Step 2: Check availability

1. Compile the top 15-30 candidates
2. Call `winnr_search_domains_bulk` with the list
3. Filter to available domains
4. Sort by price (cheapest first — Winnr plan domain credits cover cheapest first)
5. Present top options to user with pricing

**Output to user:**
```
Found {N} available domains. Here are the best options:

| Domain | Price | TLD |
|--------|-------|-----|
| acmehq.io | $3.99 | .io |
| acmelabs.xyz | $1.99 | .xyz |
| ...

Which domains would you like to purchase? (list numbers or "all")
```

**Wait for user confirmation** before purchasing. Domain purchase charges their Stripe card.

---

## Phase 3: Domain Purchase

**Tools**: `winnr_purchase_domains`, `winnr_list_jobs`, `winnr_get_job`

1. Build the purchase payload. For each selected domain:
   ```json
   {
     "domain": "acmehq.io",
     "price": 3.99,
     "register": true,
     "setup_dns": true,
     "setup_email": true
   }
   ```
   Note: Do NOT include `users` in the purchase call — create them separately in Phase 5 for better error handling and job tracking.

2. **Confirm with user** before calling `winnr_purchase_domains`:
   ```
   About to purchase {N} domains for approximately ${total}:
   - acmehq.io ($3.99)
   - acmelabs.xyz ($1.99)
   Plan domain credits will be applied first.

   Proceed? (yes/no)
   ```

3. Call `winnr_purchase_domains` with the confirmed list
4. Store returned job IDs for tracking

---

## Phase 4: DNS Verification

**Tools**: `winnr_get_dns_status`, `winnr_list_jobs`, `winnr_get_job`

DNS propagation depends on the setup method:
- **Winnr-managed DNS** (purchased through Winnr): Usually ready in 1-5 minutes
- **External DNS** (connected domains): 15 minutes to 48 hours

### Verification loop

1. Wait 30 seconds after purchase for initial provisioning
2. For each domain, call `winnr_get_dns_status` to check record status
3. Check for these records:
   - **MX**: Mail exchange record pointing to Winnr's mail servers
   - **SPF**: `v=spf1 include:_spf.winnr.app ~all`
   - **DKIM**: Domain key for email signing
   - **DMARC**: `v=DMARC1; p=none;` (minimum)
4. If any records are missing, report which ones and suggest waiting
5. Also check job status via `winnr_get_job` for each domain's setup job

**Output to user:**
```
DNS Status:
| Domain | MX | SPF | DKIM | DMARC | Status |
|--------|----|----|------|-------|--------|
| acmehq.io | OK | OK | OK | OK | Ready |
| acmelabs.xyz | OK | OK | Pending | OK | Waiting |

acmelabs.xyz DKIM is still propagating. This typically takes 5-15 minutes.
Proceeding with ready domains...
```

If all domains are ready, move to Phase 5. If some are still propagating, proceed with ready domains and note which ones to check later.

---

## Phase 5: Mailbox Creation

**Tools**: `winnr_bulk_create_email_users`, `winnr_list_jobs`, `winnr_get_job`

### Step 1: Generate mailbox names

For each domain, create 3-5 mailboxes with professional names:

**Naming strategy:**
- Generate realistic first + last name combinations
- Use varied username patterns to avoid looking automated:
  - `john.smith` (first.last — most common)
  - `jsmith` (initial + last)
  - `john_smith` (first_last — variation)
  - `johns` (first + initial)
- Match display name to username: "John Smith" for john.smith
- Avoid: info@, sales@, team@, hello@, contact@ (not suitable for cold outreach)

**Good name pool** (use diverse, common names):
```
First names: James, Sarah, Michael, Emily, David, Jessica, Robert, Ashley,
             Daniel, Jennifer, Chris, Amanda, Matt, Rachel, Andrew, Lauren,
             Tom, Nicole, Ryan, Megan, Jason, Katie, Brian, Stephanie
Last names:  Johnson, Williams, Brown, Davis, Miller, Wilson, Moore, Taylor,
             Anderson, Thomas, White, Harris, Martin, Garcia, Clark, Lewis
```

### Step 2: Present plan to user

```
Mailbox plan:

acmehq.io (3 mailboxes):
  - james.wilson@acmehq.io (James Wilson)
  - sarah.taylor@acmehq.io (Sarah Taylor)
  - michael.clark@acmehq.io (Michael Clark)

acmelabs.xyz (3 mailboxes):
  - emily.davis@acmelabs.xyz (Emily Davis)
  - david.moore@acmelabs.xyz (David Moore)
  - jessica.harris@acmelabs.xyz (Jessica Harris)

Total: 6 new mailboxes. Proceed? (yes/no)
```

**Wait for user confirmation.** They may want to customize names.

### Step 3: Create mailboxes

1. Build the bulk creation payload for each domain batch
2. Call `winnr_bulk_create_email_users` with up to 100 users per call
3. Track job IDs from the response
4. Poll `winnr_get_job` for each job until all complete
5. Report successes and failures

---

## Phase 6: Warming Activation

**Tools**: `winnr_enable_warming`, `winnr_update_warming_settings`

### Step 1: Enable warming on all new mailboxes

1. Collect user IDs from the successfully created mailboxes
2. Call `winnr_enable_warming` with all user IDs
3. Warming costs $0.60/mailbox/month — inform user of the total monthly cost

### Step 2: Configure warming settings (optional, recommend defaults)

Recommended defaults for new mailboxes:
- `ramp_up`: true (gradually increase volume)
- `daily_limit`: 15 (conservative start)
- `reply_rate`: 30 (30% target reply rate)

Only adjust if user requests specific settings. The defaults are designed for maximum deliverability during the warming period.

**Output to user:**
```
Warming enabled on {N} mailboxes.
Monthly warming cost: ${N * 0.60}/month

Settings: Gradual ramp-up, 15 emails/day max, 30% reply rate target.
Mailboxes will be ready for outreach campaigns in 14-21 days.
```

---

## Phase 7: Summary Report

Generate `WINNR-SETUP-REPORT.md` with:

```markdown
# Winnr Infrastructure Setup Report

**Date**: {date}
**Account**: {account_name} ({plan} plan)

## Domains Provisioned

| Domain | DNS Status | Mailboxes |
|--------|-----------|-----------|
| acmehq.io | All records verified | 3 |
| acmelabs.xyz | All records verified | 3 |

## Mailboxes Created

| Email | Name | Domain | Warming |
|-------|------|--------|---------|
| james.wilson@acmehq.io | James Wilson | acmehq.io | Active (ramp-up) |
| sarah.taylor@acmehq.io | Sarah Taylor | acmehq.io | Active (ramp-up) |
| ... | ... | ... | ... |

## Cost Summary

| Item | Cost |
|------|------|
| Domains | ${total} one-time |
| Warming | ${monthly}/month |
| Plan | ${plan_price}/month |

## Next Steps

1. **Wait 14-21 days** for warming to build sender reputation
2. **Monitor health** daily with `/winnr health`
3. **Export credentials** when ready with `/winnr export <tool>`
   - Smartlead: `/winnr export smartlead`
   - Instantly: `/winnr export instantly`
4. **Check deliverability** if issues arise with `/winnr troubleshoot`

## Important Reminders

- Do NOT send cold email campaigns until warming completes (14-21 days)
- Start with 20-30 emails/mailbox/day and scale gradually
- Monitor inbox rates — anything below 80% needs attention
- Keep 3-5 mailboxes per domain for optimal reputation distribution
```

Write this report to `WINNR-SETUP-REPORT.md` in the current working directory.

---

## Edge Cases

### User wants to connect existing domains (not purchase)
Skip Phase 3's purchase step. Instead:
1. Call `winnr_connect_domains` with the domain list
2. Return the nameserver values the user needs to set at their registrar
3. Use `winnr_check_nameservers` to verify after user updates DNS
4. Continue to Phase 5 once nameservers are verified

### User is at plan capacity
Inform them immediately in Phase 1. Options:
- Upgrade plan at app.winnr.app → Settings → Billing
- Delete unused domains/mailboxes first
- Use `/winnr scale` to optimize existing infrastructure

### Domain purchase fails (payment issue)
Direct user to app.winnr.app → Settings → Billing to update payment method. Do not retry automatically — payment issues require human intervention.

### Some mailboxes fail to create
Report which ones failed and why (common: mailbox already exists, domain not ready). Offer to retry the failed ones or skip them.
