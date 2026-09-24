# D005 Path Redaction Follow-up — Prospective Contract

Classification: REPORTING_TOOLING / NEW_SUCCESSOR_CONTRACT / NO_RUNTIME.

Historical truth is intentionally dual:
- Historical D005 Repair1 was accepted/reviewed/integrated.
- A later exact-byte reproduction found an applicable placeholder-canonicalization leakage defect.
- Current canonical bytes showed no relevant D005 path drift when the later finding was reconciled.
This contract does not rewrite the historical PASS and does not extend/reset Repair1.

## Objective

Correct only the remaining placeholder/path redaction seam so malformed or untrusted placeholder forms cannot preserve username/private-root tail information.

## Required invariants

- Only explicitly recognized placeholder labels are trusted as placeholders.
- Arbitrary labels such as `<ANYTHING>` are not automatically trusted.
- Any accepted placeholder tail must be a safe relative path.
- Repeated and nested placeholders are handled deterministically.
- Placeholder followed by absolute, UNC, or device-path syntax fails closed.
- Errors and rendered diagnostics must not leak usernames or private-root tails.
- Sanitizer idempotence is explicit and covered by tests.
## Allowed paths

- `docs/workflows/D005_PATH_REDACTION_FOLLOWUP_20260923.md`
- `tools/reporting/report_package_integrity.py`
- `tools/reporting/post_broad_diagnostic_pack.py`
- `tools/reporting/tests/test_report_package_integrity.py`
- `tools/reporting/tests/test_post_broad_diagnostic_pack.py`

No old evidence mutation. No PROJECT_STATE/P03/AGENTS mutation from author. No report-regeneration campaign, MT5, runtime, deployment, trading, risk/default, or native-equity invention.

## Acceptance

Preserve previously accepted redaction behavior and historical negative evidence. Add focused positive/negative cases covering recognized placeholders, arbitrary placeholders, safe relative tails, nested/repeated forms, absolute/UNC/device suffixes, private-root leakage, and idempotence.

Run all directly impacted reporting tests, pycompile, diff-check, applicable normal hooks, and any existing report-package integrity regression required by the four source/test paths. One bounded in-scope repair maximum. Freeze one exact clean head, then one independent exact-head GPT Scrutiny. Author cannot self-approve. Workers do not push.

## Bounded author evidence — 2026-09-23

Lane: `ct-d005-path-redaction-followup-v1-20260923`. This is the prospective successor,
not Repair2 and not a reset of historical Repair1. Historical accepted PASS remains
evidence; the later exact-byte placeholder/path-redaction defect remains real negative
evidence. No historical result or artifact was edited.

Pre-edit identity:
- Fresh `git fetch origin master` and `git ls-remote origin refs/heads/master` agreed
  at `372c73e5f33f39fa445c748f40cbfed5565c6831`.
- Registry base: `66dd2b3b1987c47876760e123fa20981ab7b821f`.
- Resumed clean HEAD: `9cdf435148978bcf9948bf276c43d8a9a91832ae`; empty
  `git status --short`. All four source/test paths matched fetched canonical bytes.
- Registry SHA256: `804e40de2bd5405cf19b05928b2ee86ac2c1466cdb352395f44f42723c923624`.
  The record was `BLOCKED / PROSPECTIVE_CONTRACT_FROZEN_LOCAL_WAITING_AUTHOR_DISPATCH`;
  the owner's explicit resume dispatch authorizes this bounded author run. Registry
  was read only; Main CT retains state/freeze/review ownership.

Pre-edit SHA256 (paths relative to this repository):

| Path | SHA256 |
| --- | --- |
| `docs/workflows/D005_PATH_REDACTION_FOLLOWUP_20260923.md` | `82444c89a4cefb0c5070419b3c48ec5a69cd333682cfec1b663865aaef0bad80` |
| `tools/reporting/report_package_integrity.py` | `f118748c666d716398641c092e85a306bb3458ba9716ac1033c700024d7eafcb` |
| `tools/reporting/post_broad_diagnostic_pack.py` | `451079672d20a216cb29d313f5203684d6f22e353805b6caf44c26d5babe242e` |
| `tools/reporting/tests/test_report_package_integrity.py` | `82363862cdac0157226c2c8423c03b6199c7ceb465669f49268b846df274286c` |
| `tools/reporting/tests/test_post_broad_diagnostic_pack.py` | `c08d813a0af8dcad21b61205d0215220662d9768ed05b1de2cdc7e043d5cbdf5` |

Red-first before source/test edits: all 58 existing reporting tests passed. Four
direct cases then failed the no-private-tail assertion: `<ANYTHING>/Users/alice/private-root/file.json`,
`<EVIDENCE_ROOT>//Users/alice/private-root/file.json`, the corresponding triple-slash
form, and `<EVIDENCE_ROOT>/<ANYTHING>/Users/alice/private-root/file.json`.
The double/triple-slash forms also collapsed to the same identity. An in-memory
replay of the six new successor tests against the exact starting source blob
confirmed 213 failing subtest assertions and two recursion errors. No checkout or
historical source mutation was needed for this replay.

One bounded correction (1/1 used): recognize only the emitted label grammar;
retain only safe relative tails; replace the whole malformed/unknown/nested
reference with `<UNSAFE_PATH_<full SHA256>>`. Hash the original spelling before
separator collapse, keeping near-collision identities distinct. Error rendering
handles a placeholder reference before scanning its embedded absolute suffix.
Generated labels pass through the same validation to enforce idempotence.
The diagnostic producer already imports this shared sanitizer and needs no source edit.

The previous nested-absolute test now asserts the successor's stricter opaque
result. Its drive, UNC and device fixtures remain, as do the non-placeholder
compatibility and historical-receipt immutability tests. The suite covers 62
malformed inputs (including 2,000 nested labels), 12 near-collision spellings,
recognized-label positives, repeated sanitization, Refusal/OSError output, and
14 diagnostic CLI exception cases. Ordinary relative paths and recognized safe
placeholder tails retain readable artifact identities.

