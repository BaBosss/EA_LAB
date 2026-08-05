#!/usr/bin/env python
"""Combined-portfolio monthly simulation.

Two modes:

1. BACKTEST mode (original, unchanged): combine per-EA closed-trade CSVs
   (columns: time,profit) from strategy-tester exports. Normalizes each EA to
   EQUAL profit-weight over the common window (so no single EA's lot scale
   dominates), sums to a portfolio series, and reports combined max drawdown,
   worst month, % positive months. Also reports the gold-pair (Zeus+BRK)
   sub-portfolio since they share XAUUSD.
   Usage: python portfolio_sim.py NAME=csv ... [--gold NAME1,NAME2]

2. LIVE mode (ORDER-156, added 2026-07-23): same combine math, but the input
   is the real multi-account live/demo deal exports in portfolio/live_deals/
   (both the MT5 `EA_LAB_deals_<login>[_<date>].csv` format from
   DealsExporter.mq5 and the MT4 `EA_LAB_mt4_orders_<login>[_<date>].csv`
   format from OrdersExporterMT4.mq4). Produces (a) the same combined
   cross-account equity/max-DD/worst-month/%positive-months shape as
   backtest mode, and (b) a monthly per-(account,magic) rollup
   (portfolio/monthly/YYYY-MM.{md,csv}) using the same PF/win%/realized-DD
   formulas already established in scripts/parse_live_deals.ps1. Every
   output states account coverage vs portfolio/DEPLOYMENTS.csv up front —
   see build_coverage_lines() — because live_deals/ does NOT have data for
   every account and a combined number that silently drops an account would
   mislead. This mode does not touch scripts/control_room_snapshot.ps1,
   daily_monitor.ps1, live_dashboard.ps1, or monitor_rotation.ps1 (protected,
   read-only reference; its file-selection / parsing conventions are mirrored
   here, not imported, so those scripts are untouched).
   Usage: python portfolio_sim.py --live
              [--live-deals-dir portfolio/live_deals]
              [--deployments portfolio/DEPLOYMENTS.csv]
              [--monthly-out portfolio/monthly]
"""
import sys, csv, re, os, glob
from collections import defaultdict
from datetime import datetime

def load_monthly(path):
    m=defaultdict(float)
    with open(path,encoding='utf-8') as f:
        for row in csv.DictReader(f):
            t=row.get('time','').strip(); mm=re.match(r'(\d{4})[.\-/](\d{2})',t)
            if not mm: continue
            try: p=float(row.get('profit','') or 0)
            except: continue
            m[f"{mm.group(1)}-{mm.group(2)}"]+=p
    return m

def maxdd(equity):
    peak=equity[0]; dd=0.0
    for e in equity:
        peak=max(peak,e); dd=max(dd,peak-e)
    return dd

def stats(name, months, series):
    # series: dict ym->value over `months`
    vals=[series.get(m,0.0) for m in months]
    eq=[]; c=0.0
    for v in vals: c+=v; eq.append(c)
    dd=maxdd([0.0]+eq)
    total=sum(vals); pos=sum(1 for v in vals if v>0)
    worst=min(vals) if vals else 0
    # express DD as % of total gain (portfolio-relative, lot-agnostic since normalized)
    ddpct = (dd/total*100) if total>0 else float('inf')
    print(f"{name:<16} months={len(months)}  total={total:6.2f}  maxDD={dd:6.2f} ({ddpct:5.1f}% of gain)  worstMo={worst:6.2f}  pos={100*pos/len(months):3.0f}%")

# =============================================================================
# LIVE mode (ORDER-156) — combine real multi-account live/demo deal exports.
# =============================================================================

MT5_GLOB = 'EA_LAB_deals_*.csv'
MT4_GLOB = 'EA_LAB_mt4_orders_*.csv'

