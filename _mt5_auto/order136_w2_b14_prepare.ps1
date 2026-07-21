$ErrorActionPreference = 'Stop'
$basePath = 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_GBPJPY_ISpick.set'
$outDir = 'D:\EA_LAB\_mt5_auto\ab_sets\order136_w2_b14'
New-Item -ItemType Directory -Force $outDir | Out-Null
$base = Get-Content -Encoding ASCII $basePath
foreach ($variant in @(@{Name='BASE'; Lot='50'}, @{Name='LOG13'; Lot='55'})) {
  $lines = $base | ForEach-Object {
    if ($_ -match '^LotProg=') { "LotProg=$($variant.Lot)" }
    elseif ($_ -match '^_0_Magic=') { '_0_Magic=990218' }
    else { $_ }
  }
  if ($variant.Lot -eq '50') {
    $lines = $lines | ForEach-Object {
      if ($_ -match '^_55_LogPowerFactor=') { '_55_LogPowerFactor=1.3' } else { $_ }
    }
  }
  $path = Join-Path $outDir "O136_W2_B14_GJ_$($variant.Name).set"
  $lines | Set-Content -Encoding ASCII $path
  Write-Output $path
}
