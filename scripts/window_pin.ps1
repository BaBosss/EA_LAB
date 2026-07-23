<#
window_pin.ps1 — SINGLE machine-readable source of the project's canonical backtest windows.

SOURCE OF TRUTH: this mirrors the "Window names" pin in CLAUDE.md's VERDICT GATE section.
Every tool in this repo that needs MAIN / BWD / HOLDOUT date ranges must dot-source this file
and call Get-WindowPin — do NOT re-type these dates in another script. When the project re-pins
(doctrine: re-pin MAIN every 6 months, never let MAIN slide over the current HOLDOUT), update
BOTH this file and CLAUDE.md in the same commit.

Iron rule (CLAUDE.md, verbatim): MAIN ∩ HOLDOUT = ∅. If a re-pin would make MAIN overlap the
current HOLDOUT, a new HOLDOUT must be declared first. Callers that build rolling windows off
this pin (e.g. scripts/walkforward.ps1) must assert no generated window overlaps HOLDOUT and
refuse to run rather than silently leak into it.

Pinned as of 2026-07-23 (per CLAUDE.md as of this date):
  MAIN    = 2023.01.01 - 2025.12.01   (36 most-recent months, ends before HOLDOUT starts)
  BWD     = 2020.01.01 - 2023.01.01   (2020-2022 trend/stress regime, contiguous into MAIN)
  HOLDOUT = 2026.01.01 - 2026.07.01   (2026H1 — never used for selection until it is "burned",
                                        i.e. actually used once as a real out-of-sample test)
#>

function Get-WindowPin {
  [PSCustomObject]@{
    MAIN    = [PSCustomObject]@{ From = [datetime]"2023-01-01"; To = [datetime]"2025-12-01" }
    BWD     = [PSCustomObject]@{ From = [datetime]"2020-01-01"; To = [datetime]"2023-01-01" }
    HOLDOUT = [PSCustomObject]@{ From = [datetime]"2026-01-01"; To = [datetime]"2026-07-01" }
    PinnedOn = [datetime]"2026-07-23"
  }
}

# Interval-overlap test shared by callers. Boundaries touching (aTo == bFrom) is NOT an overlap —
# a window that ends exactly where HOLDOUT begins is legal (that's how MAIN itself is pinned).
function Test-WindowOverlap {
  param([datetime]$AFrom, [datetime]$ATo, [datetime]$BFrom, [datetime]$BTo)
  return ($AFrom -lt $BTo) -and ($ATo -gt $BFrom)
}
