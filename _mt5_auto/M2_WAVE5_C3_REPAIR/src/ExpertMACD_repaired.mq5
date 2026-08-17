//+------------------------------------------------------------------+
//|                                                   ExpertMACD.mq5 |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
//| WAVE5 CANDIDATE 3 -- M2 EXECUTION DEFECT REPAIR.                  |
//|                                                                   |
//| DEFECT (shared, both directions, spread/quote dependent):          |
//|   CExpertSignal::OpenLongParams/OpenShortParams anchor the stop to |
//|   the ENTRY-side quote (Ask for a buy, Bid for a sell) while the   |
//|   server validates that stop against the EXIT-side quote (Bid for  |
//|   a buy, Ask for a sell). The two differ by the full spread, so    |
//|   the server-side stop distance is (StopLoss - spread), not        |
//|   StopLoss. On 5-digit NZDUSD StopLoss=20 adjusted points = 200    |
//|   raw points; in the 00:02-00:05 rollover window the NZDUSD spread |
//|   widens to 233-250 points, which drives the server-side distance  |
//|   NEGATIVE (-33..-50 pts) -- the stop is placed on the WRONG SIDE  |
//|   of the validating price and the order is rejected [Invalid       |
//|   stops]. Take-profit is never affected: the same spread shift     |
//|   moves TP AWAY from the validating price (+733..+750 pts).        |
//|                                                                   |
//| REPAIR (minimum, semantics-preserving):                            |
//|   A pre-send validator refuses the entry when the requested levels |
//|   are not placeable at the live quote. It NEVER rewrites a level.  |
//|   StopLoss=20 / TakeProfit=50 keep their exact meaning; risk is    |
//|   not widened and R:R is not altered.                              |
//|                                                                   |
//|   Why refuse rather than clamp: when spread (233-250 pts) already  |
//|   exceeds the stop budget (200 pts), the position is beyond its    |
//|   own stop at the instant of fill. No legal price is both 20 pips  |
//|   from entry and on the correct side of the exit quote, so every   |
//|   clamp would have to change what "Stop=20" means -- pushing the   |
//|   stop out to the exit-side quote silently widens real risk to     |
//|   20 pips PLUS the 25-pip spread already paid, and pulling it in   |
//|   creates an instant stop-out. Refusing is the only action that    |
//|   leaves the frozen semantics intact.                              |
//|                                                                   |
//|   Behaviour on the M2 window is therefore IDENTICAL: the five      |
//|   refused orders are exactly the five the broker already rejected, |
//|   so no trade is added or removed -- only the invalid requests     |
//|   stop being sent. Control flow is preserved too: returning false  |
//|   from OpenLongParams makes CExpertSignal::CheckOpenLong return    |
//|   false, which is the same path CExpert already took when          |
//|   CTrade::Buy failed, including the fall-through to CheckOpenShort.|
//|                                                                   |
//| The guard counts and prints every refusal (and the number of       |
//| entries it evaluated) at OnDeinit. A guard that cannot say how     |
//| many times it fired is not evidence -- a run in which it fires 0   |
//| times must read as UNTESTED, not as passed.                        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
#include <Expert\Signal\SignalMACD.mqh>
#include <Expert\Trailing\TrailingNone.mqh>
#include <Expert\Money\MoneyNone.mqh>
//--- the stop-validity arithmetic, kept pure and in one place so the focused
//--- test harness drives THIS code and not a second copy of it
#include "M2W5C3_StopGuard.mqh"
//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
//--- inputs for expert
input string Inp_Expert_Title            ="ExpertMACD";
int          Expert_MagicNumber          =10981;
bool         Expert_EveryTick            =false;
//--- inputs for signal
input int    Inp_Signal_MACD_PeriodFast  =12;
input int    Inp_Signal_MACD_PeriodSlow  =24;
input int    Inp_Signal_MACD_PeriodSignal=9;
input int    Inp_Signal_MACD_TakeProfit  =50;
input int    Inp_Signal_MACD_StopLoss    =20;
//+------------------------------------------------------------------+
//| Stop-guard instrumentation counters                              |
//+------------------------------------------------------------------+
long g_sg_evaluated      =0;   // entry level-sets examined
long g_sg_refused        =0;   // entries refused as unplaceable
long g_sg_refused_buy    =0;
long g_sg_refused_sell   =0;
long g_sg_refused_sl     =0;   // refusals attributable to the stop-loss leg
long g_sg_refused_tp     =0;   // refusals attributable to the take-profit leg
//+------------------------------------------------------------------+
//| Signal with a broker-validity gate in front of every entry        |
//+------------------------------------------------------------------+
class CSignalMACDStopSafe : public CSignalMACD
  {
protected:
   double            MinStopDistance(void);
   double            NormalizePriceToTick(const double price);
   bool              AreBuyStopsValid(const double sl,const double tp,
                                      const double bid,const double ask);
   bool              AreSellStopsValid(const double sl,const double tp,
                                       const double bid,const double ask);
   void              LogStopGuard(const string side,const double price,
                                  const double sl,const double tp,
                                  const double bid,const double ask);
public:
   virtual bool      OpenLongParams(double &price,double &sl,double &tp,datetime &expiration);
   virtual bool      OpenShortParams(double &price,double &sl,double &tp,datetime &expiration);
  };
