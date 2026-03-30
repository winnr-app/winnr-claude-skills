---
name: winnr-health
description: >
  Health check and monitoring for Winnr email infrastructure. Generates a
  traffic-light health report across all domains, mailboxes, and warming
  campaigns. Scores infrastructure health 0-100. Use when user says "health",
  "check", "monitor", "status", "how are my mailboxes doing", or wants a
  deliverability overview.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Winnr Health Check

> Comprehensive health assessment of your cold email infrastructure.
> Traffic-light scoring so you know exactly what needs attention.

---

## Workflow

```
Step 1: Gather data       → Pull account, domains, warming, DNS status
Step 2: Score each layer  → DNS health, warming health, utilization, diversity
Step 3: Flag problems     → Red/yellow/green per metric
Step 4: Generate report   → WINNR-HEALTH-REPORT.md with recommendations
```

---

## Step 1: Gather Data

Call these tools in parallel where possible:

1. `winnr_get_account` → plan type, limits
2. `winnr_get_usage` → domains/users used vs limit
3. `winnr_list_domains` → all domains with status (paginate if >25)
4. `winnr_get_warming_overview` → aggregate warming stats
5. `winnr_list_warming` → per-mailbox warming status, health score, inbox rate

For each domain with potential issues, also call:
6. `winnr_get_dns_status` → per-domain DNS record status

---

## Step 2: Scoring Methodology

### Overall Health Score (0-100)

| Category | Weight | What It Measures |
|----------|--------|-----------------|
| DNS Health | 30% | All domains have valid MX, SPF, DKIM, DMARC |
| Warming Performance | 40% | Average inbox rate, health scores, active warming |
| Account Utilization | 15% | Using a healthy % of plan capacity (not maxed, not empty) |
| Mailbox Diversity | 15% | Proper mailbox-to-domain ratio (3-5 per domain) |

### DNS Health (0-100)

For each domain, check all 4 DNS records:
- All 4 records valid = 100 points
- 3 of 4 valid = 75 points
- 2 of 4 valid = 50 points
- 1 of 4 valid = 25 points
- None valid = 0 points

**DNS Score** = average across all domains

### Warming Performance (0-100)

Based on aggregate warming metrics:
- Average inbox rate: target >90%
- Average health score: target >80
- Percentage of mailboxes actively warming: target 100%
- No mailboxes in critical state (health <60)

**Scoring:**
- Avg inbox rate >90% = 40 points, 80-90% = 25, <80% = 10
- Avg health score >80 = 30 points, 60-80 = 20, <60 = 5
- All mailboxes warming = 20 points, >80% = 15, >50% = 10, <50% = 0
- No critical mailboxes = 10 points, any critical = 0

### Account Utilization (0-100)

- Using 30-80% of domain limit = 100 (healthy scaling room)
- Using 80-95% = 75 (getting close to limit)
- Using >95% = 50 (at capacity)
- Using <10% = 50 (underutilized)
- Using 10-30% = 75 (early stage, fine)

Same calculation for user limit. Average both.

### Mailbox Diversity (0-100)

Check the mailbox-to-domain ratio:
- 3-5 mailboxes/domain = 100 (optimal)
- 2 mailboxes/domain = 75 (could add more)
- 1 mailbox/domain = 50 (single point of failure)
- 6-8 mailboxes/domain = 75 (slightly concentrated)
- >8 mailboxes/domain = 50 (too many on one domain)
- 0 mailboxes on any domain = flag as unused

Score = average across all domains.

---

## Step 3: Traffic-Light Classification

### Per-metric thresholds

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Overall score | >80 | 60-80 | <60 |
| Inbox rate | >90% | 80-90% | <80% |
| Health score | >80 | 60-80 | <60 |
| DNS records | All 4 pass | 3 of 4 | <3 of 4 |
| Mailboxes/domain | 3-5 | 2 or 6-8 | 1 or >8 |
| Plan utilization | 30-80% | 10-30% or 80-95% | <10% or >95% |

### Flag individual problems

For each mailbox with warming data:
- **RED**: inbox rate <80% OR health score <60 OR warming disabled/paused
- **YELLOW**: inbox rate 80-90% OR health score 60-80
- **GREEN**: inbox rate >90% AND health score >80 AND warming active

For each domain:
- **RED**: missing MX or SPF record
- **YELLOW**: missing DKIM or DMARC
- **GREEN**: all 4 records verified

---

## Step 4: Generate Report

Write `WINNR-HEALTH-REPORT.md`:

```markdown
# Winnr Infrastructure Health Report

**Date**: {date}
**Account**: {name} ({plan} plan)
**Overall Health Score**: {score}/100 {emoji}

---

## Score Breakdown

| Category | Score | Status | Weight |
|----------|-------|--------|--------|
| DNS Health | {dns}/100 | {status} | 30% |
| Warming Performance | {warming}/100 | {status} | 40% |
| Account Utilization | {util}/100 | {status} | 15% |
| Mailbox Diversity | {div}/100 | {status} | 15% |

---

## Domain Status

| Domain | MX | SPF | DKIM | DMARC | Mailboxes | Status |
|--------|----|----|------|-------|-----------|--------|
| acmehq.io | OK | OK | OK | OK | 3 | GREEN |
| acmelabs.xyz | OK | OK | -- | OK | 3 | YELLOW |

---

## Warming Status

| Mailbox | Status | Health | Inbox Rate | Spam Rate | Daily Vol | Status |
|---------|--------|--------|------------|-----------|-----------|--------|
| james@acmehq.io | Active | 92 | 96% | 2% | 18/day | GREEN |
| sarah@acmehq.io | Active | 78 | 87% | 8% | 15/day | YELLOW |
| emily@acmelabs.xyz | Paused | 45 | 62% | 22% | 0/day | RED |

---

## Issues Found

### Critical (fix immediately)
- emily@acmelabs.xyz: Health score 45, inbox rate 62%. **Action**: Pause sending, check domain reputation, consider disabling and re-warming.

### Warning (monitor closely)
- sarah@acmehq.io: Inbox rate 87%, trending down. **Action**: Monitor for 48 hours. If it drops below 80%, pause sending.
- acmelabs.xyz: DKIM record missing. **Action**: Run `/winnr troubleshoot acmelabs.xyz` for DNS diagnosis.

### Healthy
- 4 of 6 mailboxes are in good health (GREEN status)
- 2 of 2 domains have core DNS records (MX + SPF)

---

## Recommendations

1. {Prioritized recommendation based on the most critical issue}
2. {Second priority}
3. {Third priority}

---

## Capacity

| Resource | Used | Limit | Available | Status |
|----------|------|-------|-----------|--------|
| Domains | {n} | {limit} | {avail} | {status} |
| Mailboxes | {n} | {limit} | {avail} | {status} |
| Warming cost | ${n * 0.60}/mo | — | — | — |
```

Use these status indicators:
- GREEN = `[OK]` or checkmark
- YELLOW = `[!!]` or warning
- RED = `[XX]` or alert

---

## Quick Mode

If the user says `/winnr health quick` or just wants a snapshot, skip the full report and output inline:

```
Health: {score}/100 {status}
DNS: {n}/{total} domains fully verified
Warming: {active}/{total} active, avg inbox {rate}%, avg health {score}
Issues: {count} critical, {count} warnings
```
