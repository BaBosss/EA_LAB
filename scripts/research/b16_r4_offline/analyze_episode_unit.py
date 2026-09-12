#!/usr/bin/env python3
"""Frozen HYP-Q09R2-B16-EPISODEUNIT-01; read sources, emit JSON to stdout only.

No tester, library RNG, binary-float cashflows, or source-evidence writes.
The accepted parser's FIFO flat/nonflat transitions are reproduced with Decimal.
An exit deal is a realized ticket, including each partial-close out-deal.
"""
from __future__ import annotations

import hashlib
import json
import re
from collections import Counter, deque
from datetime import datetime
from decimal import Decimal, Inexact, localcontext
from html.parser import HTMLParser
from pathlib import Path

BASE_HEAD = "e3254868d482096a009e38c81c80ebae96a64207"
HYPOTHESIS = "HYP-Q09R2-B16-EPISODEUNIT-01"
REPLICATIONS = 5000
ROOT = Path(__file__).resolve().parents[3]
SOURCE_DIR = "factory/runs/b16_r4_20260902/usdjpy_buy_h1"
PREREG = "docs/research/B16_USDJPY_H1_R4_EPISODEUNIT_PREREG_20260912.md"
REFERENCE = "scripts/research/b16_h03/parse_h02_reports.py"
REPORT_HASHES = {
    "M1_MAIN": "a329cc1fed28a98926ef38a07c05750c31d1f47dfd568dd31ac95d38fae64aa0",
    "M1_BWD": "327e6c9be6ea8569275c7c9a066043ce22e6e6ce1e9590b5cb4b3714cc98bc2a",
    "M4_MAIN": "03c00a3fe1c61b43aa6d613418dd0973908c83a628ca0c101902fcf2d9984117",
    "M4_BWD": "7561815ec2fa094176fa1b324a723c96a16dac8f22e74e2411d1503ab0ba85ed",
}
SUPPORT_HASHES = {
    PREREG: "c6c8ea5afbdb7e6aeac967ac289153d3900691987e2bc53c10f79569307eba70",
    REFERENCE: "c2aa0995705ed63a9c2ae1b0bbb982f2375bd2da3ae9c8bff35e2ad01a005b5e",
    f"{SOURCE_DIR}/evidence_integrity.json": "9fc2c651ddb34689a6ffccfb8f904ec6aec57f7b373f555b08687faa764354d4",
    f"{SOURCE_DIR}/evidence_summary.json": "e260a42c959cd637f8556ab4e873953defaf55d381931316238bbd08e0e23faa",
    f"{SOURCE_DIR}/run_receipts.jsonl": "f6add2ccb287949d7640d90960014e07370f8990783fd2d8b542cbbdffcbfdce",
}
HEADER = ["Time", "Deal", "Symbol", "Type", "Direction", "Volume", "Price",
          "Order", "Commission", "Swap", "Profit", "Balance", "Comment"]
ZERO = Decimal(0)
SUPPORTED = "TICKET_SAMPLING_UNDERSTATES_UNCERTAINTY"
MIXED = "MIXED_OR_NOT_SUPPORTED"
BLOCKED = "BLOCKED_EVIDENCE"


