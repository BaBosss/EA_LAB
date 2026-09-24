// Engineering conversion fixture only. No includes, trading, market selection,
// timer or trading handlers. Stage B CT alone may compile/run under reservation.
// Default arm is explicit (must compile 0/0). A separately staged test control
// defines DF03_IMPLICIT_ORACLE; its 24 inherited warnings never waive production.
#property strict

// BEGIN SOURCE-BOUND CONVERSIONS
// Raw SHA256: 564099a9e48abffcfbeceb43b3558f9212ece603309eaf15e6947834aa957115
class v { public: static int B1,B2,B3,B4,B5,S1,S2,S3,S4,S5; };
class c { public: static ENUM_TIMEFRAMES Timeframe; };
int v::B1 = 0;
int v::B2 = 0;
int v::B3 = 0;
int v::B4 = 0;
int v::B5 = 0;
int v::S1 = 0;
int v::S2 = 0;
int v::S3 = 0;
int v::S4 = 0;
int v::S5 = 0;
ENUM_TIMEFRAMES c::Timeframe = PERIOD_CURRENT;
struct PriceSelector { string ModeCandleFindBy; };
PriceSelector ObjPrice1;
int identity_calls=0, comment_calls=0, value_calls=0;
long injected_magic=0; string injected_comment="";
template<typename DT1, typename DT2>
double formula(string sign, DT1 v1, DT2 v2)
{
	     if (sign == "+") return(v1 + v2);
	else if (sign == "-") return(v1 - v2);
	else if (sign == "*") return(v1 * v2);
	else if (sign == "/") return(v1 / v2);

	return false;
}
class EEFD { public:
static long StrToInteger(string value){
		return ::StringToInteger(value);
	}
static string StringSubstr(const string string_value, int start_pos, int length = 0){
		return ::StringSubstr(string_value, start_pos, ((length <= 0) ? -1 : length));
	}
static long OrderMagicNumber(){ identity_calls++; return injected_magic; }
static string OrderComment(){ comment_calls++; return injected_comment; }
};
class MDLIC_value_value
{
	public: /* Input Parameters */
	double Value;
	virtual void _callback_(int r) {return;}

	public: /* Constructor */
	MDLIC_value_value()
	{
		Value = (double)1.0;
	}

