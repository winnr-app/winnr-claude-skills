---
name: deliverability-analysis
description: >
  Root-cause a Gmail deliverability complaint for a specific sender domain.
  Sends controlled test messages through every variant of our stack (Mailcow
  submission, direct Kumo inject, Kumo-IP bypass, SES), polls Gmail IMAP for
  placement, and isolates which variable flipped inbox→spam. Use when a
  customer reports "going to spam", when Gmail inbox rates drop on a specific
  domain or Kumo relay, when evaluating whether to move a domain to SES, or
  when asked to "analyze deliverability", "test Gmail placement", "debug
  spam placement", "compare SES vs Kumo".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Glob
  - Grep
---

# Deliverability Analysis

> Gmail placement is a function of IP reputation + sender-domain reputation +
> per-recipient learned reputation + content. No single header is the signal.
> This skill runs an A/B matrix across all those variables so you can point to
> evidence instead of guessing.

---

## CRITICAL: test hygiene

Read this before sending anything. We learned the hard way that **the first test you send from a domain teaches Gmail how to treat that domain for that recipient.** Polluted ground poisons every subsequent test.

1. **NEVER send `Subject: test` / `Body: test`.** That's a textbook spam-classifier tell. Gmail will spam it AND negatively-train the per-recipient reputation, turning every subsequent humanlike test from the same domain into spam. The 10-message "all Kumo arms spammed" result from 2026-04-20 was caused by this mistake.
2. **Start with the most realistic test first**, not the "control." The first send establishes reputation.
3. **Use humanlike content** — the same template the dashboard matrix runner uses works well:
   - Subject: `Quick question about <topic> [<short token>]`
   - Body: "Hi Alex,\n\nI've been putting some thought into <topic> and wanted to run a few ideas by you when you have a chance. Nothing urgent - happy to find a time that works.\n\nLet me know what the rest of the week looks like on your end.\n\n- <name>\n"
4. **Use a mailbox name that looks real.** `nicolas@domain.com` is fine. `dtest@domain.com` signals "test" to Gmail.
5. **Rotate Gmail receivers across arms.** See receiver table below — we have 4 accounts, spread test volume across them so you don't burn one account's per-sender reputation.
6. **Do not run more than 2–3 sends from the same sender-domain to the same Gmail receiver in an hour.** Volume spikes are themselves a spam signal AND they make results unreliable because negative reputation compounds inside the test.
7. **If you need a baseline "spam-content" arm, put it LAST**, after humanlike arms have established positive signal.

---

## Inputs the user typically provides

- A domain name (customer complaint about X.com going to spam)
- A Kumo instance that appears to be degrading
- "Why does this land in spam" with a raw message or headers pasted

If only a vague ask ("analyze deliverability"), ask for one of these before starting.

---

## Test Gmail receivers

Credentials in SSM. Fetch once per session, cache locally:

```bash
aws --profile winnr ssm get-parameter --name /winnr/dashboard/inbox_test_gmail_credentials --with-decryption --query Parameter.Value --output text
```

Returns JSON with 4 receivers (labels A/B/C/D):

| Label | Address | Notes |
|---|---|---|
| A | `acaburchtest@gmail.com` | |
| B | `acaburchtest2@gmail.com` | |
| C | `acaburchtest3@gmail.com` | |
| D | `acaburchtest4@gmail.com` | |

Each has a Gmail app password in the SSM blob. Use via IMAP at `imap.gmail.com:993`. Spread arms across ≥2 receivers so per-recipient reputation doesn't pollute your conclusions.

---

## Step 1 — snapshot the domain's current stack

Before sending anything, know what you're testing against:

```bash
# DNS state (what Gmail sees when it looks up the sender)
dig +short NS <domain>
dig +short MX <domain>
dig +short TXT <domain>          # SPF
dig +short TXT dkim._domainkey.<domain>   # default Mailcow selector
dig +short TXT _dmarc.<domain>
whois <domain> 2>/dev/null | grep -iE 'creation|registrar|name server' | head -6
```

