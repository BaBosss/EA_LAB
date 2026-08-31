#property strict
#property version   "1.01"
#property description "EA_LAB P4B read-only tester OHLC exporter; never trades."

const datetime EXPORT_FROM_SERVER = D'2019.03.01 00:00:00';
const datetime EXPORT_TO_SERVER   = D'2025.12.31 00:00:00';
int g_file=INVALID_HANDLE;
int g_rows=0;
datetime g_first=0,g_last=0,g_seen_current=0,g_last_written=0;
string g_stem="";

string TfName(){ string v=EnumToString(_Period); return StringFind(v,"PERIOD_")==0 ? StringSubstr(v,7) : v; }

bool WriteBar(const int shift)
{
   MqlRates r[1];
   if(CopyRates(_Symbol,_Period,shift,1,r)!=1) return false;
   int seconds=PeriodSeconds(_Period);
   datetime close_time=r[0].time+seconds;
   if(r[0].time<EXPORT_FROM_SERVER || close_time>EXPORT_TO_SERVER || r[0].time==g_last_written) return true;
   int digits=(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS);
   FileWrite(g_file,TimeToString(r[0].time,TIME_DATE|TIME_MINUTES|TIME_SECONDS),
      DoubleToString(r[0].open,digits),DoubleToString(r[0].high,digits),DoubleToString(r[0].low,digits),DoubleToString(r[0].close,digits),
      (long)r[0].tick_volume,(int)r[0].spread,(long)r[0].real_volume);
   if(g_rows==0) g_first=r[0].time;
   g_last=r[0].time; g_last_written=r[0].time; g_rows++;
   return true;
}

int OnInit()
{
   if(!MQLInfoInteger(MQL_TESTER)){ Print("P4B_EXPORT_REFUSE:not_tester"); return INIT_FAILED; }
   g_stem="P4B_OHLC_"+_Symbol+"_"+TfName();
   g_file=FileOpen(g_stem+".csv",FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,',');
   if(g_file==INVALID_HANDLE){ PrintFormat("P4B_EXPORT_REFUSE:FileOpen=%d",GetLastError()); return INIT_FAILED; }
   FileWrite(g_file,"time_server","open","high","low","close","tick_volume","spread","real_volume");
   g_seen_current=iTime(_Symbol,_Period,0);
   WriteBar(1);
   return INIT_SUCCEEDED;
}

void OnTick()
{
   datetime current=iTime(_Symbol,_Period,0);
   if(current!=0 && current!=g_seen_current){ WriteBar(1); g_seen_current=current; }
}

void OnDeinit(const int reason)
{
   if(g_file==INVALID_HANDLE) return;
   WriteBar(0);
   FileClose(g_file); g_file=INVALID_HANDLE;
   int mh=FileOpen(g_stem+".done",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(mh!=INVALID_HANDLE){
      FileWriteString(mh,"schema=P4B_TESTER_OHLC_V1\r\n");
      FileWriteString(mh,"symbol="+_Symbol+"\r\n"); FileWriteString(mh,"tf="+TfName()+"\r\n");
      FileWriteString(mh,"rows="+IntegerToString(g_rows)+"\r\n");
      FileWriteString(mh,"first_server="+TimeToString(g_first,TIME_DATE|TIME_MINUTES|TIME_SECONDS)+"\r\n");
      FileWriteString(mh,"last_server="+TimeToString(g_last,TIME_DATE|TIME_MINUTES|TIME_SECONDS)+"\r\n");
      FileWriteString(mh,"terminal_build="+IntegerToString((int)TerminalInfoInteger(TERMINAL_BUILD))+"\r\n");
      FileWriteString(mh,"account_server="+AccountInfoString(ACCOUNT_SERVER)+"\r\n"); FileWriteString(mh,"deinit_reason="+IntegerToString(reason)+"\r\n");
      FileClose(mh);
   }
   PrintFormat("P4B_EXPORT_OK:%s %s rows=%d",_Symbol,TfName(),g_rows);
}