#!/usr/bin/env python3
"""Host-only deterministic cages for MacroGate tester-transfer implementation.

Coverage labels are intentional:
- HOST_ACTUAL_BYTES validates immutable repository feeds and exact derivations.
- HOST_SOURCE_BINDING validates compiled literals and control gating.
- PYTHON_CONTRACT_MODEL exercises adversarial ledger rules but is not native MQL.
Native compile/tester/probe coverage remains a separate Control Tower gate.
"""

from __future__ import annotations

import csv
import hashlib
import json
import re
import subprocess
import sys
import unittest
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BASE_HEAD = "4aa459566c4e5eedc2477938fa5d3f4f86d00e8e"
CONTRACT_ROOT = (
    ROOT / "factory/runs/news_macro_macrogate_tester_transfer_qual_v1_20260926"
)
CONTRACT = json.loads((CONTRACT_ROOT / "PROSPECTIVE_IMPLEMENTATION_CONTRACT.json").read_text())
EXPECTATIONS = json.loads((CONTRACT_ROOT / "FEED_RUNTIME_EXPECTATIONS.json").read_text())
SOURCE_BINDING = json.loads((CONTRACT_ROOT / "SOURCE_BINDING.json").read_text())
OWNER_AUTH = json.loads(
    Path(
        r"D:\EA_LAB_CONTROL\evidence\mg-tester-transfer-impl-v1-20260927\OWNER_AUTHORIZATION.json"
    ).read_text(encoding="utf-8-sig")
)

