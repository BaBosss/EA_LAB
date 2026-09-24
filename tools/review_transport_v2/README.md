# Review transport V2 (prospective mechanical tooling)

Status: implementation only. STANDARD_READY=false; independent scrutiny and new
V2 qualification are still required. V1 remains closed negative evidence.

The trusted launcher exports an exact standalone source/Git/evidence package into
immutable Python bytes and a read-only mapping. The reviewer receives serialized
messages with six tools only: `get_manifest`, `get_head`, `read_source`,
`read_evidence`, `read_git_object`, `get_hash`. IDs are opaque; read offsets/lengths
are byte ranges; responses use base64. Host paths are never tool arguments. The
dispatcher has an explicit operation table, exact argument sets and aggregate
budgets. It never executes model code or routes arbitrary provider tools.

The dispatcher owns execution. Unknown tools, IDs, wrong entry kinds, extra
arguments, paths, writes and process/runtime operations are denied there, even if
a hostile model requests them. An in-process fake is trusted test machinery, not
a sandbox for arbitrary Python plug-ins. No local model process is launched.

## Trust and invocation

`launch.run(Approval(...), FakeModelClient(...))` is the supported deterministic
test API. `Approval` is a separately frozen out-of-band object from the trusted
launcher/operator: control root identity, contract/transport/run IDs, expected
raw contract/state SHA256, implementation-manifest bytes and their expected hash,
and state size ceiling. Never derive expected hashes from the files being checked.
An external trusted bootstrap must verify code/runtime hashes BEFORE importing
this implementation. Its in-process checks establish continuity; self-hashing is
not a bootstrap security boundary. The trusted Windows OS, Python runtime and
approval issuer remain outside the reviewer boundary.

No real API adapter exists in this revision. `ModelClient.preflight` refuses with
`QUALIFIED_API_ADAPTER_UNAVAILABLE`. There is no environment credential discovery,
endpoint inference, network call, Codex CLI fallback, browser, MCP or helper-state
dependency. A real adapter needs a separately approved implementation/endpoint,
explicit credential-availability preflight and new operational qualification.

Implementation manifest has exactly two closed blocks, `implementation` and
`dependencies`, each with `root`, root `identity`, and `files`. Each file binds
`path`, `identity` (device/inode), `size`, `sha256`. The implementation block must
list all 18 paths in `launch.IMPLEMENTATION_PATHS`; the dependencies block contains
the complete isolated Windows embeddable Python 3.12 directory. The runtime must
disable site startup and bytecode writes (`-B`; the shipped `_pth` disables site).
All files and schema hashes, including dispatcher/client code, are pinned.

Production control root: `D:\EA_LAB_CONTROL`. Existing parent directories must
be provisioned by the trusted operator; no automatic repair or reset occurs:

- `review_transport_v2/contracts/<contract-id>/contract.json`
- `review_transport_v2/state/<transport-id>/state.json`
- `review_transport_v2/bundles/<bundle-manifest-sha256>/`
- `evidence/review-transport-v2-<run-id>/`

Each bundle/run is create-once. Existing paths (including incomplete runs) refuse.
State is strict bounded UTF-8 JSON: raw/decoded NUL, duplicates, trailing JSON,
unknown fields, excessive nesting, invalid values and wrong raw hashes refuse
before dispatch. Five schemas use a deliberately closed JSON Schema subset; the
validator refuses unsupported keywords and never resolves remote references.

The contract explicitly names source/evidence root identities and their EXACT
file inventories. A source package must contain every tracked source file being
reviewed and no extra files outside `.git`. Source bytes must match the exact
HEAD/tree/blob graph. Git objects must be an explicitly approved inventory of the
HEAD commit, required trees and source blobs; missing objects never expand the
inventory and never trigger a fetch. OID header/type/length/content are recomputed.

This first version deliberately accepts only standalone loose-object Git stores
with loose HEAD refs (SHA1 or SHA256). Linked worktrees, packed objects/refs,
alternates, replace refs, shallow/partial/promisor stores, includes and external
stores fail ENVIRONMENT. A trusted operator must supply a standalone approved
package; the launcher never clones, unpacks, repairs or fetches it. This is a
capacity/compatibility limitation, not an operational qualification claim.

