$outCsv = 'D:\EA_LAB\_mt5_auto\RSIMOM_MACDDIV_CONFIRM_SWEEPS.csv'
'Sweep,Expert,Symbol,Period,Window,SetName,PF,Trades,DDpct,Net,RF' | Set-Content $outCsv

$files1 = Get-ChildItem 'D:\EA_LAB\_mt5_auto\reports\CONF_S1_*.htm' | Sort-Object Name
foreach ($f in $files1) {
  if ($f.Name -match '^CONF_S1_(MDX_F\d+_S\d+_G\d+)_GBPUSD_D1_(MAIN|BWD)\.htm$') {
    $setName = $Matches[1]; $window = $Matches[2]
    $r = D:\EA_LAB\scripts\parse_htm.ps1 -Path $f.FullName | Out-String
    $pf = [regex]::Match($r,'PF\s*:\s*([\-\d.]+)').Groups[1].Value
    $tr = [regex]::Match($r,'Trades\s*:\s*(\d+)').Groups[1].Value
    $dd = [regex]::Match($r,'DDpct\s*:\s*([\-\d.]+)').Groups[1].Value
    $net= [regex]::Match($r,'Net\s*:\s*([\-\d.]+)').Groups[1].Value
    $rf = [regex]::Match($r,'RF\s*:\s*([\-\d.]+)').Groups[1].Value
    "S1,MacdDiv_Naked,GBPUSD,D1,$window,$setName,$pf,$tr,$dd,$net,$rf" | Add-Content $outCsv
  }
}

$files2 = Get-ChildItem 'D:\EA_LAB\_mt5_auto\reports\CONF_S2_*.htm' | Sort-Object Name
foreach ($f in $files2) {
  if ($f.Name -match '^CONF_S2_(RSIMOM_P\d+_L\d+)_XAUUSD_(H4|H1)_(MAIN|BWD)\.htm$') {
    $setName = $Matches[1]; $tf = $Matches[2]; $window = $Matches[3]
    $r = D:\EA_LAB\scripts\parse_htm.ps1 -Path $f.FullName | Out-String
    $pf = [regex]::Match($r,'PF\s*:\s*([\-\d.]+)').Groups[1].Value
    $tr = [regex]::Match($r,'Trades\s*:\s*(\d+)').Groups[1].Value
    $dd = [regex]::Match($r,'DDpct\s*:\s*([\-\d.]+)').Groups[1].Value
    $net= [regex]::Match($r,'Net\s*:\s*([\-\d.]+)').Groups[1].Value
    $rf = [regex]::Match($r,'RF\s*:\s*([\-\d.]+)').Groups[1].Value
    "S2,RsiMomentum_Naked,XAUUSD,$tf,$window,$setName,$pf,$tr,$dd,$net,$rf" | Add-Content $outCsv
  }
}
(Get-Content $outCsv | Measure-Object -Line).Lines
