<# FB-G01 production-body deterministic cage. No tester, deployment or attachment.
   Host tests are C# translations with terminal stubs, NOT native MQL execution.
   -Compile compiles isolated source copies with MetaEditor, without running them. #>
[CmdletBinding()]
param(
    [string]$RepoRoot='',
    [string]$EvidenceRoot='',
    [switch]$Compile,
    [string]$MetaEditor='D:\Meta 5\metaeditor64.exe'
)
$ErrorActionPreference='Stop'
if (!$RepoRoot) { $RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
if (!$EvidenceRoot) { $EvidenceRoot=Join-Path ([IO.Path]::GetTempPath()) ('fb_g01_'+[guid]::NewGuid().ToString('N')) }
New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
$entry=[IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/core/entries/Entry_PersistentAdaptiveGrid.mqh'))
$core=[IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/core/LabCore.mqh'))
$wrapper=[IO.File]::ReadAllText((Join-Path $RepoRoot 'ea_template/Boss_25_PersistentAdaptiveGrid.mq5'))
if ($wrapper -notmatch '#define LAB_ENTRY_25' -or $wrapper -notmatch '"25_PersistentAdaptiveGrid"') { throw 'wrapper identity' }
if ($core -notmatch '(?s)#ifdef LAB_ENTRY_25\s+if\(RiskControl_CheckDD\(\).*?PersistentAdaptiveGrid_OnTick\(\);\s+return;\s+#else') { throw 'hard risk / dedicated dispatch isolation' }
if ($entry -match 'PositionClosePartial\(|BuyLimit\(|SellLimit\(|BuyStop\(|SellStop\(') { throw 'forbidden partial/pending entry path' }
foreach ($needle in @('ACCOUNT_MARGIN_MODE_RETAIL_HEDGING','GlobalVariableSetOnCondition','ACCOUNT_SERVER',
    'ACCOUNT_LOGIN','_Symbol,_0_Magic','StringSubstr(hex,0,40)','PG_CONFIG+i',
    'CopyHigh(_Symbol,_Period,2','CopyLow(_Symbol,_Period,2','CopyClose(_Symbol,_Period,1',
    'CopyBuffer(g_pag_atr_handle,0,1,1','POSITION_IDENTIFIER','DEAL_COMMISSION','DEAL_FEE')) {
    if (!$entry.Contains($needle)) { throw "Missing adapter invariant: $needle" }
}
function Get-PagFunction([string]$Name) {
    $m=[regex]::Match($entry,'(?m)^(?:bool|int|void|double|ulong|string) '+$Name+'\(')
    if (!$m.Success) { throw "Missing production function $Name" }
    $start=$entry.IndexOf('{',$m.Index); $end=$start+1; $depth=1
    while ($depth -gt 0 -and $end -lt $entry.Length) {
        if ($entry[$end] -eq '{') { $depth++ }
        if ($entry[$end] -eq '}') { $depth-- }
        $end++
    }
    if ($depth -ne 0) { throw "Unbalanced production body $Name" }
    $entry.Substring($m.Index,$end-$m.Index)
}
$names=@([regex]::Matches(($entry -split '// BEGIN HOST CORE:')[1].Split([string[]]@('// END HOST CORE'),[StringSplitOptions]::None)[0],
    '(?m)^(?:bool|int|void|double|string) (PAG_\w+)\(') | ForEach-Object { $_.Groups[1].Value })
$names+=@('PAG_Inventory','PAG_Id','PAG_PutId','PAG_Halt','PAG_Commit','PAG_RequestQuote',
    'PAG_OpenOne','PAG_RecordFill','PAG_CloseTick','PAG_LoadATR','PAG_LoadRegime',
    'PAG_Safety','PAG_AccountUnchanged','PAG_HistoryWatermark','PersistentAdaptiveGrid_OnTick',
    'PersistentAdaptiveGrid_SharedHalt','PAG_DiskMatches')
$constants=@()
foreach ($m in [regex]::Matches(($entry -split '// BEGIN HOST CORE:')[0], '\b(P(?:AG|G)_\w+)\s*(?:=| )\s*(-?\d+)')) {
    $constants+='const int '+$m.Groups[1].Value+'='+$m.Groups[2].Value+';'
}
$bodies=foreach ($name in $names) {
    $body=Get-PagFunction $name
    $body=$body -replace '\bconst ','' -replace '\bdatetime\b','long'
    $body=$body -replace 'double &(\w+)\[\]','double[] $1'
    $body=$body -replace 'MqlTick &(\w+)','MqlTick $1'
    $body=$body -replace 'double &(\w+)','ref double $1' -replace 'int &(\w+)','ref int $1' -replace 'ulong &(\w+)','ref ulong $1'
    $body=$body -replace '(double|bool) (\w+)\[\];','$1[] $2=new $1[0];'
    $body=$body.Replace('double lease=0,disk[];','double lease=0; double[] disk=new double[0];')
    $body=$body -replace 'MqlTick (\w+);','MqlTick $1=new MqlTick();'
    $body=$body.Replace('int positions,pending; double profit;','int positions=0,pending=0; double profit=0;')
    $body=$body -replace 'ArrayResize\((\w+),','Array.Resize(ref $1,' -replace 'ArraySize\((\w+)\)','$1.Length' -replace 'ArraySort\(','Array.Sort('
    $body=$body.Replace('PAG_ReadBank(string prefix,double[] s)','PAG_ReadBank(string prefix,ref double[] s)')
    $body=$body -replace 'PAG_Get\(([^\r\n]*?),((?:bank|complete|stored|lease)|s\[i\])\)','PAG_Get($1,ref $2)'
    $body=$body.Replace('PAG_Digest(s,checksum)','PAG_Digest(s,ref checksum)')
    $body=$body -replace 'PAG_Inventory\(([^\r\n]*?),positions,pending,profit\)','PAG_Inventory($1,ref positions,ref pending,ref profit)'
    $body=$body.Replace('PAG_ReadBank(g_pag_prefix,disk)','PAG_ReadBank(g_pag_prefix,ref disk)')
    $body=$body.Replace('PAG_HistoryWatermark(watermark)','PAG_HistoryWatermark(ref watermark)')
    $body=$body.Replace('_Symbol,lot,price,margin)','_Symbol,lot,price,ref margin)')
    $body=$body.Replace('CopyBuffer(g_pag_atr_handle,0,1,1,values)','CopyBuffer(g_pag_atr_handle,0,1,1,ref values)')
    foreach ($array in @('highs','lows','close')) { $body=$body.Replace(','+$array+')',',ref '+$array+')') }
    $body=$body.Replace('double highs[],lows[],close[];','double[] highs=new double[0],lows=new double[0],close=new double[0];')
    'static '+$body
}
$hostCode=@'
using System;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Text;
public static class PagConformance {
const string _Symbol="FIXTURE",LAB_ENTRY_TAG="25_PersistentAdaptiveGrid";
const int _Period=60,_25_ATRPeriod=14,_25_DonchianBars=3,_25_MaxRungsPerSide=5,_25_SpreadSamples=50,_25_OpenCooldownSec=1;
const double _25_GridPct=.25,_25_GridATRMult=.75,_25_FixedLot=.01,_25_BasketTargetBalancePct=.25,_25_SpreadMedianMult=2.5,_25_SpreadATRCap=.1;
const int POSITION_SYMBOL=1,POSITION_MAGIC=2,POSITION_IDENTIFIER=3,POSITION_TYPE=4,POSITION_VOLUME=5,POSITION_PRICE_OPEN=6,POSITION_PROFIT=7,POSITION_SWAP=8;
const int POSITION_TYPE_BUY=0,ORDER_SYMBOL=1,ORDER_MAGIC=2,ORDER_TYPE_BUY=0,ORDER_TYPE_SELL=1;
const int DEAL_POSITION_ID=1,DEAL_SYMBOL=2,DEAL_MAGIC=3,DEAL_TYPE=4,DEAL_TYPE_BUY=0,DEAL_TYPE_SELL=1,DEAL_PROFIT=5,DEAL_SWAP=6,DEAL_COMMISSION=7,DEAL_FEE=8;
const int ACCOUNT_BALANCE=1,ACCOUNT_CREDIT=2,ACCOUNT_MARGIN_FREE=3;
const uint TRADE_RETCODE_DONE=10009;
static double[] g_pag_state,g_pag_identity,g_pag_spreads;
static bool g_pag_fault,g_pag_loaded,g_rc_kill_pending;
static int g_pag_bank,g_pag_count,g_pag_cursor,g_pag_regime,g_pag_atr_handle=1;
static long g_pag_bar;
static string g_pag_prefix="fixture.";
static Dictionary<string,double> gv=new Dictionary<string,double>();
static int writeLimit=-1,writes,flushes,checks,failures,closeCalls,requestReads;
static bool risk,allow=true,accountGate=true,news,macro,spreadOK=true,tickOK=true,historyOK=true,atrOK=true;
static double macroMult=1,lot=.01,balance=10000,credit,freeMargin=1000,profitValue,swapValue,realized,atrValue=8;
static long now=100,bar=60;
static double bid=999,ask=1001;
static int highCount=3,lowCount=3,closeCount=1;
static double[] highsData=new double[]{1002,1003,1001},lowsData=new double[]{997,998,999};
static double closeData=1000;
class MqlTick { public double bid,ask; }
class Position { public ulong id; public int dir; public double lot,price; public string symbol="FIXTURE"; public long magic=25; }
static List<Position> positions=new List<Position>();
static Position selected;
static int pendingCount;
static bool closePartial,closeFails;
static Action beforeRequest;
static bool MathIsValidNumber(double x) { return !double.IsNaN(x) && !double.IsInfinity(x); }
static double MathFloor(double x) { return Math.Floor(x); }
static double MathAbs(double x) { return Math.Abs(x); }
static double MathMax(double a,double b) { return Math.Max(a,b); }
static double MathMin(double a,double b) { return Math.Min(a,b); }
static string IntegerToString(long n) { return n.ToString(); }
static int StringLen(string s) { return s.Length; }
static void ArrayInitialize(bool[] x,bool value) { for(int i=0;i<x.Length;i++) x[i]=value; }
static void Print(string x) {}
static void PrintFormat(string x,params object[] args) {}
static long TimeCurrent() { return now; }
static long iTime(string symbol,int period,int shift) { return bar; }
static int PositionsTotal() { return positions.Count; }
static ulong PositionGetTicket(int i) { selected=positions[i];return selected.id; }
static string PositionGetString(int property) { return selected.symbol; }
static long PositionGetInteger(int property) {
 if(property==POSITION_MAGIC) return selected.magic;
 if(property==POSITION_IDENTIFIER) return (long)selected.id;
 return selected.dir-1;
}
static double PositionGetDouble(int property) {
 if(property==POSITION_VOLUME) return selected.lot;
 if(property==POSITION_PRICE_OPEN) return selected.price;
 if(property==POSITION_PROFIT) return profitValue;
 return swapValue;
}
static bool Exec_IdentityIsMine(string symbol,long magic) { return symbol==_Symbol && magic==25; }
static int OrdersTotal() { return pendingCount; }
static ulong OrderGetTicket(int i) { return (ulong)(i+1); }
static string OrderGetString(int p) { return _Symbol; }
static long OrderGetInteger(int p) { return 25; }
static bool RiskControl_IsHalted() { return risk; }
static bool RiskControl_AllowNewOrder() { return allow; }
static bool RiskControl_AcctGateOK() { return accountGate; }
static int RiskControl_MaxLevels() { return 10; }
static bool Exec_NewsBlocked() { return news; }
static bool Exec_MacroBlocked() { return macro; }
static bool Exec_SpreadOK() { return spreadOK; }
static double Exec_MacroLotMult() { return macroMult; }
static double Exec_NormalizeLot(double x) { return lot; }
static double AccountInfoDouble(int property) { return property==ACCOUNT_BALANCE ? balance : property==ACCOUNT_CREDIT ? credit : freeMargin; }
static bool SymbolInfoTick(string symbol,MqlTick tick) {
 requestReads++; if(beforeRequest!=null) beforeRequest(); tick.bid=bid;tick.ask=ask;return tickOK;
}
static bool OrderCalcMargin(int d,string symbol,double v,double p,ref double margin) { margin=10;return true; }
static int CopyBuffer(int h,int b,int shift,int count,ref double[] values) {
 if(shift!=1 || count!=1) throw new Exception("ATR shift");values=new double[]{atrValue};return atrOK?1:0;
}
static int CopyHigh(string symbol,int p,int shift,int n,ref double[] a) { if(shift!=2) throw new Exception("high shift");a=(double[])highsData.Clone();return highCount; }
static int CopyLow(string symbol,int p,int shift,int n,ref double[] a) { if(shift!=2) throw new Exception("low shift");a=(double[])lowsData.Clone();return lowCount; }
static int CopyClose(string symbol,int p,int shift,int n,ref double[] a) { if(shift!=1 || n!=1) throw new Exception("decision shift");a=new double[]{closeData};return closeCount; }
static bool HistorySelect(long from,long to) { return historyOK; }
static int HistoryDealsTotal() { return 1; }
static ulong HistoryDealGetTicket(int i) { return 900; }
static bool HistoryDealSelect(ulong deal) { return deal>0; }
static string HistoryDealGetString(ulong ticket,int p) { return _Symbol; }
static long HistoryDealGetInteger(ulong ticket,int p) {
 if(p==DEAL_POSITION_ID) return (long)g_trade.lastId;
 if(p==DEAL_MAGIC) return 25;
 return DEAL_TYPE_BUY;
}
static double HistoryDealGetDouble(ulong ticket,int p) { return p==DEAL_PROFIT ? realized : 0; }
static bool Exec_CloseAll() {
 closeCalls++;
 double[] snapshot=new double[0];
 if(!PAG_ReadBank(g_pag_prefix,ref snapshot) || snapshot[PG_CLOSE]!=1) throw new Exception("close before durable CLOSE_INTENT");
 if(closeFails) return false;
 if(closePartial && positions.Count>0) positions[0].lot/=2; else positions.Clear();
 return positions.Count==0;
}
class Trade {
 public int calls;public double price,volume;public ulong lastId; public uint result=TRADE_RETCODE_DONE;
 public bool Buy(double v,string symbol,double p,double sl,double tp,string tag) {
  calls++;price=p;volume=v;lastId=(ulong)(10000+calls);
  if(result==TRADE_RETCODE_DONE) positions.Add(new Position{id=lastId,dir=1,lot=v,price=p});return true;
 }
 public bool Sell(double v,string symbol,double p,double sl,double tp,string tag) {
  bool ok=Buy(v,symbol,p,sl,tp,tag); if(result==TRADE_RETCODE_DONE) positions[positions.Count-1].dir=2;return ok;
 }
 public uint ResultRetcode() { return result; }
 public ulong ResultDeal() { return lastId; }
}
static Trade g_trade=new Trade();
static bool PAG_Set(string key,double value) { if(writeLimit>=0 && writes++>=writeLimit) return false;gv[key]=value;return true; }
static bool PAG_Get(string key,ref double value) { return gv.TryGetValue(key,out value); }
static void PAG_Flush() { flushes++; }
static bool PAG_Digest(double[] s,ref double[] words) {
 byte[] data=new byte[s.Length*8];Buffer.BlockCopy(s,0,data,0,data.Length);
 byte[] digest=SHA256.Create().ComputeHash(data);words=new double[8];
 for(int i=0;i<8;i++) words[i]=BitConverter.ToUInt32(digest,i*4);return true;
}
static void Check(bool ok,string label) { checks++;if(!ok) { failures++;Console.WriteLine("FAIL "+label); } }
static void Reset() {
 gv.Clear();g_pag_state=new double[PAG_FIELDS];g_pag_identity=Enumerable.Repeat(17.0,8).ToArray();
 g_pag_state[PG_SCHEMA]=PAG_SCHEMA;for(int i=0;i<8;i++) g_pag_state[PG_IDENTITY+i]=17;
 g_pag_spreads=Enumerable.Repeat(.2,50).ToArray();g_pag_count=50;g_pag_cursor=0;g_pag_regime=PAG_RANGE;g_pag_bar=0;
 g_pag_fault=false;g_pag_loaded=true;g_pag_bank=-1;writeLimit=-1;writes=0;closeCalls=0;requestReads=0;
 risk=false;allow=true;g_rc_kill_pending=false;accountGate=true;news=false;macro=false;spreadOK=true;macroMult=1;
 lot=.01;balance=10000;credit=0;freeMargin=1000;profitValue=swapValue=realized=0;atrValue=8;atrOK=true;
 now=100;bar=60;bid=999;ask=1001;tickOK=historyOK=true;beforeRequest=null;
 positions.Clear();pendingCount=0;closePartial=closeFails=false;g_trade=new Trade();
 highCount=lowCount=3;closeCount=1;closeData=1000;
 highsData=new double[]{1002,1003,1001};lowsData=new double[]{997,998,999};
 gv[g_pag_prefix+"lease"]=1;PAG_Commit();
}
static void Start() {
 Check(PAG_Start(g_pag_state,999,1001,8,.25,.75,10000,0,.25,.01,5,100,60,true,true),"cycle start");PAG_Commit();
}
static void Fill() { bid=993;ask=993.2;PAG_OpenOne(8);Check(g_trade.calls==1 && !g_pag_fault,"physical rung filled"); }
public static int Run() {
 Reset();
 Check(PAG_Parameters(.25,.75,14,20,5,.01,.25,50,2.5,.1,1),"defaults");
 foreach(double bad in new double[]{0,-1,double.NaN,double.PositiveInfinity}) {
  Check(!PAG_Parameters(bad,.75,14,20,5,.01,.25,50,2.5,.1,1),"bad pct");
  Check(!PAG_Parameters(.25,bad,14,20,5,.01,.25,50,2.5,.1,1),"bad spacing mult");
  Check(!PAG_Parameters(.25,.75,14,20,5,bad,.25,50,2.5,.1,1),"bad lot");
  Check(!PAG_Parameters(.25,.75,14,20,5,.01,bad,50,2.5,.1,1),"bad target");
  Check(!PAG_Parameters(.25,.75,14,20,5,.01,.25,50,bad,.1,1),"bad median mult");
  Check(!PAG_Parameters(.25,.75,14,20,5,.01,.25,50,2.5,bad,1),"bad ATR cap");
 }
 foreach(int bad in new int[]{0,-1}) {
  Check(!PAG_Parameters(.25,.75,bad,20,5,.01,.25,50,2.5,.1,1),"ATR period");
  Check(!PAG_Parameters(.25,.75,14,bad,5,.01,.25,50,2.5,.1,1),"channel");
  Check(!PAG_Parameters(.25,.75,14,20,bad,.01,.25,50,2.5,.1,1),"rungs");
  Check(!PAG_Parameters(.25,.75,14,20,5,.01,.25,bad,2.5,.1,1),"samples");
 }
 Check(!PAG_Parameters(.25,.75,14,20,17,.01,.25,50,2.5,.1,1),"mask capacity");
 Check(!PAG_Parameters(.25,.75,14,20,5,.01,.25,50,2.5,.1,-1),"cooldown");
 Check(PAG_Hedging(2,2) && !PAG_Hedging(0,2) && !PAG_Hedging(1,2),"hedging/netting");
 string ns=PAG_IdentityText("server",11,"EURUSD",25);
 Check(ns!=PAG_IdentityText("server2",11,"EURUSD",25) && ns!=PAG_IdentityText("server",12,"EURUSD",25) && ns!=PAG_IdentityText("server",11,"EURUSD2",25) && ns!=PAG_IdentityText("server",11,"EURUSD",26),"server/account/symbol/magic isolation");
 Check(PAG_IdentityText("s|11",2,"X",25)!=PAG_IdentityText("s",11,"2|X",25),"length framing prevents delimiter alias");
 Start();double[] frozen=(double[])g_pag_state.Clone();
 Check(g_pag_state[PG_ANCHOR]==1000 && g_pag_state[PG_ATR]==8 && g_pag_state[PG_SPACE]==6 && g_pag_state[PG_TARGET]==25,"geometry/target");
 Check(!PAG_Start(g_pag_state,1999,2001,80,.25,.75,20000,10,.25,.01,5,101,60,true,true) && frozen.SequenceEqual(g_pag_state),"geometry cannot change live");
 for(int k=1;k<=5;k++) Check(PAG_Level(1000,6,1,k)==1000-k*6 && PAG_Level(1000,6,2,k)==1000+k*6,"exact levels");
 for(int mask=0;mask<32;mask++) {
  int expected=0;for(int k=1;k<=5;k++) if((mask&(1<<(k-1)))==0) {expected=k;break;}
  Check(PAG_Next(1000,6,5,mask,1,PAG_RANGE,900,901)==expected,"gap/no-refill buy mask "+mask);
  Check(PAG_Next(1000,6,5,mask,2,PAG_RANGE,1100,1101)==expected,"gap/no-refill sell mask "+mask);
 }
 Check(PAG_Next(1000,6,5,0,1,PAG_RANGE,993,994)==1 && PAG_Next(1000,6,5,0,1,PAG_RANGE,993,994.01)==0,"Ask crossing boundary");
 Check(PAG_Next(1000,6,5,0,2,PAG_RANGE,1006,1007)==1 && PAG_Next(1000,6,5,0,2,PAG_RANGE,1005.99,1007)==0,"Bid crossing boundary");
 Check(PAG_Permission(PAG_RANGE,1) && PAG_Permission(PAG_RANGE,2) && PAG_Permission(PAG_TREND_UP,1) && !PAG_Permission(PAG_TREND_UP,2) && !PAG_Permission(PAG_TREND_DOWN,1) && PAG_Permission(PAG_TREND_DOWN,2) && !PAG_Permission(PAG_HALT_DATA,1),"direction permissions");
 Check(PAG_Regime(1003,highsData,lowsData,3)==PAG_RANGE && PAG_Regime(997,highsData,lowsData,3)==PAG_RANGE && PAG_Regime(1003.01,highsData,lowsData,3)==PAG_TREND_UP && PAG_Regime(996.99,highsData,lowsData,3)==PAG_TREND_DOWN,"strict Donchian");
 foreach(int count in new int[]{-1,0,2}) { highCount=count;PAG_LoadRegime(++bar);Check(g_pag_regime==PAG_HALT_DATA,"missing high");highCount=3;lowCount=count;PAG_LoadRegime(++bar);Check(g_pag_regime==PAG_HALT_DATA,"missing low");lowCount=3; }
 foreach(double bad in new double[]{0,-1,double.NaN,double.PositiveInfinity}) {
  highsData[1]=bad;PAG_LoadRegime(++bar);Check(g_pag_regime==PAG_HALT_DATA,"bad high");highsData[1]=1003;
  atrValue=bad;Check(PAG_LoadATR()==0,"bad ATR");
 }
 atrValue=8;atrOK=false;Check(PAG_LoadATR()==0,"missing ATR");atrOK=true;
 double[] spreads=Enumerable.Repeat(1.0,50).ToArray();
 Check(!PAG_Spread(1,spreads,49,50,2.5,.1,20),"50 positive sample warmup");
 Check(PAG_Spread(2,spreads,50,50,2.5,.1,20) && !PAG_Spread(2.001,spreads,50,50,2.5,.1,20),"ATR cap boundary");
 Check(PAG_Spread(2.5,spreads,50,50,2.5,.1,100) && !PAG_Spread(2.501,spreads,50,50,2.5,.1,100),"median cap boundary");
 spreads=Enumerable.Range(1,50).Select(x=>(double)x).ToArray();
 Check(PAG_Spread(25.5,spreads,50,50,1,1,100) && !PAG_Spread(25.501,spreads,50,50,1,1,100),"even median middle pair");
 for(int cut=0;cut<PAG_FIELDS+11;cut++) {
  Reset();Start();double[] original=(double[])g_pag_state.Clone(),read=new double[0];
  int next=g_pag_bank==0?1:0;
  g_pag_state[PG_DISCONTINUITY]=1;writeLimit=cut;writes=0;
  bool ok=PAG_WriteBank(g_pag_prefix,next,g_pag_state);writeLimit=-1;
  Check(PAG_ReadBank(g_pag_prefix,ref read) && (ok?read[PG_DISCONTINUITY]==1:read.SequenceEqual(original)),"torn bank write "+cut);
 }
 Reset();Start();double[] restored=new double[0];string active=g_pag_prefix+g_pag_bank+".";
 gv.Remove(active+"8");Check(!PAG_ReadBank(g_pag_prefix,ref restored),"missing field");
 Reset();Start();active=g_pag_prefix+g_pag_bank+".";gv[active+"3"]=2000;Check(!PAG_ReadBank(g_pag_prefix,ref restored),"checksum corruption");
 Reset();Start();g_pag_state[PG_SCHEMA]=2;Check(!PAG_Valid(g_pag_state,g_pag_identity,5),"wrong schema");
 Reset();Start();g_pag_state[PG_BUY]=32;Check(!PAG_Valid(g_pag_state,g_pag_identity,5),"impossible mask");
 Reset();Start();double[] otherIdentity=(double[])g_pag_identity.Clone();otherIdentity[7]++;Check(!PAG_Valid(g_pag_state,otherIdentity,5),"namespace full identity collision rejection");
 Check(!PAG_ReadBank("other-account-symbol-magic.",ref restored),"namespace bank isolation");
 foreach(ulong id in new ulong[]{1,4294967296,9007199254740993,18446744073709551615}) { PAG_PutId(g_pag_state,PG_WATER_HI,id);Check(PAG_Id(g_pag_state,PG_WATER_HI)==id,"exact ulong halves "+id); }
 Reset();Start();Fill();int n=0,p=0;double v=0;
 Check(PAG_Inventory(false,ref n,ref p,ref v) && n==1,"owned inventory exact");
 positions.Add(new Position{id=88,dir=2,lot=.9,price=3,symbol="OTHER"});Check(PAG_Inventory(false,ref n,ref p,ref v) && n==1,"other symbol ignored");positions.RemoveAt(1);
 positions.Add(new Position{id=88,dir=2,lot=.9,price=3,magic=26});Check(PAG_Inventory(false,ref n,ref p,ref v) && n==1,"other magic ignored");positions.RemoveAt(1);
 positions[0].lot=.005;Check(!PAG_Inventory(false,ref n,ref p,ref v) && PAG_Inventory(true,ref n,ref p,ref v),"partial close allowed only under close intent");
 positions[0].lot=.02;Check(!PAG_Inventory(true,ref n,ref p,ref v),"close cannot adopt volume increase");positions[0].lot=.01;
 pendingCount=1;Check(!PAG_Inventory(true,ref n,ref p,ref v),"pending mismatch");pendingCount=0;
 positions.Clear();Check(!PAG_Inventory(false,ref n,ref p,ref v),"missing live rung");
 Reset();Start();bid=900;ask=900.2;PAG_OpenOne(8);Check(g_trade.calls==1,"one order on gap tick");
 PAG_OpenOne(8);Check(g_trade.calls==1,"cooldown at same second");now++;PAG_OpenOne(8);Check(g_trade.calls==2 && g_pag_state[PG_BUY]==3,"next tick next rung");
 Reset();Start();bid=993;ask=993.2;beforeRequest=()=>{if(requestReads==2) ask=995;};PAG_OpenOne(8);
 Check(g_trade.calls==0 && g_pag_state[PG_OPEN_INTENT]==0,"request quote spread widening veto");
 Reset();Start();bid=993;ask=993.2;beforeRequest=()=>{if(requestReads==2) {bid=1000;ask=1000.2;}};PAG_OpenOne(8);
 Check(g_trade.calls==0,"request quote no longer crosses");
 Reset();Start();Fill();Check(g_trade.price==993.2 && g_trade.volume==.01,"exact request price and flat lot");
 Reset();Start();bid=993;ask=993.2;g_trade.result=10010;PAG_OpenOne(8);Check(g_pag_fault && g_pag_state[PG_OPEN_INTENT]!=0,"partial/uncertain open fail closed");
 Reset();Start();Fill();profitValue=24;swapValue=1;tickOK=false;g_pag_count=0;closeFails=true;
 PersistentAdaptiveGrid_OnTick();Check(g_pag_state[PG_CLOSE]==1 && closeCalls==1 && positions.Count==1,"target sum profit swap persists close before attempt; spread cannot block exit");
 closeFails=false;closePartial=true;PersistentAdaptiveGrid_OnTick();Check(g_pag_state[PG_CLOSE]==1 && g_pag_state[PG_STATE]==PAG_LIVE,"partial close no reset");
 closePartial=false;PersistentAdaptiveGrid_OnTick();Check(g_pag_state[PG_STATE]==PAG_WAIT && g_pag_state[PG_CLOSE]==0 && positions.Count==0,"exact flat terminal snapshot");
 Check(PAG_ReadBank(g_pag_prefix,ref restored) && restored[PG_STATE]==PAG_WAIT,"terminal persisted");
 Check(!PAG_Start(g_pag_state,999,1001,8,.25,.75,10025,0,.25,.01,5,101,60,true,true),"wait same bar");
 Check(PAG_Start(g_pag_state,999,1001,8,.25,.75,10025,0,.25,.01,5,120,120,true,true) && g_pag_state[PG_TARGET]==25.0625,"next flat bar new baseline");
 Reset();Start();Fill();balance=10100;PersistentAdaptiveGrid_OnTick();Check(g_pag_state[PG_DISCONTINUITY]==1 && g_pag_state[PG_TARGET]==25 && g_trade.calls==1,"deposit discontinuity frozen target");
 Reset();Start();Fill();credit=1;PersistentAdaptiveGrid_OnTick();Check(g_pag_state[PG_DISCONTINUITY]==1,"credit discontinuity");
 Check(PAG_Baseline(10002,0,10000,0,2,true) && !PAG_Baseline(10002,0,10000,0,0,true) && !PAG_Baseline(10000,0,10000,0,0,false),"realized own deals vs external and unavailable history");
 Reset();Start();Fill();balance=10002;realized=2;Check(PAG_AccountUnchanged(),"production history own realization");
 PersistentAdaptiveGrid_SharedHalt();Check(g_pag_state[PG_RISK]==1 && PAG_ReadBank(g_pag_prefix,ref restored) && restored[PG_RISK]==1,"shared risk durable latch");
 risk=false;bid=900;ask=900.2;now++;PAG_OpenOne(8);Check(g_trade.calls==1,"strategy cannot self-clear halt");
 Reset();PersistentAdaptiveGrid_SharedHalt();Check(!g_pag_fault && g_pag_state[PG_RISK]==1,"halt also persists while empty");
 Reset();g_pag_count=0;bid=1000;ask=1000;
 for(int i=0;i<55;i++) PersistentAdaptiveGrid_OnTick();
 Check(g_pag_count==0 && g_pag_state[PG_STATE]==PAG_EMPTY,"nonpositive spreads never fabricate warmup");
 ask=1000.2;for(int i=0;i<49;i++) PersistentAdaptiveGrid_OnTick();
 Check(g_pag_count==49 && g_pag_state[PG_STATE]==PAG_EMPTY,"49 sample tick lifecycle blocks start");
 PersistentAdaptiveGrid_OnTick();Check(g_pag_count==50 && g_pag_state[PG_STATE]==PAG_LIVE,"50 sample tick lifecycle starts flat");
 Reset();Start();bid=1007;ask=1007.2;PAG_OpenOne(8);
 Check(g_trade.calls==1 && g_trade.price==1007 && positions[0].dir==2 && g_pag_state[PG_SELL]==1,"SELL request uses exact checked Bid");
 g_pag_regime=PAG_TREND_UP;g_pag_bar=bar;now++;bid=1020;ask=1020.2;PersistentAdaptiveGrid_OnTick();
 Check(g_trade.calls==1 && closeCalls==0 && positions.Count==1,"regime change blocks SELL additions without forced close");
 Reset();Start();bid=993;ask=993.2;beforeRequest=()=>{if(requestReads==2) allow=false;};PAG_OpenOne(8);
 Check(g_trade.calls==0,"shared safety rechecked after intent persistence");
 Reset();Start();Fill();gv.Remove(g_pag_prefix+"lease");PersistentAdaptiveGrid_OnTick();
 Check(g_pag_fault && g_trade.calls==1,"lost namespace writer lease halts");
 Console.WriteLine("FB-G01 host conformance: "+checks+" checks, "+failures+" failures");return failures;
}
'@
$hostCode+="`n"+($constants -join "`n")+"`n"+($bodies -join "`n")+"`n}"
[IO.File]::WriteAllText((Join-Path $EvidenceRoot 'production_body_host.cs'),$hostCode)
Add-Type -TypeDefinition $hostCode -Language CSharp
if ([PagConformance]::Run() -ne 0) { throw 'FB-G01 production-body conformance failed' }
Write-Host '[PASS] wrapper, hard-risk dispatch, adapter seams, source-owned deterministic tests'
if ($Compile) {
    $compileRoot=Join-Path $EvidenceRoot 'compile'
    New-Item -ItemType Directory -Path $compileRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot 'ea_template') -Destination $compileRoot -Recurse -Force
    foreach ($rel in @('Boss_25_PersistentAdaptiveGrid.mq5','tests/PersistentAdaptiveGrid_Test.mq5')) {
        $src=Join-Path (Join-Path $compileRoot 'ea_template') $rel
        $log=[IO.Path]::ChangeExtension($src,'.compile.log')
        $p=Start-Process -FilePath $MetaEditor -ArgumentList "/compile:`"$src`"","/log:`"$log`"" -WindowStyle Hidden -PassThru
        if (!$p.WaitForExit(60000)) { throw "Compile still running (not killed): PID=$($p.Id)" }
        if (!(Test-Path -LiteralPath $log) -or [IO.File]::ReadAllText($log) -notmatch 'Result: 0 errors, 0 warnings') { throw "Compile did not pass 0/0: $log" }
        Write-Host "[PASS] isolated compile 0 errors / 0 warnings: $rel"
    }
}