Deterministic author results:
- `python -B -W error -m unittest discover -s tools/reporting/tests -v`: **65/65 PASS**
  (29 integrity, 8 post-broad diagnostics, 28 existing report-asset tests).
- `powershell -NoProfile -File scripts/_test/run_post_broad_diagnostic_pack_tests.ps1`:
  **8/8 PASS**.
- `python -m py_compile` on the four allowed Python paths: **PASS**.
- `git diff --check`: **PASS**.

Post-correction source/test SHA256:

| Path | SHA256 |
| --- | --- |
| `tools/reporting/report_package_integrity.py` | `9a3aa21290459aeeb03605636d1011603c7b35cd71387792d5cf0f9ddf5d729e` |
| `tools/reporting/post_broad_diagnostic_pack.py` (unchanged) | `451079672d20a216cb29d313f5203684d6f22e353805b6caf44c26d5babe242e` |
| `tools/reporting/tests/test_report_package_integrity.py` | `7514f38f6f6843bb998cf736c4af0200c6069b19659c9dcb3d04df8857a3e39b` |
| `tools/reporting/tests/test_post_broad_diagnostic_pack.py` | `218698ad26f76dbe307c777be41663937ab9f2d7f3fe39eb04f96377c3589545` |

Normal `[codex]` commit was attempted with only these four authorized changed paths
staged. The hook refused it: `check_state.ps1 -Strict` reported
`DIVERGED_FROM_CANONICAL (behind=2 ahead=1 head=9cdf4351 ref=refs/remotes/origin/master)`
and exited 1. Other checks executed before this failure passed; later hook stages
were not reached. No commit was created, no hook was bypassed, and no rebase,
merge, branch creation or canonical-state mutation was attempted. The four-path
correction is preserved for Main CT; disposition is
**BLOCKED_CANONICAL_DIVERGENCE_HOOK**. Repair remains 1/1 used under this successor.

No status/dashboard regeneration: those paths are outside the owner's explicit
Registry-only write scope. No push. Review: **NOT_STARTED — Main CT owns independent review**.


## Owner-authorized additional bounded repair — 2026-09-23

Existing lane: `ct-d005-path-redaction-followup-v1-20260923`. Historical Repair1: **1/1 CONSUMED**, unchanged. Owner additional repair: **0/1 before source mutation**. Latest findings only; no successor, review dispatch, or scope expansion.

Fresh fetch and ls-remote agree: `c24eec92edd5f30d715478cb2cf6eac38cf0f4ee`. Verified clean reviewed HEAD `74579996836d0621d5cceedc365a409535c52a34`, tree `1c8f3945fcd49fa5a4083ddb28e856679298a3f7`; source/test SHA256 values match the historical post-correction table above. Detached reviewed worktree retained; no rebase/merge. Baseline complete reporting discovery: **65/65 PASS**.

RED captured after adding five integrity tests and one diagnostic test, before any source mutation. Commands: portable Python `-B -W error -m unittest discover -s tools/reporting/tests -p <test file> -k owner_repair`; both exit 1. Counts include failing subtest assertions:

```json
{
  "test_report_package_integrity.py": {
    "tests": 5,
    "failures": 55,
    "errors": 0
  },
  "test_post_broad_diagnostic_pack.py": {
    "tests": 1,
    "failures": 13,
    "errors": 0
  },
  "source_sha256_before_mutation": "9a3aa21290459aeeb03605636d1011603c7b35cd71387792d5cf0f9ddf5d729e"
}
```

### Repair policy and bounded evidence

Source mutation consumed the owner-authorized additional repair: **1/1 CONSUMED**.
Historical Repair1 remains **1/1 CONSUMED**. These counters are independent and
neither was reset. This is the same existing lane, with no additional review or
successor created.

- Finding 1: accepted placeholders are **bare labels only**. Every supplied tail,
  even an ordinary-looking relative tail, becomes a full-SHA256 opaque token bound
  to its original spelling. A string label cannot attest to a tail's provenance;
  this structural rule does not depend on a username/root-name denylist. Legacy
  tailed placeholders become opaque once; all newly emitted placeholders are
  idempotent. Legacy bare labels remain idempotent.
- Finding 2: unknown POSIX, rooted Windows, drive, user-home, UNC and device paths
  bind the **whole** normalized path to an opaque deterministic identity. No
  basename or intermediate host/user/private tail survives. Namespace aliases
  still normalize consistently. Supplied qualified repository roots retain
  relative paths (12 positive controls across POSIX/drive/UNC roots and both
  separator styles); ordinary relative paths remain readable. Recognized evidence
  paths retain their evidence label and deterministic whole-path identity, with
  no readable tail. This intentional conservative presentation change prevents
  generated evidence labels from requiring an unsafe tailed-placeholder exemption.
  Existing worktree labels likewise bind the whole path.
- Finding 3: error parsing recognizes label-shaped, nested, or path-bearing angle
  references rather than every angle operator. Six ordinary comparison diagnostics
  remain exact for Refusal and OSError (12 cases); fake/spaced/nested/repeated and
  path-bearing placeholder attacks fail closed. Rooted Windows and tilde-home
  error references use the same policy as portable_path. Windows namespace prefixes
  stay attached to their drive when scanning errors.
- Shared sanitizer only: `post_broad_diagnostic_pack.py` is unchanged, SHA256
  `451079672d20a216cb29d313f5203684d6f22e353805b6caf44c26d5babe242e`.
  AST comparison against reviewed HEAD confirms all functions/classes outside the
  three presentation functions are unchanged. Actual filesystem access, hashing,
  package integrity, HOLDOUT, strategy, runtime and authority semantics are unchanged.

Validation commands (portable Python after dot-sourcing `D:/EA_LAB/scripts/use_python.ps1`):

- `python -B -W error -m unittest discover -s tools/reporting/tests`: **72/72 PASS**.
- `python -B -W error -m unittest discover -s tools/reporting/tests -p test_report_package_integrity.py`:
  **35/35 PASS**.
