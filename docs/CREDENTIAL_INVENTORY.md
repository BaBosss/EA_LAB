# Credential Inventory

CODEX-AUDIT P1 (`MASTER_BACKLOG.md` §CODEX-AUDIT, "Credential inventory") — template only.
**Fill in the blanks; store actual secrets OUTSIDE git.** This file lists WHERE each
credential lives and who owns it — never the credential value itself (no passwords, no
tokens, no API keys as literal text in this file, ever).

Rows below are pre-populated from what's already discoverable in the repo (the gist token
usage in `scripts/publish_dashboard_gist.ps1` + every account number in
`portfolio/DEPLOYMENTS.csv`). Owner / Rotation date / Recovery procedure are left blank for
the user to fill in. Add new rows as new credentials show up (new VPS account, new API key,
new webhook, etc.) — keep this in sync with `portfolio/DEPLOYMENTS.csv` when accounts are
added/removed.

| Credential | Type | Owner | Location | Rotation date | Recovery procedure |
|---|---|---|---|---|---|
| GitHub gist token (`gh` CLI auth, used by `scripts/publish_dashboard_gist.ps1`) | gist-token | | | | |
| Account 159503454 "08. Blazing Arrow" login/password — REAL_CENT, MT5, VPS 66.212.22.7 | account | | | | |
| Account 159503454 "08. Blazing Arrow" investor password | investor-pw | | | | |
| Account 159475669 "Boss - Trend Swing" login/password — REAL_CENT, MT5, VPS 66.212.22.7 | account | | | | |
| Account 159475669 "Boss - Trend Swing" investor password | investor-pw | | | | |
| Account 141049900 "01. Celestial Woodfire" login/password — REAL_CENT, MT4, VPS 66.212.22.7 | account | | | | |
| Account 141049900 "01. Celestial Woodfire" investor password | investor-pw | | | | |
| Account 415573666 "Demo Mt5-2" login/password — DEMO, MT5, VPS 66.212.22.7 | account | | | | |
| Account 463666728 "Demo bundle 10" login/password — DEMO, MT5, VPS 66.212.22.7 | account | | | | |
| Account 69424711 "Demo EA3" login/password — DEMO, MT4, VPS 66.212.22.7 | account | | | | |
| Account 146237 "Exness demo (user pool)" login/password — DEMO, MT5, user terminal (host TBC) | account | | | | |
| VPS 66.212.22.7 RDP login (hosts 6 of the 7 accounts above) | api-key | | | | |

## Notes

- REAL accounts (159503454, 159475669, 141049900) are REAL_CENT money — treat their
  passwords and investor passwords as highest priority to inventory/rotate.
- DEMO accounts (415573666, 463666728, 69424711, 146237) are lower stakes but still worth
  tracking so a dead/rotated demo login doesn't silently stop the live-monitor pipeline.
- "investor-pw" = MT4/MT5 read-only investor password (used by exporters/monitoring, not by
  the EA itself) — separate from the trading (main) password.
- Source of truth for the account list: `portfolio/DEPLOYMENTS.csv` (column 1 = account
  number, column 3 = type REAL_CENT/DEMO, column 4 = platform, column 5 = host).
- This file intentionally has no automated reader/writer — it's a manual reference for the
  user, unlike `DEPLOYMENTS.csv` which the dashboard/monitor scripts parse.
