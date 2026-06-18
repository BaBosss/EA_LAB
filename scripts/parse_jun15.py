import sys, os
sys.path.insert(0, r'C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts')
sys.path.insert(0, r'D:\EA_LAB\scripts')
import parse_mt5_report as P
from score_backtest import score
from pathlib import Path
from datetime import datetime

folder = r'D:\EA_LAB\_mt5_auto\reports'
results = []
for fn in os.listdir(folder):
    if not fn.endswith('.htm'): continue
    fp = os.path.join(folder, fn)
    mtime = datetime.fromtimestamp(os.path.getmtime(fp)).date()
    if str(mtime) != '2026-06-16': continue
    try:
        d = P.parse_html_report(Path(fp))
        s = score(d, fn)
        results.append({
            'file': fn,
            'symbol': d.get('symbol', ''),
            'pf': round(d.get('profit_factor', 0), 2),
            'dd': round(d.get('equity_drawdown_relative', 0), 1),
            'rf': round(d.get('recovery_factor', 0), 2),
            'trades': d.get('total_trades', 0),
            'verdict': s.get('verdict', ''),
            'score': s.get('BacktestScore', 0),
        })
    except Exception as e:
        results.append({'file': fn, 'symbol': '?', 'pf': 0, 'dd': 0, 'rf': 0, 'trades': 0, 'verdict': 'ERR:' + str(e)[:30]})

results.sort(key=lambda x: -x['pf'])
print("{:<8} {:<7} {:<6} {:<7} {:<6} {:<7} {:<6} {}".format('Verdict','Symbol','PF','DD%','RF','Trades','Score','File'))
print("-" * 110)
for r in results:
    print("{:<8} {:<7} {:<6} {:<7} {:<6} {:<7} {:<6} {}".format(
        r['verdict'], r['symbol'], r['pf'], r['dd'], r['rf'], r['trades'], r.get('score',0) or 0, r['file']))
