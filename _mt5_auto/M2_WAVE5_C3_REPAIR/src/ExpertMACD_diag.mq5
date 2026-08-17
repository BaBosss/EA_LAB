//+------------------------------------------------------------------+
//|                                               ExpertMACD_diag.mq5 |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
//| DIAGNOSTIC BUILD -- Wave5 Candidate 3 (ExpertMACD) M2 defect RCA. |
//| Identical to ExpertMACD.mq5 except that the signal object is a    |
//| subclass which calls the base OpenLong/ShortParams and then PRINTS|
//| the values the Standard Library actually produced, together with  |
//| the quote and the broker distance rules in force at that instant. |
//| It changes NO price, NO level and NO decision: every override     |
//| returns the base result unmodified. Behaviour-neutrality is       |
//| asserted by comparing this build's run against the accepted       |
//| original-run evidence (257 cycles / 514 deals / 5 invalid stops). |
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
//| Diagnostic signal: base behaviour + instrumentation only          |
//+------------------------------------------------------------------+
class CSignalMACDDiag : public CSignalMACD
  {
protected:
   void              LogStops(const string side,const bool ok,
                              const double price,const double sl,const double tp);
public:
   virtual bool      OpenLongParams(double &price,double &sl,double &tp,datetime &expiration);
   virtual bool      OpenShortParams(double &price,double &sl,double &tp,datetime &expiration);
  };
//+------------------------------------------------------------------+
//| Print what the library produced and what the broker demands.      |
//| m_symbol is the SAME CSymbolInfo the base class priced from, so   |
//| the bid/ask logged here are the exact inputs it used -- not a     |
//| second, independently refreshed quote.                            |
//+------------------------------------------------------------------+
void CSignalMACDDiag::LogStops(const string side,const bool ok,
                               const double price,const double sl,const double tp)
  {
   if(m_symbol==NULL)
     {
      Print("[STOPDIAG] ",side," no_symbol");
      return;
     }
   int    digits = m_symbol.Digits();
   double point  = m_symbol.Point();
   double bid    = m_symbol.Bid();
   double ask    = m_symbol.Ask();
   long   stops  = SymbolInfoInteger(m_symbol.Name(),SYMBOL_TRADE_STOPS_LEVEL);
   long   freeze = SymbolInfoInteger(m_symbol.Name(),SYMBOL_TRADE_FREEZE_LEVEL);
//--- the distance the SERVER validates against: for a BUY position the
//--- stop levels are measured from Bid, for a SELL position from Ask.
   double sl_dist = 0.0, tp_dist = 0.0;
   if(side=="BUY")
     {
      sl_dist = (bid-sl)/point;
      tp_dist = (tp-bid)/point;
     }
   else
     {
      sl_dist = (sl-ask)/point;
      tp_dist = (ask-tp)/point;
     }
   Print("[STOPDIAG] ",side,
         " ok=",(ok?"1":"0"),
         " bid=",DoubleToString(bid,digits),
         " ask=",DoubleToString(ask,digits),
         " spread_pts=",DoubleToString((ask-bid)/point,1),
         " price=",DoubleToString(price,digits),
         " sl=",DoubleToString(sl,digits),
         " tp=",DoubleToString(tp,digits),
         " sl_dist_pts=",DoubleToString(sl_dist,1),
         " tp_dist_pts=",DoubleToString(tp_dist,1),
         " stops_level=",IntegerToString(stops),
         " freeze_level=",IntegerToString(freeze),
         " adj_point=",DoubleToString(PriceLevelUnit(),digits),
         " digits=",IntegerToString(digits));
  }
//+------------------------------------------------------------------+
bool CSignalMACDDiag::OpenLongParams(double &price,double &sl,double &tp,datetime &expiration)
  {
   bool res=CSignalMACD::OpenLongParams(price,sl,tp,expiration);
   LogStops("BUY",res,price,sl,tp);
   return(res);
  }
//+------------------------------------------------------------------+
bool CSignalMACDDiag::OpenShortParams(double &price,double &sl,double &tp,datetime &expiration)
  {
   bool res=CSignalMACD::OpenShortParams(price,sl,tp,expiration);
   LogStops("SELL",res,price,sl,tp);
   return(res);
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
   CSignalMACDDiag *signal=new CSignalMACDDiag;
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