def _parse_dt(s):
    s = (s or '').strip()
    for fmt in ('%Y.%m.%d %H:%M:%S', '%Y-%m-%d %H:%M:%S', '%Y.%m.%d', '%Y-%m-%d'):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    return None

def find_latest_live_files(live_dir):
    """Group EA_LAB_deals_<login>[_<yyyymmdd>].csv / EA_LAB_mt4_orders_<login>[_<yyyymmdd>].csv
    by login, keep the newest dated snapshot per account (mirrors the "newest wins"
    selection in scripts/live_dashboard.ps1 section 1 — logic mirrored, script itself
    NOT imported/modified). Selection is keyed off the filename's own date stamp (not
    on-disk mtime) so results are reproducible after a git checkout/clone.
    Returns: {login: {'platform': 'MT5'|'MT4', 'path': str, 'stamp': 'YYYYMMDD',
                       'all_stamps': [sorted 'YYYYMMDD', ...]}}
    """
    files = sorted(glob.glob(os.path.join(live_dir, MT5_GLOB))) + \
            sorted(glob.glob(os.path.join(live_dir, MT4_GLOB)))
    groups = defaultdict(list)
    for fp in files:
        base = os.path.basename(fp)
        m = re.match(r'^(EA_LAB_deals|EA_LAB_mt4_orders)_(\d+)(?:_(\d{8}))?\.csv$', base)
        if not m:
            continue
        plat = 'MT5' if m.group(1) == 'EA_LAB_deals' else 'MT4'
        login, stamp = m.group(2), (m.group(3) or '00000000')
        groups[login].append((stamp, plat, fp))
    out = {}
    for login, lst in groups.items():
        lst.sort()
        stamp, plat, fp = lst[-1]
        out[login] = {'platform': plat, 'path': fp, 'stamp': stamp,
                       'all_stamps': sorted(s for s, _, _ in lst)}
    return out

def parse_live_rows(path, platform):
    """Yield realized-trade rows (magic, symbol, dt, net) from one live-deals CSV.

    MT5 (DealsExporter.mq5, deal-level export): keep type in {0,1} (buy/sell fill;
    type>1 = BALANCE/CREDIT/CORRECTION, not a trade) AND entry in {1,2,3}
    (OUT/INOUT/OUT_BY = a close carrying realized P&L; entry=0/IN is the open leg).
    MT4 (OrdersExporterMT4.mq4, closed-order export): one row = one whole closed
    trade; keep type in {0,1} (buy/sell), type>=2 = pending/balance/other.
    net = profit + swap + commission. Filter logic mirrors scripts/live_dashboard.ps1
    section 4 (verified against the actual CSV schema on disk); math (net/PF/win%/DD)
    reuses the formulas already established in scripts/parse_live_deals.ps1.
    """
    with open(path, encoding='utf-8-sig') as f:
        for row in csv.DictReader(f):
            try:
                net = float(row.get('profit') or 0) + float(row.get('swap') or 0) + \
                      float(row.get('commission') or 0)
            except (TypeError, ValueError):
                continue
            magic = (row.get('magic') or '').strip()
            symbol = (row.get('symbol') or '').strip()
            try:
                typ = int(row.get('type'))
            except (TypeError, ValueError):
                continue
            if typ not in (0, 1):
                continue
            if platform == 'MT4':
                dt = _parse_dt(row.get('close_time'))
            else:
                try:
                    entry = int(row.get('entry'))
                except (TypeError, ValueError):
                    continue
                if entry not in (1, 2, 3):
                    continue
                dt = _parse_dt(row.get('time'))
            if dt is None:
                continue
            yield magic, symbol, dt, net

def load_live_records(live_dir):
    files = find_latest_live_files(live_dir)
    records = []
    for login, info in files.items():
        for magic, symbol, dt, net in parse_live_rows(info['path'], info['platform']):
            records.append({'account': login, 'magic': magic, 'symbol': symbol,
                             'time': dt, 'net': net})
    return records, files

