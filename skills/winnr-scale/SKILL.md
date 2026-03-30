---
name: winnr-scale
description: >
  Scale Winnr email infrastructure up or down. Handles domain purchasing,
  mailbox provisioning, and warming with proper ratios and plan awareness.
  Use when user says "scale", "add more", "grow", "expand", "reduce",
  "remove", "downsize", or wants to change the size of their infrastructure.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Winnr Scale

> Scale your cold email infrastructure with best-practice ratios.
> Plan-aware: checks capacity before adding, suggests cleanups before removing.

---

## Scale Up Workflow

### Usage: `/winnr scale <N>` or `/winnr scale up <N> mailboxes`

The user specifies a target number of new mailboxes. The skill calculates how many domains are needed.

### Step 1: Assess Capacity

**Tools**: `winnr_get_account`, `winnr_get_usage`

1. Get current plan limits and usage
2. Calculate the ask:
   - New mailboxes requested: N
   - New domains needed: ceil(N / 4) (using 4 mailboxes/domain as default ratio)
3. Check if the plan can accommodate:
   - `remaining_domains >= new_domains_needed`
   - `remaining_users >= N`
4. If insufficient capacity:
   ```
   Your {plan} plan has room for {remaining_users} more mailboxes and
   {remaining_domains} more domains.

   To add {N} mailboxes, you'd need {new_domains_needed} new domains.
   {specific shortfall explanation}

   Options:
   1. Scale to fit current plan ({max_possible} mailboxes instead)
   2. Upgrade to Enterprise ($189/mo) for up to 200 mailboxes and 40 domains
   3. Delete unused resources first — run `/winnr health` to identify candidates
   ```

### Step 2: Generate Domain and Mailbox Plan

Follow the same domain strategy as `winnr-setup`:

1. Ask user for keyword/theme if not provided
2. `winnr_suggest_domains` → generate candidates
3. `winnr_search_domains_bulk` → check availability
4. Select cheapest available domains
5. Generate 3-5 mailboxes per domain with professional names
6. Present the full plan for user approval

### Step 3: Execute

1. `winnr_purchase_domains` (with user confirmation — charges Stripe)
2. Wait for DNS propagation
3. `winnr_bulk_create_email_users`
4. `winnr_enable_warming` on all new mailboxes
5. Generate `WINNR-SCALE-REPORT.md`

### Staggered Warming (for large scale-ups)

When adding more than 20 mailboxes at once, stagger the warming:
- **Day 1**: Enable warming on first batch (up to 20 mailboxes)
- **Day 2-3**: Enable warming on second batch
- **Continue until all are warming**

This prevents a large burst of new warming activity from triggering provider suspicion.

For the skill, enable all warming at once but set conservative settings:
- `daily_limit`: 10 (lower than the setup wizard's 15)
- `ramp_up`: true
- `reply_rate`: 30

---

## Scale Down Workflow

### Usage: `/winnr scale down` or `/winnr scale down <N> mailboxes`

### Step 1: Identify Candidates for Removal

**Tools**: `winnr_list_domains`, `winnr_list_email_users`, `winnr_list_warming`

Score each mailbox for removal priority:

| Factor | Points | Reason |
|--------|--------|--------|
| Health score <40 | +30 | Burned — not recovering |
| Inbox rate <60% | +25 | Severely underperforming |
| Warming paused >7 days | +20 | Abandoned |
| No warming enabled | +15 | Not building reputation |
| Domain has only 1 mailbox | +10 | Inefficient domain use |
| Oldest domain with poor metrics | +5 | Sunk cost |

Present candidates sorted by removal priority:

```
Recommended for removal (highest priority first):

| # | Mailbox | Health | Inbox | Domain | Priority |
|---|---------|--------|-------|--------|----------|
| 1 | bad@burned.xyz | 32 | 48% | burned.xyz | 70 pts |
| 2 | low@poor.io | 45 | 65% | poor.io | 55 pts |
| 3 | stale@old.co | -- | -- | old.co | 35 pts |

Remove these {N} mailboxes? This will also delete their domains if
all mailboxes on a domain are removed.
```

### Step 2: Execute Removal

**Confirm with user before any deletions.**

Order of operations (important):
1. `winnr_disable_warming` on affected mailboxes (stop billing immediately)
2. `winnr_delete_email_user` for each mailbox
3. If a domain has zero remaining mailboxes, `winnr_delete_domain`
4. Track job completion for each deletion

### Step 3: Generate Report

```markdown
# Winnr Scale Report

**Date**: {date}
**Action**: Scale down

## Removed

| Resource | Type | Reason |
|----------|------|--------|
| bad@burned.xyz | Mailbox | Health 32, inbox 48% |
| burned.xyz | Domain | All mailboxes removed |

## Current State

| Resource | Before | After | Change |
|----------|--------|-------|--------|
| Domains | 8 | 7 | -1 |
| Mailboxes | 32 | 30 | -2 |
| Warming | 30 active | 28 active | -2 |
| Monthly warming | $18.00 | $16.80 | -$1.20 |

## Capacity Freed
- {N} domain slots available
- {N} mailbox slots available
```

---

## Rebalancing

If the user asks to "rebalance" or "optimize" without adding/removing:

1. Run a health check (like `winnr-health`)
2. Identify domains with too many (>5) or too few (1) mailboxes
3. Suggest moving mailboxes: create new ones on underloaded domains, delete from overloaded ones
4. Identify any domains with zero mailboxes (unused) for cleanup
5. Check for mailboxes that have been warming for >21 days but aren't being used for campaigns — these are ready for export

Output a rebalancing plan, confirm with user, then execute.
