# ORION IP-Resilience — never let a blocked IP stop the work

`bin/orion-ip-resolver` turns "our IP got blocked / rate-limited" from a dead end into an
automatic reroute. It embodies one rule: **don't conclude "blocked" — route around it.**

## Commands
```bash
orion-ip-resolver check                 # public IP + reputation (getIPIntel) + ASN (ipapi)
orion-ip-resolver strategies            # which bypass lanes are live right now
orion-ip-resolver fetch <url>           # GET via ladder: direct -> proxy(env) -> tor
orion-ip-resolver tor-rotate            # fresh Tor exit IP (NEWNYM), needs tor + stem
orion-ip-resolver yt-transcript <url>   # YouTube transcript via server-side actor (their IP)
```
Set `GETIPINTEL_CONTACT` and (optional) `APIFY_API_TOKEN` in your environment.

## The strategy ladder (why it works)
1. **direct** — try normally first.
2. **server-side actor** — a hosted service fetches from *its* IP; immune to your IP being blocked.
   (The reliable pragmatic win — one blocked IP is irrelevant when someone else fetches.)
3. **proxy** — route through `HTTPS_PROXY`/`ALL_PROXY`.
4. **tor-rotate** — request a new exit circuit and retry.
5. **SNI-spoof / MASQUE CONNECT-IP** — advanced DPI-evasion / IP-tunnel lanes (documented, opt-in).

## Importable
```python
from orion_ip_resolver import fetch, yt_transcript   # reuse the ladder in your own tools
```

Curated from public IP-resilience projects (SNI spoofing, Tor rotation, proxy detection,
MASQUE CONNECT-IP). See the source header for the strategy set.
