# ORDER-091/111 batch 2 — deterministic .mq4 SOURCE catalog (mirror the .mq5 catalog schema).
# Reads every .mq4 under D:\Forex, dedupes by content hash into families, classifies mechanism.
# Overnight-safe: per-file try/catch, progress log every 250 files, atomic CSV write at end.
# Python embed is broken -> PowerShell. Cross-refs .mq5 catalog for already_known.
$ErrorActionPreference='Continue'
$root='D:\Forex'
$outCsv='D:\EA_LAB\_triage\ORDER111_mq4_source_catalog.csv'
$log='D:\EA_LAB\_triage\ORDER111_mq4_catalog.log'
$mq5cat='D:\EA_LAB\_triage\ORDER111_mq5_source_catalog.csv'
"[$(Get-Date -f o)] START mq4 catalog scan of $root" | Set-Content $log

# known families from the .mq5 catalog (for already_known cross-ref)
$known=@{}
if(Test-Path $mq5cat){ try{ Import-Csv $mq5cat | ForEach-Object { $k=($_.family_name).ToLower().Trim(); if($k){$known[$k]=$true} } }catch{} }

function Normalize-Family([string]$name){
  $n=[IO.Path]::GetFileNameWithoutExtension($name).ToLower()
  $n=$n -replace '[\s_\-\.]*\(?(copy|copie|\d+)\)?$',''      # trailing copy/version
  $n=$n -replace '[_\-\s]*v?\d+([._]\d+)*$',''               # trailing version numbers
  $n=$n -replace '[^a-z0-9]+','_'; $n=$n.Trim('_')
  if(-not $n){ $n='unnamed' }
  return $n
}
# NOTE: "martingale" is BOILERPLATE in this fxDreema-lineage corpus (95% of files emit the
# label even when unused) -> it is NOT used for rough_family; captured separately as has_mart_block.
# rough_family classifies the ENTRY signal (the buildable idea). Real grid needs real grid tokens.
function Classify([string]$txt){
  $t=$txt.ToLower()
  $grid = ($t -match 'grid_distance|gridstep|grid_step|gridsize|lotexponent|lotmultipl|lot_multipl|nextlot')
  $brk  = ($t -match 'donchian|ihighest|ilowest|breakout|prevday|prev_day|breaklevel')
  $osc  = ($t -match 'irsi\s*\(|istochastic\s*\(|icci\s*\(')
  $mr   = ($osc -and ($t -match 'revers|oversold|overbought|fade|counter_trend'))
  $trend= ($t -match 'ima\s*\(|iema\s*\(|imacd\s*\(|iadx\s*\(|isar\s*\(|iichimoku\s*\(|supertrend|ma_cross|macross')
  if($mr){ return 'reversion' }
  if($brk){ return 'breakout' }
  if($osc){ return 'oscillator' }
  if($trend){ return 'trend' }
  if($grid){ return 'grid-mart' }
  return 'other'
}
$indicators='iCustom','iMA','iRSI','iStochastic','iMACD','iADX','iBands','iCCI','iSAR','iIchimoku','iATR','iMomentum','iWPR','iForce','iAO','iAlligator'

$files = Get-ChildItem -Path $root -Filter *.mq4 -Recurse -File -ErrorAction SilentlyContinue
"[$(Get-Date -f o)] found $($files.Count) .mq4 files" | Add-Content $log
$fam=@{}   # hash -> family record
$i=0
foreach($f in $files){
  $i++
  if($i % 250 -eq 0){ "[$(Get-Date -f o)] $i / $($files.Count) ... families=$($fam.Count)" | Add-Content $log }
  try{
    $bytes=[IO.File]::ReadAllBytes($f.FullName)
    $md5=[System.Security.Cryptography.MD5]::Create()
    $hash=[BitConverter]::ToString($md5.ComputeHash($bytes)) -replace '-',''
    $md5.Dispose()
    if($fam.ContainsKey($hash)){ $fam[$hash].copies++; continue }
    $txt=[Text.Encoding]::ASCII.GetString($bytes)
    # detect actual indicator CALLS: <name>( — avoids iMA matching inside iMACD
    $inds=@(); foreach($ind in $indicators){ if($txt -match ([regex]::Escape($ind)+'\s*\(')){ $inds+=$ind } }
    $famName=Normalize-Family $f.Name
    $rec=[pscustomobject]@{
      family_name=$famName
      copies=1
      representative_path=$f.FullName
      size_kb=[math]::Round($f.Length/1024,1)
      mechanism_keywords=($inds -join '|')
      uses_iCustom=$(if($inds -contains 'iCustom'){'y'}else{'n'})
      has_mart_block=$(if($txt.ToLower() -match 'martingal'){'y'}else{'n'})
      rough_family=Classify $txt
      already_known=$(if($known.ContainsKey($famName)){'y'}else{'n'})
    }
    $fam[$hash]=$rec
  }catch{ "[$(Get-Date -f o)] ERR $($f.FullName): $_" | Add-Content $log }
}
$rows=$fam.Values | Sort-Object -Property @{Expression='copies';Descending=$true},family_name
$tmp="$outCsv.tmp"
$rows | Export-Csv $tmp -NoTypeInformation -Encoding utf8
Move-Item -Force $tmp $outCsv
# summary
$byFam = $rows | Group-Object rough_family | Sort-Object Count -Descending | ForEach-Object { "$($_.Name)=$($_.Count)" }
"[$(Get-Date -f o)] DONE. files=$($files.Count) unique_families=$($rows.Count) -> $outCsv" | Add-Content $log
"[$(Get-Date -f o)] by rough_family: $($byFam -join ' · ')" | Add-Content $log
"[$(Get-Date -f o)] already_known(y)=$(($rows|Where-Object already_known -eq 'y').Count) uses_iCustom(y)=$(($rows|Where-Object uses_iCustom -eq 'y').Count)" | Add-Content $log
Write-Host "DONE: $($rows.Count) unique families from $($files.Count) files -> $outCsv"
