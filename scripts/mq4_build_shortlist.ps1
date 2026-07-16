# OVERNIGHT Phase 2 - 091 catalog -> NEVER-TOUCHED momentum build-shortlist.
# Group buildable momentum families by mechanism signature, annotate lab status, rank. ASCII-only.
$cat=Import-Csv 'D:\EA_LAB\_triage\ORDER111_mq4_source_catalog.csv'
$out='D:\EA_LAB\_triage\ORDER111_mq4_BUILD_SHORTLIST.md'
$b=$cat | Where-Object { ($_.rough_family -in 'breakout','trend') -and $_.uses_iCustom -eq 'n' -and $_.already_known -eq 'n' -and $_.mechanism_keywords -ne '' }
function LabStatus($mk){
  $m=$mk.ToLower(); $n=($mk -split '\|').Count
  # genuinely-novel indicators the lab has NEVER tested as a signal: Williams%R, Force, AO, Momentum
  $novel = ($m -match 'iwpr|iforce|iao|imomentum')
  # iMA+iADX = EMATREND family (EMA-cross + EMA200 + ADX gate) = concept CLOSED, 10+ symbols dead
  if(($m -match 'ima') -and ($m -match 'iadx')){ return 'TESTED-DEAD (iMA+iADX = EMATREND family, concept closed 10+ sym)' }
  if($m -eq 'ima'){ return 'TESTED-DEAD (naked MA-cross = EMATREND closed) unless famous EA' }
  if($m -eq 'imacd'){ return 'TESTED (MACD-cross ceiling ~1.16; MacdDiv divergence deployed)' }
  if($m -match 'isar'){ if($novel){ return 'PARTIAL-NOVEL (SAR ~ SuperTrend + untested osc)' } return 'PARTIAL (SAR ~ SuperTrend family, XAU-only)' }
  if(($m -match 'ihighest|ilowest') -and ($m -notmatch 'ima|imacd|irsi')){ return 'TESTED (N-bar breakout = BRK, XAU-only)' }
  if($novel){ return 'NEVER-TOUCHED (uses WPR/Force/AO/Momentum - lab never tested these signals)' }
  if($n -ge 3){ return 'LIGHTLY-TOUCHED (3+ combo of tested indicators)' }
  if($n -eq 2){ return 'LIGHTLY-TOUCHED (2-indicator combo)' }
  return 'review'
}
$groups = $b | Group-Object mechanism_keywords | ForEach-Object {
  $ex = ($_.Group | Sort-Object {[int]$_.copies} -Descending | Select-Object -First 4 -ExpandProperty family_name) -join ', '
  [pscustomobject]@{
    signature=$_.Name; families=$_.Count
    total_copies=(($_.Group | ForEach-Object {[int]$_.copies} | Measure-Object -Sum).Sum)
    lab_status=(LabStatus $_.Name); top_examples=$ex
  }
} | Sort-Object -Property @{Expression='total_copies';Descending=$true}
$L=@()
$L += '# ORDER-111 batch 2 - buildable momentum build-shortlist (overnight Phase 2)'
$L += ''
$L += "From 2,048 families -> **$($b.Count) buildable momentum** (trend/breakout, self-contained, not-yet-known). Grouped by mechanism signature + lab status:"
$L += ''
$L += '| mechanism | #fam | copies | lab status | top examples |'
$L += '|---|---|---|---|---|'
foreach($g in $groups){ $L += ('| `' + $g.signature + '` | ' + $g.families + ' | ' + $g.total_copies + ' | ' + $g.lab_status + ' | ' + $g.top_examples + ' |') }
$L += ''
$L += '## How to read (user decision for 091 build)'
$L += '- **NEVER-TOUCHED (3+ combo)** = build queue #1 (never tested, high novelty). Check top_examples - if you recognize one, thats a good prior.'
$L += '- **TESTED-DEAD (naked iMA)** = skip (EMATREND closed) UNLESS the named EA has logic beyond MA-cross (famous ones like firebird).'
$L += '- **PARTIAL/TESTED** = tested on some homes - build only if aiming a new home.'
$L += '- classic public EA (firebird/tsd/awesome) = real forward-track -> user picks from experience.'
$L | Set-Content $out -Encoding utf8
Write-Host "shortlist -> $out ($($groups.Count) mechanism groups, $($b.Count) buildable families)"
$groups | Select-Object -First 14 families,total_copies,lab_status,signature | Format-Table -Auto | Out-String -Width 170