def load_deployment_accounts(deployments_csv):
    accts = {}
    with open(deployments_csv, encoding='utf-8-sig') as f:
        for row in csv.DictReader(f):
            accts.setdefault(row['account'], row.get('account_name', ''))
    return accts

def load_ea_name_map(deployments_csv):
    m = {}
    with open(deployments_csv, encoding='utf-8-sig') as f:
        for row in csv.DictReader(f):
            if not re.match(r'^\d+$', row.get('magic', '') or ''):
                continue
            key = (row['account'], row['magic'])
            if key not in m:
                m[key] = row.get('ea_name', '')
    return m

def coverage_report(files, deployment_accounts):
    """Compares live_deals/ actual contents against the DEPLOYMENTS.csv account
    roster. This is the single source of truth for "how many accounts does this
    report actually cover" — computed fresh every run, never hardcoded, because
    which accounts have sensors changes over time (ORDER-156 spec)."""
    stamps = [info['stamp'] for info in files.values() if info['stamp'] != '00000000']
    newest = max(stamps) if stamps else None
    covered, empty, missing = [], [], []
    for acct in sorted(deployment_accounts):
        name = deployment_accounts[acct]
        if acct not in files:
            missing.append(f"{acct} ({name})")
            continue
        info = files[acct]
        n = sum(1 for _ in parse_live_rows(info['path'], info['platform']))
        stale = ''
        if newest and info['stamp'] != '00000000' and info['stamp'] < newest:
            stale = f" — STALE, last data {info['stamp']} (freshest account: {newest})"
        tag = f"{acct} ({name}) [{info['platform']}] snapshot={info['stamp']} trade_rows={n}{stale}"
        (covered if n > 0 else empty).append(tag)
    return {'total': len(deployment_accounts), 'covered': covered, 'empty': empty,
            'missing': missing, 'n_with_data': len(covered), 'newest_stamp': newest}

def build_coverage_lines(cov):
    lines = [
        f"ACCOUNT COVERAGE: {cov['n_with_data']}/{cov['total']} accounts in DEPLOYMENTS.csv "
        f"have usable live_deals trade data "
        f"(+{len(cov['empty'])} with a sensor file present but ZERO trade rows, "
        f"{len(cov['missing'])} with NO live_deals file at all).",
    ]
    if cov['covered']:
        lines.append("WITH DATA:")
        lines += [f"  - {c}" for c in cov['covered']]
    if cov['empty']:
        lines.append("SENSOR PRESENT, EMPTY (0 trade rows — phantom/dead account, e.g. a strategy-tester login):")
        lines += [f"  - {c}" for c in cov['empty']]
    if cov['missing']:
        lines.append("MISSING (no live_deals file for this account at all):")
        lines += [f"  - {c}" for c in cov['missing']]
    lines.append("NOTE: every combined number below EXCLUDES every account listed as "
                  "MISSING or EMPTY above. Do not read it as whole-portfolio truth until "
                  "those are filled in.")
    return lines

def month_key(dt):
    return dt.strftime('%Y-%m')

def magic_month_stats(records):
    """Group by (account, magic, month) and compute trades/net/PF/win%/realized_DD
    for that (account,magic)'s own trades within that single month — same formulas
    (gross-win/gross-loss PF, win-count%, peak-to-trough running-net drawdown) as
    scripts/parse_live_deals.ps1, grouped by (account,magic) to match
    scripts/live_dashboard.ps1's cohort-join grain (magic alone, not magic+symbol)."""
    groups = defaultdict(list)
    for r in records:
        groups[(r['account'], r['magic'], month_key(r['time']))].append(r)
    out = {}
    for key, items in groups.items():
        items.sort(key=lambda r: r['time'])
        nets = [r['net'] for r in items]
        n = len(nets)
        wins = [v for v in nets if v > 0]
        losses = [v for v in nets if v < 0]
        gross_w, gross_l = sum(wins), abs(sum(losses))
        if gross_l > 0:
            pf = round(gross_w / gross_l, 2)
        else:
            pf = float('inf') if gross_w > 0 else None
        win_pct = round(100.0 * len(wins) / n, 1) if n else 0.0
        run = peak = dd = 0.0
        for v in nets:
            run += v
            peak = max(peak, run)
            dd = max(dd, peak - run)
        out[key] = {'trades': n, 'net': round(sum(nets), 2), 'PF': pf,
                     'win_pct': win_pct, 'realized_DD': round(dd, 2)}
    return out

