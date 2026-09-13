#!/usr/bin/env python3
import argparse, json, re, sys

def strip_html(t):
    t = re.sub(r"<[^>]+>", "", t)
    return t.replace("&nbsp;"," ").replace("&amp;","&").replace("&lt;","<").replace("&gt;",">").strip()

def pn(s):
    s = s.strip().replace(",","").replace(" ","")
    if not s: return None
    try: return float(s)
    except: return None

def parse_report(path):
    with open(path,"rb") as f: raw=f.read()
    try: html=raw.decode("utf-16-le")
    except: html=raw.decode("utf-8",errors="replace")
    c=strip_html(html)
    build_match = re.search(r'\bBuild\s+(\d+)\b', html, re.I)
    def fl(label):
        i=c.find(label)
        if i==-1: return ""
        r=c[i+len(label):]
        m=re.search(r"<b>(.*?)</b>",r,re.DOTALL)
        if m: return m.group(1).strip()
        for ln in r.split(chr(10)):
            ln=ln.strip()
            if ln: return ln
        return ""
    r=dict()
    r["ea_name"]=fl("Expert:")
    r["symbol"]=fl("Symbol:")
    r["company"]=fl("Company:")
    r["report_build"]=int(build_match.group(1)) if build_match else 0
    r["currency"]=fl("Currency:")
    pr=fl("Period:")
    if pr:
        pts=pr.split("(")
        if len(pts)>=2:
            dp=pts[-1].rstrip(")").strip()
            ds=dp.split("-")
            r["period"]=pts[0].strip()
            if len(ds)==2: r["from_date"]=ds[0].strip(); r["to_date"]=ds[1].strip()
        else: r["period"]=pr
    r["initial_deposit"]=pn(fl("Initial Deposit:")) or 0
    r["leverage"]=fl("Leverage:")
    r["quality"]=fl("Quality:")
    r["history_quality"]=fl("History Quality:")
    r["bars"]=pn(fl("Bars:")) or 0
    r["ticks"]=pn(fl("Ticks:")) or 0
    m=re.search(r"Symbols:<.*?<b>(\d+)</b>",c,re.DOTALL)
    r["symbols_count"]=int(m.group(1)) if m else 0
    r["net_profit"]=pn(fl("Total Net Profit:")) or 0
    r["gross_profit"]=pn(fl("Gross Profit:")) or 0
    r["gross_loss"]=pn(fl("Gross Loss:")) or 0
    r["balance_drawdown_abs"]=pn(fl("Balance Drawdown Absolute:")) or 0
    r["equity_drawdown_abs"]=pn(fl("Equity Drawdown Absolute:")) or 0
    bdma=fl("Balance Drawdown Maximal:")
    eqdma=fl("Equity Drawdown Maximal:")
    if bdma:
        m=re.search(r"([\d,.]+)\s*\(([\d,.]+)%\)",bdma)
        if m: r["balance_drawdown_maximal_abs"]=pn(m.group(1)) or 0; r["balance_drawdown_maximal_pct"]=pn(m.group(2)) or 0
    if eqdma:
        m=re.search(r"([\d,.]+)\s*\(([\d,.]+)%\)",eqdma)
        if m: r["equity_drawdown_maximal_abs"]=pn(m.group(1)) or 0; r["equity_drawdown_maximal_pct"]=pn(m.group(2)) or 0
    bdr=fl("Balance Drawdown Relative:")
    edr=fl("Equity Drawdown Relative:")
    if bdr:
        m=re.search(r"([\d,.]+)%",bdr)
        if m: r["balance_drawdown_relative_pct"]=pn(m.group(1)) or 0
    if edr:
        m=re.search(r"([\d,.]+)%",edr)
        if m: r["equity_drawdown_relative_pct"]=pn(m.group(1)) or 0
    r["profit_factor"]=pn(fl("Profit Factor:")) or 0
    r["recovery_factor"]=pn(fl("Recovery Factor:")) or 0
    r["expected_payoff"]=pn(fl("Expected Payoff:")) or 0
    r["sharpe_ratio"]=pn(fl("Sharpe Ratio:")) or 0
    r["z_score"]=fl("Z-Score:")
    r["ahpr"]=pn(fl("AHPR:")) or 0
    r["ghpr"]=pn(fl("GHPR:")) or 0
    r["lr_correlation"]=pn(fl("LR Correlation:")) or 0
    r["ontester_result"]=pn(fl("OnTester result:")) or 0
    r["margin_level"]=fl("Margin Level:")
    r["total_trades"]=pn(fl("Total Trades:")) or 0
    r["total_deals"]=pn(fl("Total Deals:")) or 0
    sr=fl("Short Trades (won %):")
    lr2=fl("Long Trades (won %):")
    if sr:
        m=re.match(r"(\d+)\s*\(([\d,.]+)%\)",sr)
        if m: r["short_trades"]=int(m.group(1)); r["short_won_pct"]=pn(m.group(2)) or 0
    if lr2:
        m=re.match(r"(\d+)\s*\(([\d,.]+)%\)",lr2)
        if m: r["long_trades"]=int(m.group(1)); r["long_won_pct"]=pn(m.group(2)) or 0
    ptr=fl("Profit Trades (% of total):")
    lt2=fl("Loss Trades (% of total):")
    if ptr:
        m=re.match(r"(\d+)\s*\(([\d,.]+)%\)",ptr)
        if m: r["profit_trades"]=int(m.group(1)); r["profit_trades_pct"]=pn(m.group(2)) or 0
    if lt2:
        m=re.match(r"(\d+)\s*\(([\d,.]+)%\)",lt2)
        if m: r["loss_trades"]=int(m.group(1)); r["loss_trades_pct"]=pn(m.group(2)) or 0
    r["largest_profit_trade"]=pn(fl("Largest profit trade:")) or 0
    r["largest_loss_trade"]=pn(fl("Largest loss trade:")) or 0
    r["avg_profit_trade"]=pn(fl("Avg profit trade:")) or 0
    r["avg_loss_trade"]=pn(fl("Avg loss trade:")) or 0
    r["avg_consecutive_wins"]=pn(fl("Avg consecutive wins:")) or 0
    r["avg_consecutive_losses"]=pn(fl("Avg consecutive losses:")) or 0
    r["max_consecutive_wins"]=pn(fl("Max consecutive wins:")) or 0
    r["max_consecutive_losses"]=pn(fl("Max consecutive losses:")) or 0
    return r

def main():
    pa=argparse.ArgumentParser()
    pa.add_argument("report")
    pa.add_argument("--json",action="store_true")
    a=pa.parse_args()
    try: res=parse_report(a.report)
    except FileNotFoundError:
        print(json.dumps({"error":f"File not found: {a.report}","status":"NO_REPORT"}));sys.exit(1)
    except Exception as e:
        print(json.dumps({"error":str(e),"status":"PARSE_ERROR"}));sys.exit(1)
    if a.json: print(json.dumps(res,indent=2,ensure_ascii=False))
    else:
        for k,v in res.items(): print(f"  {k}: {v}")

if __name__=="__main__": main()
