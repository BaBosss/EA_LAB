# Lane Registry AmendScope V1

Prospective MECHANICAL_TOOLING author contract: owner-supplied "REGISTRY AmendScope
V1 TPL UNBLOCKER", 2026-09-23. Base: `372c73e5f33f39fa445c748f40cbfed5565c6831`.
Implementation lane: `ct-registry-amendscope-v1-20260923`.
Can do: Codex Primary (tooling author). Suggested: deterministic local tooling.
Reviewer: Main CT dispatches separate exact-head scrutiny; author cannot approve.
Scope: Registry script, existing dedicated tests, this document. No product, TPL
source/gate/baseline, runtime, risk, PROJECT_STATE or live TPL record mutation.

## API

```powershell
$p = @{
    Command = 'AmendScope'
    RegistryRoot = 'D:\fixture\registry-v1'
    RepoRoot = 'D:\EA_LAB'
    LaneId = '<existing-writer-id>'
    ExpectedState = 'BLOCKED'
    ExpectedHead = '<full-lowercase-40-hex-head>'
    AddPaths = @('scripts/example.ps1', 'scripts/_test/example.ps1')
    AuthorityRef = 'D:\approved\mechanical-amendment.md'
    AuthoritySha256 = '<SHA256-of-exact-reference-file-bytes>'
    LockTimeoutSeconds = 5
    Json = $true
}
& .\scripts\lane_registry.ps1 @p
```

AuthorityRef is a fully qualified drive-local file, hashed as raw bytes. Drive-relative,
UNC, device and mapped network-drive references are refused. The receipt records
the resolved full file path after ancestor inspection. This binds an approved
reference supplied by the authorized caller; a matching hash is not an owner
signature and the tool does not interpret prose as authority. Main CT must bind
the approved reference to the requested amendment. No network fetch.
Use PowerShell splatting for array inputs; `powershell.exe -File` does not encode
multiple string-array values reliably. Unsupported parameters fail closed.

Only BLOCKED, WAITING, PAUSED and READY writer records are eligible. State and
registered/actual HEAD must match exactly; worktree top level, branch and Git
common directory must identify the intended repository. reviewed_head must be
empty. Dirty worktrees are allowed: this operation neither certifies dirty bytes
nor activates the lane. Existing Claim and Transition lifecycle/scope rules are unchanged,
except for the owner-authorized shared literal conflict identity repair below.
Their complete-record writes now use the same depth-checked, lossless atomic writer.

Every requested path is appended to both allowed_paths and critical_paths when
absent (ordinal case-insensitive, slash-normalized membership). Only separators
and a terminal directory separator normalize; no Unicode whitespace trimming,
linguistic comparison or Unicode composition normalization occurs. NBSP, EM SPACE,
Thai characters and composed/decomposed names remain literal. This comparison is
shared by Claim, Transition and AmendScope conflict checks; historical input
validation remains unchanged. Existing spelling, order,
scope, identity, budget, arbitrary extension fields and updated_at are preserved.
There is no removal, replacement or non-scope mutation interface. The receipt's
timestamp records amendment time without repurposing updated_at.

New inputs must be literal repository-relative paths. Empty components, dot
segments, rooted/drive/UNC/device paths, ADS, controls, wildcard/invalid Windows
characters, reserved devices, leading/trailing dots/spaces and short-name aliases
are refused. V1 conservatively rejects **all** reparse ancestors, even links that
would resolve inside the repository. New suffixes require an existing verified
directory ancestor. This policy is confined to AmendScope, not historical path
normalization. External absolute historical entries remain stored verbatim.

Admission parses the Registry under its existing global lock, verifies unique
lane IDs and filenames, and checks the full resulting scope against active
competitors. Existing same-owner and runtime-lane conflict rules remain. Exact,
parent and child overlap all refuse. Absolute paths under linked worktrees map
back to the common repository namespace. Unsafe/unverifiable active competitor
namespaces fail closed. Activation still uses the existing Transition gate.

## Atomic receipt and replay

One `scope_amendments[]` receipt is appended within the same atomic lane JSON
replacement as its scope. It binds authority reference/hash, lane identity,
unchanged state/HEAD, normalized requested paths, actual additions to each array,
before/after scope SHA256, timestamp, and preserved non-scope field SHA256.
Digests cover UTF-8 without BOM compact PowerShell JSON with property/array order
preserved. Scope digest field order is allowed_paths then critical_paths; the
preserved-field digest excludes only those two arrays and scope_amendments.
Older receipts remain intact. Serialization is checked for lossless roundtrip
before replacement and exact deterministic readback occurs under lock before
`AMENDED` is returned. Existing atomic writer defaults remain unchanged.

