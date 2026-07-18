$ErrorActionPreference = "Stop"

# ---- Sweep 1: MacdDiv_Naked GBPUSD D1 ----
$base = Get-Content 'D:\EA_LAB\_mt5_auto\ab_sets\order117_gbp\MacdDiv_Naked_GBPUSD_D1_baseline.set'
$outdir1 = 'D:\EA_LAB\_mt5_auto\sweeps\order117_gbp_confirm'
Remove-Item "$outdir1\*" -Force -ErrorAction SilentlyContinue
$names1 = @()
foreach ($fast in 8,12,16) {
  foreach ($slow in 21,26,34) {
    if ($fast -ge $slow) { continue }
    foreach ($sig in 7,9) {
      $name = "MDX_F${fast}_S${slow}_G${sig}"
      $new = $base | ForEach-Object {
        if ($_ -match '^_02_MacdFast=') { "_02_MacdFast=$fast" }
        elseif ($_ -match '^_02_MacdSlow=') { "_02_MacdSlow=$slow" }
        elseif ($_ -match '^_02_MacdSignal=') { "_02_MacdSignal=$sig" }
        else { $_ }
      }
      $setPath = Join-Path $outdir1 "$name.set"
      $new | Set-Content $setPath
      $names1 += $name
    }
  }
}
$names1 | Set-Content (Join-Path $outdir1 "_names.txt")
Write-Output "Sweep1 count=$($names1.Count) files=$((Get-ChildItem $outdir1 -Filter '*.set').Count)"

# ---- Sweep 2: RsiMomentum_Naked XAU ----
$outdir2 = 'D:\EA_LAB\_mt5_auto\sweeps\rsimom_xau_confirm'
Remove-Item "$outdir2\*" -Force -ErrorAction SilentlyContinue
$names2 = @()
foreach ($per in 9,14,21) {
  foreach ($lvl in 45,50,55) {
    $name = "RSIMOM_P${per}_L${lvl}"
    $setPath = Join-Path $outdir2 "$name.set"
    @(
      "_01_RsiMode=1",
      "_01_RsiPeriod=$per",
      "_01_Level=$lvl",
      "_06_AllowLive=false"
    ) | Set-Content $setPath
    $names2 += $name
  }
}
$names2 | Set-Content (Join-Path $outdir2 "_names.txt")
Write-Output "Sweep2 count=$($names2.Count) files=$((Get-ChildItem $outdir2 -Filter '*.set').Count)"
