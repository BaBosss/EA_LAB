// Engineering script fixture. Compile only in the author lane; no tester/runtime authority.
#property strict
#property script_show_inputs
#define PAG_HELPERS_ONLY
#include "../core/ConfigFingerprint.mqh"
#include "../core/entries/Entry_PersistentAdaptiveGrid.mqh"

string fixture_keys[];
double fixture_values[];
int fixture_fail_after=-1,fixture_writes=0,fixture_checks=0,fixture_failures=0;
bool PAG_Set(const string key,const double value)
{
   if(fixture_fail_after>=0 && fixture_writes++>=fixture_fail_after) return false;
   for(int i=0;i<ArraySize(fixture_keys);i++)
      if(fixture_keys[i]==key) { fixture_values[i]=value; return true; }
   int n=ArraySize(fixture_keys);
   ArrayResize(fixture_keys,n+1); ArrayResize(fixture_values,n+1);
   fixture_keys[n]=key; fixture_values[n]=value; return true;
}
bool PAG_Get(const string key,double &value)
{
   for(int i=0;i<ArraySize(fixture_keys);i++)
      if(fixture_keys[i]==key) { value=fixture_values[i]; return true; }
   return false;
}
void PAG_Flush() {} // fixture memory only; NEVER terminal Global Variables
bool PAG_Digest(const double &s[],double &words[])
{
   string text="";
   for(int i=0;i<ArraySize(s);i++) text+=CFG_CanonDouble(s[i])+"|";
   uchar data[],key[],digest[];
   int n=StringToCharArray(text,data,0,WHOLE_ARRAY,CP_UTF8);
   ArrayResize(data,n-1);
   if(CryptEncode(CRYPT_HASH_SHA256,data,key,digest)!=32) return false;
   ArrayResize(words,8);
   for(int i=0;i<8;i++)
   {
      uint word=0;
      for(int j=0;j<4;j++) word=(word<<8)|(uint)digest[i*4+j];
      words[i]=(double)word;
   }
   return true;
}
void Check(const bool ok,const string label)
{
   fixture_checks++;
   if(!ok) fixture_failures++;
   Print((ok ? "PASS " : "FAIL ")+label);
}
void OnStart()
{
   double s[],identity[],spreads[],restored[];
   ArrayResize(s,PAG_FIELDS); ArrayInitialize(s,0.0);
   ArrayResize(identity,8); ArrayInitialize(identity,17.0);
   s[PG_SCHEMA]=PAG_SCHEMA;
   for(int i=0;i<8;i++) s[PG_IDENTITY+i]=identity[i];
   Check(PAG_Valid(s,identity,5),"empty schema");
   Check(PAG_Parameters(.25,.75,14,20,5,.01,.25,50,2.5,.10,1),"V0 parameter validation");
   Check(!PAG_Parameters(.25,.75,14,20,17,.01,.25,50,2.5,.10,1),"zone capacity refusal");
   Check(PAG_Hedging(2,2) && !PAG_Hedging(0,2),"hedging/netting");
   Check(PAG_Start(s,999,1001,8,.25,.75,10000,0,.25,.01,5,100,60,true,true),"start");
   Check(s[PG_ANCHOR]==1000 && s[PG_SPACE]==6 && s[PG_TARGET]==25,"anchor spacing basket target");
   Check(!PAG_Start(s,1999,2001,80,.25,.75,20000,0,.25,.01,5,101,60,true,true) && s[PG_ANCHOR]==1000,"freeze");
   Check(PAG_Next(1000,6,5,0,1,PAG_RANGE,975,976)==1,"gap nearest anchor");
   Check(PAG_Next(1000,6,5,3,1,PAG_RANGE,975,976)==3,"no refill");
   Check(PAG_Next(1000,6,5,31,1,PAG_RANGE,900,901)==0,"zone clamp");
   Check(!PAG_Permission(PAG_TREND_UP,2) && !PAG_Permission(PAG_TREND_DOWN,1),"regime permissions");
   ArrayResize(spreads,50); ArrayInitialize(spreads,1.0);
   Check(!PAG_Spread(1,spreads,49,50,2.5,.1,20),"spread warmup");
   Check(PAG_Spread(2,spreads,50,50,2.5,.1,20) && !PAG_Spread(2.01,spreads,50,50,2.5,.1,20),"ATR cap");
   Check(!PAG_Baseline(10100,0,10000,0,0,true) && !PAG_Baseline(10000,1,10000,0,0,true),"deposit/credit discontinuity");
   Check(PAG_WriteBank("fixture.",0,s) && PAG_ReadBank("fixture.",restored),"two bank happy");
   fixture_fail_after=7; fixture_writes=0;
   Check(!PAG_WriteBank("fixture.",1,s) && PAG_ReadBank("fixture.",restored),"partial inactive bank preserves active");
   fixture_fail_after=-1;
   PAG_Set("fixture.0.3",2000);
   Check(!PAG_ReadBank("fixture.",restored),"corrupt active bank refused");
   Check(PAG_Target(s,25,1) && !PAG_Target(s,24.99,1),"profit plus swap target boundary");
   s[PG_CLOSE]=1;
   Check(!PAG_Flat(s,false,105,60),"partial close is not flat");
   Check(PAG_Flat(s,true,105,60),"terminal flat verification");
   Check(!PAG_Start(s,999,1001,8,.25,.75,10025,0,.25,.01,5,106,60,true,true),"wait new bar");
   s[PG_RISK]=1;
   Check(!PAG_Start(s,999,1001,8,.25,.75,10025,0,.25,.01,5,120,120,true,true),"shared-risk halt persists");
   PrintFormat("FB-G01 fixture: %d checks, %d failures",fixture_checks,fixture_failures);
}
