"""Frozen B16 R4 accounting attribution; source files are read only.

Run with canonical portable Python and -B. Default output is JSON on stdout;
--write-result writes only the two contracted result paths. No tester or optimizer.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from types import ModuleType

ROOT = Path(__file__).resolve().parents[3]
RUN = "factory/runs/b16_r4_20260902/usdjpy_buy_h1"
PREREG = "docs/research/B16_USDJPY_H1_R4_SWAPCREDIT_PREREG_20260912.md"
REFERENCE = "scripts/research/b16_h03/parse_h02_reports.py"
RESULT = "factory/runs/b16_r4_offline_20260912/swapcredit/result.json"
REPORT = "docs/research/B16_USDJPY_H1_R4_SWAPCREDIT_RESULTS_20260912.md"
BASE = "e3254868d482096a009e38c81c80ebae96a64207"
PINS = {
    "M1_MAIN": "a329cc1fed28a98926ef38a07c05750c31d1f47dfd568dd31ac95d38fae64aa0",
    "M1_BWD": "327e6c9be6ea8569275c7c9a066043ce22e6e6ce1e9590b5cb4b3714cc98bc2a",
    "M4_MAIN": "03c00a3fe1c61b43aa6d613418dd0973908c83a628ca0c101902fcf2d9984117",
    "M4_BWD": "7561815ec2fa094176fa1b324a723c96a16dac8f22e74e2411d1503ab0ba85ed",
}
HEADER = ["Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price",
          "Order", "Commission", "Swap", "Profit", "Balance", "Comment"]
ZERO = Decimal("0")
DATE_FMT = "%Y.%m.%d %H:%M:%S"


class BlockedEvidence(ValueError):
    """Evidence refusal, never a strategy failure."""


def require(condition, message):
    if not condition:
        raise BlockedEvidence(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def checked_bytes(data, expected, identity):
    require(digest(data) == expected, f"source hash mismatch: {identity}")
    return data


def number(value):
    text = str(value).replace(" ", "").replace("\u00a0", "")
    require(bool(re.fullmatch(r"-?\d+(?:\.\d+)?", text)), f"invalid numeric cell: {value!r}")
    return Decimal(text)


def money(value):
    require(value == value.quantize(Decimal("0.01")), "non-cent cashflow")
    return format(value, ".2f")


def sign(value):
    return "POSITIVE" if value > 0 else "NEGATIVE" if value < 0 else "ZERO"


def reference_parser(root):
    # Execute definitions only; __main__ is not entered and no pycache is written.
    module = ModuleType("b16_swapcredit_reference")
    path = root / REFERENCE
    exec(compile(path.read_bytes(), str(path), "exec"), module.__dict__)
    return module


def html_rows(data, ref):
    parser = ref.TableParser()
    parser.feed(data.decode("utf-16", errors="strict"))
    parser.close()
    require(parser.row is None and parser.cell is None, "incomplete HTML table")
    return parser.rows


def label(rows, name):
    values = [row[i + 1] for row in rows for i in range(len(row) - 1) if row[i] == name]
    require(len(values) == 1, f"missing/duplicate report label: {name}")
    return values[0]


def attribution(deals):
    profit = sum((d["profit"] for d in deals), ZERO)
    commission = sum((d["commission"] for d in deals), ZERO)
    swap = sum((d["swap"] for d in deals), ZERO)
    credit = sum((max(d["swap"], ZERO) for d in deals if d["direction"] == "out"), ZERO)
    debit = sum((min(d["swap"], ZERO) for d in deals), ZERO)
    native = profit + commission + swap
    adjusted = native - credit
    return {
        "price_profit": money(profit), "commission": money(commission),
        "signed_total_swap": money(swap), "positive_swap_credit_total": money(credit),
        "negative_swap_debit_total": money(debit), "native_net": money(native),
        "adjusted_net": money(adjusted), "adjustment_amount": money(-credit),
        "adjustment_sign": sign(-credit), "adjusted_net_sign": sign(adjusted),
        "deal_count": len(deals),
        "ticket_count": sum(d["direction"] == "out" for d in deals),
        "entry_count": sum(d["direction"] == "in" for d in deals),
    }


def parse_ledger(rows, start, end, deposit):
    markers = [i for i, row in enumerate(rows) if row == ["Deals"]]
    require(len(markers) == 1, "missing/duplicate Deals table")
    marker = markers[0]
    require(rows[marker + 1:marker + 2] == [HEADER], "unexpected Deals header")
    body = rows[marker + 2:]
    deals, episodes, current = [], [], []
    balance, volume = deposit, ZERO
    previous, ids = None, set()
    initial_balance_seen = False
    footer = None
    for row in body:
        if row == [""] and footer is not None:
            continue
        require(footer is None, "data after Deals totals")
        if len(row) == 6 and row[0] == row[-1] == "":
            footer = row
            continue
        require(len(row) == len(HEADER), f"malformed Deals row: {row!r}")
        raw = dict(zip(HEADER, row))
        if raw["Type"] == "balance":
            # Frozen MT5 reports carry exactly one opening-deposit row. It is not
            # a trading cashflow and is admissible only in this exact source shape.
            when = datetime.strptime(raw["Time"], DATE_FMT)
            exact_initial_balance = (
                not initial_balance_seen and not deals and not episodes and not current
                and raw["Deal"] == "1" and when == start
                and raw["Symbol"] == raw["Direction"] == raw["Volume"] == raw["Price"] == ""
                and raw["Order"] == raw["Comment"] == ""
                and number(raw["Commission"]) == ZERO and number(raw["Swap"]) == ZERO
                and number(raw["Profit"]) == deposit and number(raw["Balance"]) == deposit
            )
            require(exact_initial_balance,
                    f"unsupported balance/nontrading row: deal={raw['Deal']} type={raw['Type']}")
            initial_balance_seen = True
            previous = (when, 1)
            ids.add(1)
            continue
        require(raw["Type"] in {"buy", "sell"},
                f"unsupported balance/nontrading row: deal={raw['Deal']} type={raw['Type']}")
        require((raw["Type"], raw["Direction"]) in {("buy", "in"), ("sell", "out")},
                "unsupported direction/type for frozen BUY ledger")
        require(raw["Symbol"] == "USDJPY", "unexpected deal symbol")
        when = datetime.strptime(raw["Time"], DATE_FMT)
        require(start <= when <= end, "deal outside frozen window")
        require(raw["Deal"].isdigit() and raw["Order"].isdigit(), "invalid deal/order id")
        deal_id = int(raw["Deal"])
        require(deal_id > 0 and deal_id not in ids, "duplicate/invalid deal id")
        require(previous is None or (when, deal_id) > previous, "nonmonotonic source ordering")
        previous = (when, deal_id)
        ids.add(deal_id)
        d = {"deal": deal_id, "time": raw["Time"], "direction": raw["Direction"],
             **{key: number(raw[key.title()]) for key in ("volume", "price", "profit", "swap", "commission")}}
        require(d["volume"] > 0 and d["price"] > 0, "invalid price/volume")
        for key in ("profit", "swap", "commission"):
            money(d[key])
        # Swap outside an out-deal has no supported realized-credit attribution.
        require(d["direction"] == "out" or d["swap"] == 0, "unsupported entry-side swap")
        balance += d["profit"] + d["swap"] + d["commission"]
        require(balance == number(raw["Balance"]), f"native balance reconciliation: deal {deal_id}")
        volume += d["volume"] if d["direction"] == "in" else -d["volume"]
        require(volume >= 0, "out-deal exceeds open volume")
        current.append(d)
        deals.append(d)
        if volume == 0:
            require(current[0]["direction"] == "in", "out-deal while flat")
            episodes.append(current)
            current = []
    require(footer is not None and deals and not current and volume == 0,
            "incomplete final accounting (totals missing, empty, or non-flat)")
    totals = attribution(deals)
    expected = [totals["commission"], totals["signed_total_swap"], totals["price_profit"], money(balance)]
    require([number(v) for v in footer[1:5]] == [number(v) for v in expected],
            "Deals totals reconciliation mismatch")
    return deals, episodes


def reconcile(totals, report_net, accepted_net, parser_net):
    require(number(totals["native_net"]) == number(report_net) == number(accepted_net) == number(parser_net),
            "native-net reconciliation mismatch (ledger/report/accepted/parser)")


def classify(cells):
    require(len(cells) == 4 and {c["cell"] for c in cells} == set(PINS), "requires all four frozen reports")
    require(all(c["status"] == "PASS" for c in cells), "ineligible report; no interpretation")
    failed = [c["cell"] for c in cells if number(c["totals"]["adjusted_net"]) <= 0]
    # Falsifier is evaluated even in an inert synthetic ledger.
    claim_falsified = bool(failed)
    if all(number(c["totals"]["positive_swap_credit_total"]) == 0 for c in cells):
        classification = "NO_CREDIT_DEPENDENCE_IN_RECORDED_LEDGER"
    elif claim_falsified:
        classification = "CREDIT_INDEPENDENT_POSITIVE_NET_FALSIFIED_ON_RECORDED_LEDGER"
    else:
        classification = "CREDIT_INDEPENDENT_POSITIVE_NET_NOT_FALSIFIED_ON_RECORDED_LEDGER"
    return {"classification": classification, "claim_falsified": claim_falsified, "nonpositive_cells": failed}


def analyze_cell(data, accepted, receipt, ref):
    rows = html_rows(data, ref)
    start = datetime.strptime(receipt["from"], "%Y.%m.%d")
    end = datetime.strptime(receipt["to"] + " 23:59:59", DATE_FMT)
    require(label(rows, "Period:") == f"H1 ({receipt['from']} - {receipt['to']})", "report window mismatch")
    require(label(rows, "Symbol:") == "USDJPY", "report symbol mismatch")
    deposit = number(label(rows, "Initial Deposit:"))
    require(deposit == 10000, "unexpected initial deposit")
    deals, groups = parse_ledger(rows, start, end, deposit)
    totals = attribution(deals)
    reference_deals = ref.parse_deals(rows)
    reference_cycles = ref.reconstruct_cycles(reference_deals)
    reconstructed = ref.closed_ticket_summary(reference_cycles)
    reconcile(totals, label(rows, "Total Net Profit:"), accepted["net"], reconstructed["net_profit"])
    require(totals["ticket_count"] == accepted["trades"] == reconstructed["closed_ticket_count"]
            == number(label(rows, "Total Trades:")), "ticket count mismatch")
    require(totals["deal_count"] == number(label(rows, "Total Deals:")), "deal count mismatch")
    require(len(groups) == len(reference_cycles) == accepted["cycles"], "cycle count mismatch")
    episodes = []
    for group, source in zip(groups, reference_cycles):
        require([d["deal"] for d in group] == source["deal_ids"], "episode membership mismatch")
        accounting = attribution(group)
        require(number(accounting["native_net"]) == number(source["pnl"]), "episode native-net mismatch")
        episodes.append({
            "episode": source["cycle"], "start": source["start"], "end": source["end"],
            "duration_seconds": source["duration_seconds"], "deal_ids": source["deal_ids"],
            "max_simultaneous_positions": source["max_simultaneous_positions"],
            "max_aggregate_lots": source["max_aggregate_lots"],
            "max_basket_depth": source["max_basket_depth"],
            "entry_price_span": source["entry_price_span"], "accounting": accounting,
        })
    by_year = []
    for year in range(start.year, end.year + 1):
        members = [d for d in deals if int(d["time"][:4]) == year]
        closing = [g for g in groups if int(g[-1]["time"][:4]) == year]
        by_year.append({"year": year, "cashflow_booking_year": attribution(members),
                        "cycles_closed": len(closing),
                        "episode_close_year": attribution([d for g in closing for d in g])})
    return {
        "totals": {**totals, "cycle_count": len(groups)}, "by_year": by_year, "episodes": episodes,
        "reconciliation": "PASS_LEDGER_REPORT_ACCEPTED_PARSER_COUNTS_BALANCES_TOTALS_EPISODES",
        "native_source_descriptors_unchanged": {
            **{k: accepted[k] for k in ("pf", "eqdd_pct", "largest_closed_ticket_loss", "max_depth",
                                      "max_aggregate_lots", "active_time_share", "multi_entry_gp_share")},
            "equity_drawdown_relative": label(rows, "Equity Drawdown Relative:"),
            "equity_drawdown_maximal": label(rows, "Equity Drawdown Maximal:"),
        },
        "adjusted_equity_drawdown": "NOT_CALCULATED_NO_EQUITY_PATH",
        "attribution_year_basis": "Cashflows: source deal booking year; episodes: final out-deal year (accepted parser convention).",
    }


def analyze(root=ROOT):
    cells, identities, report_data = [], {}, {}
    # Hash every canonical report independently before interpreting any ledger.
    for tag, expected in PINS.items():
        path = f"{RUN}/runtime/{tag}/report.htm"
        cell = {"cell": tag, "status": "PASS", "source": {"path": path, "expected_sha256": expected}}
        try:
            data = (root / path).read_bytes()
            cell["source"]["actual_sha256"] = digest(data)
            report_data[tag] = checked_bytes(data, expected, tag)
        except (OSError, ValueError) as exc:
            cell.update(status="BLOCKED_EVIDENCE", blocker=str(exc))
        cells.append(cell)
    result = {"schema": "ea-lab-b16-r4-swapcredit/1", "hypothesis": "HYP-Q09R2-B16-SWAPCREDIT-01",
              "author_base_head": BASE, "evidence": {"sources": identities, "cells": cells},
              "decision": {"scope": "RESEARCH_ONLY_OFFLINE_ACCOUNTING", "holdout": "UNSPENT",
                           "new_mt5_cells": 0, "optimization": "NONE", "authority_granted": False,
                           "next_consumer": "B16 robustness triage; normal review before integration",
                           "stop": "FOUR_FROZEN_REPORTS_ONLY_NO_AUTOMATIC_FOLLOWUP"}}
    try:
        def read(relative, expected=None):
            data = (root / relative).read_bytes()
            identities[relative] = digest(data)
            return checked_bytes(data, expected, relative) if expected else data

        prereg = read(PREREG).decode("utf-8-sig")
        integrity = json.loads(read(f"{RUN}/evidence_integrity.json"))
        require(integrity["status"] == "PASS" and integrity["report_sha256"] == list(PINS.values()),
                "accepted integrity report pins mismatch")
        summary = json.loads(read(f"{RUN}/evidence_summary.json", integrity["evidence_summary_sha256"]))
        receipts = [json.loads(line) for line in read(f"{RUN}/run_receipts.jsonl", integrity["run_receipts_sha256"]).splitlines() if line.strip()]
        read(f"{RUN}/runtime_preflight.json", integrity["runtime_preflight_sha256"])
        read(REFERENCE)
        read("scripts/research/b16_r4_offline/analyze_swap_credit.py")
        require(all(pin in prereg for pin in PINS.values()), "preregistration report pins mismatch")
        require(len(receipts) == len(summary["cells"]) == 4, "accepted evidence requires four cells")
        receipt_map = {f"M{r['model']}_{r['window']}": r for r in receipts}
        summary_map = {f"M{c['model']}_{c['window']}": c for c in summary["cells"]}
        require(set(receipt_map) == set(summary_map) == set(PINS), "accepted cell identity mismatch")
        ref = reference_parser(root)
        for cell in cells:
            if cell["status"] != "PASS":
                continue
            try:
                tag = cell["cell"]
                receipt, accepted = receipt_map[tag], summary_map[tag]
                require(receipt["report_sha256"] == accepted["report_sha256"] == PINS[tag], "receipt/summary hash mismatch")
                require(receipt["runtime_lane"] == "MT5-lane1" and receipt["holdout"] == "UNSPENT"
                        and receipt["exit_code"] == 0, "receipt lane/holdout/completion mismatch")
                for key in ("head_sha", "set_sha256", "ex5_sha256"):
                    require(receipt[key] == integrity[key], f"receipt identity mismatch: {key}")
                cell["source"].update(receipt=receipt, installation="D:\\Meta 5")
                cell.update(analyze_cell(report_data[tag], accepted, receipt, ref))
            except (ValueError, KeyError, IndexError, TypeError) as exc:
                cell.update(status="BLOCKED_EVIDENCE", blocker=str(exc))
        result["interpretation"] = classify(cells)
        result["status"] = "PASS"
    except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
        result.update(status="BLOCKED_EVIDENCE", blocker=str(exc),
                      interpretation={"classification": "BLOCKED_EVIDENCE", "claim_falsified": None})
    return result


def serialize(result):
    return json.dumps(result, indent=2, sort_keys=True, ensure_ascii=True, allow_nan=False) + "\n"


def render_report(result):
    lines = [
        "# B16 USDJPY/H1 R4 Swap-Credit Accounting Attribution", "",
        f"Status: `{result['status']} / RESEARCH_ONLY / ZERO_NEW_MT5`",
        "Hypothesis: `HYP-Q09R2-B16-SWAPCREDIT-01`.",
        f"Author base: `{BASE}`; device: BaBoss; branch: `codex/b16-swapcredit-20260912`.",
        f"Preregistration: `{PREREG}`.", "",
        "## Evidence", "",
        "Frozen parent: Boss16 KangarooGrid / USDJPY H1 / BUY RSI 14/30 / B16-R4-r1.",
        "All four reports belong to the same `D:\\Meta 5` / `MT5-lane1` installation lineage.",
        "MAIN: 2023-01-01..2025-12-31; BWD: 2020-01-01..2022-12-31. Currency: USD.",
        "Source reports are independently SHA256-checked against the preregistered pins and accepted integrity/receipts.",
        "The accepted summary, receipts and runtime preflight are hash-bound to the accepted integrity owner.",
        "A PASS requires native-net reconciliation using Decimal cents against Profit + Swap + Commission, report net, accepted net and the existing parser.",
        "Every deal balance, final ledger totals, ticket count and flat-to-flat episode membership must reconcile.",
        "The only transform is `adjusted_deal_net = native_deal_net - max(swap, 0)` for realized out-deals.",
        "Negative swap debits and every non-swap cashflow remain. Unsupported rows fail closed.", "",
        "| Cell | Native net | Signed swap | Positive credits removed | Negative debits retained | Adjusted net | Tickets / cycles |",
        "|---|---:|---:|---:|---:|---:|---:|",
    ]
    for cell in result["evidence"]["cells"]:
        if "totals" in cell:
            t = cell["totals"]
            lines.append(f"| {cell['cell']} | {t['native_net']} | {t['signed_total_swap']} | {t['positive_swap_credit_total']} | {t['negative_swap_debit_total']} | {t['adjusted_net']} | {t['ticket_count']} / {t['cycle_count']} |")
        else:
            lines.append(f"| {cell['cell']} | BLOCKED_EVIDENCE | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN | UNKNOWN |")
    lines += ["", "Adjustment amount is the negative of the positive-credit column; adjustment sign is NEGATIVE when credits exist and ZERO otherwise.",
              "For eligible cells, native equity drawdown is retained as source evidence only. Adjusted EqDD is NOT CALCULATED: no adjusted equity path exists.",
              "", "### Calendar-year attribution", "",
              "Cashflows are assigned by source deal booking year. Cycle counts use final out-deal year.",
              "The JSON also provides the accepted parser's episode-close-year attribution, keeping cross-year episodes intact.", "",
              "| Cell | Year | Native net | Signed swap | Positive credits | Negative debits | Adjusted net | Tickets / cycles closed |",
              "|---|---:|---:|---:|---:|---:|---:|---:|"]
    for cell in result["evidence"]["cells"]:
        for year in cell.get("by_year", []):
            t = year["cashflow_booking_year"]
            lines.append(f"| {cell['cell']} | {year['year']} | {t['native_net']} | {t['signed_total_swap']} | {t['positive_swap_credit_total']} | {t['negative_swap_debit_total']} | {t['adjusted_net']} | {t['ticket_count']} / {year['cycles_closed']} |")
    lines += ["", "### Unchanged native descriptors", "",
              "| Cell | PF | Native relative EqDD % | Max depth | Max aggregate lots | Accepted active-time share | Native multi-entry gross-profit share |",
              "|---|---:|---:|---:|---:|---:|---:|"]
    for cell in result["evidence"]["cells"]:
        if "native_source_descriptors_unchanged" in cell:
            d = cell["native_source_descriptors_unchanged"]
            lines.append(f"| {cell['cell']} | {d['pf']} | {d['eqdd_pct']} | {d['max_depth']} | {d['max_aggregate_lots']} | {d['active_time_share']} | {d['multi_entry_gp_share']} |")
    lines += ["", "For eligible cells, these descriptors retain their accepted definitions and values; they are not recomputed from adjusted cashflows.",
              "For eligible cells, every episode in the JSON retains source deal IDs, start/end, duration, position/depth/lot/span descriptors and both accounting totals.",
              "No price, volume, order, holding period, entry/exit, grid, sizing, risk or execution mechanism changes.",
              "", "### Source identities", ""]
    for cell in result["evidence"]["cells"]:
        source = cell["source"]
        lines += [f"- {cell['cell']}: `{source['path']}`; expected SHA256 `{source['expected_sha256']}`; observed `{source.get('actual_sha256', 'UNAVAILABLE')}`."]
        if "blocker" in cell:
            lines += [f"  Evidence refusal: `{cell['blocker']}`."]
    lines += ["", f"Machine-readable evidence, receipt/build/set/EX5 identities and source hashes: `{RESULT}`.",
              "Accepted R4 reference: `docs/research/B16_USDJPY_H1_R4_EXECUTION_FIDELITY_RESULTS.md`.",
              "", "## Interpretation", "",
              f"Classification: `{result['interpretation']['classification']}`."]
    if result["status"] == "PASS":
        failed = result["interpretation"]["nonpositive_cells"]
        lines += [f"Credit-independent-positive-net claim falsified: `{str(result['interpretation']['claim_falsified']).upper()}`.",
                  "Full-window adjusted net <= 0 in: " + (", ".join(failed) if failed else "NONE") + ".",
                  "This is accounting attribution on the recorded trading path, not a zero-swap strategy, broker-swap counterfactual or new execution-fidelity test."]
    else:
        lines += [f"Blocker: `{result.get('blocker', 'ineligible source evidence')}`.",
                  "No accounting-dependence or strategy-failure inference is authorized from blocked evidence."]
    lines += ["", "## Decision and limitations", "",
              "Deliver this bounded diagnostic for normal review and B16 robustness triage; stop at the four frozen reports.",
              "HOLDOUT: UNSPENT. New MT5 cells: 0. Optimization, Monte Carlo and broker portability: NOT RUN.",
              "No alternate transformation, tuning, source-evidence rewrite, EA/core/runtime/configuration change or native EqDD recalculation.",
              "No risk/default, runtime, deployment, trading, Candidate, Grade or KINT authority; KINT remains unresolved and no grade is assigned.",
              "Accepted native active-time/concentration descriptors retain historical parser conventions; this task does not reinterpret them.",
              "Lesson and next consumer are limited to observed recorded-ledger credit dependence; any follow-up experiment needs its own contract.",
              "Author output is not an independent review, project-state update, or push authorization.", "",
              "## Reproduction and gates", "",
              "Use canonical portable Python through `scripts/use_python.ps1`; pass `-B` to avoid repository bytecode caches.",
              "Run `python -B scripts/research/b16_r4_offline/test_analyze_swap_credit.py`, then",
              "`python -B scripts/research/b16_r4_offline/analyze_swap_credit.py --write-result`.",
              "Without `--write-result`, the analyzer emits JSON to stdout and writes no evidence files.",
              "Required author gates: focused fixtures, four-source analyzer/reconciliation, deterministic output, py_compile, git diff --check, strict state check and normal commit hooks.",
              "The author handoff reports actual gate outcomes; this generated report does not self-attest hook or independent-review success.", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write-result", action="store_true")
    args = parser.parse_args()
    result = analyze()
    payload = serialize(result)
    if args.write_result:
        path = ROOT / RESULT
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(payload, encoding="utf-8", newline="\n")
        (ROOT / REPORT).write_text(render_report(result), encoding="utf-8", newline="\n")
    else:
        print(payload, end="")
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    sys.exit(main())
