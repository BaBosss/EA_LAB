$base = Get-Content 'D:\EA_LAB\ea_template\sets\Boss14_GridLog_GBPJPY_ISpick.set'
$dists = @('1.5','2.0','2.5')
$tps = @('150','250','400')
foreach ($d in $dists) {
  foreach ($tp in $tps) {
    $out = $base | ForEach-Object {
      if ($_ -match '^_14_DistAtrMult=') { "_14_DistAtrMult=$d" }
      elseif ($_ -match '^_2_BasketTP_Money=') { "_2_BasketTP_Money=$tp" }
      elseif ($_ -match '^_0_Magic=') { "_0_Magic=990201" }
      else { $_ }
    }
    $name = "EC_d${d}_tp${tp}.set"
    $path = "D:\EA_LAB\_mt5_auto\ab_sets\order095_eurchf\$name"
    $out | Set-Content -Path $path -Encoding ASCII
    Write-Output $path
  }
}