A duplicate-only valid replay returns deterministic `NO_CHANGE`: no write, no
timestamp change, no added receipt. Preconditions and conflict checks still run,
so a newly conflicting competitor correctly refuses a later retry. Noncooperating
external filesystem/Registry writers are not serialized by this advisory lock;
normal Registry consumers must use the same lock. Reparse checks are admission
checks, not a security boundary against concurrent hostile filesystem mutation.

## Validation and acceptance boundary

Run `powershell -NoProfile -File scripts/_test/lane_registry_tests.ps1`.
The suite prints the original Registry count separately from the AmendScope
matrix. It exercises the real CLI against disposable repositories, preserves
dirty/index bytes, and observes concurrent readers during atomic replacement.
No fixture uses MT5. The author's evidence directory records before/after logs,
the current-Registry copied TPL admission, scope verification and hook outcome.

The TPL demonstration must operate on a copy of current Registry state and add
`scripts/_test/run_tpl_set_checkout_contract_tests.ps1` to
`ct-tpl-core-delta-contract1-20260923`. The live TPL record and four-file WIP remain
untouched; repair usage remains 0/1. Tool implementation does not grant final
live amendment authority. One normal `[codex]` commit, no push, then Main CT
scrutiny. No self-approval or integration is represented by author test PASS.