- `powershell -NoProfile -File scripts/_test/run_post_broad_diagnostic_pack_tests.ps1`:
  **9/9 PASS**.
- New matrix: 41 private-path cases, portable_path / Refusal / OSError agreement,
  deterministic identity and idempotence; 11 near-collision placeholder spellings;
  6 path-bearing angle attacks and 4 malformed-label controls; 12 readable ordinary
  diagnostic cases; 12 qualified-root relative controls and 2 evidence-root controls.
- Existing 62 malformed/nested cases, 12 near-collision spellings, Windows namespace
  and separator pairs, bare-label and unlabelled idempotence matrices remain covered.
- Leakage scan: rendered JSON plus text for all 41 private-path cases contains none
  of the fixture usernames, private roots, server/share names or home/user fragments.
  Diagnostic CLI boundary: 6 private paths x 2 exception forms = 12 no-leak cases.
  Existing package hash/input and historical-receipt immutability checks pass.
- `py_compile.compile(..., doraise=True)` on all four reporting Python files:
  **4/4 PASS**, bytecode confined to an automatically removed temporary directory.
- `git diff --check`: **PASS**.

Post-repair SHA256:

| Path | SHA256 |
| --- | --- |
| `tools/reporting/report_package_integrity.py` | `e8556d66b6e3f7cf1ddaf19766b7620d4d92c87032dd617e2a1cb1040dfafb88` |
| `tools/reporting/tests/test_report_package_integrity.py` | `735cb7c84f789274a5724e5eb3b486a59944001c348826deb94a40f593f7dcc1` |
| `tools/reporting/tests/test_post_broad_diagnostic_pack.py` | `9a81880dcab7eee51517c5b9867296e7604a1ce68b41d2ce0400a471ef06c686` |

### Finding 4 — hook evidence reconciliation

A. **Historical author attempt: REFUSED**, not PASS. At author HEAD
`9cdf435148978bcf9948bf276c43d8a9a91832ae`, check_state reported
`DIVERGED_FROM_CANONICAL (behind=2 ahead=1 head=9cdf4351 ref=refs/remotes/origin/master)`.
The original refusal above remains verbatim. Later stages were not reached and no
commit resulted from that attempt.

B. **Later Main-CT/reanchor result: recorded PASS**, separate from A. Read-only
receipt `D:/EA_LAB_CONTROL/evidence/d005-path-redaction-followup-v1-20260923/D005_REANCHOR_RECEIPT_20260923.json`
(SHA256 `8e98229f18c9f870773740614198133d030294f856f4815e5f422285d678a01f`)
records normal_hooks PASS at reanchored HEAD
`74579996836d0621d5cceedc365a409535c52a34`, parent
`372c73e5f33f39fa445c748f40cbfed5565c6831`, checked UTC
`2026-09-23T09:25:03.9754309Z`. This run inspected that receipt, not a historical
raw hook transcript; it does not reinterpret A as a PASS.

C. **This owner-authorized repair:** normal commit hooks will run against exactly
the four allowed staged paths. The exact outcome is recorded below after the
attempt. No hook bypass, push, rebase, merge, or independent review is authorized
by this evidence. Review remains **TARGETED_RECHECK_NOT_STARTED**.

This repair's normal `[codex]` commit attempt exited **1**. check_state ran in
**index** evidence mode; all executed consistency checks passed, and its sole
warning was:

```text
[WARN] canonicality: DIVERGED_FROM_CANONICAL (behind=1 ahead=1 head=74579996 ref=refs/remotes/origin/master; working tree DIRTY) - DIVERGED. Publishing from here would overwrite current content with superseded content; reconcile against refs/remotes/origin/master first.
[canonicality] publish_gate=BLOCK state=DIVERGED_FROM_CANONICAL behind=1 ahead=1 dirty=True
[OK]   core.hooksPath belongs to this checkout (OWN: D:\EA_LAB_CONTROL\w\d005-path-redaction-reanchor-0923\.githooks)
=== 1 WARNING(s) - fix the drift above ===
[pre-commit] doc drift detected (above) -- check_state.ps1 -Strict failed.
```

Later hook stages were **NOT_REACHED**. This is not a normal-hooks PASS. No commit
was created; the reviewed HEAD and its tree remain unchanged. No second commit
attempt, bypass, rebase, merge, push, status regeneration, or review dispatch was
performed. The final evidence appendix was added after the refusal; it has not
been through a second hook attempt. Its final staged diff-check is recorded by
the author command output. No source/test bytes changed after the hook attempt.

Disposition: **BLOCKED_CANONICAL_DIVERGENCE_HOOK_AFTER_D005_OWNER_REPAIR**.
Canonical ref was fetched and ls-remote verified again after the attempt:
`c24eec92edd5f30d715478cb2cf6eac38cf0f4ee`. Main CT owns reanchor and the one
independent targeted recheck. **TARGETED_RECHECK_NOT_STARTED**; **PUSH NOT_PERFORMED**.
Both historical Repair1 and owner additional repair remain **1/1 CONSUMED**.

### Recoverable bounded patch

The complete four-path patch remains staged in the reviewed worktree and is
recoverable without mutation:

```powershell
git -C D:/EA_LAB_CONTROL/w/d005-path-redaction-reanchor-0923 diff --cached --binary --full-index 74579996836d0621d5cceedc365a409535c52a34
```

For a reviewable patch without writing any fifth path, the exact three-file
source/test patch is embedded below; this evidence document is the fourth path.

Source/test patch SHA256: `235d78f8d25bc47da25c75d50ffd260e0ed71ea37225cf68fbaca45433109d78`.
Zero-context diff (`--unified=0`, apply with `git apply --unidiff-zero`) avoids whitespace-only context lines in this Markdown evidence.

