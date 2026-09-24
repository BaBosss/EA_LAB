// FB-G01 frozen V0. Dedicated physical cycle owner; no generic grid/exit path.
#ifndef BOSS_LAB_ENTRY_PERSISTENT_ADAPTIVE_GRID_MQH
#define BOSS_LAB_ENTRY_PERSISTENT_ADAPTIVE_GRID_MQH

#define PAG_CAPACITY 16
#define PAG_FIELDS 168
#define PAG_SCHEMA 1
// Snapshot indices. Tickets/identifiers use two uint halves: never cast ulong to double.
enum PAG_FIELD
{
   PG_SCHEMA=0, PG_CYCLE=1, PG_STATE=2, PG_ANCHOR=3, PG_ATR=4, PG_SPACE=5,
   PG_BUY=6, PG_SELL=7, PG_BALANCE=8, PG_CREDIT=9, PG_TARGET=10,
   PG_CLOSE=11, PG_OPEN_TIME=12, PG_CLOSE_TIME=13, PG_WAIT_BAR=14,
   PG_DISCONTINUITY=15, PG_RISK=16, PG_START=17, PG_LOT=18,
   PG_WATER_HI=19, PG_WATER_LO=20, PG_OPEN_INTENT=21, PG_RUNGS=22,
   PG_IDENTITY=24, PG_CONFIG=32, PG_SLOTS=40
};
enum PAG_STATE { PAG_EMPTY=0, PAG_LIVE=1, PAG_WAIT=2 };
enum PAG_REGIME { PAG_HALT_DATA=-1, PAG_RANGE=0, PAG_TREND_UP=1, PAG_TREND_DOWN=2 };

