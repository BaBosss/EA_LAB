# Historical non-Git administrative identity: S21

The owner explicitly assigned Codex a bounded source/state repair and existing Monitor activation after deterministic gates and independent review on 2026-10-08. Canonical source integration remains Main CT-owned. This change does not approve cleanup retries or reopen historical budgets.

`NON_GIT_ADMINISTRATIVE_V1` is an explicit identity migration for the single historical `storage-temp-cleanup-s21-20261007` record. Its BLOCKED state, owner/worker, scope, timestamps, execution blocker and all other historical fields are immutable. `base_sha` and `head_sha` are null; branch stays the empty string. Original non-Git markers remain in `legacy_base_sha` / `legacy_head_sha`. No unrelated Git commit is substituted.

The validator binds three exact local files by path and SHA256: the transcribed owner continuation authority, original Registry preimage, and existing stalled-termination reconciliation. All bindings are anchored in the reviewed source policy. A user-supplied schema label or arbitrary contract file cannot admit another record. Missing/changed bindings, unknown fields/kinds, substituted lane IDs, mixed Git/non-Git identity, changed history or an active state fail closed.

This intentionally narrow migration can be read/validated/audited. It cannot Claim, AmendScope, resume cleanup or transition S21 to an active state. Adding any other administrative record requires a separately authorized, tested and reviewed policy change. Git lanes keep their SHA validation. Audit reports `NOT_APPLICABLE_NON_GIT_ADMINISTRATIVE` and a null source head; it never presents this record as a reviewed Git source or a current executable lane.

The bindings are machine-local immutable evidence dependencies. If an evidence file becomes unavailable, validation refuses. Preserve those files with the runtime configuration and rollback manifest. The authority transcript is a provenance record, not an owner signature/attestation.

Registry migration uses exact preimage CAS under the existing Registry lock. Source, state, runtime config and current/previous publication preimages are retained for rollback. Tests cover positive Git and administrative records, malformed identity/provenance/history, activation rejection and complete Registry/publisher compatibility. Monitor health may remain DEGRADED after successful publication because deployment/runtime evidence gaps are independent.
