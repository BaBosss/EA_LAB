"""Pure byte parsers adapted from frozen canonical helpers; no filesystem reads."""
import re, html, math, configparser, hashlib
from datetime import datetime
from decimal import Decimal, InvalidOperation

def strip_html(t):
    t = re.sub(r"<[^>]+>", "", t)
    return t.replace("&nbsp;"," ").replace("&amp;","&").replace("&lt;","<").replace("&gt;",">").strip()

def pn(s):
    s = s.strip().replace(",","").replace(" ","")
    if not s: return None
    try: return float(s)
    except: return None

def parse_report(raw):
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

def extract_trades(raw):
    rows = re.findall(r"<tr[^>]*>(.*?)</tr>", decode(raw), re.S)
    out = []
    for r in rows:
        cells = [re.sub("<[^>]+>", "", c).strip()
                 for c in re.findall(r"<t[dh][^>]*>(.*?)</t[dh]>", r, re.S)]
        if len(cells) != 13 or cells[4].lower() != "out":
            continue
        try:
            t = datetime.strptime(cells[0], "%Y.%m.%d %H:%M:%S")
            profit = float(cells[10].replace(" ", "").replace(",", ""))
            comm = float(cells[8].replace(" ", "").replace(",", "") or 0)
            swap = float(cells[9].replace(" ", "").replace(",", "") or 0)
            out.append((t, profit + comm + swap))
        except ValueError:
            continue
    return out

def stats(trades, deposit=10000.0):
    eq = peak = deposit
    maxdd = 0.0
    gp = gl = 0.0
    for _, p in trades:
        eq += p
        gp += max(p, 0.0)
        gl += max(-p, 0.0)
        peak = max(peak, eq)
        if peak > 0:
            maxdd = max(maxdd, (peak - eq) / peak * 100.0)
    pf = (gp / gl) if gl > 0 else float("inf")
    return len(trades), pf, eq - deposit, maxdd

def check(ok, label):
    if not ok:
        raise ValueError(label)

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def decode(raw):
    return raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')

def assignment_map(text):
    result = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith((';', '#')) or '=' not in line:
            continue
        key, value = line.split('=', 1)
        check(key not in result, 'duplicate assignment ' + key)
        result[key] = value
    return result

def ini_maps(raw):
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    parser.read_string(decode(raw))
    return dict(parser['Tester']), dict(parser['TesterInputs'])

def rows(raw):
    return [[html.unescape(re.sub('<[^>]+>', '', c)).strip()
             for c in re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row, re.S)]
            for row in re.findall(r'<tr[^>]*>(.*?)</tr>', decode(raw), re.S)]