Then find the mailcow + relay via Firestore. The field layout:
- Mailboxes live at `accounts/{account_id}/email_users` keyed by `full_address`
- Domain config at `accounts/{account_id}/domains/{doc_id}` has `dns_provider`, `mailcow_instance`, `relay_name`, `created_at`

Use `collection_group('email_users')` filtered on `full_address=="any@<domain>"` to find the account id without scanning all accounts. (Requires an index; if missing, fall back to scanning `accounts` for a domain doc with `domain==<domain>`.)

The `relay_name` values that can appear:
- `kumo1`, `kumo4`, `kumo5`, `kumo6`, `kumo7`, `kumo8`, `kumo9` — real Kumo relays
- `ses1` — direct SES
- **Heads up:** `kumo1` on AWS sometimes routes outbound via SES (observed egress IPs in the `54.240.x.x` range). If you see a `kumo1`-labeled cell producing AWS egress IPs, it's SES-backed.
- Deprecated: `kumo2`, `kumo3`

Mailcow instance → SMTP hostname comes from `winnr-python/mailcow_hostnames.py`. SSH host names are `mailcow`, `mailcow3`…`mailcow11`.

---

## Step 2 — identify the send paths you can exercise

| Arm | How | What it isolates |
|---|---|---|
| **A_stock** | SMTP auth to `<mailcow_hostname>:587` as a real mailbox, goes through KumoMTA relay per domain's `relayhost` | Baseline: current production path |
| **C_direct** | Submit on kumo8's (or any Kumo's) `127.0.0.1:25` — Kumo still relays to Gmail | Removes Mailcow submission hop (strips `(Mailerdaemon)` Received, `X-Last-TLS-Session-Version`) |
| **E_bypass** | From the Kumo box, Python `smtplib` direct to `gmail-smtp-in.l.google.com:25` | Removes KumoMTA entirely. Same IP, totally different SMTP/TLS client |
| **F_ses** | `aws sesv2 send-email` from an SES-verified identity for the domain | AWS IP reputation + `amazonses.com` DKIM co-signature |

If you want cleaner isolation:
- **Selector variant**: generate a second DKIM key under a non-`dkim` selector and publish the TXT; sign outbound with that one only.
- **MX variant**: publish a subdomain like `t1.<domain>` with its own MX pointed off-fleet (e.g. `aspmx.l.google.com`), SPF that allows our Kumo IPs, own DKIM. Send from that subdomain via Kumo.
- **Dual-DKIM**: sign with two DKIM keys (different selectors, different `d=`) to test signer-identity vs signer-count.

---

## Step 3 — create a throwaway mailbox

The domain probably already has mailboxes — **don't send from them.** Real customer mailboxes have DM/reply history that you'll pollute. Create a test mailbox via the Mailcow admin API instead.

On the mailcow box, the API key is in the `api` SQL table:
```bash
ssh <mailcow_host> "DBPW=\$(sudo grep ^DBROOT= /mailcow/mailcow-dockerized/mailcow.conf | cut -d= -f2); sudo docker exec mailcowdockerized-mysql-mailcow-1 mysql -u root -p\$DBPW mailcow -e 'SELECT api_key FROM api LIMIT 1'"
```

Create the mailbox. Use a realistic-looking name:
```bash
ssh <mailcow_host> "APIKEY=<key>; TESTPW='<strong-random>'; curl -sk -X POST https://localhost/api/v1/add/mailbox \
  -H 'X-API-Key: \$APIKEY' -H 'Content-Type: application/json' \
  -d '{\"local_part\":\"nicolas\",\"domain\":\"<domain>\",\"name\":\"Nicolas Chen\",\"quota\":\"1024\",\"password\":\"'\$TESTPW'\",\"password2\":\"'\$TESTPW'\",\"active\":\"1\"}'"
```