Author validation on 2026-09-23: original suite **37/37 before, 37/37 after**;
AmendScope matrix **106/106**; combined **143/143**, zero failures. Final source
hashes and full logs: `D:\EA_LAB_CONTROL\evidence\registry-amendscope-0923\`.
`frozen-acceptance.log` is the stable-source acceptance run; earlier harness
failures remain in `after.log` as historical evidence, not acceptance.

The mandatory 36-item contract matrix is covered as follows:

| Contract cases | Executable evidence |
|---|---|
| 1-4 | Dirty BLOCKED / WAITING / PAUSED / READY success |
| 5-12 | Missing lane, stale state/HEAD, five forbidden states |
| 13-17 | Literal-path negatives, Windows aliases, C0/C1 controls, junction escape |
| 18 | Repeated NO_CHANGE: exact output, bytes, mtime and receipt count |
| 19-21 | Exact, parent, child active overlap; cross-checkout absolute aliases |
| 22-26 | Preserved scope/fields/digests; removal/replacement/identity/reviewer injection refusals |
| 27-28 | Malformed/duplicate Registry; concurrent old-or-new atomic reader observation |
| 29-31 | Validate/Get/Audit, unchanged lane count/IDs, dirty/index byte hashes |
| 32-34 | Authority mismatch/missing file, reviewed_head, held-lock timeout |
| 35-36 | Original duplicate Claim and Transition suite; amended activation conflict |

Final TPL copied-Registry admission: **PASS**, 1,005 copied records; target scope
4 -> 5 in both arrays; one receipt; other 1,004 fixture records unchanged. Live
TPL record SHA256 stayed
`8874AEED1449CCAA2684C9D2EE9E61703282C6440295EFAD0B5622AE2DCB0837`;
all four WIP files and the TPL index stayed byte-identical. No live amendment;
repair usage **0/1 unchanged**. Exact receipt and preservation hashes are in
`tpl-admission-output.json` and `tpl-fixture-result.json` in the evidence directory.

## Scrutiny repair1 (2026-09-23)

One bounded author repair follows independent `SCRUTINY_REPAIR_REQUIRED / HIGH`
at reviewed head `620d77b996e7dd0ed5e4343e18087d8b998c1d2d`, tree
`afbe126ab8e809a24288386ca3ba52370a25e79d`. Repair budget: **1/1 used**;
targeted independent recheck is not started. No acceptance is implied.

- Path membership and Amendment conflict comparisons preserve literal Unicode
  names using ordinal Windows case identity; historical absolute records stay
  stored verbatim and retain the existing namespace admission checks.
- AmendScope, Transition and Claim's superseded-record write all serialize with
  the supported JSON depth ceiling (100), inspect depth before mutation, and
  check JSON round-trip before atomic replacement. AmendScope retains its
  existing admission depth limit (80). Over-depth input refuses rather than
  silently stringifying leaves. Legacy records need no schema migration.
- Authority resolution requires a fully qualified local file and records its
  resolved path plus verified raw-byte hash; approval binding remains Main CT's duty.
- Ancestor inspection accepts only explicit filesystem `PathNotFound` with
  `ItemNotFoundException` / `ObjectNotFound` as absence. Access, IO and other
  inspection errors fail closed. Confirmed missing suffixes remain allowed when
  the ancestors can be inspected and contain no reparse/non-directory hazard.

Repair evidence: `D:\EA_LAB_CONTROL\evidence\registry-amendscope-0923\repair1\`.
`baseline.log`: unchanged 143/143. `red-first.log`: original 143 checks still pass;
the initial 22 repair checks produce 11 PASS / 11 FAIL before any source repair,
covering all four findings. Provider-error fixtures run through the public command
with deterministic Get-Item errors; they do not depend on ACL/admin privileges.
Later harness/green logs preserve every observed outcome. The final report binds
final test counts, source hashes, live-TPL preservation, hook outcome and staged
state. Canonical divergence is left to Main CT; no rebase, merge or push occurs.

## Owner-authorized additional repair: latest Finding 1 (2026-09-23)

Existing lane: `ct-registry-amendscope-v1-20260923`. Exact local reanchor start:
`7794cee84adcb19311ea271df622c108b210f0b1`, tree
`839e57db9ee1e9f34adf341cd81fc6686b3db68d`. The owner's current chat contract
authorizes only the latest open Claim/Transition literal Unicode conflict finding
in these same three files. Historical Repair1 remains **1/1 consumed**. The
additional owner repair became **1/1 consumed** at the first test-file mutation;
there is no second additional repair or pass-shopping authority.

Claim, Transition and AmendScope now share `Test-PathOverlap` and its separator-only
path key. Exact equality and parent/child prefix comparisons use
`OrdinalIgnoreCase`; no whitespace trimming, linguistic equality, lowercasing or
composition normalization participates in conflict identity. The AmendScope-only
comparison switch and duplicate overlap helper are removed. Stored historical
paths, input validation, namespace admission, lifecycle and Registry design remain
unchanged.

Red-first evidence: unchanged baseline **168/168 PASS** (37 original Registry,
106 initial AmendScope, 25 Repair1). With only the new tests added and before
source repair, the 39-check owner matrix returned **23 PASS / 16 FAIL**, total
**191 PASS / 16 FAIL**. The failures were eight Claim and eight Transition cases:
NBSP parent/child, terminal separator alias, distinct NBSP/plain (exact and child),
EM SPACE parent, distinct EM SPACE/plain, and distinct Unicode composition.
Case/separator aliases, Thai literal names and historical external absolute scope
preservation are also covered for each of Claim, Transition and AmendScope.
After the single source repair, full suite **207/207 PASS**: original Registry
37/37, initial AmendScope 106/106, Repair1 25/25 and owner Finding1 39/39.
Deep-extension, AuthorityRef and ancestor fail-closed gates remain green.
PowerShell parsing of both scripts and `git diff --check` pass.

The initial baseline attempt was blocked by a sandbox Git global-ignore access
warning; an attempted `NUL` excludes-file override also failed before useful
tests. The completed runs use a process-local `XDG_CONFIG_HOME` pointing to an
absent temporary directory; no persistent Git configuration changed.

Copied current TPL Registry admission: **PASS**, 1,006 records; target arrays
4 -> 5, one receipt, other 1,005 fixture records unchanged. Live TPL JSON SHA256
remains `8874AEED1449CCAA2684C9D2EE9E61703282C6440295EFAD0B5622AE2DCB0837`;
four protected WIP files and the index are byte-identical before/after. TPL repair
usage stays **0/1 unchanged**. The first fixture attempt hit Git safe-directory
ownership checking; the successful run used process-only trust for the two exact
owner repositories and a read-only lock handle while copying. No live TPL mutation.

Fresh fetch was attempted and blocked by the session environment: normal fetch
cannot write `D:/EA_LAB/.git/worktrees/registry-amendscope-reanchor-0923/FETCH_HEAD`;
`--no-write-fetch-head` fetch and `ls-remote` fail GitHub authentication with
`SEC_E_NO_CREDENTIALS`. Cached `origin/master` is
`c24eec92edd5f30d715478cb2cf6eac38cf0f4ee`; it is **not fresh canonical evidence**.
No reconciliation, reset, stash, cleanup, amend, force operation or push is authorized.
Targeted independent recheck is **NOT STARTED**; author validation is not acceptance.

Commit outcome: **BLOCKED_GIT_METADATA_PERMISSION**. Normal staging of exactly the
three authorized files refused with `Permission denied` creating
`D:/EA_LAB/.git/worktrees/registry-amendscope-reanchor-0923/index.lock`.
Normal commit hooks were **NOT REACHED**; this is not a canonical-divergence hook
rejection. No commit was created; HEAD/tree remain the pinned start identities
above, and the three-file repair is unstaged in the working tree. No hook bypass,
Git metadata relocation or alternate commit mechanism was used.