def report_inputs(raw):
    table = rows(raw)
    start = next(i for i, row in enumerate(table) if row and row[0] == 'Inputs:')
    end = next(i for i in range(start + 1, len(table)) if table[i] and table[i][0] == 'Company:')
    values = [row[-1] for row in table[start:end] if row and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', row[-1])]
    return assignment_map('\n'.join(values))

def norm(value):
    # MT5 report normalizes true/false and numeric lexical forms only.
    from decimal import Decimal, InvalidOperation
    value = value.split('||')[0].strip()
    if value.lower() in ('true', 'false'):
        return ('bool', value.lower())
    try:
        return ('number', Decimal(value))
    except InvalidOperation:
        return ('text', value)

def check_maps(declared, observed, reported):
    check(len(declared) == len(observed) == len(reported) == 157, '157/157/157 surface count')
    check(declared == observed, 'set/INI exact assignment mismatch')
    check(set(declared) == set(reported), 'report input keys mismatch')
    check(all(norm(declared[k]) == norm(reported[k]) for k in declared), 'report input values mismatch')

def expected_tester(window):
    start, end = WINDOWS[window]
    return {'Expert': r'EA_LAB_TEST\ORDER-XX00-MODEL1-SCREEN-V1\EALabTpl\Boss_15_ST03',
            'Report': f'XX00_B15_GBPUSD_H4_{window}_M1', 'Symbol': 'GBPUSD', 'Period': 'H4',
            'Leverage': '1:100', 'Model': '1', 'Optimization': '0', 'ForwardMode': '0',
            'Deposit': '10000', 'Currency': 'USD', 'FromDate': start, 'ToDate': end}

def check_identity(tester, parsed, window):
    check(all(tester.get(k) == v for k, v in expected_tester(window).items()), 'literal INI/contract mismatch')
    fields = {'ea_name': 'Boss_15_ST03', 'symbol': 'GBPUSD', 'period': 'H4',
              'from_date': WINDOWS[window][0], 'to_date': WINDOWS[window][1],
              'initial_deposit': 10000, 'currency': 'USD', 'leverage': '1:100'}
    check(all(parsed.get(k) == v for k, v in fields.items()), 'report/INI identity mismatch')

def derive(raw, parsed, window):
    table = rows(raw)
    deals = [r for r in table if len(r) == 13 and r[2] == 'GBPUSD' and r[3] in ('buy', 'sell')]
    check(all(r[4] in ('in', 'out') for r in deals), 'unsupported deal direction')
    check(len({r[1] for r in deals}) == len(deals), 'duplicate deal id')
    entries = [r for r in deals if r[4] == 'in']
    closes = [r for r in deals if r[4] == 'out']
    l0 = [r for r in entries if r[12] == '15_ST03 L0']
    trades = extract_trades(raw)
    check(len(closes) == len(trades) == parsed['total_trades'], 'close/ticket/parser count mismatch')
    check(len(deals) == parsed['total_deals'], 'deal-table completeness mismatch')
    check(len(l0) == {'MAIN': 5, 'BWD': 6}[window], 'QRESET06 L0 count mismatch')
    check(abs(sum(p for _, p in trades) - parsed['net_profit']) < .011, 'deal/report net mismatch')
    check(all(WINDOWS[window][0] <= r[0][:10] <= WINDOWS[window][1] for r in deals), 'deal outside contract')
    check(max(r[0][:10] for r in closes) == {'MAIN': '2025.12.30', 'BWD': '2022.12.30'}[window], 'full-window tail')
    participation = {'window_calendar_months': 36, 'entry_deal_count': len(entries),
                     'closed_ticket_count': len(closes), 'buy_sell_deal_count': len(deals),
                     'raw_l0_entry_tag_count': len(l0), 'independent_baskets': 'UNKNOWN',
                     'independent_episodes': 'UNKNOWN', 'basket_semantics_status': 'UNKNOWN_NOT_INDEPENDENTLY_PROVEN',
                     'time_in_market': 'UNKNOWN', 'exposure_active_months': 'UNKNOWN',
                     'method': 'Exact 13-column buy/sell Deals rows; L0 requires Direction=in and Comment=15_ST03 L0. No order-ticket-to-position or basket grouping.'}
    for kind, subset in [('entry', entries), ('close', closes), ('deal', deals), ('l0_entry_tag', l0)]:
        months = sorted({r[0][:7] for r in subset})
        participation[kind + '_active_months'] = months
        participation[kind + '_active_month_count'] = len(months)
        participation[kind + '_active_month_fraction'] = len(months) / 36
    annual = []
    for year in range(int(WINDOWS[window][0][:4]), int(WINDOWS[window][1][:4]) + 1):
        subset = [(t, p) for t, p in trades if t.year == year]
        n, pf, net, dd = stats(subset)
        annual.append({'year': year, 'closed_ticket_count': n, 'closed_deal_pf': pf if math.isfinite(pf) and n else None,
                       'pf_status': 'DEFINED' if n and math.isfinite(pf) else 'UNDEFINED_NO_GROSS_LOSS',
                       'closed_deal_net': round(net, 2), 'closed_deal_balance_dd_pct': round(dd, 8),
                       'zero_close_year': n == 0, 'exposure': 'UNKNOWN',
                       'coverage': 'Frozen full-window dates; complete buy/sell deal counts and net reconcile; unchanged truncation sidecar CHECK_PASS. Zero closes do not establish zero exposure.',
                       'dd_definition': 'Canonical year stats: closed-deal balance drawdown; each year resets to USD10000; NOT native floating EqDD.'})
    return participation, annual, deals

def svg(view, cells):
    parts = ['<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="760" viewBox="0 0 1200 760">',
             '<rect width="1200" height="760" fill="#f7f9fc"/>',
             '<style>text{font-family:Arial,sans-serif;fill:#183049} .small{font-size:13px} .label{font-size:17px}</style>']
    def text(x, y, value, size=17):
        parts.append(f'<text x="{x}" y="{y}" font-size="{size}">{html.escape(str(value))}</text>')
    titles = {'pf_home_window': 'PF by frozen Home / window', 'opportunity_participation': 'Observed tickets, L0 entry tags and active months',
              'pf_vs_participation': 'PF versus entry-active months / 36', 'native_eqdd': 'Native report Equity Drawdown Maximal'}
    text(35, 42, 'B15 XX00 | GBPUSD / H4 | ' + titles[view], 25)
    text(35, 72, 'MT5-lane3 / D:\\Meta 5c | Model 1 | MAIN 2023.01.01-2025.12.31 | BWD 2020.01.01-2022.12.31', 15)
    text(35, 100, 'Derived R1 presentation only. Native images: 8 MISSING / closure INCOMPLETE. Strategy assessment not assigned.', 15)
    if view == 'pf_vs_participation':
        x0, y0, w, h = 110, 430, 830, 270
        parts.append(f'<path d="M{x0} {y0-h} V{y0} H{x0+w}" fill="none" stroke="#536a80"/>')
        for v in range(0, 37, 6):
            x = x0 + v / 36 * w
            text(x - 5, y0 + 23, v, 13)
        for v in (0, 1, 2, 3):
            y = y0 - v / 3 * h
            text(72, y + 5, v, 13)
        text(450, 480, 'Entry-active calendar months (denominator 36)', 16)
        text(40, 160, 'PF', 16)
        for i, c in enumerate(cells):
            p = c['participation']; m = c['metrics']
            x = x0 + p['entry_active_month_count'] / 36 * w
            y = y0 - m['profit_factor'] / 3 * h
            parts.append(f'<circle cx="{x}" cy="{y}" r="7" fill="{["#22759c", "#aa5f1d"][i]}"/>')
            text(x + 14, y - 10, f'{c["window"]}: PF {m["profit_factor"]:.2f}; entry months {p["entry_active_month_count"]}/36', 16)
            text(x + 14, y + 14, f'tickets {p["closed_ticket_count"]}; L0 tags {p["raw_l0_entry_tag_count"]}; baskets/episodes UNKNOWN', 14)
    elif view == 'opportunity_participation':
        headings = ['Window', 'Closed tickets', 'L0 tags', 'Entry months', 'Close months', 'Deal months']
        xs = [45, 200, 390, 550, 760, 965]
        for x, heading in zip(xs, headings): text(x, 165, heading, 17)
        for i, c in enumerate(cells):
            p = c['participation']; y = 235 + i * 125
            vals = [c['window'], p['closed_ticket_count'], p['raw_l0_entry_tag_count'],
                    f'{p["entry_active_month_count"]}/36', f'{p["close_active_month_count"]}/36', f'{p["deal_active_month_count"]}/36']
            for x, value in zip(xs, vals): text(x, y, value, 24)
            text(45, y + 37, 'Independent baskets/episodes UNKNOWN; exposure months and time-in-market UNKNOWN.', 16)
        text(45, 465, 'L0 = exact entry-deal comment tag; calendar month counts measure ledger activity, not continuous exposure.', 16)
    else:
        maximum = 3 if view == 'pf_home_window' else 8
        for i, c in enumerate(cells):
            p = c['participation']; m = c['metrics']; y = 185 + 145 * i
            value = m['profit_factor'] if view == 'pf_home_window' else m['equity_drawdown_maximal_pct']
            text(40, y + 24, c['window'], 21)
            parts.append(f'<rect x="150" y="{y}" width="{value/maximum*740:.3f}" height="38" fill="{["#22759c", "#aa5f1d"][i]}"/>')
            label = f'{value:.2f}' if view == 'pf_home_window' else f'{value:.2f}% / USD {m["equity_drawdown_maximal_abs"]:.2f}'
            text(165 + value/maximum*740, y + 26, label, 19)
            text(150, y + 66, f'Closed tickets {p["closed_ticket_count"]}; raw L0 entry tags {p["raw_l0_entry_tag_count"]}; independent baskets/episodes UNKNOWN', 16)
        text(150, 455, f'Linear bar scale: 0 to {maximum}' + (' PF (dimensionless)' if view == 'pf_home_window' else '% EqDD'), 16)
        if view == 'native_eqdd': text(150, 483, 'Scalar from native HTML summary; this is not a native equity or underwater curve.', 16)
    text(35, 528, 'No sample floor or adequacy verdict. Zero activity/zero closes do not establish zero exposure.', 15)
    text(35, 560, 'Run: ' + OLD, 13)
    text(35, 582, 'Rejected input head: ' + REJECTED, 13)
    text(35, 604, 'EA source commit: ' + SOURCE, 13)
    for i, c in enumerate(cells):
        text(35, 630 + i * 42, c['cell_id'] + ' | report SHA256:', 13)
        text(35, 649 + i * 42, c['report']['sha256'], 13)
    text(35, 730, 'Exact cell records, input maps, years and native missing references: cells.json | Authority: PACKAGING_ONLY', 13)
    parts.append('</svg>\n')
    return '\n'.join(parts)

WINDOWS = {'MAIN': ('2023.01.01', '2025.12.31'), 'BWD': ('2020.01.01', '2022.12.31')}
OLD = 'factory/runs/xx00_b13_b15_screen_20260909/'
REJECTED = 'a0a3b5b13cb5b1f4b9585954b91ee89ac17f5dc2'
SOURCE = '24125ea69ad8f4410f8501d3ea005a60fb92936b'
