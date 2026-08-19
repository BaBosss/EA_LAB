#!/usr/bin/env python3
"""Batch pipeline: scan reports -> parse -> score / robust-pass -> registry.

Single-test HTML  -> parse + BacktestScore v1 (verdict PASS/WATCH/REJECT).
Optimizer XML     -> robust-pass selector (NOT profit-max) + plateau quality.
Writes RUN_REGISTRY.md/.csv + a SHORTLIST of optimizer batches worth re-testing.

Usage: python run_pipeline.py [root ...]   (default: ea_projects + _mt5_report_drop)
"""
import csv
import os
import sys
from pathlib import Path

SKILLS = r"C:\Users\patip\.claude\skills\backtest-report-analyzer\scripts"
HERE = os.path.dirname(os.path.abspath(__file__))
# SKILLS must stay at index 0: the local scripts\parse_mt5_report.py is a partial
# htm-only parser and lacks parse_optimizer_xml (the SKILLS copy has the full set).
sys.path.insert(0, HERE)
sys.path.insert(0, SKILLS)
import parse_mt5_report as P          # noqa: E402
import score_backtest as SB           # noqa: E402
import select_robust_pass as RS       # noqa: E402

LAB = r"D:\EA_LAB"
DEFAULT_ROOTS = [os.path.join(LAB, "ea_projects"), os.path.join(LAB, "_mt5_report_drop")]


def guess_strategy(s):
    s = s.lower()
    if "grid" in s:
        return "grid"
    if "scalp" in s:
        return "scalping"
    if "breakout" in s:
        return "breakout"
    if any(k in s for k in ("pivot", "mean", "smc", "revert", "range")):
        return "mean_reversion"
    if "swing" in s:
        return "swing"
    return "default"


def project_of(path):
    parts = Path(path).parts
    if "ea_projects" in parts:
        i = parts.index("ea_projects")
        if i + 1 < len(parts):
            return parts[i + 1]
    return Path(path).parent.name


def _optimizer_legacy_allowed(argv):
    """Narrow guard: only the optimizer-batch branch below consumes the legacy
    BacktestScore v1 selector (select_robust_pass.select_robust). Single-test
    HTML scoring uses score_backtest.score() and is unaffected — it is not
    gated, so it keeps working by default with no flag required."""
    if "--allow-legacy-selection" in argv:
        print("LEGACY / NON_FACTORY: run_pipeline.py running with explicit "
              "--allow-legacy-selection. Optimizer-batch picks are NON-AUTHORITATIVE "
              "for current Factory verdict/selection (historical/research only).")
        return True
    print("REFUSED (LEGACY / NON_FACTORY): optimizer-batch XML files use the "
          "superseded BacktestScore v1 robust-pass selector. It is NOT the "
          "current Factory selection contract, so optimizer XML files are "
          "skipped by default (single-test HTML scoring is unaffected).")
    print("Current Factory selection comes from candidate/hypothesis "
          "pre-registration (ParameterBinding + registry resolver).")
    print("To include optimizer-batch picks explicitly as historical/research-only, "
          "re-invoke with --allow-legacy-selection.")
    return False


