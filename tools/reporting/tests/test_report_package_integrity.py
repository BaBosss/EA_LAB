import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path

HERE = Path(__file__).resolve()
TOOL_DIR = HERE.parents[1]
REPO_ROOT = HERE.parents[3]
HISTORICAL_RECEIPT = REPO_ROOT / "factory/runs/b11_default_example_rerun_20260920/build/build_receipts.jsonl"
HISTORICAL_RECEIPT_SHA256 = "4067deffe5d18fd2a53d4da1302d9f152f9c2306aec4f9779a93349f45ec7cb7"
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

import report_package_integrity as rpi


class ReportPackageIntegrityTests(unittest.TestCase):
    @staticmethod
    def owner_additional_2_delimiter_paths():
        roots = ("<EVIDENCE_ROOT>/", "/home/", "Z:/Users/",
                 "//private-server/private-share/")
        tails = ("O'Brien/alice/private-root/file.json",
                 'D"Angelo/tenant/hidden-tree/file.json',
                 "segment\nalice/private-root/file.json",
                 "segment\r\nline\ntenant/hidden-tree/file.json",
                 "segment -> alice/private-root/file.json",
                 "segment' tenant/hidden-tree/file.json",
                 "segment'\nalice/private-root/file.json")
        return [root + tail for root in roots for tail in tails]

    def test_owner_additional_2_delimiter_tails_are_never_released(self):
        for raw in self.owner_additional_2_delimiter_paths():
            for separator in ("/", "\\"):
                path = raw.replace("/", separator)
                for wrapper in ("{}", "cannot read '{}'", 'cannot read "{}"'):
                    message = wrapper.format(path)
                    for exc in (rpi.Refusal(message), OSError(5, message),
                                OSError(5, "denied", path)):
                        with self.subTest(path=path, wrapper=wrapper, kind=type(exc).__name__):
                            shown = rpi.portable_error(exc)
                            for secret in ("brien", "angelo", "alice", "tenant", "private-root",
                                           "hidden-tree", "file.json", "private-server", "private-share"):
                                self.assertNotIn(secret, shown.casefold())
                            self.assertEqual(shown, rpi.portable_error(rpi.Refusal(shown)))
                            self.assertEqual(shown, rpi.portable_error(exc))

    def test_owner_additional_2_comparisons_with_relative_paths_stay_readable(self):
        for operator in ("<", ">", "<=", ">="):
            for reference in ("reports/result.json", r"reports\result.json"):
                message = f"expected {operator} 5 for {reference}"
                for exc in (rpi.Refusal(message), OSError(5, message)):
                    with self.subTest(message=message, kind=type(exc).__name__):
                        self.assertEqual(message, rpi.portable_error(exc))
        for message in ("a < b and c > d for reports/result.json",
                        "value > threshold for reports/result.json",
                        "expected < count for reports/result.json",
                        "a<b and c>d for reports/result.json"):
            self.assertEqual(message, rpi.portable_error(rpi.Refusal(message)))

    def test_owner_additional_2_known_roots_and_generated_labels(self):
        for root in ("Z:/qualified/repo", "/qualified/repo", "//qualified/share/repo"):
            for tail in ("reports/result.json", "folder with spaces/result.json"):
                for wrapper in ("cannot read {}", "cannot read '{}'", 'cannot read "{}"'):
                    with self.subTest(root=root, tail=tail, wrapper=wrapper):
                        shown = rpi.portable_error(rpi.Refusal(wrapper.format(root + "/" + tail)),
                                                   repo_root=root)
                        self.assertEqual(wrapper.format(tail), shown)
                        self.assertEqual(shown, rpi.portable_error(rpi.Refusal(shown), repo_root=root))
        for raw in self.owner_additional_2_delimiter_paths():
            label = rpi.portable_path(raw)
            for message in (label, "denied: " + label, "denied: " + label + " -> " + label,
                            "cannot read '" + label + "'\n"):
                with self.subTest(message=message):
                    self.assertEqual(message, rpi.portable_error(rpi.Refusal(message)))

    def test_owner_additional_3_malformed_placeholder_privacy_boundary(self):
        tail = "subject'quoted/restricted-tree/file.json"
        windows_tail = tail.replace("/", "\\")
        cases = (
            "< EVIDENCE_ROOT " + tail,
            "cannot read '/srv/" + tail + "'",
            'cannot read "Q:/Users/' + tail + '"',
            'cannot read "\\\\node\\share\\' + windows_tail + '"',
            "< EVIDENCE_ROOT\nsubject/restricted-tree/file.json",
            "< EVIDENCE_ROOT <ANYTHING>/subject/restricted-tree/file.json",
            "< EVIDENCE_ROOT <EVIDENCE_ROOT>/subject/restricted-tree/file.json",
        )
        for message in cases:
            for exc in (rpi.Refusal(message), OSError(5, message)):
                with self.subTest(message=message, kind=type(exc).__name__):
                    shown = rpi.portable_error(exc)
                    self.assertNotIn("restricted-tree", shown.casefold())
                    self.assertNotIn("subject", shown.casefold())
                    self.assertEqual(shown, rpi.portable_error(rpi.Refusal(shown)))
        for message in ("expected < 5 for reports/result.json",
                        "expected > 5 for reports/result.json"):
            for exc in (rpi.Refusal(message), OSError(5, message)):
                self.assertEqual(message, rpi.portable_error(exc))

    @staticmethod
    def owner_repair_private_paths():
        paths = []
        # Labels cannot attest to the origin of a syntactically relative tail.
        for label in ("<EVIDENCE_ROOT>", "<REPO_ROOT>", "<ABSOLUTE_ROOT>",
                      "<USER_HOME_012345ABCD>", "<WORKTREE_012345ABCD>"):
            for tail in ("Users/alice/private-root/file.json",
                         "home/alice/private-root/file.json",
                         "arbitrary/alice/private-root/file.json"):
                for separator in ("/", "\\"):
                    paths.append(label + separator + tail.replace("/", separator))
        paths += [
            "/home/alice/private-root/file.json", r"\Users\alice\private-root\file.json",
            r"Z:\Users\alice\private-root\file.json", r"Z:\arbitrary\alice\private-root\file.json",
            r"\\server-alice\share-secret\private-root\file.json",
            r"\\?\UNC\server-alice\share-secret\private-root\file.json",
            r"\\?\Z:\Users\alice\private-root\file.json",
            r"\??\Z:\Users\alice\private-root\file.json", r"\\.\pipe\private-root",
            "~/alice/private-root/file.json", "~alice/private-root/file.json",
        ]
        return paths

    def test_owner_repair_private_tail_opacity_and_error_agreement(self):
        for raw in self.owner_repair_private_paths():
            with self.subTest(raw=raw):
                shown = rpi.portable_path(raw)
                for secret in ("alice", "private-root", "home/alice", "server-alice", "share-secret"):
                    self.assertNotIn(secret, shown.casefold())
                self.assertNotIn("/", shown)
                self.assertEqual(shown, rpi.portable_path(shown))
                self.assertEqual(shown, rpi.portable_path(raw))
                for exc in (rpi.Refusal(raw), OSError(5, raw)):
                    self.assertEqual(shown, rpi.portable_error(exc))
                self.assertEqual("denied: " + shown, rpi.portable_error(OSError(5, "denied", raw)))

    def test_owner_repair_ordinary_angle_diagnostics(self):
        for message in ("expected < 5", "value > threshold", "a < b and c > d",
                        "expected <= 5", "value >= threshold", "a<b and c>d"):
            for exc in (rpi.Refusal(message), OSError(5, message)):
                with self.subTest(message=message, exception=type(exc).__name__):
                    self.assertEqual(message, rpi.portable_error(exc))

    def test_owner_repair_rendered_json_text_leakage_scan(self):
        payload = [{"path": rpi.portable_path(raw),
                    "error": rpi.portable_error(rpi.Refusal("cannot read '" + raw + "'"))}
                   for raw in self.owner_repair_private_paths()]
        rendered = json.dumps(payload) + "\n" + "\n".join(row["error"] for row in payload)
        for secret in ("alice", "private-root", "server-alice", "share-secret", "home/alice"):
            self.assertNotIn(secret, rendered.casefold())

    def test_owner_repair_known_root_relative_positive_controls(self):
        for root in ("Z:/qualified/repo", "/qualified/repo", "//qualified/share/repo"):
            for tail in ("reports/packet.json", "folder with spaces/file.json"):
                for separator in ("/", "\\"):
                    raw = (root + "/" + tail).replace("/", separator)
                    self.assertEqual(tail, rpi.portable_path(raw, repo_root=root))
        # Evidence references keep a deterministic identity, without an untrusted tail.
        for raw in ("D:/EA_LAB_CONTROL/evidence/lane-a/packet.json",
                    "D:/EA_LAB_CONTROL/evidence/lane-b/packet.json"):
            shown = rpi.portable_path(raw)
            self.assertRegex(shown, r"^<EVIDENCE_ROOT_[0-9A-F]{10}>$")
            self.assertEqual(shown, rpi.portable_path(shown))

    def test_owner_repair_placeholder_near_collision_matrix(self):
        paths = ["<EVIDENCE_ROOT>" + separator + "arbitrary/alice/private-root"
                 for separator in ("/", "\\", "//", "\\\\", "/\\", "\\/")]
        paths += ["<ANYTHING>/alice/private-root", "<EVIDENCE_ROOT/alice/private-root",
                  "<<EVIDENCE_ROOT>>/alice/private-root", ">alice/private-root",
                  "<EVIDENCE_ROOT><EVIDENCE_ROOT>/alice/private-root"]
        shown = [rpi.portable_path(raw) for raw in paths]
        self.assertEqual(len(paths), len(set(shown)))
        for raw, result in zip(paths, shown):
            self.assertRegex(result, r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
            self.assertEqual(result, rpi.portable_error(rpi.Refusal(raw)))
            self.assertEqual(result, rpi.portable_path(result))

    def test_owner_repair_angle_placeholder_context_matrix(self):
        attacks = ["< EVIDENCE_ROOT >/Users/alice/private-root/file.json",
                   "< EVIDENCE_ROOT /alice/private-root/file.json",
                   "> alice/private-root/file.json", "<ANYTHING>/alice/private-root",
                   "<EVIDENCE_ROOT>/<ANYTHING>/alice/private-root",
                   "<EVIDENCE_ROOT><EVIDENCE_ROOT>/alice/private-root"]
        for raw in attacks:
            with self.subTest(raw=raw):
                shown = rpi.portable_path(raw)
                self.assertRegex(shown, r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
                self.assertEqual(shown, rpi.portable_error(rpi.Refusal(raw)))
                self.assertNotIn("alice", shown.casefold())
                self.assertNotIn("private-root", shown.casefold())
        for token in ("<ANYTHING>", "< ANYTHING >", "<EVIDENCE_ROOT", "<<EVIDENCE_ROOT>>"):
            self.assertRegex(rpi.portable_error(rpi.Refusal(token)), r"^<UNSAFE_PATH_[0-9A-F]{64}>$")

    def make_dir_link(self, target: Path, link: Path) -> None:
        if os.name == "nt":
            result = subprocess.run(
                ["cmd", "/d", "/c", "mklink", "/J", str(link), str(target)],
                capture_output=True, text=True, check=False,
            )
            if result.returncode != 0:
                self.skipTest(f"cannot create Windows junction: {result.stderr or result.stdout}")
        else:
            link.symlink_to(target, target_is_directory=True)

    def remove_dir_link(self, link: Path) -> None:
        if not link.exists() and not link.is_symlink():
            return
        if os.name == "nt":
            subprocess.run(["cmd", "/d", "/c", "rmdir", str(link)], check=True)
        else:
            link.unlink()

    def make_package(self, root: Path) -> tuple[Path, Path]:
        (root / "machine").mkdir()
        (root / "visuals").mkdir()
        (root / "machine" / "summary.json").write_text('{"pf": 1.23}\n', encoding="utf-8")
        (root / "report.md").write_text("# Result\n\nEvidence only.\n", encoding="utf-8")
        (root / "visuals" / "pf.csv").write_text("cell,pf\nA,1.23\n", encoding="utf-8")
        spec = {
            "package_id": "PKG-TEST-001",
            "direct_consumer": "Main Control Tower test intake",
            "authority": "RESEARCH_ONLY / NO_RUNTIME_AUTHORITY",
            "metadata": {"experiment_id": "EXP-001", "holdout": "UNSPENT"},
            "artifacts": [                {"path": "visuals/pf.csv", "role": "visual_source"},
                {"path": "report.md", "role": "report"},
                {"path": "machine/summary.json", "role": "machine_summary", "note": "source-bound summary"},
            ],
        }
        spec_path = root / "package_spec.json"
        manifest_path = root / "report_package_manifest.json"
        spec_path.write_text(json.dumps(spec, indent=2), encoding="utf-8")
        return spec_path, manifest_path

    def test_build_validate_and_deterministic_bytes(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            manifest = rpi.build_manifest(spec_path, manifest_path)
            rpi.write_manifest(manifest, manifest_path)
            first = manifest_path.read_bytes()
            result = rpi.validate_manifest(manifest_path)
            self.assertEqual("PASS", result["status"])
            self.assertEqual("PKG-TEST-001", result["package_id"])
            self.assertEqual(3, result["artifact_count"])
            self.assertEqual(
                ["machine/summary.json", "report.md", "visuals/pf.csv"],
                [row["path"] for row in manifest["artifacts"]],
            )
            expected = hashlib.sha256((root / "machine" / "summary.json").read_bytes()).hexdigest()
            summary = next(row for row in manifest["artifacts"] if row["path"] == "machine/summary.json")
            self.assertEqual(expected, summary["sha256"])
            for row in manifest["artifacts"]:
                artifact = root / row["path"]
                self.assertEqual(artifact.stat().st_size, row["size_bytes"])
                self.assertEqual(hashlib.sha256(artifact.read_bytes()).hexdigest(), row["sha256"])
            second_path = root / "manifest_second.json"
            rpi.write_manifest(rpi.build_manifest(spec_path, second_path), second_path)
            self.assertEqual(first, second_path.read_bytes())

    def test_portable_path_rules_cover_windows_user_control_repo_and_unc_inputs(self):
        repo_root = Path(r"D:\portable\EA_LAB")
        cases = {
            r"factory\runs\cell-a\packet.json": "factory/runs/cell-a/packet.json",
            r"D:\portable\EA_LAB\factory\runs\cell-b\packet.json": "factory/runs/cell-b/packet.json",
        }
        for raw, expected in cases.items():
            with self.subTest(raw=raw):
                self.assertEqual(expected, rpi.portable_path(raw, repo_root=repo_root))
                self.assertNotIn("alice", rpi.portable_path(raw, repo_root=repo_root).casefold())
                self.assertNotIn("bob", rpi.portable_path(raw, repo_root=repo_root).casefold())

        labelled_cases = {
            r"C:\Users\alice\Desktop\packet.json": (r"^<USER_HOME_[0-9A-F]{10}>$", "alice"),
            r"C:\Users\bob\Downloads\packet.json": (r"^<USER_HOME_[0-9A-F]{10}>$", "bob"),
            r"D:\EA_LAB_CONTROL\w\lane-a\tools\reporting\packet.json": (
                r"^<WORKTREE_[0-9A-F]{10}>$",
                "lane-a",
            ),
            r"\\server-a\share-a\research\packet.json": (
                r"^<UNC_ROOT_[0-9A-F]{10}>$",
                "server-a",
            ),
        }
        for raw, (pattern, secret_root) in labelled_cases.items():
            with self.subTest(raw=raw):
                rendered = rpi.portable_path(raw, repo_root=repo_root)
                self.assertRegex(rendered, pattern)
                self.assertNotIn(secret_root, rendered.casefold())

    def test_portable_path_canonicalizes_extended_windows_namespaces_before_classification(self):
        pairs = [
            (
                r"C:\Users\alice\private\packet.json",
                r"\\?\C:\Users\alice\private\packet.json",
                r"^<USER_HOME_[0-9A-F]{10}>$",
                ("alice",),
            ),
            (
                r"D:\EA_LAB_CONTROL\evidence\lane-a\packet.json",
                r"\\?\D:\EA_LAB_CONTROL\evidence\lane-a\packet.json",
                r"^<EVIDENCE_ROOT_[0-9A-F]{10}>$",
                (),
            ),
            (
                r"D:\EA_LAB_CONTROL\w\private-lane\tools\packet.json",
                r"\\?\D:\EA_LAB_CONTROL\w\private-lane\tools\packet.json",
                r"^<WORKTREE_[0-9A-F]{10}>$",
                ("private-lane",),
            ),
            (
                r"\\server-a\share-a\research\packet.json",
                r"\\?\UNC\server-a\share-a\research\packet.json",
                r"^<UNC_ROOT_[0-9A-F]{10}>$",
                ("server-a", "share-a"),
            ),
        ]
        for ordinary, extended, pattern, secrets in pairs:
            with self.subTest(ordinary=ordinary, extended=extended):
                ordinary_rendered = rpi.portable_path(ordinary)
                extended_rendered = rpi.portable_path(extended)
                self.assertEqual(ordinary_rendered, extended_rendered)
                self.assertRegex(extended_rendered, pattern)
                for secret in secrets:
                    self.assertNotIn(secret, extended_rendered.casefold())

    def test_portable_path_fails_closed_for_placeholder_absolute_tails(self):
        self.assertRegex(
            rpi.portable_path(r"<EVIDENCE_ROOT>\lane-b\packet.json"),
            r"^<UNSAFE_PATH_[0-9A-F]{64}>$",
        )

        cases = [
            (
                r"<EVIDENCE_ROOT>/\\?\C:\Users\alice\private\packet.json",
                r"^<UNSAFE_PATH_[0-9A-F]{64}>$",
                ("alice", "C:"),
            ),
            (
                r"<EVIDENCE_ROOT>/\\?\UNC\server-a\share-a\private\packet.json",
                r"^<UNSAFE_PATH_[0-9A-F]{64}>$",
                ("server-a", "share-a"),
            ),
            (
                r"<EVIDENCE_ROOT>/\\.\pipe\private-channel",
                r"^<UNSAFE_PATH_[0-9A-F]{64}>$",
                ("pipe", "private-channel"),
            ),
        ]
        for raw, pattern, secrets in cases:
            with self.subTest(raw=raw):
                rendered = rpi.portable_path(raw)
                self.assertRegex(rendered, pattern)
                for secret in secrets:
                    self.assertNotIn(secret.casefold(), rendered.casefold())

    def test_successor_recognizes_only_explicit_placeholder_grammar(self):
        labels = ["<REPO_ROOT>", "<EVIDENCE_ROOT>", "<ABSOLUTE_ROOT>"]
        labels += [f"<{kind}_012345ABCD>" for kind in (
            "WORKTREE", "USER_HOME", "UNC_ROOT", "ABSOLUTE_ROOT", "DEVICE_PATH", "UNSAFE_TAIL"
        )]
        labels.append("<UNSAFE_PATH_" + "A" * 64 + ">")
        for label in labels:
            for tail in ("", "/reports/packet.json", "/folder with spaces/file.json"):
                with self.subTest(label=label, tail=tail):
                    expected = label + tail
                    if not tail:
                        self.assertEqual(expected, rpi.portable_path(expected))
                    else:
                        self.assertRegex(rpi.portable_path(expected), r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
                    self.assertEqual(rpi.portable_path(expected), rpi.portable_path(rpi.portable_path(expected)))
                    if tail:
                        self.assertRegex(rpi.portable_path(expected.replace("/", "\\")), r"^<UNSAFE_PATH_[0-9A-F]{64}>$")

    def test_successor_later_defect_red_first_regression(self):
        for label in ("<ANYTHING>", "<evidence_root>", "<USER_HOME>",
                      "<USER_HOME_ALICE>", "<USER_HOME_012345ABCD0>", "<USER_HOME_012345abcd>"):
            with self.subTest(label=label):
                result = rpi.portable_path(label + "/Users/alice/private-root/file.json")
                self.assertRegex(result, r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
                self.assertNotIn("alice", result.casefold())
                self.assertNotIn("private-root", result.casefold())

    @staticmethod
    def successor_malformed_paths():
        tails = [
            "/Users/alice/private-root/file.json", "//Users/alice/private-root/file.json",
            "C:/Users/alice/private-root/file.json", "C:private-root/file.json",
            r"\\server-alice\private-root\file.json", r"\\?\C:\Users\alice\private-root\file.json",
            r"\\?\UNC\server-alice\private-root\file.json", r"\\.\pipe\private-root",
            r"\??\C:\Users\alice\private-root\file.json", "/home/alice/private-root/file.json",
            "../alice/private-root", "safe/../../alice/private-root", "safe//alice/private-root",
            "safe/./alice/private-root", "safe/C:/Users/alice/private-root",
            "<EVIDENCE_ROOT>/alice/private-root", "<ANYTHING>/alice/private-root",
            "safe/<ANYTHING>/alice/private-root", "alice/private-root/", "alice/private-root/.",
            "alice/private-root/file:stream", "alice/private-root\x00/file", "alice/private-root\n/file",
            "alice/private-root/.. ", "alice/private-root/file.", "alice/private-root/ file",
            "alice/private-root/fi?le", "alice/private-root/fi*le",
        ]
        paths = [label + "/" + tail for label in ("<EVIDENCE_ROOT>", "<USER_HOME_012345ABCD>") for tail in tails]
        paths += ["<<EVIDENCE_ROOT>>/alice/private-root", "<EVIDENCE_ROOT><EVIDENCE_ROOT>/alice/private-root",
                  "<EVIDENCE_ROOT/alice/private-root", ">alice/private-root", "<ANYTHING>/alice/private-root",
                  "<EVIDENCE_ROOT>/" * 2000 + "alice/private-root"]
        return paths

    def test_successor_adversarial_malformed_paths_and_idempotence(self):
        for index, raw in enumerate(self.successor_malformed_paths()):
            with self.subTest(case=index):
                result = rpi.portable_path(raw)
                self.assertRegex(result, r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
                self.assertNotIn("alice", result.casefold())
                self.assertNotIn("private-root", result.casefold())
                self.assertEqual(result, rpi.portable_path(result))
                self.assertEqual(result, rpi.portable_path(raw))

    def test_successor_near_collision_separators_preserve_distinct_identity(self):
        paths = ["<EVIDENCE_ROOT>" + "/" * n + "Users/alice/private-root/file.json" for n in range(2, 12)]
        paths += ["<EVIDENCE_ROOT>/<ANYTHING>/alice/private-root", "<EVIDENCE_ROOT><ANYTHING>/alice/private-root"]
        results = [rpi.portable_path(raw) for raw in paths]
        self.assertEqual(len(paths), len(set(results)))

    def test_successor_error_and_oserror_no_placeholder_tail_leakage(self):
        for index, raw in enumerate(self.successor_malformed_paths()):
            for exc in (rpi.Refusal("cannot read '" + raw + "'"), OSError(5, "denied", raw),
                        OSError(5, "cannot read '" + raw + "'")):
                with self.subTest(case=index, exception=type(exc).__name__):
                    rendered = rpi.portable_error(exc)
                    self.assertNotIn("alice", rendered.casefold())
                    self.assertNotIn("private-root", rendered.casefold())
                    self.assertEqual(rendered, rpi.portable_error(rpi.Refusal(rendered)))

    def test_successor_idempotence_for_unlabelled_inputs(self):
        for raw in (r"C:\Users\alice\Desktop\file.json", r"\\server-alice\share\file.json",
                    r"\\.\pipe\private-root", "./C:/Users/alice/file.json", "/var/reports/file.json",
                    "D:/EA_LAB_CONTROL/evidence/lane/file.json", "relative/file.json",
                    "C:/Users/alice/folder:stream/file.json"):
            with self.subTest(raw=raw):
                result = rpi.portable_path(raw)
                self.assertEqual(result, rpi.portable_path(result))

    def test_portable_path_normalizes_repeated_separators_and_dot_segments(self):
        cases = [
            (
                r"\\?\C:\\Users\decoy\..\alice\private\packet.json",
                r"^<USER_HOME_[0-9A-F]{10}>$",
                ("alice", "decoy"),
            ),
            (
                r"\\?\D:\\EA_LAB_CONTROL\evidence\discard\..\lane-a\packet.json",
                r"^<EVIDENCE_ROOT_[0-9A-F]{10}>$",
                ("discard",),
            ),
            (
                r"\\?\UNC\server-a\\share-a\discard\..\research\packet.json",
                r"^<UNC_ROOT_[0-9A-F]{10}>$",
                ("server-a", "share-a", "discard"),
            ),
        ]
        for raw, pattern, secrets in cases:
            with self.subTest(raw=raw):
                rendered = rpi.portable_path(raw)
                self.assertRegex(rendered, pattern)
                self.assertNotIn("..", rendered)
                for secret in secrets:
                    self.assertNotIn(secret, rendered.casefold())

    def test_portable_path_keeps_same_basename_sources_distinguishable(self):
        pairs = [
            (r"C:\Users\alice\same\result.json", r"C:\Users\bob\same\result.json"),
            (r"\\?\C:\Users\alice\same\result.json", r"\\?\C:\Users\bob\same\result.json"),
            (r"\\server-a\share-a\same\result.json", r"\\server-b\share-b\same\result.json"),
            (
                r"\\?\UNC\server-a\share-a\same\result.json",
                r"\\?\UNC\server-b\share-b\same\result.json",
            ),
            (r"D:\EA_LAB_CONTROL\w\lane-a\same\result.json", r"D:\EA_LAB_CONTROL\w\lane-b\same\result.json"),
            (
                r"\\?\D:\EA_LAB_CONTROL\w\lane-a\same\result.json",
                r"\\?\D:\EA_LAB_CONTROL\w\lane-b\same\result.json",
            ),
        ]
        for raw_first, raw_second in pairs:
            with self.subTest(first=raw_first, second=raw_second):
                first = rpi.portable_path(raw_first)
                second = rpi.portable_path(raw_second)
                self.assertNotEqual(first, second)
                self.assertNotIn("/", first)
                self.assertNotIn("/", second)

    def test_cli_reports_portable_manifest_path_without_changing_hashes_or_inputs(self):
        historical_before = HISTORICAL_RECEIPT.read_bytes()
        self.assertEqual(HISTORICAL_RECEIPT_SHA256, hashlib.sha256(historical_before).hexdigest())
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            fixture_before = {
                path.relative_to(root).as_posix(): path.read_bytes()
                for path in root.rglob("*")
                if path.is_file()
            }
            expected_hash = hashlib.sha256((root / "machine" / "summary.json").read_bytes()).hexdigest()
            output = StringIO()
            with redirect_stdout(output):
                rc = rpi.main(["build", "--spec", str(spec_path), "--out", str(manifest_path)])
            self.assertEqual(0, rc)
            result = json.loads(output.getvalue())
            self.assertEqual(rpi.portable_path(manifest_path, repo_root=rpi.REPO_ROOT), result["manifest"])
            self.assertNotRegex(result["manifest"], r"(?i)^[a-z]:[/\\]")
            self.assertNotRegex(json.dumps(result), r"(?i)C:\\\\Users\\\\|D:\\\\EA_LAB_CONTROL\\\\")
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            summary = next(row for row in manifest["artifacts"] if row["path"] == "machine/summary.json")
            self.assertEqual(expected_hash, summary["sha256"])
            fixture_after = {
                path.relative_to(root).as_posix(): path.read_bytes()
                for path in root.rglob("*")
                if path.is_file() and path != manifest_path
            }
            self.assertEqual(fixture_before, fixture_after)
        historical_after = HISTORICAL_RECEIPT.read_bytes()
        self.assertEqual(historical_before, historical_after)
        self.assertEqual(HISTORICAL_RECEIPT_SHA256, hashlib.sha256(historical_after).hexdigest())

    def test_cli_refusal_redacts_absolute_artifact_path_from_untrusted_spec(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"][0]["path"] = r"\\?\C:\Users\alice\private\result.json"
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            output = StringIO()
            with redirect_stderr(output):
                rc = rpi.main(["build", "--spec", str(spec_path), "--out", str(manifest_path)])
            self.assertEqual(2, rc)
            result = json.loads(output.getvalue())
            self.assertEqual("BLOCKED", result["status"])
            self.assertRegex(result["error"], r"<USER_HOME_[0-9A-F]{10}>$")
            self.assertNotIn("alice", json.dumps(result).casefold())
            self.assertNotRegex(json.dumps(result), r"(?i)C:\\\\Users\\\\")

    def test_os_error_rendering_does_not_expose_username(self):
        exc = FileNotFoundError(2, "file not found", r"C:\Users\alice\private\missing.json")
        rendered = rpi.portable_error(exc)
        self.assertRegex(rendered, r"^file not found: <USER_HOME_[0-9A-F]{10}>$")
        self.assertNotIn("alice", rendered.casefold())

        strerror_path = OSError(5, r"cannot open C:\Users\Alice Smith\private\missing.json")
        rendered_strerror = rpi.portable_error(strerror_path)
        self.assertNotIn("alice smith", rendered_strerror.casefold())
        self.assertNotRegex(rendered_strerror, r"(?i)[a-z]:[/\\]")

    def test_structured_refusal_rendering_uses_the_closed_path_sanitizer(self):
        exc = rpi.Refusal(
            r"invalid source path: \\?\C:\Users\alice\private\missing.json"
        )
        rendered = rpi.portable_error(exc)
        self.assertRegex(
            rendered,
            r"^invalid source path: <USER_HOME_[0-9A-F]{10}>$",
        )
        self.assertNotIn("alice", rendered.casefold())
        self.assertNotRegex(rendered, r"(?i)(?:\\\\\?\\)?[a-z]:[/\\]")

        multiple = rpi.portable_error(
            rpi.Refusal(
                r"copy refused: C:\Users\alice\private\one.json -> "
                r"\\server-b\share-b\private\two.json"
            )
        )
        self.assertNotIn("alice", multiple.casefold())
        self.assertNotIn("server-b", multiple.casefold())
        self.assertNotIn("share-b", multiple.casefold())
        self.assertNotRegex(multiple, r"(?i)[a-z]:[/\\]|\\\\[^\\]+\\[^\\]+")

        spaced = rpi.portable_error(
            rpi.Refusal(
                r"copy refused: C:\Users\Alice Smith\private\one.json -> "
                r"\\server-b\share name\private\two.json"
            )
        )
        self.assertNotIn("alice smith", spaced.casefold())
        self.assertNotIn("server-b", spaced.casefold())
        self.assertNotIn("share name", spaced.casefold())
        self.assertNotRegex(spaced, r"(?i)[a-z]:[/\\]|\\\\[^\\]+\\[^\\]+")

        slash_forms = rpi.portable_error(
            rpi.Refusal(
                "copy refused: //server-c/share-c/private/one.json -> "
                "//?/C:/Users/dora/private/two.json -> "
                "//./pipe/private-channel"
            )
        )
        for secret in ("server-c", "share-c", "dora", "private-channel"):
            self.assertNotIn(secret, slash_forms.casefold())
        self.assertNotRegex(slash_forms, r"(?i)//(?:[^/]+/[^/]+|[?.]/)")

    def test_adversarial_generated_output_has_no_private_absolute_path_leaks(self):
        payload = {
            "paths": [
                rpi.portable_path(r"C:\Users\alice\private\one.json"),
                rpi.portable_path(r"\\?\C:\Users\bob\private\two.json"),
                rpi.portable_path(r"D:\EA_LAB_CONTROL\evidence\private-lane\three.json"),
                rpi.portable_path(r"\\?\D:\EA_LAB_CONTROL\w\private-worktree\four.json"),
                rpi.portable_path(r"\\server-a\share-a\private\five.json"),
                rpi.portable_path(r"\\?\UNC\server-b\share-b\private\six.json"),
                rpi.portable_path(r"<EVIDENCE_ROOT>/\\.\pipe\private-channel"),
            ],
            "error": rpi.portable_error(
                rpi.Refusal(r"refused \\?\C:\Users\carol\private\seven.json")
            ),
        }
        rendered = json.dumps(payload, ensure_ascii=False, sort_keys=True)
        for secret in (
            "alice",
            "bob",
            "carol",
            "private-worktree",
            "server-a",
            "share-a",
            "server-b",
            "share-b",
            "private-channel",
        ):
            self.assertNotIn(secret, rendered.casefold())
        self.assertNotRegex(
            rendered,
            r"(?i)(?:\\\\[?.]\\|[a-z]:[/\\]|\\\\[^\\]+\\[^\\]+)",
        )

    def test_tamper_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            rpi.write_manifest(rpi.build_manifest(spec_path, manifest_path), manifest_path)
            (root / "report.md").write_text("tampered\n", encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "mismatch"):
                rpi.validate_manifest(manifest_path)

    def test_missing_artifact_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"].append({"path": "missing.csv", "role": "raw"})
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "artifact missing"):
                rpi.build_manifest(spec_path, manifest_path)

    def test_parent_traversal_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            root = base / "pkg"
            root.mkdir()
            outside = base / "outside.txt"
            outside.write_text("outside", encoding="utf-8")
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [{"path": "../outside.txt", "role": "raw"}]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "unsafe segment"):
                rpi.build_manifest(spec_path, manifest_path)

    def test_absolute_paths_are_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            for bad in ("C:\\temp\\raw.csv", "/tmp/raw.csv"):
                spec = json.loads(spec_path.read_text(encoding="utf-8"))
                spec["artifacts"] = [{"path": bad, "role": "raw"}]
                spec_path.write_text(json.dumps(spec), encoding="utf-8")
                with self.subTest(path=bad), self.assertRaisesRegex(rpi.Refusal, "must be relative"):
                    rpi.build_manifest(spec_path, manifest_path)

    def test_duplicate_normalized_paths_are_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [
                {"path": "machine/summary.json", "role": "machine_summary"},
                {"path": "machine\\summary.json", "role": "duplicate"},
            ]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "duplicate artifact path"):
                rpi.build_manifest(spec_path, manifest_path)

    def test_output_must_stay_with_package(self):
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            root = base / "pkg"
            root.mkdir()
            other = base / "other"
            other.mkdir()
            spec_path, _ = self.make_package(root)
            with self.assertRaisesRegex(rpi.Refusal, "same directory"):
                rpi.build_manifest(spec_path, other / "manifest.json")

    def test_manifest_self_reference_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            manifest_path.write_text("placeholder", encoding="utf-8")
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [{"path": manifest_path.name, "role": "manifest"}]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "cannot hash itself"):
                rpi.build_manifest(spec_path, manifest_path)

    def test_required_contract_fields_are_fail_closed(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            original = json.loads(spec_path.read_text(encoding="utf-8"))
            for key in ("package_id", "direct_consumer", "authority"):
                spec = dict(original)
                spec.pop(key)
                spec_path.write_text(json.dumps(spec), encoding="utf-8")
                with self.subTest(key=key), self.assertRaisesRegex(rpi.Refusal, key):
                    rpi.build_manifest(spec_path, manifest_path)

    def test_directory_artifact_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [{"path": "machine", "role": "directory"}]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            with self.assertRaisesRegex(rpi.Refusal, "not a regular file"):
                rpi.build_manifest(spec_path, manifest_path)


    def test_leaf_symlink_branch_is_fail_closed_when_os_cannot_create_symlinks(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            spec = json.loads(spec_path.read_text(encoding="utf-8"))
            spec["artifacts"] = [{"path": "machine/summary.json", "role": "alias"}]
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            original = rpi._is_reparse_component
            rpi._is_reparse_component = lambda path: path.name == "summary.json"
            try:
                with self.assertRaisesRegex(rpi.Refusal, "reparse component"):
                    rpi.build_manifest(spec_path, manifest_path)
            finally:
                rpi._is_reparse_component = original

    def test_intermediate_directory_link_alias_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            spec_path, manifest_path = self.make_package(root)
            link = root / "machine-alias"
            self.make_dir_link(root / "machine", link)
            try:
                spec = json.loads(spec_path.read_text(encoding="utf-8"))
                spec["artifacts"] = [{"path": "machine-alias/summary.json", "role": "alias"}]
                spec_path.write_text(json.dumps(spec), encoding="utf-8")
                with self.assertRaisesRegex(rpi.Refusal, "reparse component"):
                    rpi.build_manifest(spec_path, manifest_path)
            finally:
                self.remove_dir_link(link)

    def test_intermediate_directory_link_escape_is_refused(self):
        with tempfile.TemporaryDirectory() as td:
            base = Path(td)
            root = base / "pkg"
            root.mkdir()
            outside = base / "outside"
            outside.mkdir()
            (outside / "secret.txt").write_text("outside", encoding="utf-8")
            spec_path, manifest_path = self.make_package(root)
            link = root / "escape"
            self.make_dir_link(outside, link)
            try:
                spec = json.loads(spec_path.read_text(encoding="utf-8"))
                spec["artifacts"] = [{"path": "escape/secret.txt", "role": "raw"}]
                spec_path.write_text(json.dumps(spec), encoding="utf-8")
                with self.assertRaisesRegex(rpi.Refusal, "reparse component"):
                    rpi.build_manifest(spec_path, manifest_path)
            finally:
                self.remove_dir_link(link)

if __name__ == "__main__":
    unittest.main()