def write_monthly_rollup(records, deployments_csv, out_dir, coverage_lines):
    ea_map = load_ea_name_map(deployments_csv)
    stats_by_key = magic_month_stats(records)
    months = sorted(set(k[2] for k in stats_by_key))
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for mo in months:
        rows = []
        for (acct, magic, m), s in stats_by_key.items():
            if m != mo:
                continue
            ea_name = ea_map.get((acct, magic), 'UNMAPPED')
            rows.append({'magic': magic, 'ea_name': ea_name, 'account': acct, **s})
        rows.sort(key=lambda r: -r['net'])

        csv_path = os.path.join(out_dir, f'{mo}.csv')
        with open(csv_path, 'w', newline='', encoding='utf-8') as f:
            w = csv.writer(f)
            w.writerow(['magic', 'ea_name', 'account', 'net', 'trades', 'PF', 'win%', 'realized_DD'])
            for r in rows:
                pf = 'inf' if r['PF'] == float('inf') else ('' if r['PF'] is None else r['PF'])
                w.writerow([r['magic'], r['ea_name'], r['account'], r['net'], r['trades'],
                            pf, r['win_pct'], r['realized_DD']])

        md_path = os.path.join(out_dir, f'{mo}.md')
        with open(md_path, 'w', encoding='utf-8') as f:
            f.write(f"# Monthly EA rollup — {mo}\n\n")
            f.write("Generated by `python scripts/portfolio_sim.py --live` (ORDER-156). "
                    "PF / win% / realized_DD are computed per (account, magic), scoped to "
                    "THIS month's own closed trades only (not cumulative all-time) — same "
                    "formulas as `scripts/parse_live_deals.ps1`.\n\n")
            for line in coverage_lines:
                f.write(line + "\n")
            f.write("\n| magic | ea_name | account | net | trades | PF | win% | realized_DD |\n")
            f.write("|---|---|---|---|---|---|---|---|\n")
            for r in rows:
                pf = 'inf' if r['PF'] == float('inf') else ('' if r['PF'] is None else r['PF'])
                f.write(f"| {r['magic']} | {r['ea_name']} | {r['account']} | {r['net']:.2f} | "
                        f"{r['trades']} | {pf} | {r['win_pct']} | {r['realized_DD']:.2f} |\n")
        written.append((csv_path, md_path, len(rows)))
    return written

def live_monthly_series(records):
    """Same shape as load_monthly(): {series_name -> {YYYY-MM: net}}, one series per
    (account,magic), across that (account,magic)'s FULL history (not month-scoped —
    this feeds the cross-account combined-equity curve, task (a), which needs a
    continuous cumulative series, unlike the monthly rollup in task (b))."""
    out = defaultdict(lambda: defaultdict(float))
    for r in records:
        out[f"{r['account']}|{r['magic']}"][month_key(r['time'])] += r['net']
    return {k: dict(v) for k, v in out.items()}

