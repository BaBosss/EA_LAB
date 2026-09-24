"""Current exporter readers. Decimal cash components are observations, never verdicts."""
from __future__ import annotations
import re
from collections import defaultdict
from datetime import datetime
from decimal import Decimal, localcontext
from pathlib import Path

from _triage.factory_os.runtime_identity import TRADE_DEAL_TYPES, VALID_DEAL_TYPES
from .safe import Sources, Refused, broker_time, currency, decimal, integer, opaque, symbol

DEAL_FIELDS = set("ticket time symbol magic type entry volume price profit swap commission comment".split())
SNAP_FIELDS = set("row_type login server_time currency equity balance margin free_margin margin_level_pct stopout_mode stopout_level magic symbols float_pl open_lots open_positions oldest_open_hours pending_orders".split())
ACCOUNT_VALUES = "equity balance margin free_margin margin_level_pct stopout_level".split()
MAGIC_VALUES = "float_pl open_lots open_positions oldest_open_hours pending_orders".split()
CLOCK = "BROKER_TIME_UNQUALIFIED"


def rejected_filename_account(name: str, kind: str) -> str | None:
    """Associate a malformed suffix only for withholding, never for source acceptance."""
    match = re.fullmatch(r"EA_LAB_" + kind + r"_([1-9][0-9]{0,19})(?:_[^/\\]*)?\.csv", name)
    return match[1] if match else None


def filename_account(name: str, kind: str) -> str:
    match = re.fullmatch(r"EA_LAB_" + kind + r"_([1-9][0-9]{0,19})(?:_([0-9]{8}))?\.csv", name)
    if not match:
        raise Refused("SOURCE_FILENAME_INVALID")
    if match[2]:
        try:
            datetime.strptime(match[2], "%Y%m%d")
        except ValueError:
            raise Refused("SOURCE_FILENAME_INVALID") from None
    return match[1]


def field_value(raw: str, *, count: bool = False) -> dict:
    if raw == "":
        return {"value": None, "availability": "MISSING"}
    try:
        value = integer(raw) if count else format(decimal(raw), "f")
        return {"value": value, "availability": "AVAILABLE"}
    except Refused:
        return {"value": None, "availability": "INVALID"}


class Metadata:
    def __init__(self, accounts: list[dict], deployments: list[dict], identities: list[dict], refs: list[str]):
        self.refs = refs
        self.accounts = defaultdict(list)
        self.deployments = deployments
        self.identities = identities
        self.currency_conflicts: set[str] = set()
        self.account_conflicts: set[str] = set()
        self.snapshot_filename_errors: set[str] = set()
        for row in accounts:
            self.accounts[row.get("account")].append(row)

    def account(self, login: str, *, snapshot: bool = False) -> dict:
        rows = self.accounts.get(login, [])
        if len(rows) != 1:
            raise Refused("ACCOUNT_METADATA_MISSING_OR_AMBIGUOUS")
        row = rows[0]
        currency(row.get("currency"))
        if row.get("platform") not in ({"MT4", "MT5"} if snapshot else {"MT5"}):
            raise Refused("ACCOUNT_PLATFORM_NOT_MT5")
        return row

    def mapping(self, login: str, magic: str, sym: str) -> dict:
        rows = [r for r in self.deployments if r.get("account") == login and r.get("magic") == magic
                and r.get("status") == "ACTIVE"]
        exact = [r for r in rows if r.get("symbol") == sym and ";" not in sym and "," not in sym]
        # A shared account/magic with another symbol cannot uniquely attribute this stream.
        status = "DECLARED_EXACT" if len(rows) == len(exact) == 1 else "AMBIGUOUS" if rows else "MISSING"
        pins = [r for r in self.identities if r.get("account") == login and r.get("magic") == magic]
        bound = len(pins) == 1 and pins[0].get("symbol") == sym
        return {"mapping_status": status,
                "deployment_id": opaque("deployment", login, magic, sym) if status == "DECLARED_EXACT" else None,
                "expected_identity_pin": opaque("pin", *[pins[0].get(k, "") for k in sorted(pins[0])]) if bound else None,
                "expected_identity_status": "DECLARED" if bound else "MISSING_OR_CONFLICT",
                "runtime_identity": "UNVERIFIED", "attribution_eligible": False,
                "mapping_source_refs": self.refs}


