# MacroGate DEMO regime-only VPS transport

Purpose: keep `EA_LAB_mris_regime.csv` fresh for the accepted DEMO MacroGate without publishing or modifying the NewsGuard feed.

Use `pull_regime.cmd` beside `pull_guard_feeds.ps1`. The entrypoint invokes the worker with `-RegimeOnly`, so the fetch allowlist contains only `EA_LAB_mris_regime.csv`.

The worker validates the regime file, preserves last-good `Common\Files` on failure, and atomically replaces only `EA_LAB_mris_regime.csv` on success.

`Terminal\Common\Files` is shared by terminals on the VPS. Regime-only mode must not create, replace, delete, validate, or fetch `EA_LAB_news_week.csv`.

Do not substitute `pull_news.cmd` for this DEMO-only task when activating NewsGuard on REAL accounts is outside the approved scope.

Recommended scheduled action:

`C:\rclone\pull_regime.cmd`

Expected success log suffix:

`guard feed pull COMPLETE: MacroGate regime-only feed validated and published atomically`

A missing, malformed, or stale regime feed must return non-zero and retain the last-good Common file. Do not kill or force-close an MT5 terminal to refresh this transport.