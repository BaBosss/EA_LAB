# Codex independent review of lane `S-2026-08-04-CORRECT3` — 2026-08-04

> Verbatim stdout of the review job, saved by the lane it reviews. Brief =
> `CODEX_AUDIT_CORRECT3_BRIEF.md`. Follow-up = `ORDER-1310`.
>
> **Five of the nine findings were independently reproduced by the reviewed lane before this
> file was written** (F1 · F3 · F5 · F6 · F8). The reproductions, and one correction to F6's
> stated severity, are on the `ORDER-1310` row rather than here. This file is left EXACTLY as
> the reviewer returned it, including its own execution note about the sandbox.

---

# Independent read-only review

## CONFIRMED

1. **High — [check_s2a_attestation.py:583](/D:/EA_LAB/_triage/factory_os/check_s2a_attestation.py:583): The narrowed exemption accepts any reproducible section of `MASTER_BACKLOG.md`, not specifically the approved Coverage section.**

   Concrete failure: I replaced the attestation’s post-state with the correctly hashed unrelated `## 1. ความจริงสั้น ๆ` section and supplied a stale `factory/coverage.jsonl` note. `check()` returned zero problems, kept `APPROVED`, and printed `PIN NOT ENFORCED`. Thus unrelated stable prose can replace the destination pin.

2. **High — [notifier.py:981](/D:/EA_LAB/_triage/factory_os/notifier.py:981): Caller-controlled probe IDs enter notification text while the known-secret layer is explicitly disabled.**

   Concrete failure: probe ID `159503454` produced `[EA LAB] delivery probe 159503454 → EMERGENCY`; [notifier.py:1021](/D:/EA_LAB/_triage/factory_os/notifier.py:1021) selected `NO_KNOWN_SECRETS_AVAILABLE`, and `assert_sendable()` accepted it. A user choosing their account number as a convenient unique probe ID would send it to Telegram.

3. **High — [check_s2a_attestation.py:554](/D:/EA_LAB/_triage/factory_os/check_s2a_attestation.py:554): The claimed “for that row only” exemption discards row identity and becomes path-scoped.**

   Concrete failure: synthetic row A was a qualifying destination-pinned `TRANSFER`; unrelated row B was `KEEP` but pinned the same path. B’s stale pin was exempted and its decision remained `APPROVED`. The cause is the set of paths returned at lines 554–560 and path-only comparison at line 579. This also relies on `TRANSFER + path equality` as proof of execution even though [S2A_ATTESTATION_POLICY.md:154](/D:/EA_LAB/_triage/factory_os/S2A_ATTESTATION_POLICY.md:154) states D1 has no executed-state vocabulary.

4. **Medium — [check_s2a_attestation.py:930](/D:/EA_LAB/_triage/factory_os/check_s2a_attestation.py:930): `--template` can omit an acknowledgement that `check()` still demands.**

   Concrete failure: an in-force `MASTER_BACKLOG.md` record with a valid section claim for `AGENT_TASKBOARD.md` caused template exit 0 with no acknowledgement, while `check()` emitted F7 and F2. The checker additionally requires no other row problem at line 819; the template does not.

5. **Medium — [safe_projection.py:195](/D:/EA_LAB/_triage/factory_os/safe_projection.py:195): A secret used as a dictionary key is restated in the exception path despite the redacted detail.**

   Concrete failure: `{"findings":[{"900112233":"anything"}]}` raised an exception containing `$.findings[0].900112233`. SP17 proves detection but does not check diagnostic redaction; SP07 checks absence only for a secret stored as a value.

6. **Medium — [safe_projection.py:302](/D:/EA_LAB/_triage/factory_os/safe_projection.py:302): Separator-stripping normalization creates realistic false refusals.**

   Concrete failure: `open_lots=0.05` becomes `005`, which matches `generated_at="2026-08-04T00:05:00"` after normalization. The full projection build was refused with `KNOWN_SECRET`; the former literal comparison would not match.

7. **Medium — [run_fast_cages.ps1:901](/D:/EA_LAB/scripts/_test/run_fast_cages.ps1:901): The new S2a trigger list omits judged inputs.**

   Concrete failure: `check_coverage_transfer` directly reads `schemas.json` at [check_coverage_transfer.py:639](/D:/EA_LAB/_triage/factory_os/check_coverage_transfer.py:639), and `check_s2a_migration` reads exact design claims, but neither `schemas.json` nor `_triage/EA_LAB_FACTORY_OS_DESIGN.md` selects `run_s2a_cages.ps1`. I reproduced both selections. A design-only edit removing an UNOWNABLE evidence sentence can invalidate C3 without running this cage.

8. **Low — [safe_projection.py:279](/D:/EA_LAB/_triage/factory_os/safe_projection.py:279): `LAYERS_NOT_RUN` records process history rather than the current scan.**

   Concrete failure: a sentinel scan followed by a populated-recognizer scan left the prior “KNOWN_SECRET not run” notice present. A later in-process CLI check can therefore report a skipped layer that actually ran; repeated sentinel calls also grow the list indefinitely.

9. **Low/test gap — [run_s2a_attestation_tests.py:191](/D:/EA_LAB/_triage/factory_os/run_s2a_attestation_tests.py:191): The case advertised as covering F14 always exercises F13.**

   Concrete failure: section `"S2a coverage transfer"` does not exist as an exact heading, so line 194 accepts F13 before hash comparison is reached. Mutation `elif got != eps['section_sha256']` → `elif False` at checker line 764 survives this case; the other wrong-hash test is masked by F2 and asserts only `pin is STALE`.

No additional plausible-only findings.

## Claims that held

- Current D1 has 29 rows, and the current predicate selects exactly one.
- Dictionary keys are scanned, subject to the diagnostic leak above.
- `build_id` and `generated_at` patterns match their named producers and the current projection.
- Value-based refusal messages retain rule, path, length, and suffix without repeating the full value.
- No incorrect ordering was found in the per-row problem snapshot.
- Current production consumption of `check()` goes through `main()` and `reported_decision()`; direct map consumers are tests/conformance. Keeping the returned map unchanged is defensible for current callers.
- Inspected S2a writes are confined to temporary fixtures; no tracked-file writer was found.
- Disclosing commit `633a6414` was the safest option. Correcting its historical attribution required rewriting shared history; a forward revert/reapply would not repair the original attribution and risked removing the other lane’s legitimate work.
- The single “before” timing sample weakens the precision of the measured delta, but not the three-sample after measurement or the reported 120-second ceiling.
- The eleven reviewed SHAs all have the required Claude trailer. Interleaved commits were excluded strictly by the brief’s SHA list.

SP16 accurately records the split-field gap, but it is the wrong shape as a normal passing security test: closing the vulnerability makes the suite red. It should be treated as an expected-gap tripwire, not evidence that the boundary passes.

## Execution note

The read-only sandbox prevented complete suite execution because Python had no writable temporary directory:

- S11: 70/78 cases passed; eight failed during tempfile/output setup.
- S12: 55/66 passed; eleven failed during tempfile setup.
- S2a gate: generator, generated document, and nine machine criteria passed; execution stopped when its self-test requested a tempfile.
- Standalone attestation checker exited 0.
- Conformance and schema cages were not interpretable because their fixtures failed before assertions ran.

No files were edited, created, staged, or committed by this review. Concurrent work changed the shared index during testing; those changes were not attributed to the reviewed lane.

Codex session ID: 019fca03-fb3a-77c0-ae83-5d1faaa2b0a6
Resume in Codex: codex resume 019fca03-fb3a-77c0-ae83-5d1faaa2b0a6
