<#
FB-A01 deterministic source/fixture cage.
No Strategy Tester, backtest, optimizer, runtime attachment, deploy, or push.
With -Compile, MetaEditor compiles isolated temporary copies only.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = '',
    [switch]$Compile,
    [string]$MetaEditor = 'D:\Meta 5\metaeditor64.exe'
)
$ErrorActionPreference = 'Stop'
if (!$RepoRoot) { $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path }

$entryPath = Join-Path $RepoRoot 'ea_template/core/entries/Entry_AdaptiveDonchianFlip.mqh'
$testPath = Join-Path $RepoRoot 'ea_template/tests/AdaptiveDonchianFlip_Test.mq5'
$corePath = Join-Path $RepoRoot 'ea_template/core/LabCore.mqh'
$inputPath = Join-Path $RepoRoot 'ea_template/core/Inputs.mqh'
$wrapperPath = Join-Path $RepoRoot 'ea_template/Boss_24_AdaptiveDonchianFlip.mq5'
foreach ($path in @($entryPath,$testPath,$corePath,$inputPath,$wrapperPath)) {
    if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing FB-A01 source: $path" }
}
$entry = [IO.File]::ReadAllText($entryPath)
$tests = [IO.File]::ReadAllText($testPath)
$core = [IO.File]::ReadAllText($corePath)
$inputs = [IO.File]::ReadAllText($inputPath)
$wrapper = [IO.File]::ReadAllText($wrapperPath)

$requiredEntry = @(
    'value <= current',
    'decision_close > upper + buffer',
    'decision_close < lower - buffer',
    'basic_upper < prev_upper || prev_close > prev_upper',
    'basic_lower > prev_lower || prev_close < prev_lower',
    'closes[i] > prev_upper',
    'closes[i] < prev_lower',
    'ACCOUNT_MARGIN_MODE_RETAIL_HEDGING',
    'RiskControl_AllowNewOrder()',
    'Exec_CloseAll()',
    'pending_direction',
    'reverse_attempted',
    'ADF_TrailTightens',
    'request'
)
foreach ($needle in $requiredEntry) {
    if (!$entry.Contains($needle)) { throw "Missing FB-A01 implementation seam: $needle" }
}
$requiredCases = @(
    'decision bar excluded','equality is not a BUY','equality is not a SELL',
    'ties count','missing/nonpositive','bounds map LOW/NORMAL/HIGH/EXTREME',
    'warmup seed','transitions DOWN then UP','50-sample warmup',
    'median averages middle pair','median ceiling blocks','ATR cap blocks',
    'initial SL distance','never loosens','same-direction',
    'partial close','broker close error','stale ownership',
    'exact flat verification','one open attempt','bar change cancels',
    'netting','ownership is isolated','shared-risk halt'
)
foreach ($needle in $requiredCases) {
    if (($tests + $entry) -notmatch [regex]::Escape($needle)) {
        throw "Missing FB-A01 test/guard coverage: $needle"
    }
}
if ($core -notmatch '(?s)#ifdef LAB_ENTRY_24.*?RiskControl_CheckDD\(\).*?AdaptiveDonchianFlip_OnTick\(\).*?return;') {
    throw 'LAB_ENTRY_24 does not short-circuit behind shared hard RiskControl'
}
if ($wrapper -notmatch '#define LAB_ENTRY_24' -or
    $wrapper -notmatch '#define LAB_ENTRY_TAG "24_AdaptiveDonchianFlip"') {
    throw 'Boss_24 wrapper identity mismatch'
}
foreach ($name in @('_24_DonchianBars','_24_ST_ATRPeriod','_24_ST_Mult',
    '_24_ATRPeriod','_24_ATRPctLookback','_24_ATRPctLow','_24_ATRPctHigh',
    '_24_ATRPctExtreme','_24_BufferATR_Normal','_24_BufferATR_High',
    '_24_SL_ATR_Normal','_24_SL_ATR_High','_24_FixedLot',
    '_24_SpreadSamples','_24_SpreadMedianMult','_24_SpreadATRCap')) {
    if ($inputs -notmatch ('input\s+\w+\s+' + [regex]::Escape($name) + '\s*=') -or
        $inputs -notmatch ('LAB_CONST_' + [regex]::Escape($name))) {
        throw "Input/constant guard pair missing: $name"
    }
}
Write-Host '[PASS] FB-A01 deterministic source/state coverage present'