def main():
    argv = sys.argv[1:]
    allow_legacy = _optimizer_legacy_allowed(argv)
    roots = [a for a in argv if a != "--allow-legacy-selection"] or DEFAULT_ROOTS
    files = []
    for root in roots:
        for dp, _, fns in os.walk(root):
            if any(skip in dp for skip in ("_legacy", "node_modules", ".git", "backup_before")):
                continue
            for fn in fns:
                ext = fn.lower().rsplit(".", 1)[-1]
                if ext in ("html", "htm", "xml"):
                    files.append(os.path.join(dp, fn))

    records, errors, shortlist = [], [], []
    skipped_optimizer = 0
    for f in sorted(files):
        proj = project_of(f)
        strat = guess_strategy(proj + " " + os.path.basename(f))
        try:
            if f.lower().endswith(".xml"):
                if not allow_legacy:
                    skipped_optimizer += 1
                    continue
                d = P.parse_optimizer_xml(Path(f), top=0)
                passes = d.get("passes") or []
                if not passes:
                    continue
                r = RS.select_robust(passes, strat, allow_legacy=True)
                pick = r["robust"] or r["profit_max"]
                rec = {
                    "project": proj, "type": "optimizer", "ea_name": "", "symbol": "",
                    "period": "", "PF": pick["PF"], "DD%": pick["DD%"], "RF": pick["RF"],
                    "trades": pick["trades"], "net": pick["net"],
                    "score": r["robust_score"] if r["robust_score"] is not None else "",
                    "verdict": r["plateau"],
                    "plateau": r["plateau"],
                    "survivors": f"{r['survivors']}/{r['total_passes']}",
                    "file": f,
                }
                records.append(rec)
                if r["robust"] and r["plateau"] in ("GOOD", "WEAK"):
                    shortlist.append((r["robust_score"], proj, r, f))
            else:
                d = P.parse_html_report(Path(f))
                if d.get("profit_factor") is None or not d.get("total_trades"):
                    continue
                v = SB.score(d, strat)
                m = v["metrics"]
                records.append({
                    "project": proj, "type": "single", "ea_name": d.get("ea_name"),
                    "symbol": d.get("symbol"), "period": d.get("period"),
                    "PF": m["PF"], "DD%": m["DD%"], "RF": m["RF"], "trades": m["trades"],
                    "net": m["net"], "score": v["BacktestScore"], "verdict": v["verdict"],
                    "plateau": "", "survivors": "", "file": f,
                })
        except Exception as e:
            errors.append((f, repr(e)[:120]))

    cols = ["project", "type", "ea_name", "symbol", "period", "PF", "DD%", "RF",
            "trades", "net", "score", "verdict", "plateau", "survivors", "file"]
    with open(os.path.join(LAB, "RUN_REGISTRY.csv"), "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols, extrasaction="ignore")
        w.writeheader()
        w.writerows(records)

    order = {"PASS": 0, "WATCH": 1, "REJECT": 2}
    singles = sorted([r for r in records if r["type"] == "single"],
                     key=lambda r: (order.get(r["verdict"], 3), -(r["score"] or 0)))
    opt = sorted([r for r in records if r["type"] == "optimizer"],
                 key=lambda r: -(r["score"] if isinstance(r["score"], (int, float)) else -1))

    md = ["# RUN REGISTRY", "",
          f"> auto-generated by run_pipeline.py · {len(records)} reports · {len(errors)} errors",
          "", "## Single backtests (scored)", "",
          "| Verdict | Score | Project | Symbol | PF | DD% | RF | Trades | Net | File |",
          "|---|---:|---|---|---:|---:|---:|---:|---:|---|"]
    for r in singles:
        md.append("| {verdict} | {score} | {project} | {symbol} | {PF} | {DD%} | {RF} | "
                  "{trades} | {net} | {f} |".format(f=os.path.basename(r["file"]), **r))

    md += ["", "## Optimizer batches (ROBUST pick, not profit-max)"]
    if allow_legacy:
        md += ["LEGACY / NON_FACTORY: picks below come from the superseded BacktestScore v1 "
               "robust-pass selector — historical/research-only, NON-AUTHORITATIVE for "
               "current Factory verdict/selection.", "",
               "| Plateau | RobustScore | Project | PF | DD% | RF | Trades | Net | Survivors | File |",
               "|---|---:|---|---:|---:|---:|---:|---:|---:|---|"]
        for r in opt:
            md.append("| {plateau} | {score} | {project} | {PF} | {DD%} | {RF} | {trades} | "
                      "{net} | {survivors} | {f} |".format(f=os.path.basename(r["file"]), **r))
    else:
        md += [f"REFUSED (LEGACY / NON_FACTORY): {skipped_optimizer} optimizer XML file(s) "
               "skipped — re-run with --allow-legacy-selection to include historical/"
               "research-only picks here."]

    # SHORTLIST: robust pass exists + a real plateau -> worth re-testing in MT5
    shortlist.sort(key=lambda x: -(x[0] or 0))
    md += ["", "## SHORTLIST — re-test these in MT5 first (robust pass + plateau)", "",
           "| RobustScore | Plateau | Project | Robust PF / DD% / RF | vs profit-max DD% | File |",
           "|---:|---|---|---|---:|---|"]
    for sc, proj, r, f in shortlist:
        rb, pm = r["robust"], r["profit_max"]
        md.append(f"| {sc} | {r['plateau']} | {proj} | "
                  f"{rb['PF']} / {rb['DD%']} / {rb['RF']} | {pm['DD%']} | {os.path.basename(f)} |")

    if errors:
        md += ["", "## Parse errors", ""] + [f"- {os.path.basename(f)} — {e}" for f, e in errors]
    Path(os.path.join(LAB, "RUN_REGISTRY.md")).write_text("\n".join(md), encoding="utf-8")

    npass = sum(1 for r in singles if r["verdict"] == "PASS")
    print(f"reports={len(records)} single={len(singles)} optimizer={len(opt)} errors={len(errors)}")
    print(f"  single PASS={npass}  ·  shortlist (robust+plateau)={len(shortlist)}")
    if skipped_optimizer:
        print(f"  REFUSED (LEGACY / NON_FACTORY): {skipped_optimizer} optimizer XML file(s) "
              "skipped (use --allow-legacy-selection to include historical/research-only picks)")
    print(f"wrote {LAB}\\RUN_REGISTRY.md + .csv")


if __name__ == "__main__":
    main()