ALLOWED = {
    "ea_template/Boss_15_ST03.mq5",
    "ea_template/core/LabCore.mqh",
    "ea_template/core/MacroGate_Core.mqh",
    "ea_template/core/Execution.mqh",
    "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1",
    "scripts/_test/macrogate_tester_transfer_probe.mq5",
    "scripts/_test/test_macrogate_tester_transfer_contract.py",
}
EVIDENCE_PREFIX = "factory/runs/news_macro_macrogate_tester_transfer_impl_v1_20260927/"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git(*args: str) -> str:
    proc = subprocess.run(
        ["git", "-C", str(ROOT), *args],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    return proc.stdout


def parse_tester_feed(raw: bytes) -> dict[str, object]:
    """Host model of the shared MG_ParseRegimeDataLine accepted semantics."""
    text = raw.decode("utf-8-sig")
    lines = text.splitlines()
    valid: list[tuple[datetime, str]] = []
    skipped = 0
    ascending = True
    previous: datetime | None = None
    for index, line in enumerate(lines):
        if index == 0:
            continue
        if len(line) < 8:
            continue
        try:
            fields = next(csv.reader([line]))
        except csv.Error:
            skipped += 1
            continue
        if len(fields) < 2:
            skipped += 1
            continue
        stamp = fields[0].strip()
        if " " not in stamp or "." not in stamp.split(" ", 1)[0]:
            skipped += 1
            continue
        try:
            when = datetime.strptime(stamp, "%Y.%m.%d %H:%M")
        except ValueError:
            skipped += 1
            continue
        state = fields[1].strip().upper()
        if state not in {"RISK_ON", "NEUTRAL", "RISK_OFF", "STRESS", "UNKNOWN"}:
            skipped += 1
            continue
        if previous is not None and when < previous:
            ascending = False
        previous = when
        valid.append((when, state))
    return {
        "rows": len(valid),
        "skipped": skipped,
        "ascending": ascending,
        "first": valid[0][0].strftime("%Y.%m.%d %H:%M") if valid else None,
        "last": valid[-1][0].strftime("%Y.%m.%d %H:%M") if valid else None,
        "states": [state for _, state in valid],
    }


def extract_balanced(text: str, signature: str) -> str:
    start = text.index(signature)
    brace = text.index("{", start)
    depth = 0
    for index in range(brace, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[start : index + 1]
    raise AssertionError(f"unterminated function {signature}")


def derive_wrong_same_metadata(raw: bytes) -> bytes:
    lines = raw.splitlines(keepends=True)
    if len(lines) < 3:
        raise AssertionError("REAL feed has no second data row")
    original = lines[2]
    changed = original.replace(b" 02:", b" 03:", 1)
    if changed == original or len(changed) != len(original):
        raise AssertionError("same-metadata mutation was not size preserving")
    lines[2] = changed
    return b"".join(lines)


def derive_stale_truncated(raw: bytes) -> bytes:
    lines = raw.splitlines(keepends=True)
    if len(lines) < 2:
        raise AssertionError("REAL feed cannot be truncated")
    return b"".join(lines[:-1])


class ContractAndIdentityTests(unittest.TestCase):
    def test_contract_and_owner_authority(self) -> None:
        self.assertEqual(
            CONTRACT["schema"],
            "macrogate_tester_transfer_prospective_implementation_contract/2",
        )
        self.assertTrue(OWNER_AUTH["authorized_implementation"])
        self.assertFalse(OWNER_AUTH["authorized_performance"])
        self.assertEqual(OWNER_AUTH["base"], BASE_HEAD)
        self.assertEqual(OWNER_AUTH["holdout"], "LOCKED_UNSPENT")

    def test_base_source_binding_is_exact(self) -> None:
        for item in SOURCE_BINDING["source_files"]:
            raw = subprocess.run(
                ["git", "-C", str(ROOT), "show", f"{BASE_HEAD}:{item['path']}"],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            ).stdout
            self.assertEqual(sha256(raw), item["sha256"], item["path"])

    def test_immutable_current_paths_unchanged(self) -> None:
        expected = {item["path"]: item["sha256"] for item in SOURCE_BINDING["source_files"]}
        for path in ("ea_template/core/Inputs.mqh", "ea_template/core/ConfigFingerprint.mqh"):
            self.assertEqual(sha256((ROOT / path).read_bytes()), expected[path], path)

    def test_changed_paths_stay_in_allowlist(self) -> None:
        lines = git("status", "--porcelain=v1", "--untracked-files=all").splitlines()
        for line in lines:
            path = line[3:].replace("\\", "/")
            if " -> " in path:
                path = path.split(" -> ", 1)[1]
            self.assertTrue(path in ALLOWED or path.startswith(EVIDENCE_PREFIX), path)

    def test_vendor_trade_binding(self) -> None:
        path = Path(
            r"D:\MetaTraderData\Roaming\MetaQuotes\Terminal\9CA16B8382AE4CF692710FB36B9DA355\MQL5\Include\Trade\Trade.mqh"
        )
        self.assertEqual(
            sha256(path.read_bytes()),
            "96e6781624534377fe7971cba52cca3d62d1b030bc10d5e4ebf3ed8c541399ed",
        )


class FeedByteTests(unittest.TestCase):
    def test_all_eleven_golden_feeds(self) -> None:
        self.assertEqual(len(EXPECTATIONS["entries"]), 11)
        for item in EXPECTATIONS["entries"]:
            raw = (ROOT / item["source_path"]).read_bytes()
            parsed = parse_tester_feed(raw)
            self.assertEqual(len(raw), item["bytes"], item["filename"])
            self.assertEqual(sha256(raw), item["sha256"], item["filename"])
            self.assertEqual(parsed["rows"], item["rows"], item["filename"])
            self.assertEqual(parsed["first"], item["first"], item["filename"])
            self.assertEqual(parsed["last"], item["last"], item["filename"])
            self.assertTrue(parsed["ascending"], item["filename"])

    def test_raw_hash_vectors_distinguish_lf_crlf_bom_and_count(self) -> None:
        vectors = {
            b"abc": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            b"a\n": "87428fc522803d31065e7bce3cf03fe475096631e5e07bbd7a0fde60c4cf25c7",
            b"a\r\n": "8e4621379786ef42a4fec155cd525c291dd7db3c1fde3478522f4f61c03fd1bd",
            b"\xef\xbb\xbfa\n": "be4fccb045869c7ad387b9081a44cfd495b37efc020da4b44542de0d980c747f",
            bytes((0, 1, 2, 3)): "054edec1d0211f624fed0cbca9d4f9400b0e491c43742af2c5b0abebf0c990d8",
        }
        for raw, expected in vectors.items():
            self.assertEqual(sha256(raw), expected)
        self.assertEqual(len({sha256(raw) for raw in vectors}), len(vectors))

    def test_negative_fixture_derivations_are_exact(self) -> None:
        item = EXPECTATIONS["entries"][0]
        raw = (ROOT / item["source_path"]).read_bytes()
        wrong = derive_wrong_same_metadata(raw)
        self.assertEqual(len(wrong), len(raw))
        self.assertEqual(
            sha256(wrong),
            "7e1dbd8e3850c5d14858c7183d9f842767bbe0e33d16ed148be4fbd9dc84f5e4",
        )
        self.assertEqual(parse_tester_feed(wrong)["rows"], item["rows"])
        self.assertEqual(parse_tester_feed(wrong)["first"], item["first"])
        self.assertEqual(parse_tester_feed(wrong)["last"], item["last"])
        stale = derive_stale_truncated(raw)
        self.assertEqual(
            sha256(stale),
            "70271717ee95f618a2d76b2b0a8d1ca2d8da9edf2cc9a079b74d4ea90e484e19",
        )

    def test_unknown_equal_and_unsorted_parser_semantics(self) -> None:
        raw = (
            b"datetime,state,ri\n"
            b"2020.01.01 02:00,UNKNOWN,0\n"
            b"2020.01.01 02:00,NEUTRAL,0\n"
        )
        parsed = parse_tester_feed(raw)
        self.assertEqual(parsed["states"], ["UNKNOWN", "NEUTRAL"])
        self.assertTrue(parsed["ascending"])
        backwards = raw + b"2019.12.31 02:00,STRESS,0\n"
        self.assertFalse(parse_tester_feed(backwards)["ascending"])


class SourceBindingTests(unittest.TestCase):
    def test_boss_wrapper_has_exact_opt_in_dependencies(self) -> None:
        text = (ROOT / "ea_template/Boss_15_ST03.mq5").read_text()
        names = re.findall(r'^#property tester_file "([^"]+)"$', text, re.MULTILINE)
        self.assertEqual(names, CONTRACT["transfer"]["production_filenames"])
        self.assertEqual(len(names), 11)
        self.assertNotRegex(text, r"^#define LAB_MG_TESTER_EVIDENCE_QUAL$", msg="control must remain compilable")

    def test_compiled_expected_map_matches_json(self) -> None:
        text = (ROOT / "ea_template/core/MacroGate_Core.mqh").read_text()
        pattern = re.compile(
            r'if\(fname == "(?P<name>[^"]+)"\)\s*\n\s*'
            r'\{ sha256="(?P<sha>[0-9a-f]{64})"; bytes=(?P<bytes>\d+); rows=(?P<rows>\d+); '
            r'first="(?P<first>[^"]+)"; last="(?P<last>[^"]+)"; return true; \}'
        )
        actual = {
            match["name"]: {
                "sha256": match["sha"],
                "bytes": int(match["bytes"]),
                "rows": int(match["rows"]),
                "first": match["first"],
                "last": match["last"],
            }
            for match in pattern.finditer(text)
        }
        expected = {
            item["filename"]: {key: item[key] for key in ("sha256", "bytes", "rows", "first", "last")}
            for item in EXPECTATIONS["entries"]
        }
        self.assertEqual(actual, expected)

    def test_qualified_loader_has_one_binary_open_and_same_buffer_parse(self) -> None:
        text = (ROOT / "ea_template/core/MacroGate_Core.mqh").read_text()
        body = extract_balanced(text, "bool MGTT_LoadQualifiedRegime(")
        self.assertEqual(body.count("FileOpen("), 1)
        self.assertIn("FILE_READ|FILE_BIN", body)
        self.assertNotIn("FILE_COMMON", body)
        self.assertNotIn("FILE_SHARE_WRITE", body)
        self.assertEqual(body.count("FileReadArray("), 1)
        self.assertIn("MGTT_Sha256Hex(raw", body)
        self.assertIn("CharArrayToString(raw", body)
        self.assertNotIn("MG_LoadRegime(", body)
        for field in CONTRACT["transfer"]["success_marker_fields"]:
            self.assertIn(field, body)
        for marker in CONTRACT["transfer"]["failure_markers"]:
            self.assertIn(marker, text)

    def test_native_observer_is_feature_gated_and_forwards_once_per_path(self) -> None:
        text = (ROOT / "ea_template/core/Execution.mqh").read_text()
        feature = text.split("#ifdef LAB_MG_TESTER_EVIDENCE_QUAL", 1)[1].split("#else", 1)[0]
        observer = extract_balanced(feature, "virtual bool OrderSend(")
        self.assertEqual(observer.count("CTrade::OrderSend(request,result)"), 2)
        self.assertEqual(observer.count("bool transport_ok=CTrade::OrderSend(request,result)"), 1)
        self.assertIn("if(!MGTT_IsActive() || !g_mgtt_open_context)", observer)
        self.assertNotIn("_MG_SelfGate", feature)
        init = extract_balanced(text, "void Exec_Init()")
        self.assertIn("g_trade.SetAsyncMode(false)", init)

    def test_probe_has_no_trade_api_and_imports_actual_loader(self) -> None:
        text = (ROOT / "scripts/_test/macrogate_tester_transfer_probe.mq5").read_text()
        self.assertIn('../../ea_template/core/MacroGate_Core.mqh', text)
        self.assertIn('../../ea_template/core/Execution.mqh', text)
        self.assertIn("MGTT_LoadQualifiedRegime", text)
        self.assertIn("ProbeLedgerEvidence", text)
        self.assertIn("CERTIFIED_COUNTS_PASS self_gate=0 no_order_send=1", text)
        self.assertIn("ADVERSARIAL_FAIL_CLOSED_PASS", text)
        self.assertEqual(len(re.findall(r"^#property tester_file", text, re.MULTILINE)), 1)
        self.assertNotRegex(
            text,
            r"\b(?:CTrade|OrderSend|PositionOpen|Buy|Sell|BuyLimit|SellLimit|BuyStop|SellStop)\s*\(",
        )

    def test_control_source_retains_original_execution_path(self) -> None:
        current = (ROOT / "ea_template/core/Execution.mqh").read_text()
        base = git("show", f"{BASE_HEAD}:ea_template/core/Execution.mqh")
        for signature in (
            "bool Exec_Open(const int direction, double lot, const double sl, const double tp, const string comment)",
            "bool Exec_PlacePending(const int direction, const bool isStop, double lot,",
        ):
            base_body = extract_balanced(base, signature)
            current_body = extract_balanced(current, signature)
            # The original body must remain a literal suffix after the opt-in branch.
            base_inner = base_body[base_body.index("{") + 1 : -1].strip()
            self.assertIn(base_inner, current_body)

    def test_orchestrator_is_bounded_and_fail_closed(self) -> None:
        text = (ROOT / "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1").read_text()
        case_ids = re.findall(r"@\{ id='([^']+)'", text)
        self.assertEqual(
            case_ids,
            ["POSITIVE_GOLDEN_REAL", "MISSING", "WRONG_SAME_METADATA", "STALE_TRUNCATED_COPY"],
        )
        self.assertIn("REFUSE: competing or unresolved terminal/tester/editor process exists", text)
        self.assertIn("RuntimeLeaseLaneId", text)
        self.assertIn("runtime lease owner/state mismatch", text)
        self.assertIn("requiredWorktreeHead = 'b586d4d32c04fa33a30517ab3a1a8469b238d2ac'", text)
        self.assertIn("$relative.Substring(0,$relative.Length-4)", text)
        self.assertNotIn("ChangeExtension($relative,$null)", text)
        self.assertIn("$caseLogText", text)
        self.assertIn("$caseTag='MGTT_' + $case.id", text)
        self.assertIn("[IO.FileShare]::Read", text)
        self.assertNotIn("[IO.FileShare]::ReadWrite", text)
        self.assertIn("performance='NOT_RUN'", text)
        self.assertIn("-Symbol GBPUSD -Period H4 -FromDate 2020.01.02 -ToDate 2020.01.03 -Model 1", text)


def classify_native(
    *, transport: bool, retcode: int, order: int, deal: int, result_volume: float,
    path: str, requested: float, step: float
) -> str:
    accepted = {10008, 10009, 10010}  # PLACED, DONE, DONE_PARTIAL
    documented_non_acceptance = {
        10004, 10006, 10007, 10011, 10012, 10013, 10014, 10015, 10016,
        10017, 10018, 10019, 10020, 10021, 10022, 10023, 10024, 10025,
        10026, 10027, 10028, 10029, 10030, 10031, 10032, 10033, 10034,
        10035, 10036, 10038, 10039, 10040, 10041, 10042, 10043, 10044,
        10045, 10046,
    }
    positive_identity = order > 0 or deal > 0
    positive_volume = result_volume > 0
    if not transport:
        return "UNRESOLVED_RESULT" if retcode in accepted or positive_identity or positive_volume else "REQUEST_REJECTED"
    tolerance = max(1e-12, step * 1e-8)
    if path == "MARKET":
        if retcode == 10009 and positive_identity and result_volume > 0 and step > 0 and abs(result_volume - requested) <= tolerance:
            return "MARKET_ACCEPTED_DONE"
        if retcode == 10010 and positive_identity and 0 < result_volume <= requested + tolerance and step > 0:
            return "MARKET_ACCEPTED_PARTIAL"
        if retcode == 10008 and order > 0:
            return "MARKET_ACCEPTED_PENDING"
        if retcode in accepted:
            return "UNRESOLVED_RESULT"
    elif path == "PENDING":
        if retcode in {10008, 10009} and order > 0:
            return "PENDING_PLACED"
        if retcode in accepted:
            return "UNRESOLVED_RESULT"
    if retcode in documented_non_acceptance:
        if positive_identity or positive_volume:
            return "UNRESOLVED_RESULT"
        return "REQUEST_REJECTED"
    return "UNRESOLVED_RESULT"


@dataclass
class LedgerModel:
    session: str = "A"
    began: bool = False
    ended: bool = False
    sequences: list[int] = field(default_factory=list)
    attempts: dict[int, bool] = field(default_factory=dict)
    submits: dict[int, bool] = field(default_factory=dict)
    native_categories: list[str] = field(default_factory=list)
    deal_ids: set[int] = field(default_factory=set)
    duplicate_deal: bool = False
    mixed_session: bool = False

    def event(self, sequence: int, session: str) -> None:
        self.sequences.append(sequence)
        if session != self.session:
            self.mixed_session = True

    def certified(self) -> bool:
        return (
            self.began
            and self.ended
            and self.sequences == list(range(1, len(self.sequences) + 1))
            and all(self.attempts.values())
            and all(self.submits.values())
            and "UNRESOLVED_RESULT" not in self.native_categories
            and not self.duplicate_deal
            and not self.mixed_session
        )


class PythonContractModelTests(unittest.TestCase):
    def test_path_specific_result_classification(self) -> None:
        cases = [
            (dict(transport=True, retcode=10009, order=1, deal=2, result_volume=0.10, path="MARKET", requested=0.10, step=0.01), "MARKET_ACCEPTED_DONE"),
            (dict(transport=True, retcode=10010, order=1, deal=2, result_volume=0.05, path="MARKET", requested=0.10, step=0.01), "MARKET_ACCEPTED_PARTIAL"),
            (dict(transport=True, retcode=10008, order=1, deal=0, result_volume=0.0, path="PENDING", requested=0.10, step=0.01), "PENDING_PLACED"),
            (dict(transport=True, retcode=10006, order=0, deal=0, result_volume=0.0, path="MARKET", requested=0.10, step=0.01), "REQUEST_REJECTED"),
            (dict(transport=False, retcode=10009, order=0, deal=0, result_volume=0.10, path="MARKET", requested=0.10, step=0.01), "UNRESOLVED_RESULT"),
            (dict(transport=False, retcode=10012, order=0, deal=0, result_volume=0.0, path="MARKET", requested=0.10, step=0.01), "REQUEST_REJECTED"),
            (dict(transport=False, retcode=10012, order=0, deal=0, result_volume=0.01, path="MARKET", requested=0.10, step=0.01), "UNRESOLVED_RESULT"),
            (dict(transport=True, retcode=10006, order=7, deal=0, result_volume=0.0, path="MARKET", requested=0.10, step=0.01), "UNRESOLVED_RESULT"),
            (dict(transport=True, retcode=10005, order=0, deal=0, result_volume=0.0, path="MARKET", requested=0.10, step=0.01), "UNRESOLVED_RESULT"),
            (dict(transport=True, retcode=10037, order=0, deal=0, result_volume=0.0, path="MARKET", requested=0.10, step=0.01), "UNRESOLVED_RESULT"),
            (dict(transport=True, retcode=99999, order=0, deal=0, result_volume=0.0, path="MARKET", requested=0.10, step=0.01), "UNRESOLVED_RESULT"),
        ]
        for values, expected in cases:
            self.assertEqual(classify_native(**values), expected)

    def test_adversarial_sequence_footer_duplicate_and_session_fail_closed(self) -> None:
        good = LedgerModel(began=True, ended=True, attempts={1: True}, submits={1: True}, native_categories=["REQUEST_REJECTED"])
        good.event(1, "A")
        good.event(2, "A")
        self.assertTrue(good.certified())
        for mutate in ("gap", "footer", "attempt", "submit", "unresolved", "duplicate", "session"):
            model = LedgerModel(began=True, ended=True, attempts={1: True}, submits={1: True}, native_categories=["REQUEST_REJECTED"])
            model.event(1, "A")
            model.event(2, "A")
            if mutate == "gap": model.sequences = [1, 3]
            if mutate == "footer": model.ended = False
            if mutate == "attempt": model.attempts[1] = False
            if mutate == "submit": model.submits[1] = False
            if mutate == "unresolved": model.native_categories.append("UNRESOLVED_RESULT")
            if mutate == "duplicate": model.duplicate_deal = True
            if mutate == "session": model.mixed_session = True
            self.assertFalse(model.certified(), mutate)


if __name__ == "__main__":
    print("COVERAGE HOST_ACTUAL_BYTES HOST_SOURCE_BINDING PYTHON_CONTRACT_MODEL")
    print("NATIVE_COVERAGE NOT_RUN_BY_AUTHOR_CONTRACT")
    unittest.main(testRunner=unittest.TextTestRunner(stream=sys.stdout, verbosity=2))
