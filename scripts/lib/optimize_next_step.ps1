# optimize_next_step.ps1 -- ORDER-152(c). What should the operator do with a produced optimizer XML?
#
# WHY THIS EXISTS. mt5_optimize.ps1 used to print "next: python select_robust_pass.py ..." on every
# successful optimize pass. select_robust_pass.py's own docstring says it implements the archived,
# superseded BacktestScore v1 gate and has not been re-verified against the current VERDICT GATE /
# backtest-optimize-rigor LADDER. Selection stays candidate/hypothesis-contract driven (see
# _triage/factory_os/registry.py + candidate.py, the resolver mt5_optimize.ps1 already threads
# -HypothesisRevision through to optimize_guard.ps1). This launcher must not point operators at the
# old generic ranking formula, and per the same rule must not invent a replacement formula here
# either -- when no contract is bound to the run, selection is BLOCKED, not guessed at.
#
# CATEGORY: PURE. Takes two strings, returns one string. No file I/O, no process launch -- the only
# reason this is testable without MT5, and split out for exactly that reason
# (scripts\_test\run_mt5_optimize_launcher_hardening_tests.ps1 drives it directly on fixtures).
#
# NO Set-StrictMode HERE ON PURPOSE: dot-sourced into a launcher; a shared library must be inert to
# its callers (memory `strictmode-in-dotsourced-library-leaks`).

function Get-OptimizeNextStepMessage {
    <#
      .SYNOPSIS
        -> [string] the one "next:" line mt5_optimize.ps1 prints after a successful optimizer XML.
      .PARAMETER DestXml
        The collected optimizer XML's final path (already moved out of the terminal DATA folder).
      .PARAMETER HypothesisRevision
        The -HypothesisRevision this run was submitted under, or '' if none was supplied.
    #>
    param(
        [Parameter(Mandatory)][string]$DestXml,
        [string]$HypothesisRevision = ''
    )
    if ($HypothesisRevision -ne '') {
        return "next: $DestXml is a candidate for hypothesis '$HypothesisRevision'. Selection is candidate/hypothesis-contract driven (see _triage\factory_os\registry.py + candidate.py) -- do not use select_robust_pass.py (archived BacktestScore v1, not re-verified against the VERDICT GATE)."
    }
    return "next: SELECTION BLOCKED -- no -HypothesisRevision was supplied to this run, so no pre-registered candidate/hypothesis contract is bound to $DestXml. Attach one via the Factory OS candidate/hypothesis registry before selecting a pass; select_robust_pass.py (archived BacktestScore v1) must not be used as a substitute."
}
