#!/usr/bin/env python3
"""Deterministic host/adversarial cages for MGTT Repair1.

These tests bind the actual MQL and PowerShell sources and prepare native MQL
probe cages. They do not claim compile, MT5, TPL, or reviewer acceptance.
"""

from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ORIGINAL_BASE = "4aa459566c4e5eedc2477938fa5d3f4f86d00e8e"
REPAIR_PARENT = "5845c4e039a3d9ef57e6997af42655a3d854d34e"
CONTROL = "b586d4d32c04fa33a30517ab3a1a8469b238d2ac"
A1_ADMISSION_BASE = "8268774667b2114bbd5307b8bbc5edcff07e5b8d"
A1_ADMISSION_BASE_TREE = "a381f484951117d650127f6fb82fd4f87c58eef9"
A1_CORRECTIVE_PARENT = "5e390cc90a6f0557d9b5f4f6ff01ce28bd9b7a96"
A1_CORRECTIVE_PARENT_TREE = "53f8e9e19557b5ebffbc3f68db5eeadc5e923553"
A1_SOURCE_LANE = "ct-news-macro-mgtt-shortlived-tester-identity-v1-20260928"
A1_RUNTIME_LOGICAL_LANE = "ct-mgtt-shortlived-tester-identity-native-runtime-20260928"
A1_RUNTIME_CHILD_LANE = "ct-mgtt-shortlived-tester-identity-native-runtime-a1-20260928"
A1_PREDECESSOR_EVIDENCE = r"D:\EA_LAB_CONTROL\evidence\mgtt-runner-exit-provenance-v1-20260928"
A1_CURRENT_EVIDENCE = r"D:\EA_LAB_CONTROL\evidence\mgtt-shortlived-tester-identity-v1-20260928"
V2_BASE = "b9531886c5d2a4e5194684462cf66bd30035e588"
V2_BASE_TREE = "7e817204ed82dc0f35c1d33a2600f84248b2e9d6"
V2_SOURCE_LANE = "ct-news-macro-mgtt-capture-normalization-v2-20260928"
V2_RUNTIME_LANE = "ct-mgtt-capture-normalization-v2-native-runtime-20260928"
V2_PREDECESSOR_EVIDENCE = r"D:\EA_LAB_CONTROL\evidence\mgtt-shortlived-tester-identity-v1-20260928"
V2_CURRENT_EVIDENCE = r"D:\EA_LAB_CONTROL\evidence\mgtt-capture-normalization-v2-20260928"
CONTRACT_ROOT = ROOT / "factory/runs/news_macro_macrogate_tester_transfer_qual_v1_20260926"
CONTRACT = json.loads((CONTRACT_ROOT / "PROSPECTIVE_IMPLEMENTATION_CONTRACT.json").read_text())
EXPECTATIONS = json.loads((CONTRACT_ROOT / "FEED_RUNTIME_EXPECTATIONS.json").read_text())
SOURCE_BINDING = json.loads((CONTRACT_ROOT / "SOURCE_BINDING.json").read_text())
OWNER_AUTH = json.loads(Path(r"D:\EA_LAB_CONTROL\evidence\mg-tester-transfer-impl-v1-20260927\OWNER_AUTHORIZATION.json").read_text(encoding="utf-8-sig"))
REPAIR_AUTH = json.loads(Path(r"D:\EA_LAB_CONTROL\evidence\mg-tester-transfer-impl-v1-20260927\PRECOMMIT_EXACT_TREE_OWNER_AUTH_20260927.json").read_text(encoding="utf-8-sig"))

ALLOWED = {
    "ea_template/Boss_15_ST03.mq5",
    "ea_template/core/LabCore.mqh",
    "ea_template/core/MacroGate_Core.mqh",
    "ea_template/core/Execution.mqh",
    "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1",
    "scripts/_test/macrogate_tester_transfer_probe.mq5",
    "scripts/_test/test_macrogate_tester_transfer_contract.py",
    "scripts/tpl_regression.ps1",
    "scripts/lib/tpl_baseline.ps1",
    "scripts/_test/run_tpl_declared_wrapper_tests.ps1",
}
EVIDENCE_PREFIX = "factory/runs/news_macro_macrogate_tester_transfer_impl_v1_20260927/"


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def git_bytes(*args: str) -> bytes:
    return subprocess.run(
        ["git", "-C", str(ROOT), *args], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE
    ).stdout


def git_text(*args: str) -> str:
    return git_bytes(*args).decode()


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


def parse_tester_feed(raw: bytes) -> dict[str, object]:
    lines = raw.decode("utf-8-sig").splitlines()
    valid: list[tuple[datetime, str]] = []
    skipped = 0
    ascending = True
    previous: datetime | None = None
    for index, line in enumerate(lines):
        if index == 0 or len(line) < 8:
            continue
        try:
            fields = next(csv.reader([line]))
            when = datetime.strptime(fields[0].strip(), "%Y.%m.%d %H:%M")
        except (csv.Error, ValueError, IndexError):
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
    }


def derive_wrong(raw: bytes) -> bytes:
    lines = raw.splitlines(keepends=True)
    changed = lines[2].replace(b" 02:", b" 03:", 1)
    if changed == lines[2] or len(changed) != len(lines[2]):
        raise AssertionError("wrong fixture derivation failed")
    lines[2] = changed
    return b"".join(lines)


def classify_native(*, transport: bool, retcode: int, order: int, deal: int, volume: float,
                    path: str, requested: float, step: float) -> str:
    accepted = {10008, 10009, 10010}
    ambiguous = {10011, 10012, 10023, 10025, 10028, 10031, 10036}
    rejected = {
        10004, 10006, 10007, 10011, 10013, 10014, 10015, 10016, 10017,
        10018, 10019, 10020, 10021, 10022, 10023, 10024, 10025, 10026,
        10027, 10028, 10029, 10030, 10032, 10033, 10034, 10035, 10036,
        10038, 10039, 10040, 10041, 10042, 10043, 10044, 10045, 10046,
    }
    identity = order > 0 or deal > 0
    positive_volume = volume > 0
    if not transport:
        if retcode in accepted or retcode in ambiguous or retcode not in rejected or identity or positive_volume:
            return "UNRESOLVED_RESULT"
        return "REQUEST_REJECTED"
    if retcode in ambiguous or retcode in rejected:
        return "UNRESOLVED_RESULT"
    tolerance = max(1e-12, step * 1e-8)
    if path == "MARKET":
        if retcode == 10009 and identity and volume > 0 and step > 0 and abs(volume - requested) <= tolerance:
            return "MARKET_ACCEPTED_DONE"
        if retcode == 10010 and identity and 0 < volume <= requested + tolerance and step > 0:
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
    return "UNRESOLVED_RESULT"


@dataclass
class LedgerModel:
    sessions: list[str] = field(default_factory=list)
    sequences: dict[str, list[int]] = field(default_factory=dict)
    attempt_ends: dict[int, int] = field(default_factory=dict)
    submit_returns: dict[int, int] = field(default_factory=dict)
    native_results: dict[int, int] = field(default_factory=dict)
    native_categories: list[str] = field(default_factory=list)
    fills_complete: dict[int, bool] = field(default_factory=dict)
    deals: dict[int, tuple[int, str, int, float]] = field(default_factory=dict)
    errors: int = 0

    def event(self, session: str, sequence: int) -> None:
        self.sequences.setdefault(session, []).append(sequence)

    def deal(self, deal_id: int, content: tuple[int, str, int, float]) -> None:
        if deal_id not in self.deals:
            self.deals[deal_id] = content
        elif self.deals[deal_id] != content:
            self.errors += 1

    def certified(self) -> bool:
        gap_free = all(values == list(range(1, len(values) + 1)) for values in self.sequences.values())
        return (
            gap_free
            and all(count == 1 for count in self.attempt_ends.values())
            and all(count == 1 for count in self.submit_returns.values())
            and all(count == 1 for count in self.native_results.values())
            and "UNRESOLVED_RESULT" not in self.native_categories
            and all(self.fills_complete.values())
            and self.errors == 0
        )


