<#
Scaffold the mechanical wiring for a new EA Template entry (LAB_ENTRY_<N>): a
Boss_<N>_<Name>.mq5 wrapper, a core/entries/Entry_<Name>.mqh skeleton, and the two
core/LabCore.mqh #ifdef LAB_ENTRY_<N> touch points (entry-select include + OnInit call).
Refuses on any entry-number/name collision, or a missing/ambiguous LabCore.mqh anchor,
instead of guessing an insertion point.

core/Inputs.mqh is patched only at the two generic mechanical seams the library can validate:
the LAB_ENTRY fallback chain and the mandatory StackMode/StackConfirm block. Strategy-specific
inputs remain a human/agent step because their names and semantics feed the fingerprint pipeline.
StackMode and StackConfirm are required CLI arguments; the scaffold never guesses risk/stacking
semantics.

Usage:
  powershell -File scripts\new_template_entry.ps1 -EntryNumber 19 -Name MyStrategy -StackMode STACK_SINGLE -StackConfirm CONF_DISTANCE -Description "one line"

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
    [Parameter(Mandatory)][string]$StackMode,
    [Parameter(Mandatory)][string]$StackConfirm,
    [string]$Description = '',
    [string]$TemplateRoot = ''
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $TemplateRoot) { $TemplateRoot = Join-Path $repoRoot 'ea_template' }
. (Join-Path $PSScriptRoot 'lib\new_template_entry.ps1')

$result = New-TemplateEntryScaffold -EntryNumber $EntryNumber -Name $Name -TemplateRoot $TemplateRoot -StackMode $StackMode -StackConfirm $StackConfirm -Description $Description
if (-not $result.Applied) {
    Write-Host "[new-template-entry] REFUSED: $($result.Reason)" -ForegroundColor Red
    exit 1
}

Write-Host "[new-template-entry] wrote $($result.FilesWritten -join ', ')"
Write-Host "[new-template-entry] patched $($result.FilesPatched -join ', ')"
Write-Host ''
Write-Host 'NEXT STEPS (manual, judgment required):'
Write-Host "  1. Add the strategy-specific LAB_ENTRY_$EntryNumber input group to ea_template\core\Inputs.mqh; fallback + StackMode/StackConfirm are already scaffolded."
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