class EvidenceError(ValueError):
    """Unsupported, incomplete, or unreconciled frozen evidence."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise EvidenceError(message)


class TableParser(HTMLParser):
    """Same text-cell extraction as the accepted reference, without its floats."""

    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self.row: list[str] | None = None
        self.cell: list[str] | None = None

    def handle_starttag(self, tag, attrs):
        if tag == "tr":
            require(self.row is None, "nested/incomplete table row")
            self.row = []
        elif tag in ("td", "th") and self.row is not None:
            require(self.cell is None, "nested/incomplete table cell")
            self.cell = []

    def handle_data(self, data):
        if self.cell is not None and data.strip():
            self.cell.append(data.strip())

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self.cell is not None:
            self.row.append(" ".join(self.cell))
            self.cell = None
        elif tag == "tr" and self.row is not None:
            require(self.cell is None, "incomplete table cell")
            if self.row:
                self.rows.append(self.row)
            self.row = None


def decimal_value(value: str) -> Decimal:
    # Bound the supported numeric grammar so precision 80 is provably ample for
    # source sums, 5000 draws and percentile interpolation; never round evidence.
    normalized = value.replace(" ", "").replace("\xa0", "")
    require(re.fullmatch(r"-?\d{1,24}(?:\.\d{1,8})?", normalized) is not None,
            f"unsupported decimal: {value!r}")
    return Decimal(normalized)


def label(rows: list[list[str]], name: str) -> str:
    values = [row[i + 1] for row in rows for i, item in enumerate(row[:-1]) if item == name]
    require(len(values) == 1, f"missing/ambiguous label: {name}")
    return values[0]


def positive_id(value: str) -> int:
    require(re.fullmatch(r"[1-9]\d*", value) is not None, "unsupported deal/order ID")
    return int(value)


def checked_bytes(path: Path, expected: str) -> bytes:
    data = path.read_bytes()
    require(hashlib.sha256(data).hexdigest() == expected, f"source hash mismatch: {path.name}")
    return data


def parse_report(data: bytes) -> dict:
    parser = TableParser()
    parser.feed(data.decode("utf-16", errors="strict"))
    parser.close()
    require(parser.row is None and parser.cell is None, "incomplete HTML table")
    return reconstruct(parser.rows)


def reconstruct(rows: list[list[str]]) -> dict:
    """Validate all deal rows and reconcile cashflows before returning units.

    Only a single initial deposit and the exact six-column totals footer are
    supported non-trading rows. Entry cashflow must be zero in EACH component:
    allocating entry costs to exit tickets would change the frozen experiment.
    """
    with localcontext() as context:
        context.prec = 80
        context.traps[Inexact] = True
        return _reconstruct(rows)


def _reconstruct(rows: list[list[str]]) -> dict:
    markers = [i for i, row in enumerate(rows) if row == ["Deals"]]
    require(len(markers) == 1, "missing/ambiguous Deals section")
    marker = markers[0]
    require(rows[marker + 1:marker + 2] == [HEADER], "unsupported deal header")
    deposit = decimal_value(label(rows, "Initial Deposit:"))
    native_net = decimal_value(label(rows, "Total Net Profit:"))
    native_trades = decimal_value(label(rows, "Total Trades:"))
    native_deals = decimal_value(label(rows, "Total Deals:"))
    require(deposit > 0, "unsupported initial deposit")
    require(label(rows, "Symbol:") == "USDJPY", "unsupported symbol")
    deals = []
    footer = None
    funded = False
    previous_key = None
    ids = set()
    for row in rows[marker + 2:]:
        if footer is not None:
            require(row == [""], "unsupported row after totals footer")
            continue
        if len(row) == 6 and row[0] == row[-1] == "":
            require(funded and bool(deals), "premature totals footer")
            footer = [decimal_value(item) for item in row[1:5]]
            continue
        require(len(row) == len(HEADER), f"unsupported ledger row: {row!r}")
        record = dict(zip(HEADER, row))
        try:
            time = datetime.strptime(record["Time"], "%Y.%m.%d %H:%M:%S")
        except ValueError as exc:
            raise EvidenceError("unsupported deal time") from exc
        deal_id = positive_id(record["Deal"])
        require(deal_id not in ids, "duplicate deal ID")
        ids.add(deal_id)
        key = (time, deal_id)
        require(previous_key is None or key > previous_key, "noncanonical deal order")
        previous_key = key
        amounts = [decimal_value(record[field]) for field in ("Commission", "Swap", "Profit")]
        balance = decimal_value(record["Balance"])
        if record["Type"] == "balance":
            require(not funded and not deals and deal_id == 1, "unsupported non-trading balance row")
            require(all(record[field] == "" for field in
                        ("Symbol", "Direction", "Volume", "Price", "Order", "Comment")),
                    "unsupported deposit fields")
            require(amounts == [ZERO, ZERO, deposit] and balance == deposit,
                    "initial deposit reconciliation mismatch")
            funded = True
            continue
        require(funded, "missing initial balance row")
        require(record["Symbol"] == "USDJPY", "unsupported ledger symbol")
        require((record["Type"], record["Direction"]) in {("buy", "in"), ("sell", "out")},
                "unsupported type/direction (BUY-only frozen parent)")
        volume = decimal_value(record["Volume"])
        require(volume > 0 and decimal_value(record["Price"]) > 0, "nonpositive volume/price")
        positive_id(record["Order"])
        if record["Direction"] == "in":
            require(amounts == [ZERO, ZERO, ZERO], "unsupported nonzero entry cashflow")
        deals.append({"id": deal_id, "time": record["Time"], "direction": record["Direction"],
                      "volume": volume, "amounts": amounts, "cashflow": sum(amounts, ZERO),
                      "balance": balance})
    require(footer is not None, "missing totals footer / incomplete ledger")
    require(len(deals) == native_deals, "native deal count reconciliation mismatch")

    inventory = deque()
    episodes = []
    current_ids, current_tickets = [], []
    balance = deposit
    totals = [ZERO, ZERO, ZERO]
    for deal in deals:
        balance += deal["cashflow"]
        require(balance == deal["balance"], f"running balance reconciliation mismatch at {deal['id']}")
        totals = [a + b for a, b in zip(totals, deal["amounts"])]
        if deal["direction"] == "in":
            if not inventory:
                current_ids, current_tickets = [], []
            inventory.append(deal["volume"])
        else:
            require(bool(inventory), "out deal occurs while flat")
            remaining = deal["volume"]
            while remaining > 0 and inventory:
                consumed = min(inventory[0], remaining)
                inventory[0] -= consumed
                remaining -= consumed
                if inventory[0] == 0:
                    inventory.popleft()
            require(remaining == 0, "out deal exceeds source open volume")
            current_tickets.append(deal["cashflow"])
        current_ids.append(deal["id"])
        if not inventory:
            episodes.append({"deal_ids": current_ids, "tickets": current_tickets,
                             "cashflow": sum(current_tickets, ZERO)})
    require(not inventory, "source deal ledger ends non-flat")
    tickets = [value for episode in episodes for value in episode["tickets"]]
    episode_units = [episode["cashflow"] for episode in episodes]
    require(bool(tickets) and bool(episodes), "empty realized ledger")
    require(len(tickets) == native_trades, "native trade count reconciliation mismatch")
    require(totals + [balance] == footer, "footer component reconciliation mismatch")
    total = sum(totals, ZERO)
    require(total == native_net == sum(tickets, ZERO) == sum(episode_units, ZERO) == balance - deposit,
            "native net / ticket / episode reconciliation mismatch")
    require(sum((v for v in tickets if v > 0), ZERO) == decimal_value(label(rows, "Gross Profit:")),
            "gross profit reconciliation mismatch")
    require(sum((v for v in tickets if v < 0), ZERO) == decimal_value(label(rows, "Gross Loss:")),
            "gross loss reconciliation mismatch")
    return {"observed_total": total, "tickets": tickets, "episodes": episodes,
            "episode_units": episode_units, "components": dict(zip(("commission", "swap", "profit"), totals)),
            "N": len(tickets), "K": len(episodes), "deal_count": len(deals),
            "episode_size_distribution": dict(sorted(Counter(len(e["tickets"]) for e in episodes).items()))}


def sample_index(cell: str, arm: str, replication: int, draw: int, unit_count: int) -> int:
    require(cell in REPORT_HASHES and arm in {"TICKET", "EPISODE"}, "unsupported sampler identity")
    require(type(replication) is int and 0 <= replication < REPLICATIONS, "invalid replication")
    require(type(unit_count) is int and unit_count > 0, "invalid unit count")
    require(type(draw) is int and 0 <= draw < unit_count, "invalid draw")
    payload = f"20260912|{cell}|{arm}|{replication}|{draw}".encode("utf-8")
    return int.from_bytes(hashlib.sha256(payload).digest()[:8], "big", signed=False) % unit_count


def resampled_sum(units: list[Decimal], cell: str, arm: str, replication: int) -> Decimal:
    require(bool(units), "empty sampling arm")
    return sum((units[sample_index(cell, arm, replication, draw, len(units))]
                for draw in range(len(units))), ZERO)


def quantile(sorted_sums: list[Decimal], probability: Decimal) -> Decimal:
    require(len(sorted_sums) == REPLICATIONS, "quantile requires exactly 5000 sums")
    require(isinstance(probability, Decimal) and ZERO <= probability <= 1, "invalid exact probability")
    h = Decimal(REPLICATIONS - 1) * probability
    j = int(h)
    g = h - j
    # p=1 is defined at the last observation; no out-of-bounds x[5000].
    return sorted_sums[j] if g == 0 else sorted_sums[j] + g * (sorted_sums[j + 1] - sorted_sums[j])


def bootstrap(units: list[Decimal], cell: str, arm: str) -> dict:
    with localcontext() as context:
        context.prec = 80
        context.traps[Inexact] = True
        sums = sorted(resampled_sum(units, cell, arm, r) for r in range(REPLICATIONS))
        lower, median, upper = [quantile(sums, Decimal(p)) for p in ("0.025", "0.5", "0.975")]
        return {"replications": REPLICATIONS, "draws_per_replication": len(units),
                "q025": lower, "median": median, "q975": upper, "width": upper - lower}


def classify(cells: dict) -> str:
    if set(cells) != set(REPORT_HASHES) or any(c.get("status") != "PASS" for c in cells.values()):
        return BLOCKED
    return SUPPORTED if all(c["EPISODE"]["width"] > c["TICKET"]["width"] for c in cells.values()) else MIXED


def encode(result: dict) -> str:
    def exact(value):
        if isinstance(value, Decimal):
            return format(value, "f")
        raise TypeError(type(value).__name__)
    return json.dumps(result, default=exact, sort_keys=True, indent=2, ensure_ascii=True) + "\n"


def analyze(root: Path = ROOT) -> dict:
    result = {"schema": "ea-lab-b16-r4-episodeunit/1", "hypothesis": HYPOTHESIS,
              "author_base_head": BASE_HEAD, "status": "PASS", "classification": BLOCKED,
              "authority": "OFFLINE_INFERENCE_METHOD_DIAGNOSTIC_ONLY", "new_mt5_cells": 0,
              "holdout": "UNSPENT", "lane": "MT5-lane1", "installation": "D:\\Meta 5",
              "support_sources": {}, "cells": {}, "blockers": [],
              "method": {"seed_text": "20260912", "replications_per_arm_report": REPLICATIONS,
                         "sampler": "SHA256 UTF-8 20260912|CELL|ARM|replication|draw; first 8 bytes unsigned big-endian modulo unit_count",
                         "quantile": "h=4999*p; j=floor(h); g=h-j; x[j]+g*(x[j+1]-x[j]); p=0.025,0.5,0.975",
                         "cashflow": "Profit+Swap+Commission, exact Decimal; JSON decimal strings",
                         "ticket": "realized exit deal (including partial-close out-deals)",
                         "episode": "complete FIFO flat-to-nonflat-to-flat inventory episode",
                         "pooling": False}}
    support_data = {}
    for relative, expected in SUPPORT_HASHES.items():
        identity = {"path": relative, "expected_sha256": expected}
        result["support_sources"][relative] = identity
        try:
            data = (root / relative).read_bytes()
            identity["sha256"] = hashlib.sha256(data).hexdigest()
            require(identity["sha256"] == expected, f"source hash mismatch: {relative}")
            support_data[relative] = data
        except (OSError, ValueError) as exc:
            result["blockers"].append(str(exc))
    ledgers = {}
    # Hash and validate all four independently before allowing ANY inference.
    for cell, expected in REPORT_HASHES.items():
        relative = f"{SOURCE_DIR}/runtime/{cell}/report.htm"
        record = {"status": BLOCKED, "source": {"path": relative, "expected_sha256": expected},
                  "model": int(cell[1]), "model_label": "M1_M1_OHLC_RESEARCH" if cell[1] == "1" else "M4_REAL_TICK_FIDELITY",
                  "window": cell.split("_")[1], "lane": "MT5-lane1"}
        result["cells"][cell] = record
        try:
            data = (root / relative).read_bytes()
            record["source"]["sha256"] = hashlib.sha256(data).hexdigest()
            require(record["source"]["sha256"] == expected, f"source hash mismatch: {cell}")
            ledgers[cell] = parse_report(data)
            record["status"] = "VALIDATED_NOT_SAMPLED"
        except (OSError, ValueError, IndexError) as exc:
            record["blocker"] = str(exc)
            result["blockers"].append(f"{cell}: {exc}")
    if result["blockers"]:
        result["status"] = BLOCKED
        return result

    summary = json.loads(support_data[f"{SOURCE_DIR}/evidence_summary.json"], parse_float=Decimal)
    receipts = [json.loads(line) for line in support_data[f"{SOURCE_DIR}/run_receipts.jsonl"].decode().splitlines()]
    for cell, ledger in ledgers.items():
        record = result["cells"][cell]
        accepted = next(c for c in summary["cells"] if c["model"] == record["model"] and c["window"] == record["window"])
        if (ledger["N"], ledger["K"], ledger["observed_total"]) != (accepted["trades"], accepted["cycles"], accepted["net"]):
            record["status"] = BLOCKED
            result["blockers"].append(f"{cell}: accepted summary reconciliation mismatch")
        receipt = next(c for c in receipts if c["model"] == record["model"] and c["window"] == record["window"])
        record["runtime_identity"] = {key: receipt[key] for key in
                                      ("head_sha", "runtime_lane", "set_sha256", "ex5_sha256", "build_receipt", "from", "to")}
    if result["blockers"]:
        result["status"] = BLOCKED
        return result

    for cell, ledger in ledgers.items():
        record = result["cells"][cell]
        record.update({key: ledger[key] for key in ("observed_total", "N", "K", "deal_count", "components", "episode_size_distribution")})
        record["reconciliation"] = "EXACT: native net = all deal cashflows = ticket sum = episode sum = final balance - deposit; components/footer, gross P/L, counts and accepted N/K/net agree"
        record["episode_ledger_sha256"] = hashlib.sha256(encode({"episodes": ledger["episodes"]}).encode()).hexdigest()
        record["TICKET"] = bootstrap(ledger["tickets"], cell, "TICKET")
        record["EPISODE"] = bootstrap(ledger["episode_units"], cell, "EPISODE")
        record["episode_width_strictly_greater"] = record["EPISODE"]["width"] > record["TICKET"]["width"]
        record["status"] = "PASS"
    result["classification"] = classify(result["cells"])
    return result


if __name__ == "__main__":
    output = analyze()
    print(encode(output), end="")
    raise SystemExit(0 if output["status"] == "PASS" else 2)