class AuthorityAndByteTests(unittest.TestCase):
    def test_authorities_are_narrow_and_exact(self) -> None:
        self.assertTrue(OWNER_AUTH["authorized_implementation"])
        self.assertFalse(OWNER_AUTH["authorized_performance"])
        self.assertEqual(REPAIR_AUTH["repair_parent"], REPAIR_PARENT)
        self.assertEqual(REPAIR_AUTH["current_control"], CONTROL)
        self.assertEqual(REPAIR_AUTH["repair_findings"], [f"MGTT-00{i}" for i in range(1, 8)])
        self.assertFalse(REPAIR_AUTH["performance_authorized"])

    def test_original_source_binding_remains_exact(self) -> None:
        for item in SOURCE_BINDING["source_files"]:
            self.assertEqual(sha256(git_bytes("show", f"{ORIGINAL_BASE}:{item['path']}")), item["sha256"])

    def test_worktree_changes_stay_in_repair_allowlist(self) -> None:
        for line in git_text("status", "--porcelain=v1", "--untracked-files=all").splitlines():
            path = line[3:].replace("\\", "/").split(" -> ")[-1]
            self.assertTrue(path in ALLOWED or path.startswith(EVIDENCE_PREFIX), path)

    def test_all_feed_bytes_and_negative_derivations(self) -> None:
        self.assertEqual(len(EXPECTATIONS["entries"]), 11)
        for item in EXPECTATIONS["entries"]:
            raw = (ROOT / item["source_path"]).read_bytes()
            parsed = parse_tester_feed(raw)
            self.assertEqual(sha256(raw), item["sha256"])
            self.assertEqual(len(raw), item["bytes"])
            self.assertEqual(parsed["rows"], item["rows"])
            self.assertEqual(parsed["first"], item["first"])
            self.assertEqual(parsed["last"], item["last"])
            self.assertTrue(parsed["ascending"])
        raw = (ROOT / EXPECTATIONS["entries"][0]["source_path"]).read_bytes()
        wrong = derive_wrong(raw)
        self.assertEqual(len(wrong), len(raw))
        self.assertEqual(sha256(wrong), "7e1dbd8e3850c5d14858c7183d9f842767bbe0e33d16ed148be4fbd9dc84f5e4")
        self.assertEqual(sha256(b"".join(raw.splitlines(keepends=True)[:-1])), "70271717ee95f618a2d76b2b0a8d1ca2d8da9edf2cc9a079b74d4ea90e484e19")


class ActualSourceContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.execution = (ROOT / "ea_template/core/Execution.mqh").read_text()
        cls.macro = (ROOT / "ea_template/core/MacroGate_Core.mqh").read_text()
        cls.probe = (ROOT / "scripts/_test/macrogate_tester_transfer_probe.mq5").read_text()
        cls.qualifier = (ROOT / "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1").read_text()
        cls.tpl = (ROOT / "scripts/tpl_regression.ps1").read_text()
        cls.tpl_lib = (ROOT / "scripts/lib/tpl_baseline.ps1").read_text()

    def test_loader_is_same_buffer_and_runtime_identity_bound(self) -> None:
        body = extract_balanced(self.macro, "bool MGTT_LoadQualifiedRegime(")
        self.assertEqual(body.count("FileOpen("), 1)
        self.assertEqual(body.count("FileReadArray("), 1)
        self.assertIn("MGTT_Sha256Hex(raw", body)
        self.assertIn("CharArrayToString(raw", body)
        self.assertIn("runtime_session", body)
        self.assertIn("g_mgtt_feed_build=build_receipt", body)
        self.assertIn("g_mgtt_feed_config=config_fingerprint", body)

    def test_terminal_records_are_counted_not_overwritten(self) -> None:
        self.assertIn("int  end_count;", self.execution)
        self.assertIn("int  return_count;", self.execution)
        self.assertIn("int   result_count;", self.execution)
        for marker in ("DUPLICATE_EXECUTION_END", "DUPLICATE_SUBMIT_RETURN", "DUPLICATE_NATIVE_SEND_RESULT"):
            self.assertIn(marker, self.execution)
        completeness = extract_balanced(self.execution, "bool MGTT_CompletenessCertified()")
        self.assertIn("end_count!=1", completeness)
        self.assertIn("return_count!=1", completeness)
        self.assertIn("result_count!=1", completeness)

    def test_deals_are_idempotent_by_content_and_conflicts_fail(self) -> None:
        callback = extract_balanced(self.execution, "void MGTT_OnTradeTransaction(")
        self.assertIn("DUPLICATE_DEAL_IDEMPOTENT", callback)
        self.assertIn("CONTRADICTORY_DEAL", callback)
        self.assertIn("callback_count", callback)
        self.assertNotIn("MGTT_DealAlreadyKnown", self.execution)

    def test_fill_coverage_uses_final_history_and_rejects_active_or_missing(self) -> None:
        finalizer = extract_balanced(self.execution, "bool MGTT_FinalizeOneNativeFill(")
        for token in ("OrderSelect(order_id)", "HistoryOrderSelect(order_id)", "HistoryDealsTotal()", "ORDER_VOLUME_INITIAL", "ORDER_VOLUME_CURRENT", "history_verified"):
            self.assertIn(token, finalizer)
        self.assertIn("MGTT_OrderStateIsActive", finalizer)
        self.assertIn("if(final_filled<=tolerance) return false", finalizer)
        self.assertIn("FILL_COVERAGE_UNAVAILABLE", self.execution)
        self.assertIn("fill_coverage_finalized=%d", self.execution)

    def test_transport_classification_is_fail_closed(self) -> None:
        classify = extract_balanced(self.execution, "string MGTT_ClassifyNative(")
        self.assertIn("MGTT_IsAmbiguousNonAcceptanceRetcode", classify)
        ambiguous = extract_balanced(self.execution, "bool MGTT_IsAmbiguousNonAcceptanceRetcode(")
        for token in ("TRADE_RETCODE_ERROR", "TRADE_RETCODE_ORDER_CHANGED", "TRADE_RETCODE_NO_CHANGES", "TRADE_RETCODE_LOCKED", "TRADE_RETCODE_POSITION_CLOSED"):
            self.assertIn(token, ambiguous)
            self.assertIn(token, self.probe)
        self.assertIn("!MGTT_IsKnownNonAcceptanceRetcode(retcode)", classify)
        observer = extract_balanced(self.execution, "virtual bool OrderSend(")
        self.assertEqual(observer.count("bool transport_ok=CTrade::OrderSend(request,result)"), 1)
        self.assertRegex(observer, r"CTrade::OrderSend\(request,result\);\s*// exactly one forward\s*int raw_last_error=GetLastError\(\);")
        self.assertIn("caller_error_preservation=NOT_CLAIMED", self.execution)

    def test_probe_executes_actual_mql_cages_without_orders(self) -> None:
        for marker in (
            "CERTIFIED_COUNTS_PASS", "IDEMPOTENT_DEAL_PASS", "DUPLICATE_TERMINALS_FAIL_CLOSED_PASS",
            "MISSING_PARTIAL_PENDING_FILL_FAIL_CLOSED_PASS", "CONTRADICTORY_DEAL_FAIL_CLOSED_PASS",
            "CLASSIFICATION_FAIL_CLOSED_PASS", "ADVERSARIAL_FAIL_CLOSED_PASS",
        ):
            self.assertIn(marker, self.probe)
        self.assertIn("MGTT_LEDGER_PROBE_SYNTHETIC", self.probe)
        self.assertNotRegex(self.probe, r"\b(?:CTrade|OrderSend|PositionOpen|Buy|Sell|BuyLimit|SellLimit|BuyStop|SellStop)\s*\(")
        self.assertIn('#define LAB_ENTRY_15', self.probe)
        self.assertIn('string actual_config=CFG_Fingerprint();', self.probe)
        self.assertIn('actual_config!=MGTT_PROBE_CONFIG_FINGERPRINT', self.probe)
        self.assertIn('MGTT_RunBegin(MGTT_PROBE_BUILD_RECEIPT,actual_config,false,', self.probe)

    def test_qualifier_binds_complete_closure_build_config_session_and_logs(self) -> None:
        for token in (
            "Get-CompileClosure", "Copy-ExactClosure", "Assert-StagedClosure", "Resolve-VendorInclude",
            "creation-time staging mismatch", "Write-BuildReceiptRecord", "Get-FullSetIdentity",
            "runtime_session", "Get-ChangedLogSlices", "Get-PrefixSha256", "metatester_processes",
            "SourceCommit", "ExpectedParent", "New-RunnerTree", "PASS_NO_PERFORMANCE",
        ):
            self.assertIn(token, self.qualifier)
        self.assertIn("PROBE_FAIL conflicting mirrored event", self.qualifier)
        self.assertIn("PROBE_FAIL incomplete session terminals", self.qualifier)
        self.assertNotIn("AllowLegacyIdentity", self.qualifier)
        self.assertIn("-Symbol", (ROOT / "scripts/mt5_run.ps1").read_text(encoding="utf-8"))
        self.assertIn("'GBPUSD'", self.qualifier)
        self.assertIn("Period='H4'", self.qualifier)
        self.assertIn("Model=1", self.qualifier)

    def test_precommit_api_is_tree_typed_and_legacy_mode_remains(self) -> None:
        for token in (
            "[switch]$PrecommitExactTree", "[string]$SourceTree", "[string]$RepairParent",
            "Assert-TplTreeIdentity", "write-tree", "New-TplPrecommitMaterialization",
            "Assert-TplMaterializedTree", "SourceTree changes an undeclared repair path",
            "precommit exact-tree mode cannot mix", "FULL_TPL_CLEAN",
        ):
            self.assertIn(token, self.tpl + self.tpl_lib)
        self.assertIn('$pythonRoot = if ($PrecommitExactTree) { $invocationRoot } else { $harnessRoot }', self.tpl)
        self.assertIn("SourceRoot is usable only with explicit DeclaredCoreDelta", self.tpl)
        self.assertIn("default", (ROOT / "scripts/_test/run_tpl_declared_wrapper_tests.ps1").read_text().lower())