```diff
diff --git a/tools/reporting/report_package_integrity.py b/tools/reporting/report_package_integrity.py
index abcb597719e236f2af096f3b5aa5ad61f106a9d5..5f2b6e038786db9e92eff49fdbcd2a62d0240efa 100644
--- a/tools/reporting/report_package_integrity.py
+++ b/tools/reporting/report_package_integrity.py
@@ -27,2 +27,2 @@ _REDACTED_PATH_RE = re.compile(
-    r"(?:WORKTREE|USER_HOME|UNC_ROOT|ABSOLUTE_ROOT|DEVICE_PATH|UNSAFE_TAIL)_[0-9A-F]{10}|"
-    r"UNSAFE_PATH_[0-9A-F]{64})>)(?:/(.+))?$"
+    r"(?:EVIDENCE_ROOT|WORKTREE|USER_HOME|UNC_ROOT|ABSOLUTE_ROOT|DEVICE_PATH|UNSAFE_TAIL)_[0-9A-F]{10}|"
+    r"UNSAFE_PATH_[0-9A-F]{64})>)$"
@@ -31 +31,7 @@ _EMBEDDED_ABSOLUTE_PATH_START_RE = re.compile(
-    r"(?i)(?:\\\\|//|[A-Z]:[\\/]|(?<![\w>?.])/(?!/))"
+    r"(?i)(?:\\\\|//|[A-Z]:[\\/]|(?<![\w>?.])[\\/]|(?<!\w)~[^\s/\\]*[\\/])"
+)
+_PLACEHOLDER_START_RE = re.compile(
+    r"(?<!\w)<(?=[A-Za-z_<\\/])|"
+    r"<(?=\s*[A-Za-z_][A-Za-z0-9_-]*\s*>)|"
+    r"<(?=[^'\"\r\n]*[\\/])|"
+    r">(?=[^'\"\r\n<>]*[\\/])"
@@ -130 +136,2 @@ def portable_path(value: str | Path, *, repo_root: str | Path | None = None) ->
-    untouched. Relative tails are retained so two files with the same basename remain distinct.
+    untouched. Absolute paths yield readable tails only under a qualified repository root.
+    Labels do not attest to tail provenance; opaque identities bind the whole path.
@@ -137,9 +144,3 @@ def portable_path(value: str | Path, *, repo_root: str | Path | None = None) ->
-            tail = match.group(2)
-            if tail is None or all(
-                part not in ("", ".", "..")
-                and not any(char in '<>:"|?*' or ord(char) < 32 or ord(char) == 127 for char in part)
-                and part == part.strip()
-                and not part.endswith(".")
-                for part in tail.split("/")
-            ):
-                return text
+            return text
+        # No string-only provenance check can distinguish a generated readable tail
+        # from a forged one. Accept bare labels only, even for known-root labels.
@@ -165,0 +167,2 @@ def _portable_unlabelled_path(text: str, *, repo_root: str | Path | None) -> str
+        if re.match(r"^~[^/]*/", text):
+            return _opaque_path_label("USER_HOME", text)
@@ -177 +180 @@ def _portable_unlabelled_path(text: str, *, repo_root: str | Path | None) -> str
-        if not root:
+        if not root or _absolute_path_kind(root) is None:
@@ -192,5 +195 @@ def _portable_unlabelled_path(text: str, *, repo_root: str | Path | None) -> str
-        tail = evidence.group(1)
-        return "<EVIDENCE_ROOT>" if not tail else f"<EVIDENCE_ROOT>/{tail}"
-
-    def labelled_root(kind: str, root: str) -> str:
-        return _opaque_path_label(kind, root)
+        return "<EVIDENCE_ROOT>" if not evidence.group(1) else _opaque_path_label("EVIDENCE_ROOT", text)
@@ -203,3 +202 @@ def _portable_unlabelled_path(text: str, *, repo_root: str | Path | None) -> str
-        label = labelled_root("WORKTREE", worktree.group("root"))
-        tail = worktree.group("tail")
-        return label if not tail else f"{label}/{tail}"
+        return _opaque_path_label("WORKTREE", text)
@@ -212,3 +209 @@ def _portable_unlabelled_path(text: str, *, repo_root: str | Path | None) -> str
-        label = labelled_root("WORKTREE", user_worktree.group("root"))
-        tail = user_worktree.group("tail")
-        return label if not tail else f"{label}/{tail}"
+        return _opaque_path_label("WORKTREE", text)
@@ -218,3 +213 @@ def _portable_unlabelled_path(text: str, *, repo_root: str | Path | None) -> str
-        label = labelled_root("USER_HOME", user_home.group("root"))
-        tail = user_home.group("tail")
-        return label if not tail else f"{label}/{tail}"
+        return _opaque_path_label("USER_HOME", text)
@@ -223,10 +216 @@ def _portable_unlabelled_path(text: str, *, repo_root: str | Path | None) -> str
-        parts = [part for part in text[2:].split("/") if part]
-        root = "//" + "/".join(parts[:2])
-        label = labelled_root("UNC_ROOT", root)
-        tail = "/".join(parts[2:]) if len(parts) > 2 else ""
-        return label if not tail else f"{label}/{tail}"
-
-    if path_kind == "drive":
-        label = labelled_root("ABSOLUTE_ROOT", text[:2])
-        tail = text[3:]
-        return label if not tail else f"{label}/{tail}"
+        return _opaque_path_label("UNC_ROOT", text)
@@ -234,2 +218 @@ def _portable_unlabelled_path(text: str, *, repo_root: str | Path | None) -> str
-    tail = text.lstrip("/")
-    return "<ABSOLUTE_ROOT>" if not tail else f"<ABSOLUTE_ROOT>/{tail}"
+    return _opaque_path_label("ABSOLUTE_ROOT", text)
@@ -246,2 +229,2 @@ def _sanitize_error_text(
-        placeholder = re.search(r"[<>]", message[cursor:])
-        placeholder_start = cursor + placeholder.start() if placeholder else None
+        placeholder = _PLACEHOLDER_START_RE.search(message, cursor)
+        placeholder_start = placeholder.start() if placeholder else None
@@ -252 +235 @@ def _sanitize_error_text(
-            delimiters = [" -> ", "'", '"']
+            delimiters = [" -> ", "'", '"', "\r", "\n"]
@@ -269 +252 @@ def _sanitize_error_text(
-        namespace_prefix = message[match.start():match.start() + 4]
+        namespace = re.match(r"(?:[\\/]{2}[?.][\\/]|[\\/]{1,2}\?\?[\\/])", message[match.start():])
@@ -271 +254 @@ def _sanitize_error_text(
-            namespace_prefix in ("\\\\?\\", "\\\\.\\", "//?/", "//./")
+            namespace is not None
@@ -273 +256 @@ def _sanitize_error_text(
-            and next_match.start() == match.start() + 4
+            and next_match.start() == match.start() + namespace.end()
diff --git a/tools/reporting/tests/test_post_broad_diagnostic_pack.py b/tools/reporting/tests/test_post_broad_diagnostic_pack.py
index dbbd258991e4bf6aabb16697a900906dba02f76e..fc35ee139f900f4c65bacfddfe03a083219190e1 100644
--- a/tools/reporting/tests/test_post_broad_diagnostic_pack.py
+++ b/tools/reporting/tests/test_post_broad_diagnostic_pack.py
@@ -29,0 +30,21 @@ class PackTests(unittest.TestCase):
+    def test_owner_repair_cli_private_tails_and_ordinary_angles(self):
+        paths = ["<EVIDENCE_ROOT>/Users/alice/private-root/file.json",
+                 r"<EVIDENCE_ROOT>\Users\alice\private-root\file.json",
+                 "/home/alice/private-root/file.json", r"\Users\alice\private-root\file.json",
+                 r"Z:\Users\alice\private-root\file.json",
+                 r"\\server-alice\share-secret\private-root\file.json"]
+        for raw in paths:
+            for exc in (MOD.Refusal("cannot read '" + raw + "'"), OSError(5, "denied", raw)):
+                with self.subTest(raw=raw, exception=type(exc).__name__):
+                    out, err = StringIO(), StringIO()
+                    with patch.object(MOD, 'parser') as parser, patch.object(MOD, 'build', side_effect=exc):
+                        parser.return_value.parse_args.return_value = argparse.Namespace()
+                        with redirect_stdout(out), redirect_stderr(err):
+                            self.assertEqual(2, MOD.main())
+                    for secret in ('alice', 'private-root', 'server-alice', 'share-secret'):
+                        self.assertNotIn(secret, err.getvalue().casefold())
+                    self.assertEqual('', out.getvalue())
+                    self.assertEqual(err.getvalue(), MOD.portable_error(MOD.Refusal(err.getvalue())))
+        for message in ('expected < 5', 'value > threshold', 'a < b and c > d'):
+            self.assertEqual(message, MOD.portable_error(MOD.Refusal(message)))
+
diff --git a/tools/reporting/tests/test_report_package_integrity.py b/tools/reporting/tests/test_report_package_integrity.py
index 1e2fcf03b21821112db922e8d51efea89c2a45fd..5e44a52a7a17027b6a8e5a44c66fe4c261d9b6bd 100644
--- a/tools/reporting/tests/test_report_package_integrity.py
+++ b/tools/reporting/tests/test_report_package_integrity.py
@@ -23,0 +24,92 @@ class ReportPackageIntegrityTests(unittest.TestCase):
+    @staticmethod
+    def owner_repair_private_paths():
+        paths = []
+        # Labels cannot attest to the origin of a syntactically relative tail.
+        for label in ("<EVIDENCE_ROOT>", "<REPO_ROOT>", "<ABSOLUTE_ROOT>",
+                      "<USER_HOME_012345ABCD>", "<WORKTREE_012345ABCD>"):
+            for tail in ("Users/alice/private-root/file.json",
+                         "home/alice/private-root/file.json",
+                         "arbitrary/alice/private-root/file.json"):
+                for separator in ("/", "\\"):
+                    paths.append(label + separator + tail.replace("/", separator))
+        paths += [
+            "/home/alice/private-root/file.json", r"\Users\alice\private-root\file.json",
+            r"Z:\Users\alice\private-root\file.json", r"Z:\arbitrary\alice\private-root\file.json",
+            r"\\server-alice\share-secret\private-root\file.json",
+            r"\\?\UNC\server-alice\share-secret\private-root\file.json",
+            r"\\?\Z:\Users\alice\private-root\file.json",
+            r"\??\Z:\Users\alice\private-root\file.json", r"\\.\pipe\private-root",
+            "~/alice/private-root/file.json", "~alice/private-root/file.json",
+        ]
+        return paths
+
+    def test_owner_repair_private_tail_opacity_and_error_agreement(self):
+        for raw in self.owner_repair_private_paths():
+            with self.subTest(raw=raw):
+                shown = rpi.portable_path(raw)
+                for secret in ("alice", "private-root", "home/alice", "server-alice", "share-secret"):
+                    self.assertNotIn(secret, shown.casefold())
+                self.assertNotIn("/", shown)
+                self.assertEqual(shown, rpi.portable_path(shown))
+                self.assertEqual(shown, rpi.portable_path(raw))
+                for exc in (rpi.Refusal(raw), OSError(5, raw)):
+                    self.assertEqual(shown, rpi.portable_error(exc))
+                self.assertEqual("denied: " + shown, rpi.portable_error(OSError(5, "denied", raw)))
+
+    def test_owner_repair_ordinary_angle_diagnostics(self):
+        for message in ("expected < 5", "value > threshold", "a < b and c > d",
+                        "expected <= 5", "value >= threshold", "a<b and c>d"):
+            for exc in (rpi.Refusal(message), OSError(5, message)):
+                with self.subTest(message=message, exception=type(exc).__name__):
+                    self.assertEqual(message, rpi.portable_error(exc))
+
+    def test_owner_repair_rendered_json_text_leakage_scan(self):
+        payload = [{"path": rpi.portable_path(raw),
+                    "error": rpi.portable_error(rpi.Refusal("cannot read '" + raw + "'"))}
+                   for raw in self.owner_repair_private_paths()]
+        rendered = json.dumps(payload) + "\n" + "\n".join(row["error"] for row in payload)
+        for secret in ("alice", "private-root", "server-alice", "share-secret", "home/alice"):
+            self.assertNotIn(secret, rendered.casefold())
+
+    def test_owner_repair_known_root_relative_positive_controls(self):
+        for root in ("Z:/qualified/repo", "/qualified/repo", "//qualified/share/repo"):
+            for tail in ("reports/packet.json", "folder with spaces/file.json"):
+                for separator in ("/", "\\"):
+                    raw = (root + "/" + tail).replace("/", separator)
+                    self.assertEqual(tail, rpi.portable_path(raw, repo_root=root))
+        # Evidence references keep a deterministic identity, without an untrusted tail.
+        for raw in ("D:/EA_LAB_CONTROL/evidence/lane-a/packet.json",
+                    "D:/EA_LAB_CONTROL/evidence/lane-b/packet.json"):
+            shown = rpi.portable_path(raw)
+            self.assertRegex(shown, r"^<EVIDENCE_ROOT_[0-9A-F]{10}>$")
+            self.assertEqual(shown, rpi.portable_path(shown))
+
+    def test_owner_repair_placeholder_near_collision_matrix(self):
+        paths = ["<EVIDENCE_ROOT>" + separator + "arbitrary/alice/private-root"
+                 for separator in ("/", "\\", "//", "\\\\", "/\\", "\\/")]
+        paths += ["<ANYTHING>/alice/private-root", "<EVIDENCE_ROOT/alice/private-root",
+                  "<<EVIDENCE_ROOT>>/alice/private-root", ">alice/private-root",
+                  "<EVIDENCE_ROOT><EVIDENCE_ROOT>/alice/private-root"]
+        shown = [rpi.portable_path(raw) for raw in paths]
+        self.assertEqual(len(paths), len(set(shown)))
+        for raw, result in zip(paths, shown):
+            self.assertRegex(result, r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
+            self.assertEqual(result, rpi.portable_error(rpi.Refusal(raw)))
+            self.assertEqual(result, rpi.portable_path(result))
+
+    def test_owner_repair_angle_placeholder_context_matrix(self):
+        attacks = ["< EVIDENCE_ROOT >/Users/alice/private-root/file.json",
+                   "< EVIDENCE_ROOT /alice/private-root/file.json",
+                   "> alice/private-root/file.json", "<ANYTHING>/alice/private-root",
+                   "<EVIDENCE_ROOT>/<ANYTHING>/alice/private-root",
+                   "<EVIDENCE_ROOT><EVIDENCE_ROOT>/alice/private-root"]
+        for raw in attacks:
+            with self.subTest(raw=raw):
+                shown = rpi.portable_path(raw)
+                self.assertRegex(shown, r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
+                self.assertEqual(shown, rpi.portable_error(rpi.Refusal(raw)))
+                self.assertNotIn("alice", shown.casefold())
+                self.assertNotIn("private-root", shown.casefold())
+        for token in ("<ANYTHING>", "< ANYTHING >", "<EVIDENCE_ROOT", "<<EVIDENCE_ROOT>>"):
+            self.assertRegex(rpi.portable_error(rpi.Refusal(token)), r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
+
@@ -93 +184,0 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-            r"D:\EA_LAB_CONTROL\evidence\lane-a\packet.json": "<EVIDENCE_ROOT>/lane-a/packet.json",
@@ -95 +185,0 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-            r"<EVIDENCE_ROOT>\lane-b\packet.json": "<EVIDENCE_ROOT>/lane-b/packet.json",
@@ -105,2 +195,2 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-            r"C:\Users\alice\Desktop\packet.json": (r"^<USER_HOME_[0-9A-F]{10}>/Desktop/packet\.json$", "alice"),
-            r"C:\Users\bob\Downloads\packet.json": (r"^<USER_HOME_[0-9A-F]{10}>/Downloads/packet\.json$", "bob"),
+            r"C:\Users\alice\Desktop\packet.json": (r"^<USER_HOME_[0-9A-F]{10}>$", "alice"),
+            r"C:\Users\bob\Downloads\packet.json": (r"^<USER_HOME_[0-9A-F]{10}>$", "bob"),
@@ -108 +198 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                r"^<WORKTREE_[0-9A-F]{10}>/tools/reporting/packet\.json$",
+                r"^<WORKTREE_[0-9A-F]{10}>$",
@@ -112 +202 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                r"^<UNC_ROOT_[0-9A-F]{10}>/research/packet\.json$",
+                r"^<UNC_ROOT_[0-9A-F]{10}>$",
@@ -127 +217 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                r"^<USER_HOME_[0-9A-F]{10}>/private/packet\.json$",
+                r"^<USER_HOME_[0-9A-F]{10}>$",
@@ -133 +223 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                r"^<EVIDENCE_ROOT>/lane-a/packet\.json$",
+                r"^<EVIDENCE_ROOT_[0-9A-F]{10}>$",
@@ -139 +229 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                r"^<WORKTREE_[0-9A-F]{10}>/tools/packet\.json$",
+                r"^<WORKTREE_[0-9A-F]{10}>$",
@@ -145 +235 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                r"^<UNC_ROOT_[0-9A-F]{10}>/research/packet\.json$",
+                r"^<UNC_ROOT_[0-9A-F]{10}>$",
@@ -159,2 +249 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-        self.assertEqual(
-            "<EVIDENCE_ROOT>/lane-b/packet.json",
+        self.assertRegex(
@@ -161,0 +251 @@ class ReportPackageIntegrityTests(unittest.TestCase):
+            r"^<UNSAFE_PATH_[0-9A-F]{64}>$",
@@ -198,2 +288,7 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                    self.assertEqual(expected, rpi.portable_path(expected))
-                    self.assertEqual(expected, rpi.portable_path(expected.replace("/", "\\")))
+                    if not tail:
+                        self.assertEqual(expected, rpi.portable_path(expected))
+                    else:
+                        self.assertRegex(rpi.portable_path(expected), r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
+                    self.assertEqual(rpi.portable_path(expected), rpi.portable_path(rpi.portable_path(expected)))
+                    if tail:
+                        self.assertRegex(rpi.portable_path(expected.replace("/", "\\")), r"^<UNSAFE_PATH_[0-9A-F]{64}>$")
@@ -271 +366 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                r"^<USER_HOME_[0-9A-F]{10}>/private/packet\.json$",
+                r"^<USER_HOME_[0-9A-F]{10}>$",
@@ -276 +371 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                r"^<EVIDENCE_ROOT>/lane-a/packet\.json$",
+                r"^<EVIDENCE_ROOT_[0-9A-F]{10}>$",
@@ -281 +376 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                r"^<UNC_ROOT_[0-9A-F]{10}>/research/packet\.json$",
+                r"^<UNC_ROOT_[0-9A-F]{10}>$",
@@ -313,2 +408,2 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-                self.assertEqual("result.json", first.rsplit("/", 1)[-1])
-                self.assertEqual("result.json", second.rsplit("/", 1)[-1])
+                self.assertNotIn("/", first)
+                self.assertNotIn("/", second)
@@ -362 +457 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-            self.assertRegex(result["error"], r"<USER_HOME_[0-9A-F]{10}>/private/result\.json")
+            self.assertRegex(result["error"], r"<USER_HOME_[0-9A-F]{10}>$")
@@ -369 +464 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-        self.assertRegex(rendered, r"^file not found: <USER_HOME_[0-9A-F]{10}>/private/missing\.json$")
+        self.assertRegex(rendered, r"^file not found: <USER_HOME_[0-9A-F]{10}>$")
@@ -384 +479 @@ class ReportPackageIntegrityTests(unittest.TestCase):
-            r"^invalid source path: <USER_HOME_[0-9A-F]{10}>/private/missing\.json$",
+            r"^invalid source path: <USER_HOME_[0-9A-F]{10}>$",
```