// BEGIN HOST CORE: the deterministic cage executes these production bodies.
bool PAG_Positive(const double x) { return MathIsValidNumber(x) && x>0.0; }
bool PAG_Integer(const double x,const double low,const double high)
{
   return MathIsValidNumber(x) && x>=low && x<=high && x==MathFloor(x);
}
bool PAG_Parameters(const double pct,const double mult,const int atr_period,
                    const int channel,const int rungs,const double lot,
                    const double target,const int samples,const double median_mult,
                    const double atr_cap,const int cooldown)
{
   return PAG_Positive(pct) && PAG_Positive(mult) && atr_period>0 && channel>0 &&
          rungs>0 && rungs<=PAG_CAPACITY && PAG_Positive(lot) && PAG_Positive(target) &&
          samples>0 && PAG_Positive(median_mult) && PAG_Positive(atr_cap) && cooldown>=0;
}
bool PAG_Hedging(const long mode,const long hedging_mode) { return mode==hedging_mode; }
string PAG_IdentityText(const string server,const long login,const string symbol,const long magic)
{
   return "FB-G01/1|"+IntegerToString(StringLen(server))+":"+server+"|"+
      IntegerToString(login)+"|"+IntegerToString(StringLen(symbol))+":"+symbol+"|"+IntegerToString(magic);
}
int PAG_Regime(const double close,const double &highs[],const double &lows[],const int n)
{
   if(!PAG_Positive(close) || n<=0 || ArraySize(highs)!=n || ArraySize(lows)!=n)
      return PAG_HALT_DATA;
   double upper=0.0,lower=1.0e100;
   for(int i=0;i<n;i++)
   {
      if(!PAG_Positive(highs[i]) || !PAG_Positive(lows[i]) || highs[i]<lows[i])
         return PAG_HALT_DATA;
      upper=MathMax(upper,highs[i]); lower=MathMin(lower,lows[i]);
   }
   if(close>upper) return PAG_TREND_UP;
   if(close<lower) return PAG_TREND_DOWN;
   return PAG_RANGE;
}
bool PAG_Permission(const int regime,const int direction)
{
   return (direction==1 && (regime==PAG_RANGE || regime==PAG_TREND_UP)) ||
          (direction==2 && (regime==PAG_RANGE || regime==PAG_TREND_DOWN));
}
int PAG_Bit(const int k) { return 1<<(k-1); }
double PAG_Level(const double anchor,const double spacing,const int direction,const int k)
{
   return anchor+(direction==1 ? -1.0 : 1.0)*k*spacing;
}
int PAG_Next(const double anchor,const double spacing,const int rungs,const int mask,
             const int direction,const int regime,const double bid,const double ask)
{
   if(!PAG_Positive(anchor) || !PAG_Positive(spacing) || !PAG_Positive(bid) ||
      !PAG_Positive(ask) || ask<=bid || rungs<1 || rungs>PAG_CAPACITY ||
      !PAG_Permission(regime,direction)) return 0;
   for(int k=1;k<=rungs;k++)
   {
      if((mask&PAG_Bit(k))!=0) continue;
      double level=PAG_Level(anchor,spacing,direction,k);
      if((direction==1 && ask<=level) || (direction==2 && bid>=level)) return k;
   }
   return 0;
}
bool PAG_Spread(const double spread,const double &samples[],const int count,
                const int required,const double mult,const double cap,const double atr)
{
   if(required<=0 || count<required || ArraySize(samples)!=required ||
      !PAG_Positive(spread) || !PAG_Positive(atr) || !PAG_Positive(mult) || !PAG_Positive(cap))
      return false;
   double sorted[];
   ArrayResize(sorted,required);
   for(int i=0;i<required;i++)
   {
      if(!PAG_Positive(samples[i])) return false;
      sorted[i]=samples[i];
   }
   ArraySort(sorted);
   double median=sorted[required/2];
   if(required%2==0) median=(sorted[required/2-1]+median)/2.0;
   return spread<=mult*median && spread<=cap*atr;
}
bool PAG_Start(double &s[],const double bid,const double ask,const double atr,
               const double pct,const double mult,const double balance,const double credit,
               const double target_pct,const double lot,const int rungs,const long now,
               const long bar,const bool flat,const bool ready)
{
   if(!flat || !ready || s[PG_STATE]==PAG_LIVE || s[PG_CLOSE]!=0 || s[PG_RISK]!=0 ||
      (s[PG_STATE]==PAG_WAIT && bar<=s[PG_WAIT_BAR]) || bar<=0 || now<=0 ||
      !PAG_Positive(bid) || !PAG_Positive(ask) || ask<=bid || !PAG_Positive(atr) ||
      !PAG_Positive(balance) || !MathIsValidNumber(credit) || !PAG_Positive(lot)) return false;
   double anchor=(bid+ask)/2.0,spacing=MathMax(anchor*pct/100.0,atr*mult);
   double target=balance*target_pct/100.0;
   if(!PAG_Positive(anchor) || !PAG_Positive(spacing) || !PAG_Positive(target) ||
      anchor-rungs*spacing<=0.0 || s[PG_CYCLE]>=9007199254740990.0) return false;
   for(int i=PG_SLOTS;i<PAG_FIELDS;i++) s[i]=0.0;
   s[PG_CYCLE]++; s[PG_STATE]=PAG_LIVE; s[PG_ANCHOR]=anchor; s[PG_ATR]=atr;
   s[PG_SPACE]=spacing; s[PG_BUY]=0; s[PG_SELL]=0; s[PG_BALANCE]=balance;
   s[PG_CREDIT]=credit; s[PG_TARGET]=target; s[PG_DISCONTINUITY]=0;
   s[PG_START]=(double)now; s[PG_LOT]=lot; s[PG_RUNGS]=rungs;
   s[PG_OPEN_INTENT]=0;
   return true;
}
bool PAG_Target(const double &s[],const double profit,const int positions)
{
   return s[PG_STATE]==PAG_LIVE && positions>0 && MathIsValidNumber(profit) &&
          PAG_Positive(s[PG_TARGET]) && profit>=s[PG_TARGET];
}
bool PAG_Flat(double &s[],const bool flat,const long now,const long bar)
{
   if(!flat || s[PG_CLOSE]!=1 || s[PG_STATE]!=PAG_LIVE || now<=0 || bar<=0) return false;
   s[PG_STATE]=PAG_WAIT; s[PG_CLOSE]=0; s[PG_CLOSE_TIME]=(double)now;
   s[PG_WAIT_BAR]=(double)bar; s[PG_OPEN_INTENT]=0;
   // Retain cycle geometry, baseline, target, masks and identifiers as terminal summary.
   return true;
}
bool PAG_Baseline(const double balance,const double credit,const double initial_balance,
                  const double initial_credit,const double realized,const bool history_ready)
{
   return history_ready && MathIsValidNumber(balance) && MathIsValidNumber(credit) &&
          MathIsValidNumber(realized) && MathAbs(credit-initial_credit)<0.0000001 &&
          MathAbs(balance-initial_balance-realized)<0.0000001;
}
bool PAG_CanAdd(const double &s[],const bool safety,const long now,const int cooldown)
{
   return safety && s[PG_STATE]==PAG_LIVE && s[PG_CLOSE]==0 && s[PG_RISK]==0 &&
          s[PG_DISCONTINUITY]==0 && s[PG_OPEN_INTENT]==0 &&
          now>=s[PG_OPEN_TIME] && now-s[PG_OPEN_TIME]>=cooldown;
}
int PAG_Slot(const int direction,const int k) { return PG_SLOTS+((direction-1)*PAG_CAPACITY+k-1)*4; }
bool PAG_Valid(const double &s[],const double &identity[],const int rungs)
{
   if(ArraySize(s)!=PAG_FIELDS || ArraySize(identity)!=8 || s[PG_SCHEMA]!=PAG_SCHEMA) return false;
   for(int i=0;i<PAG_FIELDS;i++) if(!MathIsValidNumber(s[i])) return false;
   for(int i=0;i<8;i++) if(s[PG_IDENTITY+i]!=identity[i]) return false;
   if(!PAG_Integer(s[PG_CYCLE],0,9007199254740990.0) ||
      !PAG_Integer(s[PG_STATE],PAG_EMPTY,PAG_WAIT) ||
      !PAG_Integer(s[PG_BUY],0,(1<<rungs)-1) || !PAG_Integer(s[PG_SELL],0,(1<<rungs)-1) ||
      !PAG_Integer(s[PG_CLOSE],0,1) || !PAG_Integer(s[PG_RISK],0,1) ||
      !PAG_Integer(s[PG_DISCONTINUITY],0,1) || !PAG_Integer(s[PG_OPEN_INTENT],0,2*PAG_CAPACITY) ||
      !PAG_Integer(s[PG_WATER_HI],0,4294967295.0) || !PAG_Integer(s[PG_WATER_LO],0,4294967295.0) ||
      s[23]!=0) return false;
   for(int i=PG_OPEN_TIME;i<=PG_WAIT_BAR;i++) if(!PAG_Integer(s[i],0,9007199254740990.0)) return false;
   if(!PAG_Integer(s[PG_START],0,9007199254740990.0)) return false;
   if(s[PG_STATE]==PAG_EMPTY)
   {
      for(int i=PG_CYCLE;i<PG_IDENTITY;i++) if(i!=PG_RISK && s[i]!=0) return false;
   }
   else
   {
      if(s[PG_CYCLE]<1 || s[PG_RUNGS]!=rungs || !PAG_Positive(s[PG_ANCHOR]) ||
         !PAG_Positive(s[PG_ATR]) || !PAG_Positive(s[PG_SPACE]) || !PAG_Positive(s[PG_BALANCE]) ||
         !PAG_Positive(s[PG_TARGET]) || !PAG_Positive(s[PG_LOT]) || s[PG_START]<=0 ||
         s[PG_ANCHOR]-rungs*s[PG_SPACE]<=0) return false;
      if(s[PG_STATE]==PAG_WAIT && (s[PG_CLOSE]!=0 || s[PG_WAIT_BAR]<=0 || s[PG_CLOSE_TIME]<=0)) return false;
   }
   for(int direction=1;direction<=2;direction++)
      for(int k=1;k<=PAG_CAPACITY;k++)
      {
         int p=PAG_Slot(direction,k);
         int mask=(int)s[direction==1 ? PG_BUY : PG_SELL];
         bool filled=k<=rungs && (mask&PAG_Bit(k))!=0;
         if(!PAG_Integer(s[p],0,4294967295.0) || !PAG_Integer(s[p+1],0,4294967295.0)) return false;
         if(filled)
         {
            if((s[p]==0 && s[p+1]==0) || s[p+2]!=s[PG_LOT] || !PAG_Positive(s[p+3])) return false;
            for(int q=PG_SLOTS;q<p;q+=4) if(s[q]==s[p] && s[q+1]==s[p+1]) return false;
         }
         else if(s[p]!=0 || s[p+1]!=0 || s[p+2]!=0 || s[p+3]!=0) return false;
      }
   return true;
}
// bank backend is wrapped below for deterministic failure injection in the cage.
bool PAG_WriteBank(const string prefix,const int bank,const double &s[])
{
   string key=prefix+IntegerToString(bank)+".";
   double checksum[];
   if(!PAG_Digest(s,checksum)) return false;
   if(!PAG_Set(key+"complete",0)) return false;
   for(int i=0;i<PAG_FIELDS;i++) if(!PAG_Set(key+IntegerToString(i),s[i])) return false;
   for(int i=0;i<8;i++) if(!PAG_Set(key+"hash"+IntegerToString(i),checksum[i])) return false;
   if(!PAG_Set(key+"complete",PAG_SCHEMA)) return false;
   PAG_Flush();
   // Commit point LAST. A torn inactive bank cannot replace a complete active bank.
   if(!PAG_Set(prefix+"active",bank)) return false;
   PAG_Flush();
   return true;
}
bool PAG_ReadBank(const string prefix,double &s[])
{
   double bank=0,complete=0;
   if(!PAG_Get(prefix+"active",bank) || !PAG_Integer(bank,0,1)) return false;
   string key=prefix+IntegerToString((int)bank)+".";
   if(!PAG_Get(key+"complete",complete) || complete!=PAG_SCHEMA) return false;
   ArrayResize(s,PAG_FIELDS);
   for(int i=0;i<PAG_FIELDS;i++) if(!PAG_Get(key+IntegerToString(i),s[i])) return false;
   double checksum[];
   if(!PAG_Digest(s,checksum)) return false;
   for(int i=0;i<8;i++)
   {
      double stored=0;
      if(!PAG_Get(key+"hash"+IntegerToString(i),stored) || stored!=checksum[i]) return false;
   }
   return true;
}
// END HOST CORE

