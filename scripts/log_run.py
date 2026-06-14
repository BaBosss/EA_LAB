#!/usr/bin/env python3
"""log_run.py — บันทึกผล MT5 run ลง master log (Excel-friendly CSV).

อ่าน report ที่ fetch_report.ps1 ดึงมา (single .htm หรือ optimize .xml), สกัด
metrics ด้วย parser เดิม แล้ว append เป็นแถวเดียวลง D:\\EA_LAB\\RUN_LOG.csv
(UTF-8 BOM -> เปิดใน Excel ภาษาไทยไม่เพี้ยน, double-click ได้เลย).

  single   : PF/DD/RF/trades/net + BacktestScore + verdict  (จาก score_backtest)
  optimize : robust pick PF/DD/RF/trades/net + plateau + survivors (จาก select_robust)

ใช้:
  python log_run.py "<report.htm|opt.xml>"            # auto-detect ชนิด
  python log_run.py "<file>" --type single --strategy grid
  python log_run.py --show                            # โชว์ log ปัจจุบัน

dedup (ลบแถว+รายงานเก่าที่ใกล้เคียง เหลือ run ล่าสุดต่อ ea+symbol+type):
  python log_run.py --dedup                # ลบแถวซ้ำใน log อย่างเดียว
  python log_run.py --dedup --purge-files  # ลบไฟล์ report เก่าที่ถูก dedup ทิ้งด้วย
"""
import argparse
import csv
import os
import re
import sys
from datetime import datetime
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts")
import parse_mt5_report as P          # noqa: E402
import score_backtest as SB           # noqa: E402
import select_robust_pass as RS       # noqa: E402

LOG = Path(r"D:\EA_LAB\RUN_LOG.csv")
COLS = ["logged_at", "type", "ea", "symbol", "timeframe", "date_from", "date_to",
        "PF", "DD_pct", "RF", "trades", "net", "EP", "SR", "Edge",
        "score", "verdict", "report_file"]


def _now():
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _read_rows():
    if not LOG.exists():
        return []
    with open(LOG, encoding="utf-8-sig", newline="") as fh:
        return list(csv.DictReader(fh))


def _write_rows(rows):
    with open(LOG, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=COLS)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in COLS})


def _split_period(period):
    """'H1 (2024.01.01 - 2026.06.01)' -> ('H1','2024.01.01','2026.06.01')"""
    tf = (re.match(r"\s*([A-Za-z0-9]+)", period or "") or [None, ""])[1]
    dm = re.search(r"(\d{4}\.\d{2}\.\d{2})\s*-\s*(\d{4}\.\d{2}\.\d{2})", period or "")
    return tf, (dm.group(1) if dm else ""), (dm.group(2) if dm else "")


def row_for_single(path, strategy):
    d = P.parse_html_report(Path(path))
    v = SB.score(d, strategy)
    tf, frm, to = _split_period(d.get("period", ""))
    m = v["metrics"]
    ep = d.get("expected_payoff")
    avg_loss = d.get("average_loss_trade")
    # Edge เป็นหน่วย R = กำไรคาดหวังต่อไม้ / ขนาดการเสียปกติ (เทียบข้าม EA ได้)
    edge = ""
    if isinstance(ep, (int, float)) and isinstance(avg_loss, (int, float)) and abs(avg_loss) > 1e-9:
        edge = round(ep / abs(avg_loss), 3)
    return {
        "logged_at": _now(), "type": "single",
        "ea": v.get("ea_name") or d.get("ea_name", ""), "symbol": v.get("symbol", ""),
        "timeframe": tf, "date_from": frm, "date_to": to,
        "PF": m.get("PF"), "DD_pct": m.get("DD%"), "RF": m.get("RF"),
        "trades": m.get("trades"), "net": m.get("net"),
        "EP": ep, "SR": d.get("sharpe_ratio"), "Edge": edge,
        "score": v.get("BacktestScore"), "verdict": v.get("verdict"),
        "report_file": str(path),
    }


def _title_meta(path):
    raw = P.read_text_auto(Path(path))
    t = re.search(r"<Title>(.*?)</Title>", raw, re.I)
    title = t.group(1).strip() if t else ""
    m = re.match(r"^(.*?)\s+([A-Z0-9._]+),([A-Za-z0-9]+)\s+(\d{4}\.\d{2}\.\d{2})-(\d{4}\.\d{2}\.\d{2})", title)
    if m:
        return m.group(1).strip(), m.group(2), m.group(3), m.group(4), m.group(5)
    return title, "", "", "", ""