## OWNER_ADDITIONAL_2 bounded author delivery — 2026-09-24

This appendix records the current execution binding and supersedes earlier scope
and delivery instructions only for this authorized attempt. Same lane:
`ct-d005-path-redaction-followup-v1-20260923`; execution worktree:
`D:/EA_LAB_CONTROL/w/d005-auth2-0924`. Authority:
`D:/EA_LAB_CONTROL/evidence/ct-clearance-20260924/AUTHORITY_AND_DAG.md`,
`D005_INPUT_MANIFEST.json`, and the owner's explicit bounded dispatch.

The execution parent is `1df924b1ac7e112148dd8a70773c8c63b0b9a893`.
All four input files matched their manifest SHA256 pins from rejected reviewed
`54ce5b281eed27a88d84cf26f71c380f2b648013`. The latest actual finding source is
`D:/EA_LAB_CONTROL/evidence/mainct-autonomous-wave-20260923/03_d005_review_RESULT.txt`.
Original WIP, reviewed worktrees, and historical evidence were not changed.

Current WRITE scope is exactly this document, `report_package_integrity.py`,
`tests/test_report_package_integrity.py`, and
`tests/test_post_broad_diagnostic_pack.py` under `tools/reporting`.
`post_broad_diagnostic_pack.py` is READ ONLY. No Registry/state, source-root,
security, runtime, MT5, network/API, deployment, or research authority is added.

