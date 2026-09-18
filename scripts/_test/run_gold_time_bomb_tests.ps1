<#
DF02 deterministic author checks. No terminal/tester/deploy invocation.
Executes the actual numeric MQL kernel and the MQL test cases via a small C#
syntax adapter; this is not evidence of MQL runtime or broker execution parity.
Optional MetaEditor compilation uses a unique temporary source copy only.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [string]$ParentSource = 'D:\EA_LAB_CONTROL\evidence\strategy-source-recovery-20260915-r1\capture\sources\BOSS_CUSTOM\(Boss) Gold Robot Scalping Time Bomb\(Boss) Gold Robot Scalping Time Bomb rev1.mq5',
    [switch]$Compile,
    [string]$MetaEditor = 'D:\Meta 5\metaeditor64.exe'
)
$ErrorActionPreference = 'Stop'
if (!$RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }
$expected = '795c446093bc0ef888bad84f162646f94d303831e8becf10955d7e016ed1f93c'
$sha = [Security.Cryptography.SHA256]::Create()
try { $actual = ([BitConverter]::ToString($sha.ComputeHash([IO.File]::ReadAllBytes($ParentSource)))).Replace('-', '').ToLowerInvariant() }
finally { $sha.Dispose() }
if ($actual -ne $expected) { throw "Frozen parent SHA mismatch: $actual" }
Write-Host "[PASS] parent $actual :: $ParentSource"
$entry = [IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/core/entries/Entry_GoldTimeBomb.mqh'))
$tests = [IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/tests/GoldTimeBomb_Test.mq5'))
function Region([string]$text, [string]$name) {
    $m = [regex]::Match($text, '(?s)// BEGIN ' + $name + '\r?\n(.*?)// END ' + $name)
    if (!$m.Success) { throw "Missing exact test seam: $name" }
    return $m.Groups[1].Value
}
$kernel = Region $entry 'DF02 DETERMINISTIC KERNEL'
$cases = Region $tests 'DF02 TEST CASES'
# Syntax-only lowering: no replacement of function bodies, arithmetic or branches.
$code = $kernel + "`n" + $cases
$code = $code -replace '\bconst\s+', ''
$code = $code -replace '(?m)^struct ', 'public struct '
$code = $code -replace '(?m)^(double|bool|long|int|void) ', 'public static $1 '
$code = $code -replace '(?m)^   (double|bool|long|string|void) ', '   public $1 '
# The previous rule affects struct members only at this stage: remove access
# modifiers from local declarations by tracking brace depth, without parsing math.
$depth = 0
$lines = foreach ($line in ($code -split "`r?`n")) {
    if ($depth -ne 1) { $line = $line -replace '^   public ', '   ' }
    # Top-level functions have depth 1 too: distinguish them from struct members.
    if ($line -match '^public struct ') { $inStruct = $true }
    if (!$inStruct) { $line = $line -replace '^   public ', '   ' }
    $depth += ([regex]::Matches($line, '\{').Count - [regex]::Matches($line, '\}').Count)
    if ($depth -eq 0 -and $line -match '^\}') { $inStruct = $false }
    $line
}
$code = $lines -join "`n"
$code = $code -replace '(?m)^(\s*)(GT_Bomb|GT_Grid|GT_Trail) (\w+);', '$1$2 $3 = new $2();'
$support = @'
public static double MathAbs(double x) { return System.Math.Abs(x); }
public static double MathMax(double a, double b) { return System.Math.Max(a,b); }
public static double MathMin(double a, double b) { return System.Math.Min(a,b); }
public static double MathRound(double x) { return System.Math.Round(x, System.MidpointRounding.AwayFromZero); }
public static bool MathIsValidNumber(double x) { return !double.IsNaN(x) && !double.IsInfinity(x); }
public static void Print(string text) { System.Console.WriteLine(text); }
'@
Add-Type -TypeDefinition ("public class DF02AuthorTests {`n" + $support + $code + "`n}")
$failed = [DF02AuthorTests]::GT_RunTests()
Write-Host "[DF02 KERNEL] $([DF02AuthorTests]::gt_checks) checks, $failed failures (C# syntax adapter; NO_MT5)"
if ($failed) { throw 'DF02 deterministic behavior failure' }

# Verify the production seams not represented by numeric-only tests.
$required = @(
    'PositionsTotal()', 'PositionGetInteger(POSITION_MAGIC) == _20_MagicStart',
    'PositionGetString(POSITION_SYMBOL) == _Symbol',
    'OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, 1.0, tick.ask, margin_one)',
    'AccountInfoDouble(ACCOUNT_MARGIN_FREE)', 'request.sl = 0;', 'request.tp = 0;',
    'GT_PreserveTP(PositionGetDouble(POSITION_TP), 40.0)',
    'iTime(_Symbol, PERIOD_CURRENT, 1)', 'iClose(_Symbol, PERIOD_CURRENT, 0)',
    'ORDER_TIME_DAY : ORDER_TIME_SPECIFIED', 'GT_ExpiryName(result.order)',
    'PositionSelectByTicket(result.order)', 'request.position = ticket;'
)
foreach ($needle in $required) {
    if (!$entry.Contains($needle)) { throw "Missing production seam: $needle" }
}
if ($entry -match '\b(OrdersTotal|Stack_DecideAdd|MM_FirstLot|Recovery_OnTick|RiskControl_CheckDD)\s*\(') {
    throw 'DF02 position gate/lifecycle leaked into pending count or generic chassis'
}
$sequence = '(?s)void GoldTimeBomb_OnTick\(\).*?GT_Expire\(\);.*?GT_Add\(1, true\);.*?GT_Add\(-1, true\);.*?GT_Initial\(1\);.*?GT_Trailing\(\);.*?GT_Initial\(-1\);.*?GT_Add\(1, false\);.*?GT_Add\(-1, false\);'
if ($entry -notmatch $sequence) { throw 'Parent root execution ordering changed' }
Write-Host '[PASS] production seams and source root ordering (structural only)'

. (Join-Path $RepoRoot 'scripts/use_python.ps1')
$env:PYTHONDONTWRITEBYTECODE = '1'
# Independently compare each existing build's active source closure to the exact
# frozen base. Comments and inactive preprocessor branches do not affect behavior.
$closureCheck = @'
import pathlib,posixpath,re,subprocess,sys,functools
root=pathlib.Path(sys.argv[1]); base='1b5ed52fd895d904b1eb3340bfd15619ed7d119a'
@functools.lru_cache(None)
def read(rel,old):
    if old:
        return subprocess.check_output(['git','show',base+':'+rel],cwd=root).decode('utf-8-sig')
    return (root/rel).read_text(encoding='utf-8-sig')
def closure(rel,old,defs):
    stack=[True]; out=[]
    for line in read(rel,old).splitlines():
        t=line.strip()
        m=re.match(r'#(ifdef|ifndef)\s+(\w+)',t)
        if m:
            hit=m[2] in defs
            stack.append(stack[-1] and (hit if m[1]=='ifdef' else not hit)); continue
        if t.startswith('#else'):
            stack[-1]=stack[-2] and not stack[-1]; continue
        if t.startswith('#endif'): stack.pop(); continue
        if not stack[-1] or not t or t.startswith('//'): continue
        m=re.match(r'#define\s+(\w+)',t)
        if m: defs.add(m[1])
        m=re.match(r'#undef\s+(\w+)',t)
        if m: defs.discard(m[1])
        m=re.match(r'#include\s+"([^"]+)"',t)
        if m:
            child=posixpath.normpath((pathlib.PurePosixPath(rel).parent/m[1]).as_posix())
            out.extend(closure(child,old,defs))
        else: out.append(t)
    assert len(stack)==1,rel
    return out
for n in range(11,19):
    wrappers=list((root/'ea_template').glob('Boss_'+str(n)+'_*.mq5'))
    assert len(wrappers)==1,n
    rel=wrappers[0].relative_to(root).as_posix()
    before=closure(rel,True,set()); after=closure(rel,False,set())
    assert before==after, 'B%d active source changed'%n
    print('[PASS] B%d active source closure unchanged (%d lines)'%(n,len(after)))
native='\n'.join(closure('ea_template/Boss_20_GoldTimeBomb.mq5',False,set()))
assert native.count('int OnInit()')==1 and native.count('void OnTick()')==1
for forbidden in ('void Lab_OpenOrder(', 'RiskControl_CheckDD()', 'Stack_DecideAdd(', 'RuntimeIdentity_Init()'):
    assert forbidden not in native, 'B20 reached shared lifecycle: '+forbidden
assert 'void OnTick() { GoldTimeBomb_OnTick(); }' in native
print('[PASS] B20 compiles exactly one native lifecycle, without shared fallback')
'@
$closureCheck | python - $RepoRoot
if ($LASTEXITCODE) { throw 'Existing build source comparison failed' }

if ($Compile) {
    if (!(Test-Path -LiteralPath $MetaEditor -PathType Leaf)) { throw "COMPILE_UNAVAILABLE: $MetaEditor" }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('df02_compile_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    # Retain the temporary artifacts/logs for exact evidence; never copy to Experts.
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_template') -Destination $tempRoot -Recurse
    foreach ($rel in @('Boss_20_GoldTimeBomb.mq5', 'tests/GoldTimeBomb_Test.mq5')) {
        $src = Join-Path (Join-Path $tempRoot 'ea_template') $rel
        $log = [IO.Path]::ChangeExtension($src, '.compile.log')
        $process = Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$src`"", "/log:`"$log`"" -WindowStyle Hidden -PassThru
        if (!$process.WaitForExit(60000)) { throw "Compile still running; no process killed. PID=$($process.Id) log=$log" }
        if (!(Test-Path -LiteralPath $log)) { throw "Compile log unavailable: $log" }
        $content = [IO.File]::ReadAllText($log)
        Write-Host ($content -split "`r?`n" | Where-Object { $_ -match 'Result:|error|warning' } | Out-String)
        if ($content -notmatch 'Result: 0 errors, 0 warnings' -or !(Test-Path -LiteralPath ([IO.Path]::ChangeExtension($src, '.ex5')))) {
            throw "Compile acceptance failed: $log"
        }
        Write-Host "[PASS] compile only: $src :: $log"
    }
}
Write-Host '[PASS] DF02 author checks complete; different-family review still required'
