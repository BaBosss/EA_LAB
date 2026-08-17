<#
Scaffold the mechanical wiring for a new EA Template entry (LAB_ENTRY_<N>): a
Boss_<N>_<Name>.mq5 wrapper, a core/entries/Entry_<Name>.mqh skeleton, and the two
core/LabCore.mqh #ifdef LAB_ENTRY_<N> touch points (entry-select include + OnInit call).
Refuses on any entry-number/name collision, or a missing/ambiguous LabCore.mqh anchor,
instead of guessing an insertion point.

core/Inputs.mqh is intentionally left to a human/agent: its LAB_ENTRY_<n> sections are
scattered across several non-contiguous blocks whose exact input names feed the generated
fingerprint pipeline (InputSurface_gen.mqh / LockedConstants_gen.mqh). This script reports
every anchor line for the highest existing entry so that step cannot be silently missed,
but it does not edit the file.

Usage:
  powershell -File scripts\new_template_entry.ps1 -EntryNumber 19 -Name MyStrategy -Description "one line"

Still required afterward (unchanged, existing tooling -- not run by this script):
  1. Add the LAB_ENTRY_<N> input group to ea_template\core\Inputs.mqh (see anchors printed below).
  2. Implement Entry_Evaluate() (and Entry_<Name>_Init() if needed) in the new Entry_<Name>.mqh.
  3. Regenerate the fingerprint pipeline: _triage\factory_os\gen_input_surface.py --write and
     gen_locked_constants.py --write.
  4. ea_template\deploy.ps1 -Compile ; ea_template\tests\run_tests.ps1 ; scripts\tpl_regression.ps1
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][int]$EntryNumber,
    [Parameter(Mandatory)][string]$Name,
    [string]$Description = '',
    [string]$TemplateRoot = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $TemplateRoot) { $TemplateRoot = Join-Path $repoRoot 'ea_template' }
. (Join-Path $PSScriptRoot 'lib\new_template_entry.ps1')

$result = New-TemplateEntryScaffold -EntryNumber $EntryNumber -Name $Name -TemplateRoot $TemplateRoot -Description $Description
if (-not $result.Applied) {
    Write-Host "[new-template-entry] REFUSED: $($result.Reason)" -ForegroundColor Red
    exit 1
}

Write-Host "[new-template-entry] wrote $($result.FilesWritten -join ', ')"
Write-Host "[new-template-entry] patched $($result.FilesPatched -join ', ')"
Write-Host ''
Write-Host 'NEXT STEPS (manual, judgment required):'
Write-Host "  1. Add a LAB_ENTRY_$EntryNumber input group to ea_template\core\Inputs.mqh."
if ($result.InputsAnchorLines.Count -gt 0) {
    Write-Host '     Existing highest-numbered entry''s anchors (add a matching block near each):'
    foreach ($a in $result.InputsAnchorLines) { Write-Host "       core\Inputs.mqh:$($a.Line): $($a.Text)" }
} else {
    Write-Host '     (no existing LAB_ENTRY_<n> anchors found in core\Inputs.mqh -- inspect it manually)'
}
Write-Host "  2. Implement Entry_Evaluate() (and Entry_${Name}_Init() if needed) in $($result.FilesWritten[1])."
Write-Host '  3. Regenerate the fingerprint pipeline: _triage\factory_os\gen_input_surface.py --write, gen_locked_constants.py --write.'
Write-Host '  4. ea_template\deploy.ps1 -Compile ; ea_template\tests\run_tests.ps1 ; scripts\tpl_regression.ps1'
exit 0