To route this mailbox through a non-default relay (e.g. kumo7 instead of the domain's default), use `edit/mailbox` with `attr.relayhost=<id>`. The `relayhosts` table on each mailcow lists valid ids.

**Delete the mailbox at the end of the session**, always.

---

## Step 4 — send the arms

Keep all arms using the same humanlike subject+body template. Change only one variable between arms so attribution is clean.

### A_stock (Mailcow → Kumo)

```python
import ssl, smtplib, uuid, time, random, string
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.utils import formatdate

token = f"dtok-{uuid.uuid4().hex[:6]}"
msg = MIMEMultipart("alternative", boundary=f"----=_part_{uuid.uuid4().hex[:20]}")
msg["Subject"] = f"Quick question about quarterly planning [{token}]"
msg["From"] = "Nicolas Chen <nicolas@<domain>>"
msg["To"] = "<receiver>@gmail.com"
msg["Date"] = formatdate(localtime=False)
msg["Message-ID"] = f"<{uuid.uuid4().hex}@<domain>>"
msg.attach(MIMEText("Hi Alex,\r\n\r\nI've been putting some thought into quarterly planning and wanted to run a few ideas by you when you have a chance. Nothing urgent - happy to find a time that works.\r\n\r\nLet me know what the rest of the week looks like on your end.\r\n\r\n- Nicolas\r\n", "plain"))
msg.attach(MIMEText("<html><body><p>Hi Alex,</p><p>...same body in html...</p></body></html>", "html"))

with smtplib.SMTP("<mailcow_hostname>", 587, timeout=30) as s:
    s.ehlo(); s.starttls(context=ssl.create_default_context()); s.ehlo()
    s.login("nicolas@<domain>", "<pw>")
    s.send_message(msg)
print(f"SENT token={token}")
```

### E_bypass (direct from Kumo IP)

Run this **on the Kumo host**. Requires `dkimpy` + `dnspython` (`pip3 install --user dkimpy dnspython`). Fetch the DKIM private key from Mailcow Redis:

```bash
ssh <mailcow_host> "REDISPW=\$(sudo grep ^REDISPASS= /mailcow/mailcow-dockerized/mailcow.conf | cut -d= -f2); sudo docker exec mailcowdockerized-redis-mailcow-1 redis-cli -a \$REDISPW --no-auth-warning HGET DKIM_PRIV_KEYS dkim.<domain>" > /tmp/dkim.key
```

Then on the Kumo box, run a DKIM-signing+submission script. Template is in this skill's `bypass_template.py` section below. Critical gotchas:

- **Force IPv4**: our Kumo IPv6 has no rDNS. Gmail will reject with `550 5.7.25 ... missing PTR`. Patch `socket.socket` to convert `AF_INET6` to `AF_INET` and bind to a specific v4 IP.
- **Don't verify Gmail MX cert hostname** in Python: connecting to `gmail-smtp-in.l.google.com` by IP (we need to bind a source IP first, which forces IP connection) breaks TLS SNI verification. Use `ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE`. Security is fine — we're not concerned about MITM on 99.9%-uptime public Google.
- **Use `smtplib.SMTP.mail()` and `.rcpt()`**, not `.docmd('MAIL FROM', ...)` — the latter mangles the command syntax Kumo expects (strips the colon).
- **Set HELO to the rDNS of the bind IP** so FCrDNS passes: `socket.gethostbyaddr(BIND_IP)[0]`.

### F_ses (SES send)

If the domain isn't SES-verified, set it up first (it's idempotent and harmless):

```python
import boto3
s = boto3.Session(profile_name='winnr', region_name='us-east-1')
ses = s.client('sesv2')
try: r = ses.create_email_identity(EmailIdentity='<domain>')
except ses.exceptions.AlreadyExistsException: r = ses.get_email_identity(EmailIdentity='<domain>')
tokens = r['DkimAttributes']['Tokens']
# Publish 3 CNAMEs at <token>._domainkey.<domain> -> <token>.dkim.amazonses.com
# - Route53 direct if dns_provider=route53
# - ClouDNS via winnr-python/clouddns_client.py if dns_provider=clouddns*
# SPF on the domain must include amazonses.com (most winnr domains already do)
```

Then send:
```python
ses.send_email(FromEmailAddress=f"dan@{DOMAIN}", Destination={"ToAddresses":[TO]}, Content={"Raw":{"Data": msg.as_bytes()}})
```

---

## Step 5 — poll Gmail for placement