//+------------------------------------------------------------------+
//| Smallest distance the server will accept between a level and the  |
//| price it validates against. STOPS_LEVEL and FREEZE_LEVEL are both |
//| read because either can reject the request; the floor of one tick |
//| covers the common stops_level==0 broker, where a level sitting    |
//| exactly ON the validating price is still not placeable.           |
//+------------------------------------------------------------------+
double CSignalMACDStopSafe::MinStopDistance(void)
  {
   string sym=m_symbol.Name();
   return(SG_MinStopDistance(m_symbol.Point(),
                             SymbolInfoInteger(sym,SYMBOL_TRADE_STOPS_LEVEL),
                             SymbolInfoInteger(sym,SYMBOL_TRADE_FREEZE_LEVEL),
                             SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE)));
  }
//+------------------------------------------------------------------+
//| Round a price onto the symbol's tick grid. On a symbol whose tick |
//| size equals its point this is the identity, which is why it does  |
//| not disturb the 257 entries that were already valid.              |
//+------------------------------------------------------------------+
double CSignalMACDStopSafe::NormalizePriceToTick(const double price)
  {
   return(SG_NormalizeToTick(price,
                             SymbolInfoDouble(m_symbol.Name(),SYMBOL_TRADE_TICK_SIZE),
                             m_symbol.Digits()));
  }
//+------------------------------------------------------------------+
//| A long position is closed at Bid, so the server measures BOTH of  |
//| its levels from Bid.                                              |
//+------------------------------------------------------------------+
bool CSignalMACDStopSafe::AreBuyStopsValid(const double sl,const double tp,
                                           const double bid,const double ask)
  {
   bool sl_bad=false,tp_bad=false;
   bool ok=SG_BuyStopsValid(sl,tp,bid,MinStopDistance(),sl_bad,tp_bad);
   if(sl_bad)
      g_sg_refused_sl++;
   if(tp_bad)
      g_sg_refused_tp++;
   return(ok);
  }
//+------------------------------------------------------------------+
//| A short position is closed at Ask, so the server measures BOTH of |
//| its levels from Ask.                                              |
//+------------------------------------------------------------------+
bool CSignalMACDStopSafe::AreSellStopsValid(const double sl,const double tp,
                                            const double bid,const double ask)
  {
   bool sl_bad=false,tp_bad=false;
   bool ok=SG_SellStopsValid(sl,tp,ask,MinStopDistance(),sl_bad,tp_bad);
   if(sl_bad)
      g_sg_refused_sl++;
   if(tp_bad)
      g_sg_refused_tp++;
   return(ok);
  }
//+------------------------------------------------------------------+
//| One line per refusal, carrying every quantity the decision used.  |
//+------------------------------------------------------------------+
void CSignalMACDStopSafe::LogStopGuard(const string side,const double price,
                                       const double sl,const double tp,
                                       const double bid,const double ask)
  {
   int    digits=m_symbol.Digits();
   double point =m_symbol.Point();
   double sl_dist=(side=="BUY") ? (bid-sl)/point : (sl-ask)/point;
   double tp_dist=(side=="BUY") ? (tp-bid)/point : (ask-tp)/point;
   Print("[STOP_GUARD] REFUSED ",side,
         " bid=",DoubleToString(bid,digits),
         " ask=",DoubleToString(ask,digits),
         " spread_pts=",DoubleToString((ask-bid)/point,1),
         " price=",DoubleToString(price,digits),
         " sl=",DoubleToString(sl,digits),
         " tp=",DoubleToString(tp,digits),
         " sl_dist_pts=",DoubleToString(sl_dist,1),
         " tp_dist_pts=",DoubleToString(tp_dist,1),
         " need_pts=",DoubleToString(MinStopDistance()/point,1),
         " stops_level=",IntegerToString(SymbolInfoInteger(m_symbol.Name(),SYMBOL_TRADE_STOPS_LEVEL)),
         " freeze_level=",IntegerToString(SymbolInfoInteger(m_symbol.Name(),SYMBOL_TRADE_FREEZE_LEVEL)));
  }