# Execute selected production bodies with deterministic host API stubs. This
# exercises request-time gating and complete-window acquisition; it is not a
# native MQL5 execution or a broker simulation. Unsupported syntax fails closed.
function Get-AdfBody([string]$Name) {
    $match = [regex]::Match($entry, '(?m)^(?:bool|int|void|double) ' + $Name + '\(')
    if (!$match.Success) { throw "Missing function: $Name" }
    $start = $entry.IndexOf('{', $match.Index)
    $depth = 1
    $end = $start + 1
    while ($depth -gt 0 -and $end -lt $entry.Length) {
        if ($entry[$end] -eq '{') { $depth++ }
        if ($entry[$end] -eq '}') { $depth-- }
        $end++
    }
    if ($depth -ne 0) { throw "Unbalanced function: $Name" }
    $entry.Substring($match.Index, $end - $match.Index)
}
$bodies = foreach ($name in @('ADF_Donchian','ADF_Median','ADF_SpreadPass',
    'ADF_Percentile','ADF_Regime','ADF_Breakout','ADF_InitialSL',
    'ADF_LoadDecision','ADF_Open','ADF_FsmReset','ADF_FsmStep')) {
    $body = Get-AdfBody $name
    $body = $body -replace '\bconst ', ''
    $body = $body -replace 'double &(\w+)\[\]', 'double[] $1'
    $body = $body -replace 'double &(\w+)', 'ref double $1'
    $body = $body -replace 'ADF_(Decision|Fsm) &(\w+)', 'ADF_$1 $2'
    $body = $body -replace 'double highs\[\],lows\[\];', 'double[] highs=new double[0],lows=new double[0];'
    $body = $body -replace 'double (\w+)\[\];', 'double[] $1=new double[0];'
    $body = $body -replace 'MqlTick tick;', 'MqlTick tick=new MqlTick();'
    $body = $body -replace 'ArrayResize\((\w+),', 'Array.Resize(ref $1,'
    $body = $body -replace 'ArraySize\((\w+)\)', '$1.Length'
    $body = $body -replace 'ArraySort\(', 'Array.Sort('
    $body = $body -replace 'Copy(High|Low)\(_Symbol,_Period,2,_24_DonchianBars,(highs|lows)\)', 'Copy$1(_Symbol,_Period,2,_24_DonchianBars,ref $2)'
    $body = $body.Replace('CopyBuffer(g_adf_atr_handle,0,1,need,values)', 'CopyBuffer(g_adf_atr_handle,0,1,need,ref values)')
    $body = $body.Replace('ADF_Median(samples,required,median)', 'ADF_Median(samples,required,ref median)')
    $body = $body.Replace('ADF_Percentile(current,history,_24_ATRPctLookback,pct)', 'ADF_Percentile(current,history,_24_ATRPctLookback,ref pct)')
    $body = $body.Replace('ADF_Donchian(highs,lows,_24_DonchianBars,upper,lower)', 'ADF_Donchian(highs,lows,_24_DonchianBars,ref upper,ref lower)')
    $body = $body.Replace('ADF_LoadSuperTrend(trend,decision.st_upper,decision.st_lower)', 'ADF_LoadSuperTrend(ref trend,ref decision.st_upper,ref decision.st_lower)')
    'static ' + $body
}
$constants = foreach ($m in [regex]::Matches($entry,'(?m)^\s*(ADF_\w+)\s*=\s*(-?\d+)')) {
    'const int ' + $m.Groups[1].Value + '=' + $m.Groups[2].Value + ';'
}
$hostCode = @'
using System;
public static class AdfConformanceChecks {
class MqlTick { public double ask, bid; }
class ADF_Decision { public bool ready; public long bar; public int direction,regime; public double atr,st_upper,st_lower; }
class ADF_Fsm { public int state,pending_direction; public long pending_bar,last_open_bar; public bool reverse_attempted; }
const string _Symbol="FIXTURE", LAB_ENTRY_TAG="24_AdaptiveDonchianFlip";
const int _Period=1,_24_DonchianBars=3,_24_ATRPctLookback=4,g_adf_atr_handle=1,_24_SpreadSamples=50;
const double _24_ATRPctLow=20,_24_ATRPctHigh=80,_24_ATRPctExtreme=95;
const double _24_BufferATR_Normal=0.1,_24_BufferATR_High=0.2;
const double _24_SL_ATR_Normal=2,_24_SL_ATR_High=2.5,_24_FixedLot=0.01;
const double _24_SpreadMedianMult=3,_24_SpreadATRCap=0.1;
const uint TRADE_RETCODE_DONE=10009;
static double[] g_adf_spreads=new double[50];
public static int g_adf_spread_count=50,g_adf_open_refusals,checks,failures,diagnostics,tickReads;
static double requestSpread=1,historyValue=0;
static bool tickAvailable=true;
static int highCount=3,lowCount=3,badIndex=-1;
class Trade {
 public int calls; public double price,sl;
 public bool Buy(double lot,string symbol,double p,double s,double tp,string tag) { calls++;price=p;sl=s;return true; }
 public bool Sell(double lot,string symbol,double p,double s,double tp,string tag) { return Buy(lot,symbol,p,s,tp,tag); }
 public uint ResultRetcode() { return TRADE_RETCODE_DONE; }
}
static Trade g_trade=new Trade();
static bool MathIsValidNumber(double x) { return !double.IsNaN(x) && !double.IsInfinity(x); }
static void ArraySetAsSeries(double[] a,bool b) {}
static bool Exec_NewsBlocked() { return false; }
static bool Exec_MacroBlocked() { return false; }
static bool RiskControl_AllowNewOrder() { return true; }
static double Exec_NormalizeLot(double x) { return x; }
static double ADF_NormalizeInitialStop(int d,double p,double s) { return s; }
static bool SymbolInfoTick(string s,MqlTick t) { tickReads++; t.bid=1000;t.ask=1000+requestSpread;return tickAvailable; }
static void Print(string s) { diagnostics++; }
static void PrintFormat(string s,params object[] args) { diagnostics++; }
static long iTime(string s,int p,int shift) { return shift==1 ? 100 : 0; }
static double iClose(string s,int p,int shift) { return shift==1 ? 20 : double.NaN; }
static double iHigh(string s,int p,int shift) { return shift-2==badIndex ? historyValue : 12; }
static double iLow(string s,int p,int shift) { return shift-2==badIndex ? historyValue : 5; }
static int CopyHigh(string s,int p,int shift,int count,ref double[] a) {
 if(shift!=2 || count!=_24_DonchianBars) throw new Exception("wrong High window");
 a=new double[count];for(int i=0;i<count;i++) a[i]=i==badIndex ? historyValue : 12; return highCount;
}
static int CopyLow(string s,int p,int shift,int count,ref double[] a) {
 if(shift!=2 || count!=_24_DonchianBars) throw new Exception("wrong Low window");
 a=new double[count];for(int i=0;i<count;i++) a[i]=i==badIndex ? historyValue : 5; return lowCount;
}
static int CopyBuffer(int h,int b,int shift,int count,ref double[] a) { a=new double[]{1,2,2,3,2};return count; }
static bool ADF_LoadSuperTrend(ref int t,ref double u,ref double l) { t=1;u=12;l=5;return true; }
static void Check(bool ok,string label) { checks++;if(!ok) failures++;Console.WriteLine((ok ? "[PASS] " : "[FAIL] ")+label); }
public static int Run() {
 for(int i=0;i<50;i++) g_adf_spreads[i]=1;
 foreach(int direction in new int[]{1,2}) {
  foreach(double spread in new double[]{1,2,2.01,3,3.01}) {
   double atr=spread>=3 ? 100 : 20;
   g_trade=new Trade();g_adf_open_refusals=0;diagnostics=0;tickReads=0;requestSpread=spread;
   Check(ADF_SpreadPass(1,g_adf_spreads,50,50,3,0.1,atr),"SCR-001 earlier quote passes");
   bool expected=spread<=3 && spread<=0.1*atr;
   bool opened=ADF_Open(direction,atr,ADF_REGIME_NORMAL);
   Check(opened==expected && g_trade.calls==(expected ? 1 : 0),"SCR-001 exact request quote gate direction="+direction+" spread="+spread);
   Check(tickReads==1 && g_adf_open_refusals==(expected ? 0 : 1) && (expected || diagnostics>0),"SCR-001 single request tick / refusal diagnostic");
   if(expected) Check(g_trade.price==(direction==1 ? 1000+spread : 1000) && g_trade.sl==ADF_InitialSL(direction,g_trade.price,atr,2),"SCR-001 request price and SL preserved");
  }
  foreach(bool reverse in new bool[]{false,true}) {
   ADF_Fsm f=new ADF_Fsm();ADF_FsmReset(f);
   if(reverse) Check(ADF_FsmStep(f,100,true,direction,true,1,3-direction,0,false)==ADF_ACTION_CLOSE,"SCR-001 close before reverse");
   Check(ADF_FsmStep(f,100,!reverse,direction,true,0,0,0,false)==ADF_ACTION_OPEN,"SCR-001 open attempt armed");
   requestSpread=4;g_trade=new Trade();
   Check(!ADF_Open(direction,20,ADF_REGIME_NORMAL) && g_trade.calls==0,"SCR-001 widened quote refuses armed open");
   Check(ADF_FsmStep(f,100,false,0,true,0,0,0,false)==ADF_ACTION_NONE && ADF_FsmStep(f,100,true,direction,true,0,0,0,false)==ADF_ACTION_NONE,"SCR-001 no same-bar retry after refusal");
  }
 }
 requestSpread=1;g_adf_spread_count=49;g_trade=new Trade();
 Check(!ADF_Open(1,20,ADF_REGIME_NORMAL) && g_trade.calls==0,"SCR-001 request gate warmup");g_adf_spread_count=50;
 tickAvailable=false;g_trade=new Trade();g_adf_open_refusals=0;diagnostics=0;
 Check(!ADF_Open(1,20,ADF_REGIME_NORMAL) && g_trade.calls==0,"SCR-001 missing request tick");tickAvailable=true;
 ADF_Decision d=new ADF_Decision();
 Check(ADF_LoadDecision(d) && d.ready && d.direction==1,"SCR-002 complete valid window control");
 foreach(int count in new int[]{-1,0,2}) {
  highCount=count;lowCount=3;d=new ADF_Decision();
  Check(!ADF_LoadDecision(d) && !d.ready && d.direction==0,"SCR-002 incomplete High count="+count);
  highCount=3;lowCount=count;d=new ADF_Decision();
  Check(!ADF_LoadDecision(d) && !d.ready && d.direction==0,"SCR-002 incomplete Low count="+count);
 }
 highCount=lowCount=3;
 foreach(double invalid in new double[]{0,-1,double.NaN,double.PositiveInfinity}) {
  for(int i=0;i<3;i++) { badIndex=i;historyValue=invalid;d=new ADF_Decision();
   Check(!ADF_LoadDecision(d) && !d.ready && d.direction==0,"SCR-002 invalid element="+invalid+" index="+i);
  }
 }
 double upper=0,lower=0;
 Check(!ADF_Donchian(new double[]{10,4,12},new double[]{5,6,7},3,ref upper,ref lower),"SCR-002 inverted bar fails");
 Check(!ADF_Donchian(new double[]{10,11},new double[]{5,6,7},3,ref upper,ref lower),"SCR-002 short array fails");
 Check(ADF_Breakout(12,12,5,0,1)==0 && ADF_Breakout(5,12,5,0,-1)==0,"SCR-002 equality stays non-breakout");
 Console.WriteLine("FB-A01 host conformance: "+checks+" checks, "+failures+" failures");return failures;
}
'@
$hostCode += "`n" + ($constants -join "`n") + "`n" + ($bodies -join "`n") + "`n}"
Add-Type -TypeDefinition $hostCode -Language CSharp
if ([AdfConformanceChecks]::Run() -ne 0) { throw 'FB-A01 host conformance failed' }

if ($Compile) {
    if (!(Test-Path -LiteralPath $MetaEditor -PathType Leaf)) {
        throw "COMPILE_UNAVAILABLE: $MetaEditor"
    }
    $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('fb_a01_compile_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_template') -Destination $tempRoot -Recurse
    foreach ($rel in @('Boss_24_AdaptiveDonchianFlip.mq5','tests/AdaptiveDonchianFlip_Test.mq5')) {
        $src = Join-Path (Join-Path $tempRoot 'ea_template') $rel
        $log = [IO.Path]::ChangeExtension($src,'.compile.log')
        $p = Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$src`"","/log:`"$log`"" -WindowStyle Hidden -PassThru
        if (!$p.WaitForExit(60000)) { throw "Compile still running; process not killed. PID=$($p.Id)" }
        $content = [IO.File]::ReadAllText($log)
        if ($content -notmatch 'Result: 0 errors, 0 warnings') { throw "Compile failed: $log" }
        Write-Host "[PASS] compile 0/0: $rel"
    }
}