### Changes and finding disposition (author evidence, not acceptance)

- FINDING_1, placeholder delimiter-tail laundering: repaired in author gates.
- FINDING_2, quoted unknown-root delimiter-tail leakage: repaired in author gates.
  Error text no longer splits a reference at quotes, newlines, arrows, or another
  path start. The complete remaining reference span stays untrusted. Terminal
  outer quoting/whitespace is retained without releasing any readable tail.
  A qualified root permits readable relative output only for an unambiguous
  single reference. There is no username/private-directory blacklist.
- FINDING_3, comparison plus relative-path overredaction: repaired in author gates.
  Placeholder recognition uses adjacent label/path syntax; a slash in a later
  whitespace-separated diagnostic phrase is insufficient. Both `expected < 5
  for reports/result.json` and `expected > 5 for reports/result.json` remain exact.
- FINDING_4, hook provenance: the latest review's historical PASS is preserved.
  This delivery has NO fresh hook or acceptance PASS. CT owns staging, normal
  hooks, freezing, and the one separate targeted recheck.

Privacy tradeoff: free-text content after an ambiguous path start is opaque,
including possible prose after that path; free text cannot attest to where a
private filename ends. Diagnostic prefixes, ordinary comparison text with relative
references, unambiguous known-root relative positives, and bare generated-label
chains remain readable/idempotent. Structured OSError filenames retain their
existing separate treatment. No report hashing, integrity, or research semantics
changed: AST comparison to the rejected reviewed source identifies only
`_sanitize_error_text` as a changed function and `_PLACEHOLDER_START_RE` as the
changed top-level definition. All other functions/classes and top-level AST match.