	public: /* The main method */
	double _execute_()
	{
		return Value;
	}
};
MDLIC_value_value Value1,Value2,Value3,Value4,Value5;
double _Value1_() {value_calls++; return Value1._execute_();}
double _Value2_() {value_calls++; return Value2._execute_();}
double _Value3_() {value_calls++; return Value3._execute_();}
double _Value4_() {value_calls++; return Value4._execute_();}
double _Value5_() {value_calls++; return Value5._execute_();}
void SourceInitialState(){
v::B1 = 1;
v::B2 = 2;
v::B3 = 3;
v::B4 = 4;
v::B5 = 5;
v::S1 = 1;
v::S2 = 2;
v::S3 = 3;
v::S4 = 4;
v::S5 = 5;
}
// RCA 1838; raw RHS offset 57164
int Site0(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B1 = formula(compare, lo, ro);
#else
v::B1 = (int)(formula(compare, lo, ro));
#endif
return v::B1;
}
// RCA 1873; raw RHS offset 57930
int Site1(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B2 = formula(compare, lo, ro);
#else
v::B2 = (int)(formula(compare, lo, ro));
#endif
return v::B2;
}
// RCA 1908; raw RHS offset 58696
int Site2(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B3 = formula(compare, lo, ro);
#else
v::B3 = (int)(formula(compare, lo, ro));
#endif
return v::B3;
}
// RCA 1943; raw RHS offset 59462
int Site3(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B4 = formula(compare, lo, ro);
#else
v::B4 = (int)(formula(compare, lo, ro));
#endif
return v::B4;
}
// RCA 1978; raw RHS offset 60228
int Site4(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S1 = formula(compare, lo, ro);
#else
v::S1 = (int)(formula(compare, lo, ro));
#endif
return v::S1;
}
// RCA 2013; raw RHS offset 60994
int Site5(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S2 = formula(compare, lo, ro);
#else
v::S2 = (int)(formula(compare, lo, ro));
#endif
return v::S2;
}
// RCA 2048; raw RHS offset 61760
int Site6(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S3 = formula(compare, lo, ro);
#else
v::S3 = (int)(formula(compare, lo, ro));
#endif
return v::S3;
}
// RCA 2083; raw RHS offset 62526
int Site7(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S4 = formula(compare, lo, ro);
#else
v::S4 = (int)(formula(compare, lo, ro));
#endif
return v::S4;
}
// RCA 2488; raw RHS offset 73285
int Site8(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S5 = formula(compare, lo, ro);
#else
v::S5 = (int)(formula(compare, lo, ro));
#endif
return v::S5;
}
// RCA 2523; raw RHS offset 74053
int Site9(string compare, double lo, double ro){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B5 = formula(compare, lo, ro);
#else
v::B5 = (int)(formula(compare, lo, ro));
#endif
return v::B5;
}
// RCA 4570; raw RHS offset 131300
string Site10(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
ObjPrice1.ModeCandleFindBy = c::Timeframe;
#else
ObjPrice1.ModeCandleFindBy = (string)(c::Timeframe);
#endif
return ObjPrice1.ModeCandleFindBy;
}
// RCA 7031; raw RHS offset 193773
int Site11(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S1 = _Value1_();
#else
v::S1 = (int)(_Value1_());
#endif
return v::S1;
}
// RCA 7032; raw RHS offset 193796
int Site12(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S2 = _Value2_();
#else
v::S2 = (int)(_Value2_());
#endif
return v::S2;
}
// RCA 7033; raw RHS offset 193819
int Site13(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S3 = _Value3_();
#else
v::S3 = (int)(_Value3_());
#endif
return v::S3;
}
// RCA 7034; raw RHS offset 193842
int Site14(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S4 = _Value4_();
#else
v::S4 = (int)(_Value4_());
#endif
return v::S4;
}
// RCA 7035; raw RHS offset 193865
int Site15(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::S5 = _Value5_();
#else
v::S5 = (int)(_Value5_());
#endif
return v::S5;
}
// RCA 7070; raw RHS offset 194815
int Site16(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B1 = _Value1_();
#else
v::B1 = (int)(_Value1_());
#endif
return v::B1;
}
// RCA 7071; raw RHS offset 194838
int Site17(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B2 = _Value2_();
#else
v::B2 = (int)(_Value2_());
#endif
return v::B2;
}
// RCA 7072; raw RHS offset 194861
int Site18(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B3 = _Value3_();
#else
v::B3 = (int)(_Value3_());
#endif
return v::B3;
}
// RCA 7073; raw RHS offset 194884
int Site19(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B4 = _Value4_();
#else
v::B4 = (int)(_Value4_());
#endif
return v::B4;
}
// RCA 7074; raw RHS offset 194907
int Site20(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
v::B5 = _Value5_();
#else
v::B5 = (int)(_Value5_());
#endif
return v::B5;
}
// RCA 11083; raw RHS offset 306293
int Site21(){
int magic_number;
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
magic_number = EEFD::OrderMagicNumber();
#else
magic_number = (int)(EEFD::OrderMagicNumber());
#endif
return magic_number;
}
// RCA 11627; raw RHS offset 318791
int Site22(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
int ticket_oco = EEFD::StrToInteger(EEFD::StringSubstr(EEFD::OrderComment(), 5, StringLen(EEFD::OrderComment())-1));
#else
int ticket_oco = (int)(EEFD::StrToInteger(EEFD::StringSubstr(EEFD::OrderComment(), 5, StringLen(EEFD::OrderComment())-1)));
#endif
return ticket_oco;
}
// RCA 13756; raw RHS offset 365453
int Site23(){
#ifdef DF03_IMPLICIT_ORACLE
// TEST CONTROL ONLY: original implicit conversion warning expected.
int M       = EEFD::OrderMagicNumber();
#else
int M       = (int)(EEFD::OrderMagicNumber());
#endif
return M;
}
int FormulaSite(int site, string compare, double lo, double ro){
if(site==0) return Site0(compare,lo,ro);
if(site==1) return Site1(compare,lo,ro);
if(site==2) return Site2(compare,lo,ro);
if(site==3) return Site3(compare,lo,ro);
if(site==4) return Site4(compare,lo,ro);
if(site==5) return Site5(compare,lo,ro);
if(site==6) return Site6(compare,lo,ro);
if(site==7) return Site7(compare,lo,ro);
if(site==8) return Site8(compare,lo,ro);
if(site==9) return Site9(compare,lo,ro);
return 0; }
int ResetSite(int site){
if(site==11) return Site11();
if(site==12) return Site12();
if(site==13) return Site13();
if(site==14) return Site14();
if(site==15) return Site15();
if(site==16) return Site16();
if(site==17) return Site17();
if(site==18) return Site18();
if(site==19) return Site19();
if(site==20) return Site20();
return 0; }
int MagicSite(int site){
if(site==21) return Site21();
if(site==23) return Site23();
return 0; }
int FormulaInitial(int site){
if(site==0) return v::B1;
if(site==1) return v::B2;
if(site==2) return v::B3;
if(site==3) return v::B4;
if(site==4) return v::S1;
if(site==5) return v::S2;
if(site==6) return v::S3;
if(site==7) return v::S4;
if(site==8) return v::S5;
if(site==9) return v::B5;
return 0; }
bool TimeBranch(string ModeCandleFindBy){ return ModeCandleFindBy == "time"; }
// END SOURCE-BOUND CONVERSIONS