//+------------------------------------------------------------------+
bool CSignalMACDStopSafe::OpenLongParams(double &price,double &sl,double &tp,datetime &expiration)
  {
   if(!CSignalMACD::OpenLongParams(price,sl,tp,expiration))
      return(false);
   g_sg_evaluated++;
   sl=NormalizePriceToTick(sl);
   tp=NormalizePriceToTick(tp);
   double bid=m_symbol.Bid();
   double ask=m_symbol.Ask();
   if(!AreBuyStopsValid(sl,tp,bid,ask))
     {
      g_sg_refused++;
      g_sg_refused_buy++;
      LogStopGuard("BUY",price,sl,tp,bid,ask);
      return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
bool CSignalMACDStopSafe::OpenShortParams(double &price,double &sl,double &tp,datetime &expiration)
  {
   if(!CSignalMACD::OpenShortParams(price,sl,tp,expiration))
      return(false);
   g_sg_evaluated++;
   sl=NormalizePriceToTick(sl);
   tp=NormalizePriceToTick(tp);
   double bid=m_symbol.Bid();
   double ask=m_symbol.Ask();
   if(!AreSellStopsValid(sl,tp,bid,ask))
     {
      g_sg_refused++;
      g_sg_refused_sell++;
      LogStopGuard("SELL",price,sl,tp,bid,ask);
      return(false);
     }
   return(true);
  }
//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+
CExpert ExtExpert;
//+------------------------------------------------------------------+
//| Initialization function of the expert                            |
//+------------------------------------------------------------------+
int OnInit(void)
  {
//--- Initializing expert
   if(!ExtExpert.Init(Symbol(),Period(),Expert_EveryTick,Expert_MagicNumber))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing expert");
      ExtExpert.Deinit();
      return(-1);
     }
//--- Creation of signal object
   CSignalMACDStopSafe *signal=new CSignalMACDStopSafe;
   if(signal==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating signal");
      ExtExpert.Deinit();
      return(-2);
     }
//--- Add signal to expert (will be deleted automatically))
   if(!ExtExpert.InitSignal(signal))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing signal");
      ExtExpert.Deinit();
      return(-3);
     }
//--- Set signal parameters
   signal.PeriodFast(Inp_Signal_MACD_PeriodFast);
   signal.PeriodSlow(Inp_Signal_MACD_PeriodSlow);
   signal.PeriodSignal(Inp_Signal_MACD_PeriodSignal);
   signal.TakeLevel(Inp_Signal_MACD_TakeProfit);
   signal.StopLevel(Inp_Signal_MACD_StopLoss);
//--- Check signal parameters
   if(!signal.ValidationSettings())
     {
      //--- failed
      printf(__FUNCTION__+": error signal parameters");
      ExtExpert.Deinit();
      return(-4);
     }
//--- Creation of trailing object
   CTrailingNone *trailing=new CTrailingNone;
   if(trailing==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating trailing");
      ExtExpert.Deinit();
      return(-5);
     }
//--- Add trailing to expert (will be deleted automatically))
   if(!ExtExpert.InitTrailing(trailing))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing trailing");
      ExtExpert.Deinit();
      return(-6);
     }
//--- Set trailing parameters
//--- Check trailing parameters
   if(!trailing.ValidationSettings())
     {
      //--- failed
      printf(__FUNCTION__+": error trailing parameters");
      ExtExpert.Deinit();
      return(-7);
     }
//--- Creation of money object
   CMoneyNone *money=new CMoneyNone;
   if(money==NULL)
     {
      //--- failed
      printf(__FUNCTION__+": error creating money");
      ExtExpert.Deinit();
      return(-8);
     }
//--- Add money to expert (will be deleted automatically))
   if(!ExtExpert.InitMoney(money))
     {
      //--- failed
      printf(__FUNCTION__+": error initializing money");
      ExtExpert.Deinit();
      return(-9);
     }
//--- Set money parameters
//--- Check money parameters
   if(!money.ValidationSettings())
     {
      //--- failed
      printf(__FUNCTION__+": error money parameters");
      ExtExpert.Deinit();
      return(-10);
     }
//--- Tuning of all necessary indicators
   if(!ExtExpert.InitIndicators())
     {
      //--- failed
      printf(__FUNCTION__+": error initializing indicators");
      ExtExpert.Deinit();
      return(-11);
     }
//--- succeed
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Print("[STOP_GUARD] SUMMARY evaluated=",IntegerToString(g_sg_evaluated),
         " refused=",IntegerToString(g_sg_refused),
         " refused_buy=",IntegerToString(g_sg_refused_buy),
         " refused_sell=",IntegerToString(g_sg_refused_sell),
         " leg_sl=",IntegerToString(g_sg_refused_sl),
         " leg_tp=",IntegerToString(g_sg_refused_tp));
   ExtExpert.Deinit();
  }
//+------------------------------------------------------------------+
//| Function-event handler "tick"                                    |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   ExtExpert.OnTick();
  }
//+------------------------------------------------------------------+
//| Function-event handler "trade"                                   |
//+------------------------------------------------------------------+
void OnTrade(void)
  {
   ExtExpert.OnTrade();
  }
//+------------------------------------------------------------------+
//| Function-event handler "timer"                                   |
//+------------------------------------------------------------------+
void OnTimer(void)
  {
   ExtExpert.OnTimer();
  }
//+------------------------------------------------------------------+