Three integrity tests were added: delimiter privacy/determinism/idempotence,
comparison diagnostics, and known-root/generated-label positives. Two diagnostic
tests exercise delimiter privacy and ordinary comparisons through `main()` for
Refusal, OSError strerror, and structured OSError filename boundaries. Existing
test assertions were retained.

### RED-FIRST and bounded validation

Evidence directory:
`D:/EA_LAB_CONTROL/evidence/ct-clearance-20260924/d005-owner-additional-2/`.
Portable Python was already provisioned; each command dot-sourced
`scripts/use_python.ps1`. Imports/subprocesses used `-B` or process-scoped
`PYTHONDONTWRITEBYTECODE=1`; compilation output is under external evidence.

| Gate | Identity / result | Exit |
| --- | --- | --- |
| Pre-edit full reporting | 72 tests, all passed; `baseline-reporting.log` | 0 |
| RED integrity | `test_report_package_integrity.py`, `-k owner_additional_2`: 3 tests, 281 failing subcases | 1 |
| RED diagnostics | `test_post_broad_diagnostic_pack.py`, same filter: 2 tests, 200 failing subcases | 1 |
| GREEN integrity matrix | Same 3 tests, all passed | 0 |
| GREEN diagnostic matrix | Same 2 tests, all passed | 0 |
| Complete reporting | `python -B -W error -m unittest discover -s tools/reporting/tests -v`: 77/77 | 0 |
| Existing diagnostic wrapper | `powershell -NoProfile -File scripts/_test/run_post_broad_diagnostic_pack_tests.ps1`: 11/11 | 0 |
| Additional adversarial matrix | 498/498: 432 private delimiter, 18 qualified-root ambiguous, 32 ordinary comparison, 16 generated-label chain cases | 0 |
| py_compile | 4/4 Python files, including unchanged diagnostic producer; external bytecode only | 0 |
| Scope AST / producer hash | Only authorized presentation parser/regex delta; producer unchanged | 0 |

