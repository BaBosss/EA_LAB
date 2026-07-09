//+------------------------------------------------------------------+
//| ADXDumper.mq5 — dump per-bar ADX to CSV from the tester.          |
//| Read-only utility (no trade functions). Run once in Strategy      |
//| Tester over the span you need; writes                             |
//|   <Common>\Files\ADX_<symbol>_<tf>.csv (time,adx,plusDI,minusDI)  |
//| Used for offline regime-conditioning of historical trade lists    |
//| (ORDER-065/067 style analysis) without touching any EA.           |
//+------------------------------------------------------------------+
#property strict

input int             InpAdxPeriod = 14;
input ENUM_TIMEFRAMES InpTF        = PERIOD_H4;

int g_adx = INVALID_HANDLE;
int g_fh  = INVALID_HANDLE;
datetime g_last = 0;

int OnInit()
{
   g_adx = iADX(_Symbol, InpTF, InpAdxPeriod);
   if(g_adx == INVALID_HANDLE) return INIT_FAILED;
   string name = "ADX_" + _Symbol + "_" + EnumToString(InpTF) + ".csv";
   g_fh = FileOpen(name, FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI, ',');
   if(g_fh == INVALID_HANDLE) return INIT_FAILED;
   FileWrite(g_fh, "time", "adx", "plusdi", "minusdi");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int r) { if(g_fh != INVALID_HANDLE) FileClose(g_fh); if(g_adx != INVALID_HANDLE) IndicatorRelease(g_adx); }

void OnTick()
{
   datetime t = iTime(_Symbol, InpTF, 0);
   if(t == g_last) return;
   g_last = t;
   double a[1], p[1], m[1];
   // bar 1 = last CLOSED bar of the dump TF
   if(CopyBuffer(g_adx, 0, 1, 1, a) < 1) return;
   if(CopyBuffer(g_adx, 1, 1, 1, p) < 1) return;
   if(CopyBuffer(g_adx, 2, 1, 1, m) < 1) return;
   FileWrite(g_fh, TimeToString(iTime(_Symbol, InpTF, 1), TIME_DATE | TIME_SECONDS),
             DoubleToString(a[0], 2), DoubleToString(p[0], 2), DoubleToString(m[0], 2));
}