Every arm gets a unique token in its subject. Poll all three folders because Gmail's "All Mail" does **not** include Spam:

```python
import imaplib
im = imaplib.IMAP4_SSL("imap.gmail.com"); im.login(RECEIVER, APP_PW.replace(" ", ""))
for folder, name in [('"[Gmail]/All Mail"','all'), ('"[Gmail]/Spam"','spam'), ('INBOX','inbox')]:
    im.select(folder, readonly=True)
    typ, data = im.search(None, f'(SUBJECT "{TOKEN}")')
    ids = (data[0] or b'').split()
    print(f'{name}: {len(ids)}')
```

Delivery to Gmail is usually under 60 seconds. Polls can start after 30s and loop up to ~5 minutes. If the arm never shows up, the message was rejected or blackholed — check Kumo's logs on the sending box (`/var/log/kumomta/$(date +%Y%m%d)-*` zstd-compressed JSON) and Mailcow postfix logs (`docker logs --since 20m mailcowdockerized-postfix-mailcow-1`).

**Interpreting placement:**
- **All 3 folders = 0 matches** → message rejected upstream. Check sending-box logs.
- **Spam has it, Inbox does not** → placement = spam.
- **Inbox has it, Spam does not** → placement = inbox.
- **Both** → rare race; treat as inbox (Gmail moved it).

---

## Step 6 — extract evidence from headers

For every arm, fetch the full message headers and extract:

```
Authentication-Results: mx.google.com;
  dkim=pass|fail header.i=@<...> header.s=<...> header.b=<...>
  spf=pass|fail ... client-ip=<...>
  dmarc=pass|fail (p=REJECT sp=REJECT dis=NONE) header.from=<...>
Received: from <egress hostname> (<rdns>. [<egress ip>]) by mx.google.com with ESMTPS ... (version=<tls> cipher=<cipher>)
ARC-Message-Signature: ... fh=<hash>
```

Useful things to compare across arms:
- `client-ip` — what egress IP actually reached Gmail
- `header.s` and `header.i` on dkim= lines — which DKIM identities signed and passed
- TLS `cipher=` — our Kumo sends pick `TLS_AES_256_GCM_SHA384`, SES picks `TLS_AES_128_GCM_SHA256` (preference difference, not a signal)
- Presence of `X-KumoRef`, `X-SES-Outgoing`, `Feedback-ID`
- rDNS parent of egress IP (e.g. `snakecharmer.net`, `bottombook.com` — these are our parked rDNS domains; `smtp-out.amazonses.com` for SES)
- `Received` chain — number of hops, presence of `(Mailerdaemon)` string from Mailcow

---

## Step 7 — cross-reference historic placement

Before concluding anything from ~10 sends, look at the matrix runner's own data. It sends 160-cell runs across (dns_provider × mailcow × relay × redirect × age) with all 4 Gmail receivers:

```
winnr-python/cli/inbox_test_runs/run_*.json
```

Each cell has `placement.verdict` = inbox|spam|... and the sender/dimensions/egress-ip/rdns. To compute inbox rate by relay for a run:

```python
import json, collections
d = json.load(open('cli/inbox_test_runs/run_YYYYMMDD_HHMMSS.json'))
by_relay = collections.defaultdict(lambda: collections.Counter())
for c in d.get('cells', []):
    v = (c.get('placement') or {}).get('verdict')
    r = (c.get('dimensions') or {}).get('relay_name')
    if v and r: by_relay[r][v] += 1
for r in sorted(by_relay):
    c = by_relay[r]; t = sum(c.values()); i = c.get('inbox',0)
    print(f"{r}: {i}/{t} = {i/t*100:.0f}%")
```

Use this to distinguish "domain-specific problem" from "relay-wide degradation." If the complained-about domain spams but the rest of the relay inboxes normally, it's a domain issue. If the whole relay's inbox rate crashed, it's the relay. Multi-week trend = rotation decision.

---

## Step 8 — always clean up

At the end of a session:

1. **Delete the test mailbox.** `curl -X POST /api/v1/delete/mailbox`.
2. **Revert any SPF widening** you did for testing.
3. **Delete any temporary DNS records** (new DKIM selectors, subdomain MX/SPF/DKIM) — Route53 via `boto3`, ClouDNS via `winnr-python/clouddns_client.py`.
4. **Remove DKIM private keys** from `/tmp/` on any box you touched and locally.
5. **Leave SES identities + DKIM CNAMEs in place** if you created them — they're harmless and useful for future routing decisions.

Do not leave test mailboxes active. They complicate future testing and can confuse customers reviewing their domain.

---

## Common results and what they mean

| Pattern | Conclusion |
|---|---|
| All Kumo arms spam, SES arm inboxes | Most likely: sender-domain reputation is low with this receiver. Check matrix-run data to see if this is just this receiver or fleet-wide. |
| Every send from a specific Kumo relay spams, same domain via another Kumo relay inboxes | Relay-specific IP reputation issue. Consider rotation. |
| First arm inboxes, subsequent arms from same domain spam within an hour | You poisoned per-recipient reputation mid-test. Stop, switch to a different Gmail receiver, wait 24h, re-run with clean test hygiene. |
| Everything spams including SES | Content is the issue, or the specific Gmail receiver has a very negative history with this domain. Try a different receiver. |
| Direct-inject to Kumo (C) and bypass-from-Kumo (E) produce the same placement | KumoMTA software isn't the fingerprint. It's IP reputation. |
| Selector rotation (non-`dkim`) produces same placement | Selector name isn't the signal. (Confirmed 2026-04-20.) |
| Subdomain with off-fleet MX produces same placement | MX-on-our-fleet isn't the signal. (Confirmed 2026-04-20.) |

---

## What's already been ruled out (from 2026-04-20 investigation)

Do **not** re-test these unless something material changed — each was confirmed via ≥2 independent arms:

- Body/subject content (stock vs humanlike)
- Mailcow submission headers (`(Mailerdaemon)` Received, `X-Last-TLS-Session-Version`)
- KumoMTA software / `X-KumoRef` / queue processing
- DKIM selector name (tested `m202604` vs `dkim` — same result)
- Dual DKIM / signer count
- Second-identity DKIM from an old unused domain (tested `programessentials.com`, 2003-registered — no effect)
- DNS provider (ClouDNS vs Route53 native)
- Vanity nameservers vs native NS
- Registrar (Openprovider vs Dynadot)
- Domain age (1 day vs 140 days)
- SPF shape (chained includes vs simple `ip4`)
- `include:amazonses.com` presence in SPF
- `s1.` subdomain convention
- Specific Kumo instance (tested 4, 6, 8; all equivalent behavior)
- Kumo IP ASN (OVH, Contabo, Scaleway, Hetzner, Hivelocity — all equivalent)
- rDNS parent domain (`meetaccountingstaff.com`, `bottombook.com`, `ifights.com`, `usedtraveltrailer.com`, `erginaltinel.com`, `snakecharmer.net`, `growthplanhub.com` — tried Hivelocity-default `.static.hvvc.us` too; no effect)
- MX-of-sender-domain pointing to our fleet
- Per-domain SES co-signature won't help unless the second identity has reputation — `amazonses.com` works because AWS has it, not because it's a second DKIM

The variables that DO matter: **sending IP reputation** (cumulative per-IP Gmail score), **sender-domain reputation per recipient** (trained by engagement and by prior placement), and **content patterns that look like cold outreach**. These are not things you can fix with a single message tweak; they're earned over time or bought by routing through a trusted ESP.

---

## Final report shape

After a full run, write up:

1. **What the customer sees** (1 sentence: "messages from X.com to Gmail land in spam")
2. **What the evidence shows** (table: arm → placement → egress IP → auth results)
3. **What's ruled out** (pulling from "Common results" above)
4. **What the remaining candidate causes are** (ranked)
5. **Actionable next steps** (route to SES for this domain, rotate Kumo IPs, warm via engagement campaigns, check GPT reputation)
6. **State changes** (mailbox deleted, SPF restored, SES identity left in place, etc.)

Keep it evidence-first. Don't speculate past what the arms actually showed.