#ifndef PAG_HELPERS_ONLY
double g_pag_state[],g_pag_identity[],g_pag_config[],g_pag_spreads[];
string g_pag_prefix="";
bool g_pag_fault=false,g_pag_loaded=false,g_pag_lease=false;
int g_pag_bank=-1,g_pag_atr_handle=INVALID_HANDLE,g_pag_count=0,g_pag_cursor=0;
int g_pag_regime=PAG_HALT_DATA;
datetime g_pag_bar=0;

bool PAG_Set(const string key,const double value) { return GlobalVariableSet(key,value)!=0; }
bool PAG_Get(const string key,double &value) { return GlobalVariableGet(key,value); }
void PAG_Flush() { GlobalVariablesFlush(); }
bool PAG_HashText(const string text,double &words[],string &hex)
{
   uchar bytes[],key[],hash[];
   int n=StringToCharArray(text,bytes,0,WHOLE_ARRAY,CP_UTF8);
   if(n<=1) return false;
   ArrayResize(bytes,n-1);
   if(CryptEncode(CRYPT_HASH_SHA256,bytes,key,hash)!=32) return false;
   ArrayResize(words,8); hex="";
   for(int i=0;i<32;i++) hex+=StringFormat("%02x",(uint)hash[i]);
   for(int i=0;i<8;i++)
   {
      uint word=0;
      for(int j=0;j<4;j++) word=(word<<8)|(uint)hash[i*4+j];
      words[i]=(double)word;
   }
   return true;
}
bool PAG_Digest(const double &s[],double &words[])
{
   string text="",hex="";
   for(int i=0;i<ArraySize(s);i++) text+=CFG_CanonDouble(s[i])+"|";
   return PAG_HashText(text,words,hex);
}