Windows handles pin root ancestry against rename/delete and files against
write/delete while checking reparse points, symlinks, hardlinks, identities and
inventories. Other OSes refuse. After export the reviewer reads only memory.
Enumeration errors, including unreadable nested directories, refuse rather than
silently omitting a subtree from the exact inventory.
Pre-dispatch rechecks and finally-block postconditions verify source, evidence,
HEAD, contract, state and implementation/runtime continuity. This is not a global
machine freeze; unrelated host activity is outside this package's attestation.

## Results and receipts

Substantive results require nonzero successful evidence reads, full byte coverage
of every required entry (all evidence entries are mandatory), evidence citations,
valid schema and exact reviewed HEAD/bundle hash. Manifest/hash-only calls,
duplicate chunks and partial reads cannot satisfy coverage. Fake results are
accepted only when every cited entry has full successful content-read coverage,
including optional source/Git entries outside the contract's required set. There
is no metadata-only citation mode. Fake results are
labelled `DETERMINISTIC_TEST_ONLY`; their verdict is never an acceptance verdict.
Every runtime gate is `NOT_QUALIFIED` in receipts, not an invented twelve-gate PASS.

Failures before dispatch produce ENVIRONMENT, zero dispatch and null verdict.
Provider/coverage/postcondition failures after dispatch retain the actual count
and null verdict. Invalid output-root/approval bootstrap or failed disk writes
raise: a durable receipt cannot honestly be promised on an unsafe/unwritable root.
No source/state repair, retry or fallback occurs.

The receipt binds all requested identities, preflight/postconditions, coverage,
provider request IDs, read-log hash, raw-output hash and validated-result hash.
Raw provider bytes are also persisted as `.bin`; a deterministic JSON rendering
of their ordered inventory is separately hashed. `raw_model_outputs` binds every
binary's exact filename, byte size and SHA256; `raw_model_output_sha256` hashes
that canonical inventory, also persisted as `raw_model_outputs.json`. No lossy
text decoding participates in this binding, including malformed provider output.

Files are exclusive-create and fsynced. Creation-handle identities are compared
when the file is pinned; a same-byte replacement in the close/open interval
refuses. All bundle/run artifacts remain pinned against write/delete through
completion. Immediately before writing `receipt.json` last, both groups undergo
exact identity/byte/inventory verification, including rejection of extra empty
directories. An unsafe/incomplete persisted bundle or run raises and leaves no
completion receipt. Original artifacts are never overwritten. Directory handles
prevent root replacement but do not freeze child-name creation: inventory is a
final observed boundary, not an OS-wide exclusion against later additions.

## Deterministic validation

Use the primary portable runtime after dot-sourcing `scripts/use_python.ps1`.
Set `RT_V2_TEST_ROOT` to a new create-once directory under the authorized V2
evidence root. Tests retain their fixtures and receipts for inspection. From the
implementation worktree run:

```powershell
. D:\EA_LAB\scripts\use_python.ps1
$env:RT_V2_TEST_ROOT = '<new approved evidence directory>'
python -B -c "import sys,unittest; sys.path.insert(0,'tools/review_transport_v2'); sys.path.insert(0,'tools/review_transport_v2/tests'); s=unittest.defaultTestLoader.discover('tools/review_transport_v2/tests'); r=unittest.TextTestRunner(verbosity=2).run(s); sys.exit(not r.wasSuccessful())"
```

`test_gate_contract.py` preserves gates 1–12. Other suites exercise corruption,
HEAD/path/Git identity, unknown tool/ID, writes/Registry/process/runtime, partial
and zero evidence, provider failure, receipt binding and byte repeatability.
Fixtures use synthetic loose Git objects; no MT5/product/runtime operation occurs.
Normal hooks, diff-check, schema validation and py_compile must also pass. These
are implementation tests only; do not rerun V1 or dispatch independent scrutiny
from this author lane. Main CT consumes the exact clean implementation commit.

Repair1 (start `3f66c678be7c34952394099e282b0a629375b426`) is **1/1 consumed**.
RTV2-001..004 each have red-first regression evidence; the initial seven test
methods produced 17 failing assertions/subcases before their production fixes.
The repair remains author implementation evidence only: STANDARD_READY=false,
TARGETED_RECHECK_NOT_STARTED. No real adapter or broker operation was added.