def read_ledgers(sources: Sources, root: Path, meta: Metadata) -> dict:
    names = sources.discover(root, "EA_LAB_deals_")
    accounts: dict[str, dict] = {}
    quarantine: dict[tuple[str, str], set[str]] = defaultdict(set)
    seen: dict[tuple[str, str], dict] = {}
    all_refs: dict[tuple[str, str], set[str]] = defaultdict(set)
    total_rows = 0
    incomplete = set(meta.snapshot_filename_errors)
    for name in names:
        login, ref = rejected_filename_account(name, "deals"), None
        try:
            login = filename_account(name, "deals")
            metadata = meta.account(login)
            account = accounts.setdefault(login, {"currency": metadata["currency"], "source_refs": [], "file_errors": False})
            if login in meta.currency_conflicts:
                account["file_errors"] = True
            raw, ref = sources.read(root, name, "DEAL_EXPORT")
            account["source_refs"].append(ref)
            rows = sources.csv(raw, DEAL_FIELDS, {"time_unix"})
            for row in rows:
                total_rows += 1
                ticket = None
                try:
                    ticket = integer(row["ticket"], positive=True)
                    key = (login, ticket)
                    all_refs[key].add(ref)
                    normalized = {"time": broker_time(row["time"]), "magic": integer(row["magic"]),
                                  "type": row["type"], "entry": row["entry"],
                                  "symbol": symbol(row["symbol"], empty=row["type"] not in TRADE_DEAL_TYPES),
                                  "comment": row["comment"]}
                    if row["type"] not in VALID_DEAL_TYPES or row["entry"] not in {"0", "1", "2", "3"}:
                        raise Refused("DEAL_ENUM_INVALID")
                    for field in ("volume", "price", "profit", "swap", "commission"):
                        normalized[field] = decimal(row[field])
                    if normalized["volume"] < 0 or normalized["price"] < 0:
                        raise Refused("DEAL_UNSIGNED_VALUE_INVALID")
                    epoch = integer(row["time_unix"], positive=True) if "time_unix" in row else None
                    if epoch is not None:
                        # DEAL_TIME and TimeToString(DEAL_TIME) must agree in the same
                        # naive broker coordinate. This establishes no UTC offset.
                        coordinate = int((datetime.fromisoformat(normalized["time"]) - datetime(1970, 1, 1)).total_seconds())
                        if int(epoch) != coordinate:
                            raise Refused("BROKER_TIME_FIELDS_CONFLICT")
                    prior = seen.get(key)
                    if prior and prior["shared"] != normalized:
                        quarantine[key].add("SHARED_FIELD_CONFLICT")
                    if prior and epoch is not None and prior["epoch"] not in (None, epoch):
                        quarantine[key].add("KNOWN_TIME_UNIX_CONFLICT")
                    if not prior:
                        seen[key] = {"shared": normalized, "epoch": epoch}
                    elif prior["epoch"] is None:
                        prior["epoch"] = epoch
                except Refused as exc:
                    if ticket:
                        quarantine[(login, ticket)].add(str(exc))
                    else:
                        account["file_errors"] = True
                    sources.error("ledger", str(exc), ref)
        except Refused as exc:
            if login:
                incomplete.add(login)
            if login in accounts:
                accounts[login]["file_errors"] = True
            sources.error("ledger", str(exc), ref)
    results = []
    for login in sorted(set(accounts) | set(meta.accounts)):
        try:
            metadata = meta.account(login, snapshot=True)
        except Refused:
            continue
        account = accounts.get(login)
        binding_conflict = login in meta.account_conflicts
        withheld = account is None or account["file_errors"] or login in incomplete or binding_conflict
        groups = defaultdict(list)
        excluded = 0
        for (acct, ticket), value in seen.items():
            if acct != login or (acct, ticket) in quarantine:
                continue
            row = value["shared"]
            if row["type"] not in TRADE_DEAL_TYPES:
                excluded += 1
                continue
            groups[(row["magic"], row["symbol"])].append(((acct, ticket), row))
        components = []
        for (magic, sym), values in sorted(groups.items()):
            with localcontext() as ctx:
                ctx.prec = 50  # fixed input digits + bounded million-row accumulation
                sums = {f: sum((row[f] for _, row in values), Decimal(0)) for f in ("profit", "swap", "commission")}
                valid = not withheld
                times = sorted(row["time"] for _, row in values)
                components.append({"stream_id": opaque("stream", login, magic, sym), "symbol_key": opaque("symbol", sym),
                    "deal_count": len(values) if valid else None,
                    "gross_realized_profit_component": format(sums["profit"], "f") if valid else None,
                    "swap": format(sums["swap"], "f") if valid else None,
                    "commission": format(sums["commission"], "f") if valid else None,
                    "reported_components_subtotal": format(sum(sums.values()), "f") if valid else None,
                    "fee": None, "fee_availability": "NOT_EXPORTED", "all_costs_complete": False,
                    "cycle_identifiers": "NOT_EXPORTED", "window_first": times[0], "window_latest": times[-1],
                    "clock_basis": CLOCK, "source_refs": sorted(set().union(*(all_refs[k] for k, _ in values))),
                    **meta.mapping(login, magic, sym)})
        conflicts = [{"deal_key": opaque("deal", *key), "reasons": sorted(codes), "source_refs": sorted(all_refs[key])}
                     for key, codes in sorted(quarantine.items()) if key[0] == login]
        results.append({"account_key": opaque("account", login), "currency": metadata["currency"],
            "platform": metadata["platform"],
            "availability": "UNAVAILABLE" if withheld else "PARTIAL",
            "reason": "SNAPSHOT_ACCOUNT_BINDING_CONFLICT" if binding_conflict else "LEDGER_MISSING" if account is None else "INVALID_EXPORT_WITHHELD" if withheld else "COST_CYCLE_CLOCK_AND_RUNTIME_GAPS",
            "broker_server_identity": "NOT_EXPORTED", "history_completeness": "EXPORT_WINDOW_NOT_LIFETIME_PROOF",
            "deal_count": None if withheld else sum(len(v) for v in groups.values()),
            "non_trading_deals_excluded": excluded, "components": components, "quarantined": conflicts,
            "source_refs": account["source_refs"] if account else []})
    return {"accounts": results, "raw_rows_read": total_rows,
            "enum_contract": "tools/DealsExporter/DealsExporter.mq5 + _triage/factory_os/runtime_identity.py",
            "deal_filter": "DEAL_TYPE_BUY_0_SELL_1_ALL_ENTRY_0_1_2_3_INCLUDING_ENTRY_COSTS",
            "unit": "DEAL_EVENTS_NOT_TRADE_CYCLES", "account_totals_across_currencies": None}


