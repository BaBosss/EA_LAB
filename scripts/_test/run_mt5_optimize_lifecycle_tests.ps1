# ORDER-1707 (E-1): Offline lifecycle & negative-control cage for scripts\mt5_optimize.ps1
# Verifies without launching a live MT5 terminal:
#   C1. Preflight failure (optimize_guard.ps1 refusal or bad surface) aborts BEFORE .opt cache deletion, staging report cleanup, or final INI write.
#   C2. An existing destination report is quarantined (renamed, content kept), never overwritten or deleted (canonical A-F2).
#   C3. Active timeout ($proc.HasExited -eq $false) exits 2 visibly without killing process or publishing partial XML.
#   C4. Non-zero $proc.ExitCode exits 4 and refuses to publish even when a fresh XML exists on disk.
#   C5. Pre-existing / backdated XML report is refused after process exit.
#   C6. Truncated / malformed XML (missing closing </Workbook> or missing Worksheet/Table/Row) is refused and not published.
#   C7. Well-formed XML whose <DocumentProperties><Title> names a foreign tag/expert is refused and not published.
#   C8. Positive control: exited 0 + fresh, size/hash-stable, well-formed SpreadsheetML XML bound to invocation tag is published cleanly.
#   C9. Static safety invariant: scripts\mt5_optimize.ps1 contains zero Stop-Process / taskkill / .Kill() calls and launches with -WindowStyle Hidden.

$ErrorActionPreference = "Stop"
$repoRoot  = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$optScript = Join-Path $repoRoot "scripts\mt5_optimize.ps1"

$passed = 0
$failed = 0

function Assert-Case {
    param([string]$Name, [bool]$Condition, [string]$Detail = "")
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $Name :: $Detail" -ForegroundColor Red
        $script:failed++
    }
}

function New-ValidSpreadsheetMlXml {
    param([string]$TitleTag)
    return @"
<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
 <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">
  <Title>$TitleTag</Title>
 </DocumentProperties>
 <Worksheet ss:Name="Tester Optimizator Results">
  <Table ss:ExpandedColumnCount="8" ss:ExpandedRowCount="3">
   <Row>
    <Cell><Data ss:Type="String">Pass</Data></Cell>
    <Cell><Data ss:Type="String">Result</Data></Cell>
    <Cell><Data ss:Type="String">Profit</Data></Cell>
    <Cell><Data ss:Type="String">Expected Payoff</Data></Cell>
    <Cell><Data ss:Type="String">Profit Factor</Data></Cell>
    <Cell><Data ss:Type="String">Recovery Factor</Data></Cell>
    <Cell><Data ss:Type="String">Sharpe Ratio</Data></Cell>
    <Cell><Data ss:Type="String">_0_FastMA</Data></Cell>
   </Row>
   <Row>
    <Cell><Data ss:Type="Number">0</Data></Cell>
    <Cell><Data ss:Type="Number">120.5</Data></Cell>
    <Cell><Data ss:Type="Number">120.5</Data></Cell>
    <Cell><Data ss:Type="Number">12.05</Data></Cell>
    <Cell><Data ss:Type="Number">1.45</Data></Cell>
    <Cell><Data ss:Type="Number">1.80</Data></Cell>
    <Cell><Data ss:Type="Number">1.10</Data></Cell>
    <Cell><Data ss:Type="Number">20</Data></Cell>
   </Row>
  </Table>
 </Worksheet>
</Workbook>
"@
}

$tmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mt5_opt_lifecycle_" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
# Canonical mt5_optimize.ps1 also runs the symbol preflight and the build/config identity gate. These
# synthetic runs supply a capability file and the explicit non-green legacy-identity escape hatch.
$capFile = Join-Path $tmpRoot 'capability.json'
Set-Content -LiteralPath $capFile -Encoding UTF8 -Value '{"symbols":["XAUUSD","AUDNZD"]}'