void PAG_Halt(const string reason)
{
   if(!g_pag_fault) Print("[FB-G01] PERSISTENCE_MISMATCH_HALT: "+reason);
   g_pag_fault=true;
}
bool PAG_Commit()
{
   if(g_pag_fault || !PAG_Valid(g_pag_state,g_pag_identity,_25_MaxRungsPerSide))
   { PAG_Halt("snapshot invalid before commit"); return false; }
   int next=(g_pag_bank==0 ? 1 : 0);
   if(!PAG_WriteBank(g_pag_prefix,next,g_pag_state))
   { PAG_Halt("two-bank write failed"); return false; }
   g_pag_bank=next;
   return true;
}
ulong PAG_Id(const double &s[],const int p)
{
   return ((ulong)(uint)s[p]<<32)|(ulong)(uint)s[p+1];
}
void PAG_PutId(double &s[],const int p,const ulong id)
{
   s[p]=(double)(uint)(id>>32); s[p+1]=(double)(uint)(id&0xffffffff);
}
bool PAG_Namespace()
{
   string raw=PAG_IdentityText(AccountInfoString(ACCOUNT_SERVER),AccountInfoInteger(ACCOUNT_LOGIN),_Symbol,_0_Magic);
   string hex="";
   if(!PAG_HashText(raw,g_pag_identity,hex)) return false;
   // 160-bit locator + full 256-bit identity in each bank detects locator collisions.
   g_pag_prefix="PAG25."+StringSubstr(hex,0,40)+".";
   string config=CFG_Fingerprint();
   return config!="" && StringLen(g_pag_prefix)+12<=63 &&
      PAG_HashText(config+"|"+IntegerToString((int)_Period),g_pag_config,hex);
}
bool PersistentAdaptiveGrid_ConfigValid()
{
   if(!PAG_Parameters(_25_GridPct,_25_GridATRMult,_25_ATRPeriod,_25_DonchianBars,
      _25_MaxRungsPerSide,_25_FixedLot,_25_BasketTargetBalancePct,_25_SpreadSamples,
      _25_SpreadMedianMult,_25_SpreadATRCap,_25_OpenCooldownSec)) return false;
   if(!PAG_Hedging(AccountInfoInteger(ACCOUNT_MARGIN_MODE),ACCOUNT_MARGIN_MODE_RETAIL_HEDGING))
   { Print("[FB-G01] INIT REFUSED: hedging account required; netting refused"); return false; }
   if(DryRun || _MG_SelfGate)
   { Print("[FB-G01] INIT REFUSED: DryRun and macro self-gate unsupported by persistent V0"); return false; }
   return true;
}
// Every live position must match a filled slot by immutable identifier, side,
// original open price and volume. CLOSE_INTENT allows only monotonic reductions.
bool PAG_Inventory(const bool closing,int &positions,int &pending,double &profit)
{
   positions=0; pending=0; profit=0.0;
   bool seen[]; ArrayResize(seen,2*PAG_CAPACITY); ArrayInitialize(seen,false);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0) return false;
      if(!Exec_IdentityIsMine(PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_MAGIC))) continue;
      positions++;
      ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      int direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : 2);
      double volume=PositionGetDouble(POSITION_VOLUME),price=PositionGetDouble(POSITION_PRICE_OPEN);
      bool found=false;
      for(int k=1;k<=_25_MaxRungsPerSide;k++)
      {
         int p=PAG_Slot(direction,k),index=(direction-1)*PAG_CAPACITY+k-1;
         if(id==0 || id!=PAG_Id(g_pag_state,p)) continue;
         if(seen[index] || price!=g_pag_state[p+3] || !PAG_Positive(volume) ||
            (closing ? volume>g_pag_state[p+2]+1e-9 : MathAbs(volume-g_pag_state[p+2])>1e-9)) return false;
         seen[index]=true; found=true; break;
      }
      if(!found) return false;
      double value=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      if(!MathIsValidNumber(value)) return false;
      profit+=value;
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(OrderGetTicket(i)==0) return false;
      if(Exec_IdentityIsMine(OrderGetString(ORDER_SYMBOL),OrderGetInteger(ORDER_MAGIC))) pending++;
   }
   if(pending!=0) return false; // this strategy never places/adopts a pending order
   if(g_pag_state[PG_STATE]!=PAG_LIVE) return positions==0;
   if(!closing)
      for(int d=1;d<=2;d++) for(int k=1;k<=_25_MaxRungsPerSide;k++)
      {
         bool filled=(((int)g_pag_state[d==1 ? PG_BUY : PG_SELL])&PAG_Bit(k))!=0;
         if(filled!=seen[(d-1)*PAG_CAPACITY+k-1]) return false;
      }
   return true;
}
bool PAG_HistoryWatermark(ulong &watermark)
{
   watermark=0;
   if(!HistorySelect(0,TimeCurrent())) return false;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0) return false;
      if(ticket>watermark) watermark=ticket;
   }
   return true;
}
bool PAG_AccountUnchanged()
{
   if(!HistorySelect((datetime)g_pag_state[PG_START],TimeCurrent())) return false;
   double realized=0;
   ulong watermark=PAG_Id(g_pag_state,PG_WATER_HI);
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      ulong ticket=HistoryDealGetTicket(i);
      if(ticket==0) return false;
      if(ticket<=watermark) continue;
      if(!Exec_IdentityIsMine(HistoryDealGetString(ticket,DEAL_SYMBOL),HistoryDealGetInteger(ticket,DEAL_MAGIC))) continue;
      long type=HistoryDealGetInteger(ticket,DEAL_TYPE);
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
      realized+=HistoryDealGetDouble(ticket,DEAL_PROFIT)+HistoryDealGetDouble(ticket,DEAL_SWAP)+
                HistoryDealGetDouble(ticket,DEAL_COMMISSION)+HistoryDealGetDouble(ticket,DEAL_FEE);
   }
   return PAG_Baseline(AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_CREDIT),
      g_pag_state[PG_BALANCE],g_pag_state[PG_CREDIT],realized,true);
}
double PAG_LoadATR()
{
   double values[];
   if(CopyBuffer(g_pag_atr_handle,0,1,1,values)!=1 || !PAG_Positive(values[0])) return 0.0;
   return values[0];
}
void PAG_LoadRegime(const datetime bar)
{
   if(bar<=0) { g_pag_regime=PAG_HALT_DATA; return; }
   if(bar==g_pag_bar && g_pag_regime!=PAG_HALT_DATA) return;
   g_pag_bar=bar; g_pag_regime=PAG_HALT_DATA;
   double highs[],lows[],close[];
   if(CopyHigh(_Symbol,_Period,2,_25_DonchianBars,highs)!=_25_DonchianBars ||
      CopyLow(_Symbol,_Period,2,_25_DonchianBars,lows)!=_25_DonchianBars ||
      CopyClose(_Symbol,_Period,1,1,close)!=1) return;
   g_pag_regime=PAG_Regime(close[0],highs,lows,_25_DonchianBars);
}
bool PAG_Safety()
{
   return !RiskControl_IsHalted() && !g_rc_kill_pending && RiskControl_AllowNewOrder() &&
      RiskControl_AcctGateOK() && !Exec_NewsBlocked() && !Exec_MacroBlocked() &&
      Exec_SpreadOK();
}
bool PAG_RequestQuote(const MqlTick &quote,const double atr)
{
   return PAG_Positive(quote.bid) && PAG_Positive(quote.ask) &&
      PAG_Spread(quote.ask-quote.bid,g_pag_spreads,g_pag_count,_25_SpreadSamples,
                  _25_SpreadMedianMult,_25_SpreadATRCap,atr);
}
bool PAG_RecordFill(const int direction,const int k,const ulong deal)
{
   if(deal==0 || !HistoryDealSelect(deal)) return false;
   ulong id=(ulong)HistoryDealGetInteger(deal,DEAL_POSITION_ID);
   if(id==0) return false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      if(PositionGetTicket(i)==0) return false;
      if(!Exec_IdentityIsMine(PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_MAGIC)) ||
         (ulong)PositionGetInteger(POSITION_IDENTIFIER)!=id) continue;
      if((PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? 1 : 2)!=direction ||
         MathAbs(PositionGetDouble(POSITION_VOLUME)-g_pag_state[PG_LOT])>1e-9) return false;
      int p=PAG_Slot(direction,k);
      PAG_PutId(g_pag_state,p,id);
      g_pag_state[p+2]=PositionGetDouble(POSITION_VOLUME);
      g_pag_state[p+3]=PositionGetDouble(POSITION_PRICE_OPEN);
      int m=(direction==1 ? PG_BUY : PG_SELL);
      g_pag_state[m]=(int)g_pag_state[m]|PAG_Bit(k);
      g_pag_state[PG_OPEN_TIME]=(double)TimeCurrent();
      g_pag_state[PG_OPEN_INTENT]=0;
      int positions,pending; double profit;
      return PAG_Inventory(false,positions,pending,profit) && PAG_Commit();
   }
   return false;
}
void PAG_OpenOne(const double atr)
{
   if(!PAG_CanAdd(g_pag_state,PAG_Safety(),(long)TimeCurrent(),_25_OpenCooldownSec)) return;
   int positions,pending; double profit;
   if(!PAG_Inventory(false,positions,pending,profit)) { PAG_Halt("pre-request inventory"); return; }
   if(positions>=2*_25_MaxRungsPerSide || positions>=RiskControl_MaxLevels()) return;
   double lot=Exec_NormalizeLot(_25_FixedLot);
   // A dynamic MacroGate lot reduction cannot change a frozen flat rung lot.
   if(lot!=g_pag_state[PG_LOT] || Exec_MacroLotMult()!=1.0) return;
   MqlTick quote;
   if(!SymbolInfoTick(_Symbol,quote) || !PAG_RequestQuote(quote,atr)) return;
   int direction=1;
   int k=PAG_Next(g_pag_state[PG_ANCHOR],g_pag_state[PG_SPACE],_25_MaxRungsPerSide,
      (int)g_pag_state[PG_BUY],1,g_pag_regime,quote.bid,quote.ask);
   if(k==0)
   {
      direction=2;
      k=PAG_Next(g_pag_state[PG_ANCHOR],g_pag_state[PG_SPACE],_25_MaxRungsPerSide,
         (int)g_pag_state[PG_SELL],2,g_pag_regime,quote.bid,quote.ask);
   }
   if(k==0) return;
   double price=(direction==1 ? quote.ask : quote.bid),margin=0;
   if(!OrderCalcMargin(direction==1 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,lot,price,margin) ||
      !MathIsValidNumber(margin) || margin<0 || margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) return;
   // Crash between submission and inventory commit must never replay an uncertain rung.
   g_pag_state[PG_OPEN_INTENT]=(direction-1)*PAG_CAPACITY+k;
   if(!PAG_Commit()) return;
   // Re-read after persistence IO; bind both crossing and spread to THIS request quote.
   if(!SymbolInfoTick(_Symbol,quote) || !PAG_RequestQuote(quote,PAG_LoadATR()) || !PAG_Safety() ||
      PAG_Next(g_pag_state[PG_ANCHOR],g_pag_state[PG_SPACE],_25_MaxRungsPerSide,
       (int)g_pag_state[direction==1 ? PG_BUY : PG_SELL],direction,g_pag_regime,quote.bid,quote.ask)!=k)
   { g_pag_state[PG_OPEN_INTENT]=0; PAG_Commit(); return; }
   price=(direction==1 ? quote.ask : quote.bid);
   // Existing FB-A01 exact-quote CTrade pattern. No zero-price refresh, pending or retry loop.
   bool sent=(direction==1 ? g_trade.Buy(lot,_Symbol,price,0,0,LAB_ENTRY_TAG)
                           : g_trade.Sell(lot,_Symbol,price,0,0,LAB_ENTRY_TAG));
   uint result=g_trade.ResultRetcode();
   if(!sent || result!=TRADE_RETCODE_DONE || !PAG_RecordFill(direction,k,g_trade.ResultDeal()))
      PAG_Halt("unconfirmed/partial order: committed OPEN_INTENT retained; no replay");
}
void PAG_CloseTick()
{
   // CLOSE_INTENT was durably committed before entering this function.
   Exec_CloseAll();
   int positions,pending; double profit;
   if(!PAG_Inventory(true,positions,pending,profit)) { PAG_Halt("close reconciliation"); return; }
   if(PAG_Flat(g_pag_state,positions==0 && pending==0,(long)TimeCurrent(),(long)iTime(_Symbol,_Period,0)))
      PAG_Commit();
}
bool PersistentAdaptiveGrid_Init()
{
   g_pag_fault=false; g_pag_loaded=false; g_pag_bank=-1; g_pag_count=0; g_pag_cursor=0;
   g_pag_bar=0; g_pag_regime=PAG_HALT_DATA;
   if(!PAG_Namespace()) return false;
   // One writer per account/symbol/magic. Temporary GV disappears on terminal exit;
   // ordinary detach releases it. An abandoned lease refuses init until normal recovery.
   if(!GlobalVariableTemp(g_pag_prefix+"lease") ||
      !GlobalVariableSetOnCondition(g_pag_prefix+"lease",1.0,0.0))
   { Print("[FB-G01] INIT REFUSED: namespace already leased"); return false; }
   g_pag_lease=true;
   if(ArrayResize(g_pag_spreads,_25_SpreadSamples)!=_25_SpreadSamples) return false;
   ArrayInitialize(g_pag_spreads,0.0);
   g_pag_atr_handle=iATR(_Symbol,_Period,_25_ATRPeriod);
   if(g_pag_atr_handle==INVALID_HANDLE) return false;
   ArrayResize(g_pag_state,PAG_FIELDS); ArrayInitialize(g_pag_state,0.0);
   if(GlobalVariableCheck(g_pag_prefix+"active"))
   {
      if(!PAG_ReadBank(g_pag_prefix,g_pag_state) || !PAG_Valid(g_pag_state,g_pag_identity,_25_MaxRungsPerSide))
      { PAG_Halt("missing/corrupt/schema/identity snapshot"); return true; }
      g_pag_bank=(int)GlobalVariableGet(g_pag_prefix+"active");
      for(int i=0;i<8;i++) if(g_pag_state[PG_CONFIG+i]!=g_pag_config[i])
      { PAG_Halt("configuration/timeframe changed across persisted cycle"); return true; }
      g_pag_loaded=true;
      if(g_pag_state[PG_OPEN_INTENT]!=0) { PAG_Halt("unresolved OPEN_INTENT"); return true; }
      int positions,pending; double profit;
      if(!PAG_Inventory(g_pag_state[PG_CLOSE]==1 || g_pag_state[PG_RISK]==1,positions,pending,profit))
         PAG_Halt("live inventory differs from committed snapshot");
   }
   else
   {
      // A partial initial write is evidence of unresolved state, not a fresh start.
      for(int i=GlobalVariablesTotal()-1;i>=0;i--)
         if(StringFind(GlobalVariableName(i),g_pag_prefix)==0 && GlobalVariableName(i)!=g_pag_prefix+"lease")
         { PAG_Halt("orphan bank without selector"); return true; }
      int positions,pending; double profit;
      if(!PAG_Inventory(false,positions,pending,profit))
      { PAG_Halt("uncommitted owned inventory"); return true; }
      g_pag_state[PG_SCHEMA]=PAG_SCHEMA;
      for(int i=0;i<8;i++) g_pag_state[PG_IDENTITY+i]=g_pag_identity[i];
      for(int i=0;i<8;i++) g_pag_state[PG_CONFIG+i]=g_pag_config[i];
      g_pag_loaded=PAG_Commit();
   }
   return true;
}
void PersistentAdaptiveGrid_SharedHalt()
{
   if(g_pag_loaded && !g_pag_fault && g_pag_state[PG_RISK]!=1)
   { g_pag_state[PG_RISK]=1; PAG_Commit(); }
   // Keep the strategy halt and writer lease alive even while LabCore bypasses OnTick.
   if(g_pag_loaded && !g_pag_fault && !PAG_DiskMatches()) PAG_Halt("halt snapshot/lease unavailable");
}
bool PAG_DiskMatches()
{
   double lease=0,disk[];
   if(!PAG_Get(g_pag_prefix+"lease",lease) || lease!=1 || !PAG_ReadBank(g_pag_prefix,disk)) return false;
   for(int i=0;i<PAG_FIELDS;i++) if(disk[i]!=g_pag_state[i]) return false;
   return true;
}
void PersistentAdaptiveGrid_OnTick()
{
   if(g_pag_fault || !g_pag_loaded) return; // shared hard RiskControl still runs in LabCore
   // Reading the complete active snapshot also keeps all GV fields alive through long cycles.
   if(!PAG_DiskMatches()) { PAG_Halt("concurrent snapshot mutation or missing bank/lease"); return; }
   if(g_pag_state[PG_RISK]!=0) return;
   int positions,pending; double profit;
   if(!PAG_Inventory(g_pag_state[PG_CLOSE]==1,positions,pending,profit))
   { PAG_Halt("inventory mismatch on tick"); return; }
   if(g_pag_state[PG_STATE]==PAG_LIVE && g_pag_state[PG_DISCONTINUITY]==0 && !PAG_AccountUnchanged())
   {
      g_pag_state[PG_DISCONTINUITY]=1;
      Print("[FB-G01] ACCOUNT_BASELINE_DISCONTINUITY: frozen target retained; new rungs blocked");
      if(!PAG_Commit()) return;
   }
   if(g_pag_state[PG_CLOSE]==1) { PAG_CloseTick(); return; }
   if(PAG_Target(g_pag_state,profit,positions))
   {
      g_pag_state[PG_CLOSE]=1;
      if(PAG_Commit()) PAG_CloseTick();
      return;
   }
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick)) return;
   double spread=tick.ask-tick.bid;
   if(PAG_Positive(spread))
   {
      g_pag_spreads[g_pag_cursor]=spread; g_pag_cursor=(g_pag_cursor+1)%_25_SpreadSamples;
      if(g_pag_count<_25_SpreadSamples) g_pag_count++;
   }
   datetime bar=iTime(_Symbol,_Period,0);
   PAG_LoadRegime(bar);
   double atr=PAG_LoadATR();
   if(g_pag_regime==PAG_HALT_DATA || !PAG_RequestQuote(tick,atr) || !PAG_Safety()) return;
   if(g_pag_state[PG_STATE]!=PAG_LIVE)
   {
      ulong watermark=0;
      if(!PAG_HistoryWatermark(watermark)) return;
      double lot=Exec_NormalizeLot(_25_FixedLot);
      if(MathAbs(lot-_25_FixedLot)>1e-9) PrintFormat("[FB-G01] broker/cap normalized rung lot %.8f -> %.8f",_25_FixedLot,lot);
      if(!PAG_Start(g_pag_state,tick.bid,tick.ask,atr,_25_GridPct,_25_GridATRMult,
         AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_CREDIT),_25_BasketTargetBalancePct,
         lot,_25_MaxRungsPerSide,(long)TimeCurrent(),(long)bar,positions==0 && pending==0,true)) return;
      PAG_PutId(g_pag_state,PG_WATER_HI,watermark);
      if(!PAG_Commit()) return;
   }
   PAG_OpenOne(atr);
}
void PersistentAdaptiveGrid_Deinit()
{
   if(g_pag_atr_handle!=INVALID_HANDLE) IndicatorRelease(g_pag_atr_handle);
   g_pag_atr_handle=INVALID_HANDLE;
   if(g_pag_lease) GlobalVariableSetOnCondition(g_pag_prefix+"lease",0.0,1.0);
   g_pag_lease=false;
}
#endif // PAG_HELPERS_ONLY
#endif