int rows=0;
void Row(string key,string value)
{
   Print("DF03_ROW|",key,"|",value);
   rows++;
}
string IntText(int value){ return IntegerToString(value); }
string Bytes(string value)
{
   // Exact UTF-16 code units, including length, not locale/display equality.
   string result=IntegerToString(StringLen(value))+":";
   for(int i=0;i<StringLen(value);i++) result+=StringFormat("%04X",(uint)StringGetCharacter(value,i));
   return result;
}
int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return INIT_FAILED;
#ifdef DF03_IMPLICIT_ORACLE
   Print("DF03_ARM|IMPLICIT_TEST_CONTROL");
#else
   Print("DF03_ARM|EXPLICIT");
#endif
   Print("DF03_RUNTIME|",TerminalInfoInteger(TERMINAL_BUILD));
   // Overflow and nonfinite results are observations of the pinned MQL build.
   // No Python model, clamps, rounding changes or expected platform values.
   double values[]={-2147483649.0,-2147483648.75,-2147483648.0,-2147483647.75,
                    -5.999,-5.0,-1.999,-1.0,-0.999,-0.0,0.0,0.999,1.0,1.999,
                    5.0,5.999,2147483646.75,2147483647.0,2147483647.75,
                    2147483648.0,2147483649.0,1.0e100,-1.0e100,0.0,0.0,0.0};
   values[23]=MathArcsin(2.0); // quiet invalid-number domain, compare exact cast result
   values[24]=MathExp(1000.0);
   values[25]=-MathExp(1000.0);
   string signs[]={"+","-","*","/"};
   for(int site=0;site<10;site++)
      for(int op=0;op<4;op++)
         for(int i=0;i<ArraySize(values);i++)
            Row(StringFormat("formula:%d:%d:%d",site,op,i),IntText(FormulaSite(site,signs[op],values[i],5.0)));
   for(int site=11;site<=20;site++)
      for(int i=0;i<ArraySize(values);i++)
      {
         Value1.Value=values[i]; Value2.Value=values[i]; Value3.Value=values[i];
         Value4.Value=values[i]; Value5.Value=values[i]; value_calls=0;
         int result=ResetSite(site);
         Row(StringFormat("reset:%d:%d",site,i),IntText(result)+":"+IntText(value_calls));
      }
   SourceInitialState();
   int initial[]={v::B1,v::B2,v::B3,v::B4,v::B5,v::S1,v::S2,v::S3,v::S4,v::S5};
   for(int i=0;i<10;i++) Row(StringFormat("initial:%d",i),IntText(initial[i]));
   Value1.Value=1.0; Value2.Value=2.0; Value3.Value=3.0; Value4.Value=4.0; Value5.Value=5.0;
   for(int site=11;site<=20;site++)
   {
      value_calls=0;
      int result=ResetSite(site);
      Row(StringFormat("native-reset:%d",site),IntText(result)+":"+IntText(value_calls));
   }
   for(int site=0;site<10;site++)
   {
      // Includes repeated +5 at ordinary state and the positive int32 boundary.
      for(int edge=0;edge<2;edge++)
      {
         SourceInitialState();
         int state=(edge==0 ? FormulaInitial(site) : 2147483637);
         for(int n=0;n<8;n++)
         {
            state=FormulaSite(site,"+",(double)state,5.0);
            Row(StringFormat("repeat:%d:%d:%d",site,edge,n),IntText(state));
         }
      }
   }
   long identities[]={0,-1,1,4023,4028,2147483646,2147483647,2147483648,
                      2147483649,-2147483648,-2147483649,4294967295,4294967296,
                      4294971319,9223372036854775807,-9223372036854775807};
   for(int slot=0;slot<2;slot++)
      for(int i=0;i<ArraySize(identities);i++)
      {
         int site=(slot==0 ? 21 : 23);
         injected_magic=identities[i]; identity_calls=0;
         int result=MagicSite(site);
         Row(StringFormat("magic:%d:%d",site,i),IntText(result)+":"+IntText(identity_calls));
      }
   string comments[]={"","[oco:","[oco:]","[oco:0]","[oco:1]","[oco:-1]",
                      "[oco:+42]","[oco: 42]","[oco:42junk]","[oco:abc]","[oco:42",
                      "[oco:2147483647]","[oco:2147483648]","[oco:-2147483649]",
                      "[oco:4294967296]","[oco:4294971319]","[oco:9223372036854775807]",
                      "[oco:9223372036854775808]","[oco:999999999999999999999999999999]",
                      "[oco:-999999999999999999999999999999]","prefix[oco:1]","[oco:1.5]"};
   for(int i=0;i<ArraySize(comments);i++)
   {
      injected_comment=comments[i]; comment_calls=0;
      int result=Site22(); // Also characterize parser on malformed prefix inputs.
      int calls=comment_calls;
      bool prefix=(EEFD::StringSubstr(EEFD::OrderComment(),0,5)=="[oco:");
      Row(StringFormat("comment:%d",i),IntText(result)+":"+IntText(calls)+":"+IntText((int)prefix));
   }
   ENUM_TIMEFRAMES frames[]={PERIOD_CURRENT,PERIOD_M1,PERIOD_M2,PERIOD_M3,PERIOD_M4,
      PERIOD_M5,PERIOD_M6,PERIOD_M10,PERIOD_M12,PERIOD_M15,PERIOD_M20,PERIOD_M30,
      PERIOD_H1,PERIOD_H2,PERIOD_H3,PERIOD_H4,PERIOD_H6,PERIOD_H8,PERIOD_H12,
      PERIOD_D1,PERIOD_W1,PERIOD_MN1};
   for(int i=0;i<ArraySize(frames);i++)
   {
      c::Timeframe=frames[i];
      string result=Site10();
      Row(StringFormat("timeframe:%d",i),Bytes(result)+":"+IntText((int)TimeBranch(result)));
   }
   Print("DF03_DONE|",rows);
   return INIT_SUCCEEDED;
}
void OnTick() {} // No order, account, chart or market operation.
