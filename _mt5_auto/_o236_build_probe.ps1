$base = 'D:\EA_LAB\ea_template\sets\B14_AB_off.set'
$dir  = 'D:\EA_LAB\_mt5_auto\ab_sets\o236_probe'

# P_SC1
$c = Get-Content $base; $c = $c -replace '^StackConfirm=.*', 'StackConfirm=1'; $c | Set-Content "$dir\P_SC1.set" -Encoding UTF8

# P_SC2
$c = Get-Content $base; $c = $c -replace '^StackConfirm=.*', 'StackConfirm=2'; $c | Set-Content "$dir\P_SC2.set" -Encoding UTF8

# P_SC3
$c = Get-Content $base; $c = $c -replace '^StackConfirm=.*', 'StackConfirm=3'; $c | Set-Content "$dir\P_SC3.set" -Encoding UTF8

# P_SC4
$c = Get-Content $base; $c = $c -replace '^StackConfirm=.*', 'StackConfirm=4'; $c | Set-Content "$dir\P_SC4.set" -Encoding UTF8

# P_SC4_BR0p50
$c = Get-Content $base; $c = $c -replace '^StackConfirm=.*', 'StackConfirm=4'; $c += '_9_PA_MinBodyRatio=0.5'; $c | Set-Content "$dir\P_SC4_BR0p50.set" -Encoding UTF8

# P_SC4_BR0p75
$c = Get-Content $base; $c = $c -replace '^StackConfirm=.*', 'StackConfirm=4'; $c += '_9_PA_MinBodyRatio=0.75'; $c | Set-Content "$dir\P_SC4_BR0p75.set" -Encoding UTF8

# P_SC4_BR1p50
$c = Get-Content $base; $c = $c -replace '^StackConfirm=.*', 'StackConfirm=4'; $c += '_9_PA_MinBodyRatio=1.5'; $c | Set-Content "$dir\P_SC4_BR1p50.set" -Encoding UTF8

# P_SC4_BR2p00
$c = Get-Content $base; $c = $c -replace '^StackConfirm=.*', 'StackConfirm=4'; $c += '_9_PA_MinBodyRatio=2.0'; $c | Set-Content "$dir\P_SC4_BR2p00.set" -Encoding UTF8

# P_RM1
$c = Get-Content $base; $c += '_9_RegimeGateAdds=true'; $c += '_50_RegimeMode=1'; $c | Set-Content "$dir\P_RM1.set" -Encoding UTF8

# P_RM2
$c = Get-Content $base; $c += '_9_RegimeGateAdds=true'; $c += '_50_RegimeMode=2'; $c | Set-Content "$dir\P_RM2.set" -Encoding UTF8

# P_RM1_NoDown
$c = Get-Content $base; $c += '_9_RegimeGateAdds=true'; $c += '_50_RegimeMode=1'; $c += '_50_AllowTrendDown=false'; $c | Set-Content "$dir\P_RM1_NoDown.set" -Encoding UTF8

Write-Output 'ALL FILES CREATED'
Get-ChildItem $dir | Select-Object Name, Length