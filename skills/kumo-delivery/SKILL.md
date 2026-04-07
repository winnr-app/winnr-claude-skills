---
name: kumo-delivery
description: >
  KumoMTA delivery report. SSHes into kumo instances, parses today's logs,
  and reports delivery rates by provider, source IP, temp fail reasons,
  bounce reasons, and Gmail unusual-rate flags. Use when user says
  "kumo delivery", "how is kumo doing", "delivery on kumo", "kumo stats",
  "kumo report", or asks about KumoMTA sending performance.
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
---

# KumoMTA Delivery Report

> SSH into KumoMTA instances and analyze today's delivery logs.

## Instances

| Instance | SSH Host | Provider | Sudo | Egress IPs |
|----------|----------|----------|------|------------|
| kumo1 | `kumo1` | AWS | yes | 10 Elastic IPs |
| kumo2 | `kumo2` | OVH | no | Dedicated |
| kumo4 | `kumo4` | Contabo | no | 212.47.77.201-225 |
| kumo5 | `kumo5` | Contabo | yes | SUSPENDED |
| kumo6 | `kumo6` | Hetzner | yes | 148.251.28.64/27 + 178.63.7.0/26 |
| kumo7 | `kumo7` | Hivelocity | yes | 37.72.175.177-190 |
| kumo8 | `kumo8` | OVH | yes | 15.204.2.225-253 |

kumo3 is decommissioned. kumo5 is suspended by Contabo.

## How to run

When the user asks about kumo delivery, run the analysis script below via SSH on the requested instance(s). If no specific instance is mentioned, check all active instances (kumo1, kumo2, kumo4, kumo6, kumo7, kumo8).

### Log location and format

Logs are zstd-compressed JSONL at `/var/log/kumomta/YYYYMMDD-*`. On instances with `sudo: yes`, prefix commands with `sudo`.

### Analysis script

For each instance, run:

```bash
ssh <host> "for f in /var/log/kumomta/$(date +%Y%m%d)-*; do <sudo> zstdcat \$f 2>/dev/null || <sudo> cat \$f; done" | python3 -c "
import sys, json
from collections import Counter

types = Counter()
by_provider = {}
by_source = {}
gmail_unusual = Counter()
ms_reasons = Counter()
bounce_reasons = Counter()

for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try: rec = json.loads(line)
    except: continue
    
    rtype = rec.get('type', '')
    types[rtype] += 1
    site = rec.get('site', '').lower()
    src = rec.get('egress_source', '') or '?'
    src_addr = rec.get('source_address', {})
    ip = src_addr.get('address', '').split(':')[0] if src_addr and isinstance(src_addr, dict) else ''
    
    if 'google' in site or 'aspmx' in site: prov = 'Google'
    elif 'outlook' in site or 'protection.outlook' in site: prov = 'Microsoft'
    elif 'yahoo' in site: prov = 'Yahoo'
    elif '_dc-mx' in site: prov = 'Custom MX'
    elif not site: prov = 'Local'
    else: prov = 'Other'
    
    if prov not in by_provider:
        by_provider[prov] = {'d': 0, 't': 0, 'b': 0}
    
    if rtype == 'Delivery':
        by_provider[prov]['d'] += 1
        if src not in by_source: by_source[src] = {'d': 0, 't': 0, 'b': 0, 'ip': ip}
        by_source[src]['d'] += 1
    elif rtype == 'TransientFailure':
        by_provider[prov]['t'] += 1
        if src not in by_source: by_source[src] = {'d': 0, 't': 0, 'b': 0, 'ip': ip}
        by_source[src]['t'] += 1
        content = rec.get('response', {}).get('content', '')
        if 'unusual rate' in content.lower():
            gmail_unusual[ip or src] += 1
        if prov == 'Microsoft':
            code = rec.get('response', {}).get('code', 0)
            ms_reasons[f'[{code}] {content[:90]}'] += 1
    elif rtype == 'Bounce':
        by_provider[prov]['b'] += 1
        if src not in by_source: by_source[src] = {'d': 0, 't': 0, 'b': 0, 'ip': ip}
        by_source[src]['b'] += 1
        content = rec.get('response', {}).get('content', '')
        code = rec.get('response', {}).get('code', 0)
        bounce_reasons[f'[{code}] {content[:90]}'] += 1

total_d = sum(v['d'] for k,v in by_provider.items() if k != 'Local')
total_t = sum(v['t'] for k,v in by_provider.items() if k != 'Local')
total_b = sum(v['b'] for k,v in by_provider.items() if k != 'Local')
total_final = total_d + total_b
rate = (total_d / total_final * 100) if total_final > 0 else 0

print(f'Delivered: {total_d:,}  |  Temp fails: {total_t:,}  |  Bounces: {total_b:,}  |  Rate: {rate:.1f}%')
print()
print(f'{\"Provider\":<15} {\"Delivered\":>10} {\"TempFail\":>10} {\"Bounce\":>8} {\"Rate\":>8}')
for p in sorted(by_provider, key=lambda p: by_provider[p]['d']+by_provider[p]['b'], reverse=True):
    if p == 'Local': continue
    v = by_provider[p]; t = v['d']+v['b']; r = (v['d']/t*100) if t > 0 else 0
    print(f'{p:<15} {v[\"d\"]:>10,} {v[\"t\"]:>10,} {v[\"b\"]:>8,} {r:>7.1f}%')

print()
print(f'=== BY SOURCE IP (top 15) ===')
print(f'{\"Source\":<22} {\"IP\":<18} {\"Del\":>8} {\"Temp\":>8} {\"Bnc\":>6} {\"Rate\":>8}')
for src in sorted(by_source, key=lambda s: by_source[s]['d']+by_source[s]['b'], reverse=True)[:15]:
    v = by_source[src]
    if not v['ip']: continue
    t = v['d'] + v['b']; r = (v['d']/t*100) if t > 0 else 0
    print(f'{src:<22} {v[\"ip\"]:<18} {v[\"d\"]:>8,} {v[\"t\"]:>8,} {v[\"b\"]:>6,} {r:>7.1f}%')

if gmail_unusual:
    print(f'\nGmail unusual rate: {sum(gmail_unusual.values())} hits across {len(gmail_unusual)} IPs')
    for ip, c in gmail_unusual.most_common(10):
        print(f'  {ip}: {c}')
else:
    print(f'\nGmail unusual rate: none')

if ms_reasons:
    print(f'\nTop Microsoft temp fail reasons:')
    for r, c in ms_reasons.most_common(5):
        print(f'  [{c:>4}] {r}')

if bounce_reasons:
    print(f'\nTop bounce reasons:')
    for r, c in bounce_reasons.most_common(5):
        print(f'  [{c:>4}] {r}')
"
```

Replace `<host>` with the SSH host name and `<sudo>` with `sudo` if the instance requires it (see table above), or empty string if not.

### Date override

To check a specific date instead of today, replace `$(date +%Y%m%d)` with the desired date prefix (e.g. `20260406`).

## Output format

Present results as a concise summary for each instance:
- Headline: instance name, provider, delivery rate, volume
- Provider breakdown table (Google, Microsoft, etc.)
- Source IP table only if there are notable differences between IPs (some good, some bad)
- Gmail unusual rate flags (always mention even if zero)
- Microsoft temp fail reasons if significant
- Bounce reasons if any

## What to watch for

- **Gmail "unusual rate"**: IP reputation issue, especially "IP Netblock" variant
- **Microsoft S77714 "Server busy"**: Throttling, usually clears in 24h
- **Microsoft "banned sending IP"**: Needs delist at sender.office.com
- **High temp fail ratio**: Messages stuck retrying — delivery rate looks fine but many messages pending
- **554 Relay access denied**: Sender domain not configured in KumoMTA relay config
- **550 SPF failures**: `isn't allowed to send email for` — DKIM/SPF alignment issue