def read_snapshots(sources: Sources, root: Path, meta: Metadata) -> dict:
    observations = defaultdict(list)
    incomplete = set()
    for name in sources.discover(root, "EA_LAB_snapshot_"):
        login, ref = rejected_filename_account(name, "snapshot"), None
        try:
            login = filename_account(name, "snapshot")
            metadata = meta.account(login, snapshot=True)
            raw, ref = sources.read(root, name, "ACCOUNT_SNAPSHOT")
            rows = sources.csv(raw, SNAP_FIELDS)
            if any(row["login"] != login for row in rows):
                meta.account_conflicts.add(login)
                raise Refused("SNAPSHOT_ACCOUNT_OR_TIME_CONFLICT")
            account_rows = [r for r in rows if r["row_type"] == "ACCOUNT"]
            if len(account_rows) != 1:
                raise Refused("SNAPSHOT_ACCOUNT_ROW_COUNT")
            acc = account_rows[0]
            when = broker_time(acc["server_time"])
            if currency(acc["currency"]) != metadata["currency"]:
                meta.currency_conflicts.add(login)
                raise Refused("ACCOUNT_CURRENCY_CONFLICT")
            values = {f: field_value(acc[f]) for f in ACCOUNT_VALUES}
            values["stopout_mode"] = {"value": acc["stopout_mode"] if acc["stopout_mode"] in {"PERCENT", "MONEY"} else None,
                                       "availability": "AVAILABLE" if acc["stopout_mode"] in {"PERCENT", "MONEY"} else "MISSING" if acc["stopout_mode"] == "" else "INVALID"}
            magics = {}
            for row in rows:
                if row["row_type"] not in {"ACCOUNT", "MAGIC", "SYMBOL"}:
                    raise Refused("SNAPSHOT_ROW_TYPE_INVALID")
                if row["login"] != login or row["server_time"] != acc["server_time"]:
                    raise Refused("SNAPSHOT_ACCOUNT_OR_TIME_CONFLICT")
                blank_fields = ({"magic", "symbols", *MAGIC_VALUES} if row["row_type"] == "ACCOUNT"
                                else {"currency", *ACCOUNT_VALUES, "stopout_mode"})
                if row["row_type"] == "SYMBOL":
                    blank_fields |= {"magic", "oldest_open_hours", "pending_orders"}
                    symbol(row["symbols"])
                if any(row[f] != "" for f in blank_fields):
                    raise Refused("SNAPSHOT_ROW_LAYOUT_INVALID")
                if row["row_type"] == "MAGIC":
                    magic = integer(row["magic"])
                    symbols = row["symbols"].split(";") if row["symbols"] else []
                    for sym in symbols:
                        symbol(sym)
                    if magic in magics:
                        raise Refused("SNAPSHOT_DUPLICATE_MAGIC")
                    mapping = meta.mapping(login, magic, symbols[0]) if len(symbols) == 1 else {
                        "mapping_status": "MULTI_SYMBOL_OR_MISSING", "attribution_eligible": False, "runtime_identity": "UNVERIFIED"}
                    magics[magic] = {"magic_key": opaque("magic", login, magic),
                        "fields": {f: field_value(row[f], count=f in {"open_positions", "pending_orders"}) for f in MAGIC_VALUES},
                        "mapping": mapping}
            observations[login].append({"observed_broker_time": when, "fields": values,
                "floating": [magics[k] for k in sorted(magics)],
                "floating_availability": "OBSERVED_MAGIC_ROWS" if magics else "NO_MAGIC_ROWS_NOT_ZERO_PROOF",
                "source_refs": [ref], "conflict": False})
        except Refused as exc:
            if login:
                incomplete.add(login)
                if str(exc) == "SOURCE_FILENAME_INVALID":
                    meta.snapshot_filename_errors.add(login)
            sources.error("accounts", str(exc), ref)
    results = []
    for login in sorted(set(meta.accounts) | set(observations)):
        try:
            metadata = meta.account(login, snapshot=True)
        except Refused:
            continue
        grouped = defaultdict(list)
        for point in observations[login]:
            grouped[point["observed_broker_time"]].append(point)
        points = []
        for when, group in sorted(grouped.items()):
            point = dict(group[0])
            point["source_refs"] = sorted({ref for p in group for ref in p["source_refs"]})
            if any(p["fields"] != point["fields"] or p["floating"] != point["floating"] for p in group[1:]):
                point["conflict"] = True
                point["fields"] = {f: {"value": None, "availability": "CONFLICT"} for f in point["fields"]}
                point["floating"] = None
                point["floating_availability"] = "CONFLICT"
            points.append(point)
        intervals = [{"from": a["observed_broker_time"], "to": b["observed_broker_time"],
                      "observed_elapsed_seconds": int((datetime.fromisoformat(b["observed_broker_time"]) - datetime.fromisoformat(a["observed_broker_time"])).total_seconds()),
                      "gap": "UNOBSERVED_BETWEEN_SAMPLES", "clock_basis": CLOCK}
                     for a, b in zip(points, points[1:])]
        # Neither the producer nor ACCOUNTS.csv supplies a server/broker binding. These
        # are unqualified source observations, never a broker-qualified equity curve.
        results.append({"account_key": opaque("account", login), "currency": metadata["currency"],
            "platform": metadata["platform"],
            "availability": "PARTIAL" if points else "UNAVAILABLE", "broker": None, "server": None,
            "identity_qualification": "BROKER_SERVER_NOT_EXPORTED", "qualified_series": None,
            "currency_binding_conflict": login in meta.currency_conflicts,
            "metadata_source_refs": meta.refs,
            "clock_basis": CLOCK, "freshness": "UNKNOWN", "samples": points, "intervals": intervals,
            "first_observed": points[0]["observed_broker_time"] if points else None,
            "latest_observed": points[-1]["observed_broker_time"] if points else None,
            "latest": points[-1] if points and login not in incomplete else None,
            "latest_reason": "INVALID_SOURCE_MAY_HIDE_LATEST" if login in incomplete else "LATEST_INCLUDING_PARTIAL_OR_CONFLICT" if points else "SNAPSHOT_MISSING",
            "interpolation": None, "calculations": None})
    return {"accounts": results, "cross_currency_total": None, "broker_qualified_series_available": False}