def row_for_optimize(path, strategy):
    ea, sym, tf, frm, to = _title_meta(path)
    d = P.parse_optimizer_xml(Path(path), top=0)
    r = RS.select_robust(d.get("passes") or [], strategy)
    # ไม่มี robust survivor -> log ตัว profit-max แทน (กันแถวว่าง), หมายเหตุไว้ใน verdict
    rb = r.get("robust") or r.get("profit_max") or {}
    tag = "robust" if r.get("robust") else "profitmax"
    plateau = f"{r['plateau']} {r['survivors']}/{r['total_passes']} ({tag})"

    def _r(x, n=2):
        return round(x, n) if isinstance(x, (int, float)) else x
    return {
        "logged_at": _now(), "type": "optimize",
        "ea": ea, "symbol": sym, "timeframe": tf, "date_from": frm, "date_to": to,
        "PF": _r(rb.get("PF")), "DD_pct": _r(rb.get("DD%")), "RF": _r(rb.get("RF")),
        "trades": rb.get("trades"), "net": _r(rb.get("net")),
        "EP": _r(rb.get("EP")), "SR": _r(rb.get("SR")), "Edge": "",
        "score": r.get("robust_score"), "verdict": plateau,
        "report_file": str(path),
    }


def _key(r):
    return (str(r.get("ea", "")).strip().lower(),
            str(r.get("symbol", "")).strip().lower(),
            str(r.get("type", "")).strip().lower())


def dedup(purge_files=False):
    """เหลือ run ล่าสุดต่อ (ea, symbol, type) — แถวอื่นถูกตัดทิ้ง.
    purge_files=True -> ลบไฟล์ report ของแถวที่ถูกตัดด้วย (ถ้าไม่มีแถวอื่นอ้างถึง)."""
    rows = _read_rows()
    # ลำดับเดิม = เก่า->ใหม่ (append ต่อท้าย); ตัวล่าสุด = ตัวท้ายสุดของแต่ละ key
    latest = {}
    for i, r in enumerate(rows):
        latest[_key(r)] = i
    keep_idx = set(latest.values())
    kept = [r for i, r in enumerate(rows) if i in keep_idx]
    dropped = [r for i, r in enumerate(rows) if i not in keep_idx]
    _write_rows(kept)

    purged, skipped = [], []
    if purge_files:
        kept_files = {os.path.normcase(os.path.abspath(r["report_file"]))
                      for r in kept if r.get("report_file")}
        for r in dropped:
            f = r.get("report_file", "")
            if not f:
                continue
            ap = os.path.abspath(f)
            if os.path.normcase(ap) in kept_files:
                skipped.append(f)          # ไฟล์เดียวกับที่ยังเก็บ -> ไม่ลบ
                continue
            try:
                if os.path.exists(ap):
                    os.remove(ap)
                    purged.append(f)
            except OSError as e:
                skipped.append(f"{f} ({e})")
    return kept, dropped, purged, skipped


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("report", nargs="?", help="report .htm (single) หรือ .xml (optimize)")
    ap.add_argument("--type", choices=["auto", "single", "optimize"], default="auto")
    ap.add_argument("--strategy", default="default")
    ap.add_argument("--show", action="store_true", help="โชว์ log ปัจจุบัน")
    ap.add_argument("--dedup", action="store_true", help="เหลือ run ล่าสุดต่อ ea+symbol+type")
    ap.add_argument("--purge-files", action="store_true", help="ลบไฟล์ report เก่าที่ถูก dedup ด้วย")
    a = ap.parse_args()

    if a.dedup:
        kept, dropped, purged, skipped = dedup(purge_files=a.purge_files)
        print(f"dedup: เก็บ {len(kept)} แถว, ตัด {len(dropped)} แถว")
        for r in dropped:
            print(f"  - ตัด: {r['type']:8} {r['ea']} {r['symbol']}  ({r['logged_at']})")
        if a.purge_files:
            print(f"ลบไฟล์ {len(purged)} ไฟล์" + (f", ข้าม {len(skipped)}" if skipped else ""))
            for f in purged:
                print(f"  x {f}")
        return

    if a.show or not a.report:
        rows = _read_rows()
        if not rows:
            print("(log ว่าง)")
            return
        print(f"RUN_LOG.csv — {len(rows)} แถว")
        for r in rows:
            print(f"  {r['logged_at']}  {r['type']:8} {r['ea']:22.22} {r['symbol']:7} "
                  f"PF={r['PF']:>5} DD={r['DD_pct']:>5} RF={r['RF']:>5} "
                  f"EP={r.get('EP',''):>6} SR={r.get('SR',''):>5} Edge={r.get('Edge',''):>5} "
                  f"tr={r['trades']:>5} score={r['score']:>5} {r['verdict']}")
        return

    typ = a.type
    if typ == "auto":
        typ = "optimize" if a.report.lower().endswith(".xml") else "single"
    row = row_for_optimize(a.report, a.strategy) if typ == "optimize" else row_for_single(a.report, a.strategy)

    rows = _read_rows()
    rows.append(row)
    _write_rows(rows)
    print(f"logged [{typ}] {row['ea']} {row['symbol']}  "
          f"PF={row['PF']} DD={row['DD_pct']} RF={row['RF']} trades={row['trades']} "
          f"score={row['score']} -> {row['verdict']}")
    print(f"  -> {LOG}")


if __name__ == "__main__":
    main()