def run_live_mode(live_deals_dir, deployments_csv, monthly_out_dir):
    records, files = load_live_records(live_deals_dir)
    deployment_accounts = load_deployment_accounts(deployments_csv)
    cov = coverage_report(files, deployment_accounts)
    coverage_lines = build_coverage_lines(cov)

    print("=" * 78)
    for line in coverage_lines:
        print(line)
    print("=" * 78)

    if not records:
        print("\nNo realized-trade rows found in any selected live_deals file — nothing to combine.")
        return

    # --- task (a): combined cross-account equity (same shape as backtest mode) ---
    eas = live_monthly_series(records)
    allm = sorted(set().union(*[set(m) for m in eas.values()]))
    norm = {}
    for n, m in eas.items():
        s = sum(v for v in m.values() if v > 0) or 1.0
        norm[n] = {k: v / s for k, v in m.items()}
    print(f"\n=== per (account|magic) series, {len(eas)} groups (normalized to equal profit-weight) ===")
    for n in sorted(eas):
        stats(n, sorted(eas[n].keys()), norm[n])
    print(f"\n=== COMBINED cross-account portfolio ({cov['n_with_data']}/{cov['total']} accounts, "
          f"equal-weight per account|magic group, all months) ===")
    port = {ym: sum(norm[n].get(ym, 0.0) for n in eas) for ym in allm}
    stats("PORTFOLIO", allm, port)

    # unnormalized (real-dollar) combined net too, since equal-weight is a shape
    # match for backtest mode but live accounts run real, unequal lot sizes.
    real_total = sum(r['net'] for r in records)
    print(f"\n(unnormalized real-money combined net across the {cov['n_with_data']} accounts with "
          f"data, all history: {real_total:,.2f})")

    # --- task (b): monthly per-(account,magic) rollup ---
    written = write_monthly_rollup(records, deployments_csv, monthly_out_dir, coverage_lines)
    print(f"\n=== monthly rollup written to {monthly_out_dir} ===")
    for csv_path, md_path, nrows in written:
        print(f"  {os.path.basename(csv_path)} / {os.path.basename(md_path)}  ({nrows} EA-account rows)")

def main():
    if '--live' in sys.argv[1:]:
        rest = sys.argv[1:]
        def opt(flag, default):
            for a in rest:
                if a.startswith(flag + '='):
                    return a.split('=', 1)[1]
            return default
        live_deals_dir = opt('--live-deals-dir', os.path.join('portfolio', 'live_deals'))
        deployments_csv = opt('--deployments', os.path.join('portfolio', 'DEPLOYMENTS.csv'))
        monthly_out_dir = opt('--monthly-out', os.path.join('portfolio', 'monthly'))
        run_live_mode(live_deals_dir, deployments_csv, monthly_out_dir)
        return

    args=[a for a in sys.argv[1:] if not a.startswith('--')]
    gold=None
    for a in sys.argv[1:]:
        if a.startswith('--gold'): gold=a.split('=',1)[1].split(',') if '=' in a else None
    eas={}
    for a in args:
        n,p=a.split('=',1); eas[n]=load_monthly(p)
    # common window = union of months (portfolio runs all together; missing EA-month = 0)
    allm=sorted(set().union(*[set(m) for m in eas.values()]))
    # normalize each EA to equal positive-total (unit profit-weight) over its active months
    norm={}
    for n,m in eas.items():
        s=sum(v for v in m.values() if v>0) or 1.0
        norm[n]={k:v/s for k,v in m.items()}   # each EA's winning months sum to 1.0
    print("=== per-EA (normalized to equal profit-weight) ===")
    for n in eas: stats(n, sorted(eas[n].keys()), norm[n])
    print("\n=== COMBINED 6-EA portfolio (equal-weight, all months) ===")
    port={ym: sum(norm[n].get(ym,0.0) for n in eas) for ym in allm}
    stats("PORTFOLIO", allm, port)
    if gold:
        print(f"\n=== GOLD PAIR ({'+'.join(gold)}) — shared XAUUSD ===")
        gm=sorted(set().union(*[set(eas[g]) for g in gold]))
        gp={ym: sum(norm[g].get(ym,0.0) for g in gold) for ym in gm}
        stats("GOLD-PAIR", gm, gp)

if __name__=='__main__': main()