The RED implementation SHA256 remained
`e8556d66b6e3f7cf1ddaf19766b7620d4d92c87032dd617e2a1cb1040dfafb88`.
RED records, exact test commands/exits, verbose GREEN logs, adversarial counts,
compile/source binding, final diff-check, exact path inventory, and all final
SHA256 values are in the evidence directory. The retained new test matrix covers
504 sanitizer delimiter cases, 20 comparison controls, 18 known-root positives,
112 generated-label contexts, 360 diagnostic delimiter cases, and 8 diagnostic
comparison cases. Newline/multiline, both quote styles, arrows, POSIX/drive/UNC,
both slash styles, and unrelated synthetic names are represented. Full discovery
also retains all earlier malformed/nested/namespace/hash/negative/idempotence tests.

Post-repair Python source SHA256:

| File under tools/reporting | SHA256 |
| --- | --- |
| `report_package_integrity.py` | `ebc8f663a4acabf95e22e04a460b354cc379cd74719b4dbf99d5e628bb27a035` |
| `tests/test_report_package_integrity.py` | `1da5608c265e77800673d692f3a8feea4f4155b98956442d5d3a5c7f8eef1928` |
| `tests/test_post_broad_diagnostic_pack.py` | `9be0c78beae80a9f34dfff7b1dba826af5e69e27f65d0024c0e6b41f80e38c33` |
| `post_broad_diagnostic_pack.py` (unchanged) | `451079672d20a216cb29d313f5203684d6f22e353805b6caf44c26d5babe242e` |

### Budgets and delivery boundary

Historical Repair1 = **1/1 CONSUMED**. OWNER_ADDITIONAL_1 = **1/1 CONSUMED**.
OWNER_ADDITIONAL_2 was **0/1** at admission and is now **1/1 CONSUMED** by the
single implementation attempt. No budget reset, successor, or reviewer dispatch.
No further implementation attempt is authorized by this delivery.

Disposition: **AUTHOR_GATES_COMPLETE / WIP_DELIVERY / TARGETED_RECHECK_PENDING**.
Findings 1–3 have no remaining reproduced counterexample in these author gates;
independent closure remains OPEN pending CT's exact frozen-source targeted recheck.
No self-approval, acceptance PASS, integration, or source freeze is claimed.
No git add/commit/push was attempted, as explicitly instructed. This deliberate WIP
delivery is not a failed commit and does not consume or grant another repair.

## OWNER_ADDITIONAL_3 bounded correction — 2026-09-24

Authority remains the existing lane `ct-d005-path-redaction-followup-v1-20260923`; no new lane or repair-budget reset was created. Historical Repair1, OWNER_ADDITIONAL_1, and OWNER_ADDITIONAL_2 remain 1/1 consumed. OWNER_ADDITIONAL_3 is 1/1 consumed from the production-source mutation in this attempt.

Fresh reconciliation before mutation verified `origin/master == git ls-remote origin refs/heads/master == e0ae8db95decd4e6a117bd41f2e5f03b13f0f882`. The latest independent recheck reviewed `8484018150ee0f4534db38710f39939cb83c4576` and left only `D005-A2-001 / HIGH`: malformed placeholder text with whitespace between a label and a relative private tail could bypass placeholder recognition and leak through both Refusal and OSError boundaries. Current canonical had moved, so this correction was made without rebase/merge and is preserved for Main CT reanchor. No push is authorized.

RED-first was proven before production-source mutation. With the new Owner3 tests present and `report_package_integrity.py` unchanged from reviewed head `84840181`, the integrity Owner3 case failed 4 subcases and the diagnostic CLI Owner3 case failed 4 subcases. The reproduced leaks were the spaced-label apostrophe/private-tail form and newline/multiline continuation, under both Refusal and OSError. The same matrix retained quoted POSIX, Windows drive, UNC, malformed nested/repeated placeholder, numeric comparison, and idempotence controls.

The bounded repair changes only `_PLACEHOLDER_START_RE`: after an angle marker and label token, a whitespace-separated immediate path-bearing or nested-angle continuation is now recognized as untrusted placeholder syntax. No username, apostrophe-bearing name, directory, drive, server, or sample path is special-cased. `post_broad_diagnostic_pack.py` remains byte-unmodified by this attempt.

Post-repair deterministic gates:
- Owner3 targeted integrity: PASS.
- Owner3 diagnostic CLI boundary: PASS.
- Full reporting unit suite: 79/79 PASS.
- Diagnostic suite: 12/12 PASS.
- Adversarial matrix: 18/18 PASS.
- Leakage scan: 14/14 PASS.
- Idempotence: 14/14 PASS.
- Numeric comparison controls (`expected < 5` / `expected > 5` with `reports/result.json`): 4/4 PASS.
- Python compile: 4/4 PASS, bytecode emitted outside the repository.
- `git diff --check`: PASS before commit.

Preserved semantics: report integrity hashing, research semantics, HOLDOUT/artifact authority, strategy/runtime behavior, qualified repo/evidence-relative usefulness, and deterministic generated-placeholder idempotence are unchanged. Acceptance remains pending one independent targeted recheck by Main CT; this author result is not self-review or integration authority.