try {
    Write-Host "=== ORDER-1707 (E-1) mt5_optimize.ps1 Lifecycle & Negative-Control Cage ==="

    $dataDir     = Join-Path $tmpRoot "DataDir"
    $autoDir     = Join-Path $tmpRoot "AutoDir"
    $cacheDir    = Join-Path $dataDir "Tester\cache"
    $decisionLog = Join-Path $tmpRoot "optimize_decisions.jsonl"
    New-Item -ItemType Directory -Force -Path $cacheDir, (Join-Path $autoDir "optimizations"), (Join-Path $autoDir "ini") | Out-Null

    $validSet = Join-Path $tmpRoot "valid_synth.set"
    @(
        "_0_FastMA=20||19||1||21||Y"
        "_9_MaxLevels=3||3||1||5||N"
        "_32_SL_Money=250.0||250.0||50.0||500.0||N"
    ) | Set-Content -Path $validSet -Encoding ASCII

    # Sweeping safety parameter _9_MaxLevels triggers optimize_guard.ps1 refusal (exit 3)
    $badGuardSet = Join-Path $tmpRoot "bad_guard_safety_sweep.set"
    @(
        "_9_MaxLevels=3||2||1||6||Y"
    ) | Set-Content -Path $badGuardSet -Encoding ASCII

    # --- C1: Preflight failure (optimize_guard refusal) aborts BEFORE .opt cache delete or final INI write ---
    $canaryOpt = Join-Path $cacheDir "SyntheticOptEA_canary.opt"
    "CANARY_OPT_BYTES" | Set-Content -Path $canaryOpt -Encoding ASCII
    $tagC1 = "TAG_C1_PREFLIGHT_FAIL"
    $iniC1 = Join-Path $autoDir "ini\${tagC1}.ini"
    $stgC1 = Join-Path $dataDir "${tagC1}_leftover.xml"
    "LEFTOVER_STAGING" | Set-Content -Path $stgC1 -Encoding ASCII

    $outC1 = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$badGuardSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC1' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog'
        exit `$LASTEXITCODE
    " 2>&1
    $codeC1 = $LASTEXITCODE
    Assert-Case "C1.a preflight failure aborts before launch (exit 3)" ($codeC1 -eq 3) "exit=$codeC1 out=$($outC1 -join ' ')"
    Assert-Case "C1.b .opt cache preserved on preflight failure" (Test-Path -LiteralPath $canaryOpt)
    Assert-Case "C1.c DataDir report staging file preserved on preflight failure" (Test-Path -LiteralPath $stgC1)
    Assert-Case "C1.d final ini/<ReportName>.ini NOT written on preflight failure" (-not (Test-Path -LiteralPath $iniC1))

    # --- C2: Existing destination is QUARANTINED (canonical A-F2), never overwritten or deleted; mock run, no MT5 ---
    $tagC2  = "TAG_C2_DEST_EXISTS"
    $destC2 = Join-Path $autoDir "optimizations\$tagC2.xml"
    "ORIGINAL_DEST_CONTENT" | Set-Content -Path $destC2 -Encoding UTF8
    $outC2 = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$validSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -TimeoutSec 5 -XmlFlushGraceSec 0 -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC2' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog' -MockProcessRunner {
            param(`$ini, `$srcXml, `$repName)
            return [pscustomobject]@{ Id = 91002; HasExited = `$true; ExitCode = 0 }
        }
        exit `$LASTEXITCODE
    " 2>&1
    $codeC2 = $LASTEXITCODE
    $quarC2 = @(Get-ChildItem -LiteralPath (Split-Path $destC2) -Filter "$tagC2.xml.superseded-*" -File)
    Assert-Case "C2.a existing destination quarantined and announced (STALE DEST XML)" (($outC2 -join " ") -match "STALE DEST XML") "exit=$codeC2 out=$($outC2 -join ' ')"
    Assert-Case "C2.b quarantined copy keeps the original content" ($quarC2.Count -eq 1 -and ((Get-Content -LiteralPath $quarC2[0].FullName -Raw).Trim()) -eq "ORIGINAL_DEST_CONTENT")
    Assert-Case "C2.c run without XML closes NO-XML (exit 4) and the destination is absent" ($codeC2 -eq 4 -and -not (Test-Path -LiteralPath $destC2)) "exit=$codeC2"
    # --- C3: Active timeout ($proc.HasExited = $false) exits 2 without killing or publishing ---
    $tagC3  = "TAG_C3_ACTIVE_TIMEOUT"
    $destC3 = Join-Path $autoDir "optimizations\$tagC3.xml"
    $fixC3  = Join-Path $tmpRoot "fix_$tagC3.xml"
    (New-ValidSpreadsheetMlXml -TitleTag $tagC3) | Set-Content -LiteralPath $fixC3 -Encoding UTF8
    $outC3 = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$validSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -TimeoutSec 1 -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC3' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog' -MockProcessRunner {
            param(`$ini, `$srcXml, `$repName)
            Copy-Item -LiteralPath '$fixC3' -Destination `$srcXml -Force
            return [pscustomobject]@{ Id = 91003; HasExited = `$false; ExitCode = 0 }
        }
        exit `$LASTEXITCODE
    " 2>&1
    $codeC3 = $LASTEXITCODE
    Assert-Case "C3.a active timeout returns exit code 2" ($codeC3 -eq 2 -and ($outC3 -join " ") -match "ABORT TIMEOUT") "exit=$codeC3 out=$($outC3 -join ' ')"
    Assert-Case "C3.b active timeout does NOT publish XML to optimizations/" (-not (Test-Path -LiteralPath $destC3))

    # --- C4: Non-zero $proc.ExitCode refused even when valid fresh XML exists ---
    $tagC4  = "TAG_C4_NONZERO_EXIT"
    $destC4 = Join-Path $autoDir "optimizations\$tagC4.xml"
    $fixC4  = Join-Path $tmpRoot "fix_$tagC4.xml"
    (New-ValidSpreadsheetMlXml -TitleTag $tagC4) | Set-Content -LiteralPath $fixC4 -Encoding UTF8
    $outC4 = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$validSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -TimeoutSec 5 -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC4' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog' -MockProcessRunner {
            param(`$ini, `$srcXml, `$repName)
            Copy-Item -LiteralPath '$fixC4' -Destination `$srcXml -Force
            return [pscustomobject]@{ Id = 91004; HasExited = `$true; ExitCode = 7 }
        }
        exit `$LASTEXITCODE
    " 2>&1
    $codeC4 = $LASTEXITCODE
    Assert-Case "C4.a non-zero ExitCode fails with exit 4" ($codeC4 -eq 4 -and ($outC4 -join " ") -match "ABORT EXITCODE") "exit=$codeC4"
    Assert-Case "C4.b non-zero ExitCode does NOT publish XML" (-not (Test-Path -LiteralPath $destC4))

    # --- C5: Pre-existing / backdated stale XML refused ---
    $tagC5  = "TAG_C5_STALE_XML"
    $destC5 = Join-Path $autoDir "optimizations\$tagC5.xml"
    $fixC5  = Join-Path $tmpRoot "fix_$tagC5.xml"
    (New-ValidSpreadsheetMlXml -TitleTag $tagC5) | Set-Content -LiteralPath $fixC5 -Encoding UTF8
    $outC5 = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$validSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -TimeoutSec 5 -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC5' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog' -MockProcessRunner {
            param(`$ini, `$srcXml, `$repName)
            Copy-Item -LiteralPath '$fixC5' -Destination `$srcXml -Force
            (Get-Item -LiteralPath `$srcXml).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddMinutes(-10)
            return [pscustomobject]@{ Id = 91005; HasExited = `$true; ExitCode = 0 }
        }
        exit `$LASTEXITCODE
    " 2>&1
    $codeC5 = $LASTEXITCODE
    Assert-Case "C5.a backdated stale XML fails verification" ($codeC5 -eq 4 -and ($outC5 -join " ") -match "predates invocation start") "exit=$codeC5 out=$($outC5 -join ' ')"
    Assert-Case "C5.b backdated stale XML is NOT published" (-not (Test-Path -LiteralPath $destC5))

    # --- C6: Truncated XML (missing </Workbook> / incomplete structure) refused ---
    $tagC6  = "TAG_C6_TRUNCATED_XML"
    $destC6 = Join-Path $autoDir "optimizations\$tagC6.xml"
    $fixC6  = Join-Path $tmpRoot "fix_$tagC6.xml"
    "<Workbook><Worksheet><Table><Row><Cell><Data>Pass</Data></Cell></Row>" | Set-Content -LiteralPath $fixC6 -Encoding UTF8
    $outC6 = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$validSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -TimeoutSec 5 -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC6' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog' -MockProcessRunner {
            param(`$ini, `$srcXml, `$repName)
            Copy-Item -LiteralPath '$fixC6' -Destination `$srcXml -Force
            return [pscustomobject]@{ Id = 91006; HasExited = `$true; ExitCode = 0 }
        }
        exit `$LASTEXITCODE
    " 2>&1
    $codeC6 = $LASTEXITCODE
    Assert-Case "C6.a truncated XML fails with INVALID XML" ($codeC6 -eq 4 -and ($outC6 -join " ") -match "does not end with a closing </Workbook>") "exit=$codeC6 out=$($outC6 -join ' ')"
    Assert-Case "C6.b truncated XML is NOT published" (-not (Test-Path -LiteralPath $destC6))

    # --- C7: Foreign <Title> tag mismatch refused ---
    $tagC7  = "TAG_C7_TITLE_MISMATCH"
    $destC7 = Join-Path $autoDir "optimizations\$tagC7.xml"
    $fixC7  = Join-Path $tmpRoot "fix_$tagC7.xml"
    (New-ValidSpreadsheetMlXml -TitleTag "FOREIGN_UNRELATED_TAG_999") | Set-Content -LiteralPath $fixC7 -Encoding UTF8
    $outC7 = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$validSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -TimeoutSec 5 -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC7' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog' -MockProcessRunner {
            param(`$ini, `$srcXml, `$repName)
            Copy-Item -LiteralPath '$fixC7' -Destination `$srcXml -Force
            return [pscustomobject]@{ Id = 91007; HasExited = `$true; ExitCode = 0 }
        }
        exit `$LASTEXITCODE
    " 2>&1
    $codeC7 = $LASTEXITCODE
    Assert-Case "C7.a foreign Title XML fails with INVALID XML" ($codeC7 -eq 4 -and ($outC7 -join " ") -match "does not match ReportName") "exit=$codeC7 out=$($outC7 -join ' ')"
    Assert-Case "C7.b foreign Title XML is NOT published" (-not (Test-Path -LiteralPath $destC7))

    # --- C8: Positive control (fresh, stable, well-formed SpreadsheetML XML bound to tag) ---
    $tagC8  = "TAG_C8_VALID_PUBLISH"
    $destC8 = Join-Path $autoDir "optimizations\$tagC8.xml"
    $fixC8  = Join-Path $tmpRoot "fix_$tagC8.xml"
    (New-ValidSpreadsheetMlXml -TitleTag $tagC8) | Set-Content -LiteralPath $fixC8 -Encoding UTF8
    $outC8 = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$validSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -TimeoutSec 5 -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC8' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog' -MockProcessRunner {
            param(`$ini, `$srcXml, `$repName)
            Copy-Item -LiteralPath '$fixC8' -Destination `$srcXml -Force
            return [pscustomobject]@{ Id = 91008; HasExited = `$true; ExitCode = 0 }
        }
        exit `$LASTEXITCODE
    " 2>&1
    $codeC8 = $LASTEXITCODE
    Assert-Case "C8.a valid invocation exits 0" ($codeC8 -eq 0 -and ($outC8 -join " ") -match "OK OPTIMIZER XML") "exit=$codeC8 out=$($outC8 -join ' ')"
    Assert-Case "C8.b valid XML published to optimizations/" (Test-Path -LiteralPath $destC8)

    # --- C11: structurally wrong XML that is fresh, stable and closed by </Workbook> is refused (GPT review of 9f5bc206) ---
    $validC11 = New-ValidSpreadsheetMlXml -TitleTag "TAG_C11"
    $c11Cases = @(
        @{ Tag = "TAG_C11_NO_TITLE";     Expect = "no DocumentProperties/Title"; Xml = ($validC11 -replace '(?s)\s*<DocumentProperties.*?</DocumentProperties>', '') }
        @{ Tag = "TAG_C11_BLANK_TITLE";  Expect = "no DocumentProperties/Title"; Xml = ($validC11 -replace '<Title>TAG_C11</Title>', '<Title>  </Title>') }
        @{ Tag = "TAG_C11_LOOSE_ROWS";   Expect = "Incomplete SpreadsheetML structure"; Xml = '<?xml version="1.0"?><Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"><DocumentProperties xmlns="urn:schemas-microsoft-com:office:office"><Title>TAG_C11_LOOSE_ROWS</Title></DocumentProperties><Worksheet/><Table/><Row/><Row/></Workbook>' }
        @{ Tag = "TAG_C11_NO_NAMESPACE"; Expect = "not in the SpreadsheetML namespace"; Xml = ($validC11 -replace 'xmlns="urn:schemas-microsoft-com:office:spreadsheet"', '') }
    )
    foreach ($case in $c11Cases) {
        $tag  = $case.Tag
        $dest = Join-Path $autoDir "optimizations\$tag.xml"
        $fix  = Join-Path $tmpRoot "fix_$tag.xml"
        ($case.Xml -replace 'TAG_C11(?=</Title>)', $tag) | Set-Content -LiteralPath $fix -Encoding UTF8
        $out = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
            & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$validSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -TimeoutSec 5 -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tag' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog' -MockProcessRunner {
                param(`$ini, `$srcXml, `$repName)
                Copy-Item -LiteralPath '$fix' -Destination `$srcXml -Force
                return [pscustomobject]@{ Id = 91011; HasExited = `$true; ExitCode = 0 }
            }
            exit `$LASTEXITCODE
        " 2>&1
        $code = $LASTEXITCODE
        Assert-Case "C11 $tag refused with INVALID XML (exit 4)" ($code -eq 4 -and ($out -join " ") -match [regex]::Escape($case.Expect)) "exit=$code out=$($out -join ' ')"
        Assert-Case "C11 $tag is NOT published" (-not (Test-Path -LiteralPath $dest))
    }

    # --- C9: Static source checks on scripts\mt5_optimize.ps1 ---
    $srcText = Get-Content -LiteralPath $optScript -Raw
    Assert-Case "C9.a mt5_optimize.ps1 uses -WindowStyle Hidden" ($srcText -match "-WindowStyle\s+Hidden")
    Assert-Case "C9.b mt5_optimize.ps1 contains zero process-kill calls" ($srcText -notmatch "Stop-Process|taskkill|\.Kill\(")

    # --- C10: R3-3 Template wrapper preset coverage preflight (count-matching wrong/duplicate key refused before cache/INI touch) ---
    $baseSet16 = Join-Path $repoRoot "ea_template\sets\regression\Boss_16_KangarooGrid_defaults.set"
    $badKeySet16 = Join-Path $tmpRoot "Boss_16_wrong_key_same_count.set"
    $dupKeySet16 = Join-Path $tmpRoot "Boss_16_dup_key_same_count.set"
    $raw16Lines = Get-Content -LiteralPath $baseSet16
    # Replace one valid key with a bogus key while keeping the exact same declared count
    $wrongLines = $raw16Lines | ForEach-Object {
        if ($_ -match '^_9_StepPoints=') { '_9_BogusNonExistentKey=300.0' } else { $_ }
    }
    $wrongLines | Set-Content -LiteralPath $badKeySet16 -Encoding ASCII
    # Replace one valid key with a duplicate of ExitMode while keeping the exact same line count
    $dupLines = $raw16Lines | ForEach-Object {
        if ($_ -match '^_9_StepPoints=') { 'ExitMode=22' } else { $_ }
    }
    $dupLines | Set-Content -LiteralPath $dupKeySet16 -Encoding ASCII

    $canaryOpt16 = Join-Path $cacheDir "Boss_16_KangarooGrid_canary.opt"
    "CANARY_OPT_16" | Set-Content -LiteralPath $canaryOpt16 -Encoding ASCII
    $tagC10a = "TAG_C10A_WRONG_KEY"
    $iniC10a = Join-Path $autoDir "ini\${tagC10a}.ini"
    $stgC10a = Join-Path $dataDir "${tagC10a}_leftover.xml"
    "LEFTOVER_STAGING_10A" | Set-Content -LiteralPath $stgC10a -Encoding ASCII

    $outC10a = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'EALabTpl\Boss_16_KangarooGrid' -SetFile '$badKeySet16' -Symbol 'AUDNZD' -Period 'M15' -FromDate '2023.01.01' -ToDate '2025.01.01' -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC10a' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog'
        exit `$LASTEXITCODE
    " 2>&1
    $codeC10a = $LASTEXITCODE
    Assert-Case "C10.a count-matching wrong key in template preset refused by check_template_presets.py (exit 2)" (
        ($codeC10a -eq 2) -and (($outC10a -join " ") -match "check_template_presets\.py refused")
    ) "exit=$codeC10a out=$($outC10a -join ' ')"
    Assert-Case "C10.b .opt cache, staging XML, and final INI untouched on wrong-key template refusal" (
        (Test-Path -LiteralPath $canaryOpt16) -and (Test-Path -LiteralPath $stgC10a) -and (-not (Test-Path -LiteralPath $iniC10a))
    )

    $tagC10b = "TAG_C10B_DUP_KEY"
    $iniC10b = Join-Path $autoDir "ini\${tagC10b}.ini"
    $outC10b = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'EALabTpl\Boss_16_KangarooGrid' -SetFile '$dupKeySet16' -Symbol 'AUDNZD' -Period 'M15' -FromDate '2023.01.01' -ToDate '2025.01.01' -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC10b' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog'
        exit `$LASTEXITCODE
    " 2>&1
    $codeC10b = $LASTEXITCODE
    Assert-Case "C10.c count-matching duplicate key in template preset refused before cache/INI touch (exit 2)" (
        ($codeC10b -eq 2) -and (Test-Path -LiteralPath $canaryOpt16) -and (-not (Test-Path -LiteralPath $iniC10b))
    ) "exit=$codeC10b"

    # --- C11: R3-3 UTF-16LE SpreadsheetML XML report positive control ---
    $tagC11  = "TAG_C11_UTF16_XML"
    $destC11 = Join-Path $autoDir "optimizations\${tagC11}.xml"
    $fixC11  = Join-Path $tmpRoot "fix_${tagC11}.xml"
    [System.IO.File]::WriteAllText($fixC11, (New-ValidSpreadsheetMlXml -TitleTag $tagC11), [System.Text.Encoding]::Unicode)

    $outC11 = & powershell -NoProfile -ExecutionPolicy Bypass -Command "
        & '$optScript' -Expert 'TestPkg\SyntheticOptEA' -SetFile '$validSet' -Symbol 'XAUUSD' -Period 'H1' -FromDate '2023.01.01' -ToDate '2025.01.01' -TimeoutSec 5 -Terminal '$env:SystemRoot\System32\hostname.exe' -CapabilityFile '$capFile' -AllowLegacyIdentity -ReportName '$tagC11' -DataDir '$dataDir' -AutoDir '$autoDir' -DecisionLogPath '$decisionLog' -MockProcessRunner {
            param(`$ini, `$srcXml, `$repName)
            Copy-Item -LiteralPath '$fixC11' -Destination `$srcXml -Force
            (Get-Item -LiteralPath `$srcXml).LastWriteTime = Get-Date
            return [pscustomobject]@{ Id = 99906; HasExited = `$true; ExitCode = 0 }
        }
        exit `$LASTEXITCODE
    " 2>&1
    $codeC11 = $LASTEXITCODE
    Assert-Case "C11.a valid UTF-16LE SpreadsheetML XML report accepted (exit 0) and published" (
        ($codeC11 -eq 0) -and (($outC11 -join " ") -match "OK OPTIMIZER XML") -and (Test-Path -LiteralPath $destC11)
    ) "exit=$codeC11 out=$($outC11 -join ' ')"
} finally {
    Remove-Item -LiteralPath $tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=== Summary: $passed passed, $failed failed ==="
if ($failed -gt 0) { exit 1 }
exit 0
