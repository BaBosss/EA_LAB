# setfile_surface.ps1 -- ORDER-1268. What does a .set entering a run DECLARE about its surface?
#
# WHY THIS EXISTS. `scripts/mt5_run.ps1` and `scripts/mt5_optimize.ps1` accept ANY existing .set,
# including a single-assignment one. mt5_run warns only when NO file is supplied; mt5_optimize
# does not warn at all. MT5 fills every unlisted input from the PER-TERMINAL tester cache, so
# Run A with a partial file, another session touching the same EA in the same terminal, and Run B
# with the IDENTICAL file is three different effective configurations and one filename. That is
# the ORDER-165 "8/8 false drift" and it is in this repo's memory as
# `mt5-tester-cache-nondeterminism`.
#
# WHY IT DOES NOT SIMPLY REFUSE A PARTIAL FILE. ORDER-700 reasoned this through and was right:
# the repo holds 2,177 tracked .set files, most of them partial, and a guard that refuses valid
# work gets switched off. So the rule here is REFUSE OR RECORD, and which one you get depends on
# what the file itself says:
#
#   FULL         it carries the `; build=... surface=N ...` provenance line preset.render_set
#                writes, and it carries exactly N assignments -> the run is reproducible, recorded
#   MISMATCH     it carries that line and does NOT carry N assignments -> REFUSED. This is not a
#                legacy file; it is a COMPILED preset that has been edited or truncated since, and
#                it is the one case where the file's own claim can be shown false
#   UNDECLARED   no provenance line -> RECORDED, loudly, never refused. The 2,177. The run may be
#                perfectly fine; what is not fine is a report that does not say the remainder came
#                from the cache
#   UNREADABLE   the path does not exist or cannot be read -> REFUSED, never folded into
#                UNDECLARED. `unreadable-input-must-refuse-not-skip`: "I could not read it" and
#                "it declares nothing" are different facts, and a reader that reports the second
#                for the first has reported a measurement it never took
#
# CATEGORY: PURE-ish. It reads ONE path, named by the caller, and returns a record. It prints
# nothing, decides nothing, and launches nothing -- the runners own the policy of what to do with
# each state, and `run_setfile_tests.ps1` drives this function directly on fixtures, which is the
# only reason any of it is testable without an MT5 terminal.
#
# NO Set-StrictMode HERE ON PURPOSE: this file is dot-sourced into two launchers, and
# `strictmode-in-dotsourced-library-leaks` is a paid-for lesson -- a shared library must be inert
# to its callers.

function Get-SetSurfaceState {
    <#
      .SYNOPSIS
        -> [pscustomobject] State, BuildTag, Declared, Assignments, Refuse, Message
      .PARAMETER Path
        The .set the caller is about to hand to the tester. May be $null/empty: "no set file at
        all" is a real state the caller must handle and is reported as NOSETFILE rather than
        guessed at.
    #>
    param([string]$Path)

    # NOT [AllowNull()][string]: that coerces $null to '' silently, which is how a "could not
    # read" branch becomes dead code and a guard reports CLEAN over a file it never saw
    # (`ps-allownull-string-coerces-null-to-empty`).
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return [pscustomobject]@{
            State = 'NOSETFILE'; BuildTag = $null; Declared = $null; Assignments = 0
            Refuse = $false
            Message = 'no -SetFile: EVERY input comes from this terminal''s tester cache (MQL5\Profiles\Tester), rewritten by any session that touches this EA here. NON-REPRODUCIBLE -- pass a FULL .set for any number you intend to keep (ORDER-165).'
        }
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [pscustomobject]@{
            State = 'UNREADABLE'; BuildTag = $null; Declared = $null; Assignments = 0
            Refuse = $true
            Message = ("the -SetFile '{0}' does not exist. REFUSED rather than treated as absent: a run launched with a set file the caller believes it passed, and the tester never saw, is configured entirely from the terminal cache while the command line says otherwise." -f $Path)
        }
    }
    try {
        $lines = @(Get-Content -LiteralPath $Path -ErrorAction Stop)
    } catch {
        return [pscustomobject]@{
            State = 'UNREADABLE'; BuildTag = $null; Declared = $null; Assignments = 0
            Refuse = $true
            Message = ("the -SetFile '{0}' could not be read: {1}. REFUSED, not skipped." -f $Path, $_.Exception.Message)
        }
    }

    # @() around the pipeline: `($pipeline).Count` is $null when the pipeline yields exactly ONE
    # object, which is how a detector that found exactly one thing reported nothing
    # (`powershell-pipeline-count-null-on-single-result`, the fourth occurrence in eight days).
    $assign = @($lines | Where-Object {
        $t = $_.Trim()
        $t -and (-not $t.StartsWith(';')) -and $t.Contains('=')
    }).Count

    # The line preset.render_set emits:  ; build=<tag> surface=<n> effective_config_hash=<sha> (<scope>)
    $tag = $null; $declared = $null
    foreach ($l in $lines) {
        $m = [regex]::Match($l.Trim(), '^;\s*build=(\S+)\s+surface=(\d+)\s+effective_config_hash=([0-9a-f]{64})')
        if ($m.Success) { $tag = $m.Groups[1].Value; $declared = [int]$m.Groups[2].Value; break }
    }

    if ($null -eq $declared) {
        return [pscustomobject]@{
            State = 'UNDECLARED'; BuildTag = $null; Declared = $null; Assignments = $assign
            Refuse = $false
            Message = ("this .set carries {0} assignment(s) and NO surface declaration, so nothing here can say whether it is the full surface of any build. Any input it omits is filled from this terminal's tester cache (ORDER-165). RECORDED, not refused -- the 2,177 legacy files are legitimate work and ORDER-700 declined to judge them. Compile with gen_default_preset.py to get a file that states its own surface." -f $assign)
        }
    }
    if ($assign -ne $declared) {
        return [pscustomobject]@{
            State = 'MISMATCH'; BuildTag = $tag; Declared = $declared; Assignments = $assign
            Refuse = $true
            Message = ("this .set DECLARES build {0}'s surface of {1} inputs and carries {2} assignment(s). REFUSED: a compiled preset that no longer matches its own header has been edited or truncated since it was generated, so the {3} input(s) it is short of are filled from the terminal cache while the file's own provenance line claims a full surface." -f $tag, $declared, $assign, [math]::Abs($declared - $assign))
        }
    }
    return [pscustomobject]@{
        State = 'FULL'; BuildTag = $tag; Declared = $declared; Assignments = $assign
        Refuse = $false
        Message = ("full surface of build {0}: {1} of {1} inputs declared and present. No input is left to the terminal cache." -f $tag, $declared)
    }
}