class NativeHarnessExecutionTests(unittest.TestCase):
    """Execute the actual PowerShell helpers without launching a trading process."""

    @staticmethod
    def ps_quote(value: object) -> str:
        return "'" + str(value).replace("'", "''") + "'"

    def run_helper(self, name: str, body: str, directory: Path) -> subprocess.CompletedProcess:
        source = ROOT / "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1"
        script = directory / (name + ".ps1")
        script.write_text(
            "$ErrorActionPreference='Stop'\n"
            "$tokens=$null;$parseErrors=$null\n"
            f"$ast=[Management.Automation.Language.Parser]::ParseFile({self.ps_quote(source)},[ref]$tokens,[ref]$parseErrors)\n"
            "if($parseErrors.Count){throw 'source parse failure'}\n"
            "$defs=$ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)\n"
            f"$definition=@($defs | Where-Object Name -eq '{name}')\n"
            "if($definition.Count -ne 1){throw 'helper identity ambiguous'}\n"
            "foreach($def in $defs){. ([scriptblock]::Create($def.Extent.Text))}\n" + body,
            encoding="utf-8-sig",
        )
        return subprocess.run(
            ["powershell.exe", "-NoProfile", "-File", str(script)],
            capture_output=True, text=True, timeout=90,
            env={k: v for k, v in os.environ.items() if k.upper() != "PSMODULEPATH"},
        )

    def test_named_runner_arguments_reach_actual_script_parameters(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_bind_") as temp:
            directory = Path(temp)
            (directory / "scripts").mkdir()
            (directory / "scripts/mt5_run.ps1").write_text(
                "param([string]$Expert,[string]$Symbol,[int]$Model,[string]$SetFile)\n"
                "@{Expert=$Expert;Symbol=$Symbol;Model=$Model;SetFile=$SetFile}|ConvertTo-Json -Compress\nexit 0\n",
                encoding="utf-8-sig",
            )
            expert = "EA_LAB_TEST\\literal $name's value"
            set_file = "C:\\fixture space\\literal $() and apostrophe's.set"
            result = self.run_helper(
                "Write-RunnerInvocation",
                f"$command=Write-RunnerInvocation {self.ps_quote(directory)} "
                f"@{{Expert={self.ps_quote(expert)};Symbol='GBPUSD';Model=1;SetFile={self.ps_quote(set_file)}}} "
                f"{self.ps_quote(directory)}\n& $command\n",
                directory,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(json.loads(result.stdout), dict(Expert=expert, Symbol="GBPUSD", Model=1, SetFile=set_file))

    def test_actual_transitive_compile_closure_materializes_typed_arrays(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_closure_") as temp:
            result = self.run_helper(
                "Get-CompileClosure",
                f"$RepoRoot={self.ps_quote(ROOT)}\n"
                "$SourceCommit=(git -C $RepoRoot write-tree).Trim()\n"
                "$bossRelative='ea_template/Boss_15_ST03.mq5'\n"
                "$probeRelative='scripts/_test/macrogate_tester_transfer_probe.mq5'\n"
                "$vendorRoot='D:\\MetaTraderData\\Roaming\\MetaQuotes\\Terminal\\9CA16B8382AE4CF692710FB36B9DA355\\MQL5\\Include'\n"
                ". (Join-Path $RepoRoot 'scripts\\lib\\evidence.ps1')\n"
                "$closure=Get-CompileClosure\n"
                "@{repo_count=$closure.repo.Count;vendor_count=$closure.vendor.Count;"
                "trade_count=@($closure.vendor|Where-Object path -Like '*\\Trade\\Trade.mqh').Count} | ConvertTo-Json -Compress\n",
                Path(temp),
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            facts = json.loads(result.stdout)
            self.assertGreater(facts['repo_count'], 20)
            self.assertGreaterEqual(facts['vendor_count'], 6)
            self.assertEqual(facts['trade_count'], 1)

    def test_runner_archive_preserves_long_path_bytes_and_refuses_traversal(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_archive_") as temp:
            directory = Path(temp)
            archive = directory / "valid.zip"
            relative = "/".join(["long_component_" + "x" * 35] * 5) + "/source.txt"
            payload = b"exact\r\nsource\n\x00bytes"
            with zipfile.ZipFile(archive, "w") as writer:
                writer.writestr(relative, payload)
            destination = directory / "materialized"
            result = self.run_helper(
                "Expand-MgttGitArchive",
                f"Expand-MgttGitArchive {self.ps_quote(archive)} {self.ps_quote(destination)} {self.ps_quote(sys.executable)}\n",
                directory,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            # The portable runtime also needs the extended prefix when reading
            # and removing the deliberately over-MAX_PATH fixture.
            extended_destination = Path("\\\\?\\" + str(destination.resolve()))
            try:
                self.assertEqual((extended_destination / relative).read_bytes(), payload)
            finally:
                self.assertEqual(destination.resolve().parent, directory.resolve())
                shutil.rmtree(extended_destination)
            bad_archive = directory / "bad.zip"
            with zipfile.ZipFile(bad_archive, "w") as writer:
                writer.writestr("../escaped.txt", b"must not escape")
            result = self.run_helper(
                "Expand-MgttGitArchive",
                f"Expand-MgttGitArchive {self.ps_quote(bad_archive)} {self.ps_quote(directory / 'rejected')} {self.ps_quote(sys.executable)}\n",
                directory,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((directory / "escaped.txt").exists())


class AuthorRebindPredecessorPinTests(unittest.TestCase):
    """Keep the four mandatory A1 predecessor artifacts byte-pinned in V2."""

    def test_hard_admission_retains_exact_a1_predecessor_evidence_pins(self) -> None:
        source = (ROOT / "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1").read_text(encoding="utf-8-sig")
        offline = extract_balanced(source, "function Invoke-OfflineValidation")
        preflight = extract_balanced(source, "function Invoke-PreflightValidation")
        exact_tokens = (
            r"a1-closeout\A1_DURABLE_CHECKPOINT.json",
            "c75d153511a529884141a542a5ba433ad90128065719d4e24b6439a29c94ed19",
            r"a1-closeout\A1_FINAL_RECONCILIATION.json",
            "5e8e4e55614bf642aca3fc8312b8df07dfe5122a616e19ab90f732ee41b00268",
            r"a1-native-campaign\POSITIVE_GOLDEN_REAL.PROCESS_OBSERVATIONS.json",
            "e9b0cec4c20bf8064cc8905f64ea62bf2b4c5968275d37cf66eef3ea7baf5ffe",
            r"a1-native-campaign\POSITIVE_GOLDEN_REAL\POSITIVE_GOLDEN_REAL.RUNNER_EXIT.json",
            "e7b0ed1c89b688e3c45750540b0c3c43d820c79a600eb48709958c8fe4ad58c6",
        )
        for token in exact_tokens:
            self.assertIn(token, offline)
        self.assertIn("Assert-CurrentContractIdentity", offline)
        self.assertIn("RuntimeLeaseRecordId", preflight)


class CaptureNormalizationV2IdentityTests(NativeHarnessExecutionTests):
    """Pin the prospective V2 source/runtime/evidence identity."""

    def run_identity(self, directory: Path, **overrides: str) -> subprocess.CompletedProcess:
        values = {
            "AdmissionBase": V2_BASE,
            "SourceLane": V2_SOURCE_LANE,
            "RuntimeLogicalLane": V2_RUNTIME_LANE,
            "RuntimeRecordLane": V2_RUNTIME_LANE,
            "PredecessorEvidenceRoot": V2_PREDECESSOR_EVIDENCE,
            "CurrentEvidenceRoot": V2_CURRENT_EVIDENCE,
        }
        values.update(overrides)
        arguments = " ".join(
            f"-{name} {self.ps_quote(value)}" for name, value in values.items()
        )
        return self.run_helper(
            "Assert-CurrentContractIdentity",
            f"Assert-CurrentContractIdentity {arguments} | ConvertTo-Json -Compress\n",
            directory,
        )

    def test_v2_contract_identity_is_accepted_and_predecessor_identity_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_v2_identity_") as temp:
            result = self.run_identity(Path(temp))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertEqual(observed["admission_base"], V2_BASE)
            self.assertEqual(observed["source_lane"], V2_SOURCE_LANE)
            self.assertEqual(observed["runtime_logical_lane"], V2_RUNTIME_LANE)
        for field, stale in (
            ("AdmissionBase", A1_ADMISSION_BASE),
            ("SourceLane", A1_SOURCE_LANE),
            ("RuntimeLogicalLane", A1_RUNTIME_LOGICAL_LANE),
            ("PredecessorEvidenceRoot", A1_PREDECESSOR_EVIDENCE),
            ("CurrentEvidenceRoot", A1_CURRENT_EVIDENCE),
        ):
            with self.subTest(field=field), tempfile.TemporaryDirectory(prefix="mgtt_v2_stale_") as temp:
                result = self.run_identity(Path(temp), **{field: stale})
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_v2_hard_admission_tokens_are_exact(self) -> None:
        source = (ROOT / "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1").read_text(encoding="utf-8-sig")
        for token in (
            V2_BASE,
            V2_BASE_TREE,
            V2_SOURCE_LANE,
            V2_RUNTIME_LANE,
            V2_PREDECESSOR_EVIDENCE,
            V2_CURRENT_EVIDENCE,
            "7b49bbb22cfa85691212532cf3cc8ed125576fad815c8ed7b507a5f8585522cd",
            "e39a5c5de3ad2e2137049cd807a573ceb3bef799fe5e12192ff9866d8a382289",
        ):
            self.assertIn(token, source.lower() if token == token.lower() else source)


class SuccessorConfigTests(unittest.TestCase):
    """Execute the prospective calculator embedded in the production harness."""

    def calculator(self):
        source = (ROOT / "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1").read_text(encoding="utf-8-sig")
        match = re.search(r"\$configCalculator = @'\n(.*?)\n'@", source, re.S)
        self.assertIsNotNone(match, "production prospective calculator missing")
        sys.path.insert(0, str(ROOT / "_triage/factory_os"))
        namespace = {"__name__": "mgtt_fixture"}
        exec(compile(match[1], "production_config_calculator", "exec"), namespace)
        return namespace["mgtt_identity"]

    def test_current_closure_and_stale_expected_rejection(self):
        calculate = self.calculator()
        read = lambda path: git_bytes("show", f"HEAD:{path}").decode("utf-8-sig")
        frozen = read("ea_template/sets/regression/Boss_15_ST03_defaults.set")
        result = calculate(read, frozen)
        self.assertEqual(result["keys"], 157)
        self.assertEqual(result["constants"]["MG_ST_INVALID"], "-100")
        self.assertEqual(result["fingerprint"], "7dfd909aa23a659dbf41b3bf4004e764b96fd62a4f106d53fb8290ac8efe92cc")
        stale = "d3d548b77d96037fbee8a483bd25206f2d323600f2e00cf8ad012c7f566c2456"
        with self.assertRaisesRegex(ValueError, "CONFIG_MISMATCH"):
            calculate(read, frozen, stale)
        self.assertEqual(calculate(read, frozen, result["fingerprint"]), result)

    def test_changed_and_added_constants_with_identical_inputs_change_identity(self):
        calculate = self.calculator()
        read = lambda path: git_bytes("show", f"HEAD:{path}").decode("utf-8-sig")
        frozen = read("ea_template/sets/regression/Boss_15_ST03_defaults.set")
        original = calculate(read, frozen)
        for replacement in ("#define MG_ST_INVALID -101", "#define MG_ST_INVALID -100\n#define MGTT_FIXTURE_CONSTANT 17"):
            def changed(path):
                text = read(path)
                return re.sub(r"#define\s+MG_ST_INVALID\s+\(-100\)", replacement, text)
            revised = calculate(changed, frozen)
            self.assertEqual(original["inputs"], revised["inputs"])
            self.assertNotEqual(original["fingerprint"], revised["fingerprint"])

    def test_header_is_not_the_computation_and_missing_extra_duplicate_inputs_refuse(self):
        calculate = self.calculator()
        read = lambda path: git_bytes("show", f"HEAD:{path}").decode("utf-8-sig")
        frozen = read("ea_template/sets/regression/Boss_15_ST03_defaults.set")
        original = calculate(read, frozen)
        self.assertEqual(original, calculate(read, re.sub(r"[0-9a-f]{64}", "0" * 64, frozen)))
        lines = frozen.splitlines()
        assignment = next(line for line in lines if line and not line.startswith(";") and "=" in line)
        for invalid in (frozen.replace(assignment + "\n", ""), frozen + "\nextra=1\n", frozen + "\n" + assignment):
            with self.assertRaises(ValueError):
                calculate(read, invalid)


class SuccessorProcessTests(NativeHarnessExecutionTests):
    def test_old_two_step_observation_reproduces_short_lived_enrichment_race(self):
        """The predecessor saw PID/start time, then lost the process before enrichment."""
        with tempfile.TemporaryDirectory(prefix="mgtt_old_race_") as temp:
            directory = Path(temp)
            result = self.run_helper(
                "Add-ProcessObservation",
                "$row=[ordered]@{kind='SELECTED_CANDIDATE';pid=25952;"
                "creation_time_utc='2026-09-28T05:45:41.3552037Z';path=$null;sha256=$null;"
                "parent_pid=$null;ancestry=@();observation_status='RAW'}\n"
                "$initiallyObserved=$true\n"
                "$enrichmentLookup=@()\n"
                "if($initiallyObserved -and $enrichmentLookup.Count -ne 1){"
                "$row.observation_status='INCOMPLETE';"
                "$row.error='process exited or identity changed during observation'}\n"
                "$row|ConvertTo-Json -Depth 10 -Compress\n",
                directory,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            row = json.loads(result.stdout)
            self.assertEqual(row["pid"], 25952)
            self.assertTrue(row["creation_time_utc"])
            self.assertIsNone(row["path"])
            self.assertEqual(row["observation_status"], "INCOMPLETE")

    def test_single_early_snapshot_survives_selected_process_exit_before_enrichment(self):
        """One snapshot must contain everything needed after the tester disappears."""
        with tempfile.TemporaryDirectory(prefix="mgtt_single_snapshot_") as temp:
            directory = Path(temp)
            terminal = directory / "terminal64.exe"
            tester = directory / "metatester64.exe"
            body = (
                f"$evidenceFull={self.ps_quote(directory)}\n"
                f"$journal={self.ps_quote(directory / 'PROCESS_OBSERVATIONS.jsonl')}\n"
                "$start=[datetime]'2026-09-28T05:00:00Z'\n"
                f"$t=[pscustomobject]@{{path={self.ps_quote(terminal)};sha256=('a'*64);file_version='T'}}\n"
                f"$m=[pscustomobject]@{{path={self.ps_quote(tester)};sha256=('b'*64);file_version='M'}}\n"
                "$script:snapshotCalls=0\n"
                "function Get-CimInstance {\n"
                "  $script:snapshotCalls++\n"
                "  if($script:snapshotCalls -gt 1){throw 'selected process already exited'}\n"
                "  return @(\n"
                "    [pscustomobject]@{Name='powershell.exe';ProcessId=9;ParentProcessId=1;CreationDate=[datetime]'2026-09-28T04:59:59Z';ExecutablePath='C:\\Windows\\powershell.exe';CommandLine='runner'},\n"
                f"    [pscustomobject]@{{Name='terminal64.exe';ProcessId=11;ParentProcessId=9;CreationDate=[datetime]'2026-09-28T05:00:01Z';ExecutablePath={self.ps_quote(terminal)};CommandLine='terminal'}},\n"
                f"    [pscustomobject]@{{Name='metatester64.exe';ProcessId=12;ParentProcessId=11;CreationDate=[datetime]'2026-09-28T05:00:02Z';ExecutablePath={self.ps_quote(tester)};CommandLine='tester'}},\n"
                "    [pscustomobject]@{Name='explorer.exe';ProcessId=1;ParentProcessId=0;CreationDate=[datetime]'2026-09-28T04:00:00Z';ExecutablePath='C:\\Windows\\explorer.exe';CommandLine='shell'}\n"
                "  )\n"
                "}\n"
                "$rows=@(Get-EarlyProcessSnapshot $t $m $start $journal)\n"
                "$captured=Complete-ProcessCapture $rows $t $m $start 'CASE'\n"
                "@{calls=$script:snapshotCalls;rows=$rows;captured=$captured}|ConvertTo-Json -Depth 20 -Compress\n"
            )
            result = self.run_helper("Get-EarlyProcessSnapshot", body, directory)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertEqual(observed["calls"], 1)
            self.assertEqual(len(observed["rows"]), 2)
            for row in observed["rows"]:
                self.assertEqual(row["observation_status"], "COMPLETE")
                self.assertTrue(row["path"])
                self.assertTrue(row["sha256"])
                self.assertTrue(row["parent_pid"])
                self.assertTrue(row["ancestry"])

    def test_actual_capture_persists_missing_snapshot_refusal(self):
        with tempfile.TemporaryDirectory(prefix="mgtt_capture_") as temp:
            directory = Path(temp)
            for filename in ('terminal64.exe', 'metatester64.exe', 'runner.stdout.log', 'runner.stderr.log'):
                (directory / filename).write_bytes(b'fixture')
            body = (
                f"$evidenceFull={self.ps_quote(directory)}\n$Terminal=Join-Path $evidenceFull 'terminal64.exe'\n"
                "function Start-Process { $p=[pscustomobject]@{Id=9;StartTime=[datetime]::Now;HasExited=$true;ExitCode=1};$p|Add-Member ScriptMethod WaitForExit {};return $p }\n"
                "function Get-CimInstance { return @() }\n"
                "Invoke-RunnerCaptured $evidenceFull @{} $evidenceFull\n"
            )
            result = self.run_helper('Invoke-RunnerCaptured', body, directory)
            self.assertNotEqual(result.returncode, 0)
            journal = [json.loads(x) for x in (directory / 'PROCESS_OBSERVATIONS.jsonl').read_text().splitlines()]
            self.assertEqual([x["kind"] for x in journal], ["RUNNER"])
            receipt = json.loads((directory / (directory.name + '.PROCESS_OBSERVATIONS.json')).read_text(encoding='utf-8-sig'))
            self.assertEqual(len(receipt['observations']), 0)

    def test_full_set_preparation_preserves_frozen_assignments_and_binds_current_git(self):
        with tempfile.TemporaryDirectory(prefix="mgtt_set_") as temp:
            directory = Path(temp)
            result = self.run_helper(
                "Get-FullSetIdentity",
                f"$RepoRoot={self.ps_quote(ROOT)}\n$evidenceFull={self.ps_quote(directory)}\n"
                "$SourceCommit=(git -C $RepoRoot rev-parse HEAD).Trim()\n"
                "$setRelative='ea_template/sets/regression/Boss_15_ST03_defaults.set'\n"
                ". (Join-Path $RepoRoot 'scripts/lib/evidence.ps1')\n"
                ". (Join-Path $RepoRoot 'scripts/lib/setfile_surface.ps1')\n"
                ". (Join-Path $RepoRoot 'scripts/lib/build_receipt.ps1')\n"
                "Get-FullSetIdentity | ConvertTo-Json -Depth 5\n", directory)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            info = json.loads(result.stdout)
            self.assertEqual(info['fingerprint'], '7dfd909aa23a659dbf41b3bf4004e764b96fd62a4f106d53fb8290ac8efe92cc')
            frozen = (directory / 'FROZEN_Boss_15_ST03_defaults.set').read_bytes()
            self.assertEqual(frozen, git_bytes('show', 'HEAD:ea_template/sets/regression/Boss_15_ST03_defaults.set'))
            rows = lambda data: [x for x in data.decode('utf-8-sig').splitlines() if x and not x.startswith(';')]
            self.assertEqual(rows(frozen), rows(Path(info['path']).read_bytes()))

    def test_durable_failure_missing_extra_short_lived_pid_reuse_and_wrong_identity(self):
        for case in ("valid", "missing", "extra", "short_lived", "historical", "pid_reuse", "wrong_identity"):
            with self.subTest(case=case), tempfile.TemporaryDirectory(prefix="mgtt_process_") as temp:
                directory = Path(temp)
                result = self.run_helper(
                    "Complete-ProcessCapture",
                    "$evidenceFull=" + self.ps_quote(directory) + "\n"
                    "$start=[datetime]'2026-09-28T05:00:00Z'\n"
                    "$t=@{path='D:\\Meta 5\\terminal64.exe';sha256=('a'*64)}\n"
                    "$m=@{path='D:\\Meta 5\\metatester64.exe';sha256=('b'*64)}\n"
                    "$rows=@(@{pid=11;creation_time_utc='2026-09-28T05:00:01Z';identity_key='11|2026-09-28T05:00:01.0000000Z';path=$t.path;sha256=$t.sha256;parent_pid=9;ancestry=@(@{pid=9;status='OBSERVED'});observation_status='COMPLETE'},"
                    "@{pid=12;creation_time_utc='2026-09-28T05:00:02Z';identity_key='12|2026-09-28T05:00:02.0000000Z';path=$m.path;sha256=$m.sha256;parent_pid=11;ancestry=@(@{pid=11;status='OBSERVED'});observation_status='COMPLETE'})\n"
                    + {"valid": "", "missing": "$rows=@($rows[0])\n", "extra": "$rows+=@{pid=13;creation_time_utc='2026-09-28T05:00:03Z';path=$m.path;sha256=$m.sha256;parent_pid=11;ancestry=@();observation_status='COMPLETE'}\n",
                       "short_lived": "$rows[1].observation_status='EXITED_BEFORE_ENRICHMENT';$rows[1].sha256=$null\n",
                       "historical": "$rows[1].creation_time_utc='2026-09-27T05:00:02Z'\n",
                       "pid_reuse": "$rows+=@{pid=12;creation_time_utc='2026-09-28T05:00:03Z';identity_key='12|2026-09-28T05:00:03.0000000Z';path=$m.path;sha256=$m.sha256;parent_pid=11;ancestry=@(@{pid=11;status='OBSERVED'});observation_status='COMPLETE'}\n",
                       "wrong_identity": "$rows[1].path='D:\\Other\\metatester64.exe'\n"}[case]
                    + "Complete-ProcessCapture $rows $t $m $start 'CASE' | ConvertTo-Json -Depth 10\n",
                    directory,
                )
                receipt = directory / "CASE.PROCESS_OBSERVATIONS.json"
                self.assertTrue(receipt.exists(), result.stdout + result.stderr)
                evidence = json.loads(receipt.read_text(encoding="utf-8-sig"))
                self.assertEqual(len(evidence["observations"]), 1 if case == "missing" else 3 if case in {"extra", "pid_reuse"} else 2)
                self.assertEqual(result.returncode == 0, case == "valid", result.stdout + result.stderr)
                if case == "short_lived":
                    row = evidence["observations"][1]
                    self.assertEqual((row["pid"], row["creation_time_utc"], row["parent_pid"]), (12, "2026-09-28T05:00:02Z", 11))

    def test_capture_flushes_before_validation_and_uses_no_historical_reconstruction(self):
        source = (ROOT / "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1").read_text(encoding="utf-8-sig")
        capture = extract_balanced(source, "function Invoke-RunnerCaptured")
        self.assertIn("Add-ProcessObservation", capture)
        self.assertIn("finally", capture)
        self.assertIn("Complete-ProcessCapture", capture)
        self.assertIn("Get-EarlyProcessSnapshot", capture)
        self.assertNotIn("Get-Process", capture)
        helper = extract_balanced(source, "function Add-ProcessObservation")
        self.assertIn("Flush($true)", helper)
        validate = extract_balanced(source, "function Complete-ProcessCapture")
        self.assertLess(validate.index("Write-Receipt"), validate.index("throw"))
        self.assertNotIn("Get-Process", validate)
        self.assertNotIn("Get-CimInstance", validate)

    def test_runner_exit_is_durable_before_selected_process_validation_refuses(self):
        with tempfile.TemporaryDirectory(prefix="mgtt_exit_before_validation_") as temp:
            directory = Path(temp)
            for filename in ("terminal64.exe", "metatester64.exe", "runner.stdout.log", "runner.stderr.log"):
                (directory / filename).write_bytes(b"fixture")
            body = (
                f"$evidenceFull={self.ps_quote(directory)}\n$Terminal=Join-Path $evidenceFull 'terminal64.exe'\n"
                "function Start-Process { $p=[pscustomobject]@{Id=91;StartTime=[datetime]'2026-09-28T05:00:00Z';HasExited=$true;ExitCode=23};$p|Add-Member ScriptMethod WaitForExit {};return $p }\n"
                "function Get-CimInstance { return @() }\n"
                "$failed=$false;try{Invoke-RunnerCaptured $evidenceFull @{} $evidenceFull}catch{$failed=$true}\n"
                "if(!$failed){throw 'expected selected-process validation refusal'}\n"
            )
            result = self.run_helper("Invoke-RunnerCaptured", body, directory)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            receipt_path = directory / (directory.name + ".RUNNER_EXIT.json")
            self.assertTrue(receipt_path.exists())
            receipt = json.loads(receipt_path.read_text(encoding="utf-8-sig"))
            self.assertEqual(receipt["schema"], "mgtt_runner_exit/1")
            self.assertEqual(receipt["runner"]["pid"], 91)
            self.assertEqual(receipt["runner"]["exit_code"], 23)
            self.assertEqual(receipt["runner"]["exit_code_source"], "OWNED_RUNNER_PROCESS_AFTER_WAITFOREXIT")
            self.assertFalse(receipt["evidence_policy"]["stdout_text_used_for_exit_code"])
            self.assertFalse(receipt["evidence_policy"]["report_presence_used_for_exit_code"])


class CaptureNormalizationV2Tests(NativeHarnessExecutionTests):
    """Exercise the exact host seams changed by Capture Normalization V2."""

    def test_ordered_dictionary_single_match_is_one_real_identity_object(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_v2_scalar_") as temp:
            directory = Path(temp)
            terminal = directory / "terminal64.exe"
            tester = directory / "metatester64.exe"
            result = self.run_helper(
                "Get-EarlyProcessSnapshot",
                f"$journal={self.ps_quote(directory / 'PROCESS_OBSERVATIONS.jsonl')}\n"
                "$start=[datetime]'2026-09-28T05:00:00Z'\n"
                f"$t=[ordered]@{{path={self.ps_quote(terminal)};sha256=('a'*64);file_version='T-1'}}\n"
                f"$m=[ordered]@{{path={self.ps_quote(tester)};sha256=('b'*64);file_version='M-1'}}\n"
                "function Get-CimInstance { return @(\n"
                "  [pscustomobject]@{Name='powershell.exe';ProcessId=9;ParentProcessId=1;CreationDate=[datetime]'2026-09-28T04:59:59Z';ExecutablePath='C:\\Windows\\powershell.exe';CommandLine='runner'},\n"
                f"  [pscustomobject]@{{Name='terminal64.exe';ProcessId=11;ParentProcessId=9;CreationDate=[datetime]'2026-09-28T05:00:01Z';ExecutablePath={self.ps_quote(terminal)};CommandLine='terminal'}}\n"
                ")}\n"
                "$row=@(Get-EarlyProcessSnapshot $t $m $start $journal)[0]\n"
                "$row|ConvertTo-Json -Depth 20 -Compress\n",
                directory,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertEqual(observed["observation_status"], "COMPLETE")
            self.assertEqual(observed["path"], str(terminal))
            self.assertEqual(observed["sha256"], "a" * 64)
            self.assertEqual(observed["file_version"], "T-1")

    def test_zero_and_multiple_expected_matches_fail_closed(self) -> None:
        for case in ("zero", "multiple"):
            with self.subTest(case=case), tempfile.TemporaryDirectory(prefix="mgtt_v2_match_count_") as temp:
                directory = Path(temp)
                terminal = directory / "terminal64.exe"
                other = directory / "other.exe"
                terminal_expected = other if case == "zero" else terminal
                tester_expected = directory / "tester.exe" if case == "zero" else terminal
                result = self.run_helper(
                    "Get-EarlyProcessSnapshot",
                    f"$journal={self.ps_quote(directory / 'PROCESS_OBSERVATIONS.jsonl')}\n"
                    "$start=[datetime]'2026-09-28T05:00:00Z'\n"
                    f"$t=[ordered]@{{path={self.ps_quote(terminal_expected)};sha256=('a'*64);file_version='T'}}\n"
                    f"$m=[ordered]@{{path={self.ps_quote(tester_expected)};sha256=('b'*64);file_version='M'}}\n"
                    "function Get-CimInstance { return @(\n"
                    "  [pscustomobject]@{Name='powershell.exe';ProcessId=9;ParentProcessId=1;CreationDate=[datetime]'2026-09-28T04:59:59Z';ExecutablePath='C:\\Windows\\powershell.exe';CommandLine='runner'},\n"
                    f"  [pscustomobject]@{{Name='terminal64.exe';ProcessId=11;ParentProcessId=9;CreationDate=[datetime]'2026-09-28T05:00:01Z';ExecutablePath={self.ps_quote(terminal)};CommandLine='terminal'}}\n"
                    ")}\n"
                    "$row=@(Get-EarlyProcessSnapshot $t $m $start $journal)[0]\n"
                    "$row|ConvertTo-Json -Depth 20 -Compress\n",
                    directory,
                )
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                observed = json.loads(result.stdout)
                self.assertEqual(observed["observation_status"], "INCOMPLETE")
                self.assertIn("extra or unselected process executable identity", observed["error"])

    def test_unkeyed_raw_row_is_journaled_but_not_promoted_before_valid_rows(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_v2_unkeyed_") as temp:
            directory = Path(temp)
            (directory / "scripts").mkdir()
            (directory / "scripts/mt5_run.ps1").write_text("exit 0\n", encoding="utf-8-sig")
            for filename in ("terminal64.exe", "metatester64.exe", "runner.stdout.log", "runner.stderr.log"):
                (directory / filename).write_bytes(b"fixture")
            body = (
                f"$evidenceFull={self.ps_quote(directory)}\n"
                f"$Terminal={self.ps_quote(directory / 'terminal64.exe')}\n"
                "function Start-Process { $p=[pscustomobject]@{Id=900;StartTime=[datetime]::UtcNow;HasExited=$true;ExitCode=0};$p|Add-Member ScriptMethod WaitForExit {};return $p }\n"
                "function Get-EarlyProcessSnapshot($ExpectedTerminal,$ExpectedTester,$LaunchUtc,$JournalPath) {\n"
                "  $raw=[ordered]@{kind='SELECTED_CANDIDATE';pid=101;creation_time_utc=$null;identity_key=$null;path=$null;sha256=$null;parent_pid=$null;ancestry=@();observation_status='INCOMPLETE';error='snapshot missing PID, creation time, or executable path'}\n"
                "  Add-ProcessObservation $JournalPath $raw\n"
                "  $tc=[datetime]::UtcNow.AddSeconds(1);$mc=$tc.AddMilliseconds(1)\n"
                "  $t=[ordered]@{kind='SELECTED_CANDIDATE';pid=101;creation_time_utc=$tc.ToString('o');identity_key=('101|'+$tc.ToString('o'));path=$ExpectedTerminal.path;sha256=$ExpectedTerminal.sha256;file_version=$ExpectedTerminal.file_version;parent_pid=900;ancestry=@(@{pid=900;status='OBSERVED'});observation_status='COMPLETE'}\n"
                "  $m=[ordered]@{kind='SELECTED_CANDIDATE';pid=102;creation_time_utc=$mc.ToString('o');identity_key=('102|'+$mc.ToString('o'));path=$ExpectedTester.path;sha256=$ExpectedTester.sha256;file_version=$ExpectedTester.file_version;parent_pid=101;ancestry=@(@{pid=101;status='OBSERVED'});observation_status='COMPLETE'}\n"
                "  return @($raw,$t,$m)\n"
                "}\n"
                "$run=Invoke-RunnerCaptured $evidenceFull @{} $evidenceFull\n"
                "$journal=@(Get-Content -LiteralPath (Join-Path $evidenceFull 'PROCESS_OBSERVATIONS.jsonl')|ForEach-Object{$_|ConvertFrom-Json})\n"
                "$accepted=Get-Content -Raw (Join-Path $evidenceFull ((Split-Path $evidenceFull -Leaf)+'.PROCESS_VALIDATION.json'))|ConvertFrom-Json\n"
                "@{run=$run;raw_unkeyed=@($journal|Where-Object{$_.kind -eq 'SELECTED_CANDIDATE' -and [string]::IsNullOrWhiteSpace([string]$_.identity_key)}).Count;accepted_count=@($accepted.observations).Count}|ConvertTo-Json -Depth 20 -Compress\n"
            )
            result = self.run_helper("Invoke-RunnerCaptured", body, directory)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertEqual(observed["raw_unkeyed"], 1)
            self.assertEqual(observed["accepted_count"], 2)
            self.assertEqual(len(observed["run"]["terminal_processes"]), 1)
            self.assertEqual(len(observed["run"]["metatester_processes"]), 1)

    def test_ambiguous_reused_or_wrong_valid_identities_remain_fail_closed(self) -> None:
        mutations = {
            "duplicate": "$rows+=$rows[1].Clone()\n",
            "extra": "$rows+=@{pid=13;creation_time_utc='2026-09-28T05:00:03Z';identity_key='13|2026-09-28T05:00:03.0000000Z';path=$m.path;sha256=$m.sha256;parent_pid=11;ancestry=@(@{pid=11;status='OBSERVED'});observation_status='COMPLETE'}\n",
            "pid_reuse": "$rows+=@{pid=12;creation_time_utc='2026-09-28T05:00:03Z';identity_key='12|2026-09-28T05:00:03.0000000Z';path=$m.path;sha256=$m.sha256;parent_pid=11;ancestry=@(@{pid=11;status='OBSERVED'});observation_status='COMPLETE'}\n",
            "wrong_path": "$rows[1].path='D:\\Other\\metatester64.exe'\n",
            "wrong_hash": "$rows[1].sha256=('c'*64)\n",
        }
        for case, mutation in mutations.items():
            with self.subTest(case=case), tempfile.TemporaryDirectory(prefix="mgtt_v2_fail_closed_") as temp:
                directory = Path(temp)
                result = self.run_helper(
                    "Complete-ProcessCapture",
                    f"$evidenceFull={self.ps_quote(directory)}\n"
                    "$start=[datetime]'2026-09-28T05:00:00Z'\n"
                    "$t=@{path='D:\\Meta 5\\terminal64.exe';sha256=('a'*64)}\n"
                    "$m=@{path='D:\\Meta 5\\metatester64.exe';sha256=('b'*64)}\n"
                    "$rows=@(@{pid=11;creation_time_utc='2026-09-28T05:00:01Z';identity_key='11|2026-09-28T05:00:01.0000000Z';path=$t.path;sha256=$t.sha256;parent_pid=9;ancestry=@(@{pid=9;status='OBSERVED'});observation_status='COMPLETE'},"
                    "@{pid=12;creation_time_utc='2026-09-28T05:00:02Z';identity_key='12|2026-09-28T05:00:02.0000000Z';path=$m.path;sha256=$m.sha256;parent_pid=11;ancestry=@(@{pid=11;status='OBSERVED'});observation_status='COMPLETE'})\n"
                    + mutation
                    + "Complete-ProcessCapture $rows $t $m $start 'CASE'|ConvertTo-Json -Depth 20 -Compress\n",
                    directory,
                )
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def run_owned_child(self, directory: Path, exit_code: int) -> subprocess.CompletedProcess:
        stdout = directory / "runner.stdout.log"
        stderr = directory / "runner.stderr.log"
        report = directory / "report.htm"
        stdout.write_bytes(b"OK REPORT must not substitute\n")
        stderr.write_bytes(b"")
        report.write_bytes(b"<html>report</html>\n")
        body = (
            f"$evidenceFull={self.ps_quote(directory)}\n"
            f"$stdout={self.ps_quote(stdout)};$stderr={self.ps_quote(stderr)};$report={self.ps_quote(report)}\n"
            f"$p=Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoProfile','-Command','exit {exit_code}') -PassThru -WindowStyle Hidden\n"
            "$pidValue=$p.Id;$created=$p.StartTime.ToUniversalTime().ToString('o');$p.WaitForExit();$code=[int]$p.ExitCode\n"
            "$exitReceipt=Write-RunnerExitReceipt $evidenceFull 'HOST_CHILD' $pidValue $created $code $stdout $stderr\n"
            "$runner=[pscustomobject]@{runner_pid=$pidValue;runner_creation_time_utc=$created;exit_code=$code;exit_code_source='OWNED_RUNNER_PROCESS_AFTER_WAITFOREXIT';stdout=$stdout;stderr=$stderr}\n"
            f"$gate=Write-RunnerGateReceipt $evidenceFull '{V2_BASE}' '{V2_BASE_TREE}' 'POSITIVE_GOLDEN_REAL' $runner $report $true\n"
            "$passed=$false;try{Assert-PositiveRunnerReportGate $gate;$passed=$true}catch{}\n"
            "@{exit_receipt=$exitReceipt;gate=$gate;passed=$passed}|ConvertTo-Json -Depth 20 -Compress\n"
        )
        return self.run_helper("Write-RunnerExitReceipt", body, directory)

    def test_owned_host_child_exit_zero_is_durable_numeric_zero(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_v2_exit_zero_") as temp:
            result = self.run_owned_child(Path(temp), 0)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertEqual(observed["exit_receipt"]["runner"]["exit_code"], 0)
            self.assertTrue(observed["exit_receipt"]["runner"]["exit_code_available"])
            self.assertEqual(observed["exit_receipt"]["runner"]["exit_code_source"], "OWNED_RUNNER_PROCESS_AFTER_WAITFOREXIT")
            self.assertTrue(observed["passed"])

    def test_owned_host_child_nonzero_is_exact_and_positive_gate_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_v2_exit_nonzero_") as temp:
            result = self.run_owned_child(Path(temp), 17)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertEqual(observed["exit_receipt"]["runner"]["exit_code"], 17)
            self.assertFalse(observed["passed"])
            self.assertEqual(observed["gate"]["guard_outcome"], "FAIL_CLOSED")
            self.assertFalse(observed["gate"]["evidence_policy"]["stdout_text_used_for_exit_code"])
            self.assertFalse(observed["gate"]["evidence_policy"]["report_presence_substituted_for_exit_zero"])


class RunnerExitProvenanceTests(NativeHarnessExecutionTests):
    """Exercise the exact durable gate seam added by the amendment."""

    BASE = "6503ed949b70caad379d0d11842c9aa7c6b2f1ef"
    BASE_TREE = "d3e8c181e505628a3329bfeb459cce671f46a6a1"

    def run_gate(self, directory: Path, *, exit_code: int | None, report_present: bool,
                 report_fresh: bool = True, stdout: bytes = b"runner output\n") -> subprocess.CompletedProcess:
        stdout_path = directory / "runner.stdout.log"
        stderr_path = directory / "runner.stderr.log"
        report_path = directory / "report.htm"
        stdout_path.write_bytes(stdout)
        stderr_path.write_bytes(b"runner error stream\n")
        if report_present:
            report_path.write_bytes(b"<html>exact report</html>\n")
        exit_literal = "$null" if exit_code is None else str(exit_code)
        body = (
            f"$evidenceFull={self.ps_quote(directory)}\n"
            f"$stdout={self.ps_quote(stdout_path)}\n"
            f"$stderr={self.ps_quote(stderr_path)}\n"
            f"$report={self.ps_quote(report_path)}\n"
            "$runner=[pscustomobject]@{runner_pid=4242;runner_creation_time_utc='2026-09-28T07:00:00.0000000Z';"
            f"exit_code={exit_literal};exit_code_source='OWNED_RUNNER_PROCESS_AFTER_WAITFOREXIT';"
            "stdout=$stdout;stderr=$stderr;stdout_sha256=(Get-Sha256 $stdout);stderr_sha256=(Get-Sha256 $stderr)}\n"
            f"$receipt=Write-RunnerGateReceipt -CaseRoot $evidenceFull -SourceCommit '{self.BASE}' "
            f"-SourceTree '{self.BASE_TREE}' -CaseId 'POSITIVE_GOLDEN_REAL' -Runner $runner "
            f"-ReportPath $report -ReportFresh:${str(report_fresh).lower()}\n"
            "$passed=$false;$errorText=$null\n"
            "try{Assert-PositiveRunnerReportGate -Receipt $receipt;$passed=$true}catch{$errorText=$_.Exception.Message}\n"
            "@{passed=$passed;error=$errorText;receipt=$receipt}|ConvertTo-Json -Depth 20 -Compress\n"
        )
        return self.run_helper("Write-RunnerGateReceipt", body, directory)

    def test_report_present_and_exit_zero_can_pass(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_gate_zero_") as temp:
            result = self.run_gate(Path(temp), exit_code=0, report_present=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertTrue(observed["passed"])
            self.assertEqual(observed["receipt"]["guard_outcome"], "PASS")

    def test_report_present_and_nonzero_exit_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_gate_nonzero_") as temp:
            result = self.run_gate(Path(temp), exit_code=1, report_present=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertFalse(observed["passed"])
            self.assertEqual(observed["error"], "PROBE_FAIL positive runner/report")
            self.assertEqual(observed["receipt"]["guard_outcome"], "FAIL_CLOSED")

    def test_report_present_and_null_exit_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_gate_null_") as temp:
            result = self.run_gate(Path(temp), exit_code=None, report_present=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertFalse(observed["passed"])
            self.assertIsNone(observed["receipt"]["runner"]["exit_code"])
            self.assertFalse(observed["receipt"]["predicate"]["runner_exit_available"])

    def test_report_absent_and_exit_zero_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_gate_absent_") as temp:
            result = self.run_gate(Path(temp), exit_code=0, report_present=False, report_fresh=False)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertFalse(observed["passed"])
            self.assertFalse(observed["receipt"]["predicate"]["report_present"])

    def test_failure_receipt_is_durable_before_guard_and_complete(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_gate_receipt_") as temp:
            directory = Path(temp)
            result = self.run_gate(directory, exit_code=9, report_present=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            receipt_path = directory / "POSITIVE_GOLDEN_REAL.RUNNER_GATE.json"
            self.assertTrue(receipt_path.exists())
            receipt = json.loads(receipt_path.read_text(encoding="utf-8-sig"))
            self.assertEqual(receipt["schema"], "mgtt_runner_gate/1")
            self.assertEqual(receipt["source_commit"], self.BASE)
            self.assertEqual(receipt["source_tree"], self.BASE_TREE)
            self.assertEqual(receipt["case"], "POSITIVE_GOLDEN_REAL")
            self.assertEqual(receipt["runner"]["exit_code"], 9)
            self.assertEqual(receipt["runner"]["pid"], 4242)
            self.assertTrue(receipt["runner"]["creation_time_utc"])
            self.assertEqual(receipt["stdout"]["sha256"], sha256((directory / "runner.stdout.log").read_bytes()))
            self.assertEqual(receipt["stderr"]["sha256"], sha256((directory / "runner.stderr.log").read_bytes()))
            self.assertEqual(receipt["report"]["expected_path"], str(directory / "report.htm"))
            self.assertTrue(receipt["report"]["present"])
            self.assertEqual(receipt["report"]["sha256"], sha256((directory / "report.htm").read_bytes()))
            self.assertFalse(receipt["predicate"]["pass"])
            self.assertEqual(receipt["guard_outcome"], "FAIL_CLOSED")
            self.assertTrue(receipt["recorded_utc"])

    def test_ok_report_stdout_never_substitutes_for_exit_code(self) -> None:
        with tempfile.TemporaryDirectory(prefix="mgtt_gate_stdout_") as temp:
            result = self.run_gate(Path(temp), exit_code=None, report_present=True, stdout=b"OK REPORT\n")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            observed = json.loads(result.stdout)
            self.assertFalse(observed["passed"])
            self.assertFalse(observed["receipt"]["evidence_policy"]["stdout_text_used_for_exit_code"])

    def test_no_current_process_snapshot_manufactures_exit_code(self) -> None:
        source = (ROOT / "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1").read_text(encoding="utf-8-sig")
        writer = extract_balanced(source, "function Write-RunnerGateReceipt")
        gate = extract_balanced(source, "function Assert-PositiveRunnerReportGate")
        self.assertNotIn("Get-Process", writer + gate)
        self.assertNotIn("Get-CimInstance", writer + gate)
        self.assertNotIn("OK REPORT", writer + gate)
        with tempfile.TemporaryDirectory(prefix="mgtt_gate_snapshot_") as temp:
            result = self.run_gate(Path(temp), exit_code=None, report_present=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            receipt = json.loads(result.stdout)["receipt"]
            self.assertIsNone(receipt["runner"]["exit_code"])
            self.assertFalse(receipt["evidence_policy"]["current_process_snapshot_used_for_exit_code"])

    def test_native_gate_writes_receipt_before_positive_decision(self) -> None:
        source = (ROOT / "scripts/macrogate_tester_transfer_qual/qualify_transfer.ps1").read_text(encoding="utf-8-sig")
        native = extract_balanced(source, "function Invoke-NativeQualification")
        self.assertLess(native.index("Write-RunnerGateReceipt"), native.index("Assert-PositiveRunnerReportGate"))
        self.assertNotIn("$run.exit_code -ne 0 -or !(Test-Path $reportPath)", native)
        capture = extract_balanced(source, "function Invoke-RunnerCaptured")
        for token in ("runner_pid", "runner_creation_time_utc", "OWNED_RUNNER_PROCESS_AFTER_WAITFOREXIT"):
            self.assertIn(token, capture)


class AdversarialLedgerTests(unittest.TestCase):
    def test_known_rejection_vs_unknown_and_ambiguous_false_transport(self) -> None:
        base = dict(order=0, deal=0, volume=0.0, path="MARKET", requested=0.1, step=0.01)
        self.assertEqual(classify_native(transport=False, retcode=10006, **base), "REQUEST_REJECTED")
        for code in (0, 10005, 10011, 10012, 10023, 10025, 10028, 10031, 10036, 10037, 99999):
            self.assertEqual(classify_native(transport=False, retcode=code, **base), "UNRESOLVED_RESULT")
        self.assertEqual(classify_native(transport=False, retcode=10009, order=1, deal=0, volume=0.1, path="MARKET", requested=0.1, step=0.01), "UNRESOLVED_RESULT")
        self.assertEqual(classify_native(transport=True, retcode=10006, **base), "UNRESOLVED_RESULT")
        self.assertEqual(classify_native(transport=True, retcode=10006, order=1, deal=0, volume=0.0, path="MARKET", requested=0.1, step=0.01), "UNRESOLVED_RESULT")

    def test_duplicate_terminals_and_incomplete_fills_fail(self) -> None:
        good = LedgerModel(attempt_ends={1: 1}, submit_returns={1: 1}, native_results={1: 1}, native_categories=["REQUEST_REJECTED"], fills_complete={})
        good.event("A", 1); good.event("A", 2)
        self.assertTrue(good.certified())
        for field_name in ("attempt_ends", "submit_returns", "native_results"):
            bad = LedgerModel(attempt_ends={1: 1}, submit_returns={1: 1}, native_results={1: 1}, native_categories=["REQUEST_REJECTED"])
            getattr(bad, field_name)[1] = 2
            self.assertFalse(bad.certified(), field_name)
        missing = LedgerModel(attempt_ends={1: 1}, submit_returns={1: 1}, native_results={1: 1}, native_categories=["PENDING_PLACED"], fills_complete={1: False})
        self.assertFalse(missing.certified())

    def test_identical_deal_is_idempotent_but_conflict_fails(self) -> None:
        model = LedgerModel()
        content = (123, "EURUSD", 0, 0.1)
        model.deal(7, content); model.deal(7, content)
        self.assertEqual(len(model.deals), 1); self.assertEqual(model.errors, 0)
        model.deal(7, (123, "EURUSD", 0, 0.2))
        self.assertEqual(model.errors, 1); self.assertFalse(model.certified())

    def test_sequence_gap_and_mixed_session_are_detectable(self) -> None:
        model = LedgerModel()
        model.event("A", 1); model.event("A", 3); model.event("B", 1)
        self.assertFalse(model.certified())
        self.assertEqual(set(model.sequences), {"A", "B"})


if __name__ == "__main__":
    print("COVERAGE HOST_ACTUAL_BYTES ACTUAL_MQL_SOURCE ACTUAL_POWERSHELL_SOURCE ADVERSARIAL_MODEL")
    print("NATIVE_MQL_CAGES PREPARED_NOT_RUN_BY_AUTHOR_CONTRACT")
    unittest.main(testRunner=unittest.TextTestRunner(stream=sys.stdout, verbosity=2))
