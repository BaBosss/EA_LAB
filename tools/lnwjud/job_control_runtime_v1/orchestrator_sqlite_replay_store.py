"""Isolated SQLite WAL replay/CAS source fixture; not a production signer or scheduler.

External owner MUST authenticate and authorize the injected verify_claim() provider;
this class never grants process, job or trading authority. Real trust-anchor and
installed runtime qualification are separate acceptance gates.
"""
import datetime as dt
from contextlib import closing
import pathlib
import re
import sqlite3

SCHEMA = "EA_LAB_T3C_P1_SIGNED_CLAIM_V1"
FIELDS = frozenset(("schema", "source_head", "source_tree", "resource", "owner",
 "lease_id", "lease_until_utc", "sequence", "idempotency_key",
 "signed_proof_sha256", "can_execute", "can_submit"))
ID = re.compile(r"^[A-Za-z][A-Za-z0-9._-]{2,127}$")
SHA40 = re.compile(r"^[a-f0-9]{40}$")
SHA64 = re.compile(r"^[a-f0-9]{64}$")
UTC = re.compile(r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(?:\.\d{1,3})?Z$")

def instant(value):
    if not isinstance(value, str) or not UTC.fullmatch(value):
        return None
    try:
        v = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return v.timestamp()
    except (TypeError, ValueError, OverflowError):
        return None

def result(status, reason):
    return {"schema": "EA_LAB_T3C_P1_ISOLATED_LEDGER_RESULT_V1",
            "status": status, "reason": reason,
            "scope": "ISOLATED_EVIDENCE_ONLY",
            "can_execute": False, "can_submit": False}

class SQLiteReplayLedger:
    """Local SQLite WAL durability fixture with atomic resource+historical proof claim.

    Not an authenticated production lease service. CAS serialization uses
    BEGIN IMMEDIATE, one transaction, primary/unique constraints, full sync.
    """
    def __init__(self, db_path, root_dir, source_head, source_tree, *, clock=None, verify_claim=None):
        if not callable(clock) or not callable(verify_claim):
            raise ValueError("MISSING_CLOCK_OR_VERIFIER")
        if not (isinstance(source_head, str) and SHA40.fullmatch(source_head) and
                isinstance(source_tree, str) and SHA40.fullmatch(source_tree)):
            raise ValueError("SOURCE_PIN_UNQUALIFIED")
        root = pathlib.Path(root_dir)
        file = pathlib.Path(db_path)
        if not root.is_absolute() or not file.is_absolute() or not root.is_dir():
            raise ValueError("ISOLATION_ROOT_UNQUALIFIED")
        # No traversal, distinct parents, symbolic file, or external storage target.
        if root.is_symlink() or file.is_symlink() or file.parent.resolve() != root.resolve() or file.suffix != ".sqlite3":
            raise ValueError("DB_PATH_OUTSIDE_ISOLATED_ROOT")
        self._path = file
        self._source_head = source_head
        self._source_tree = source_tree
        self._clock = clock
        self._verify = verify_claim
        self._init_failed = False
        try:
            with closing(self._connect()) as con:
                con.execute("""CREATE TABLE IF NOT EXISTS current_state(
                resource TEXT PRIMARY KEY, owner TEXT NOT NULL, lease_id TEXT NOT NULL,
                expires REAL NOT NULL, sequence INTEGER NOT NULL, proof TEXT NOT NULL,
                source_head TEXT NOT NULL, source_tree TEXT NOT NULL)""")
                con.execute("""CREATE TABLE IF NOT EXISTS replay_history(
                signed_proof_sha256 TEXT PRIMARY KEY, idempotency_key TEXT NOT NULL UNIQUE,
                resource TEXT NOT NULL, sequence INTEGER NOT NULL, actor TEXT NOT NULL)""")
        except sqlite3.DatabaseError:
            self._init_failed = True

    def _connect(self):
        con = sqlite3.connect(str(self._path), isolation_level=None, timeout=10)
        try:
            con.execute("PRAGMA busy_timeout=10000")
            mode = con.execute("PRAGMA journal_mode=WAL").fetchone()[0]
            if mode.lower() != "wal":
                raise sqlite3.DatabaseError("WAL_NOT_ENABLED")
            con.execute("PRAGMA synchronous=FULL")
            if int(con.execute("PRAGMA synchronous").fetchone()[0]) != 2:
                raise sqlite3.DatabaseError("FULL_SYNC_NOT_ENABLED")
            return con
        except BaseException:
            con.close()
            raise

    def _check(self, c):
        if type(c) is not dict or frozenset(c) != FIELDS or c.get("schema") != SCHEMA:
            return False
        if c["source_head"] != self._source_head or c["source_tree"] != self._source_tree:
            return False
        if not all(isinstance(c[key], str) and ID.fullmatch(c[key]) for key in
                   ("resource", "owner", "lease_id", "idempotency_key")):
            return False
        if not isinstance(c["signed_proof_sha256"], str) or not SHA64.fullmatch(c["signed_proof_sha256"]):
            return False
        if type(c["sequence"]) is not int or not 1 <= c["sequence"] <= 2**53-1:
            return False
        if c["can_execute"] is not False or c["can_submit"] is not False:
            return False
        try:
            now = instant(self._clock())
        except Exception:
            return None
        until = instant(c["lease_until_utc"])
        if now is None:
            return None
        if until is None or until <= now or until - now > 300:
            return False
        return (now, until)

    def record(self, claim):
        verdict = self._check(claim)
        if verdict is None:
            return result("UNKNOWN", "CLOCK_OR_PROOF_UNAVAILABLE")
        if verdict is False:
            return result("BLOCKED", "CLAIM_SOURCE_OR_LEASE_INVALID")
        try:
            if self._verify(dict(claim)) is not True:
                return result("BLOCKED", "UNQUALIFIED_EXTERNAL_PROOF")
        except Exception:
            return result("UNKNOWN", "VERIFIER_UNAVAILABLE")
        if self._init_failed:
            return result("UNKNOWN", "STORAGE_INITIALIZATION_FAILED")
        now, until = verdict
        con = None
        try:
            con = self._connect()
            con.execute("BEGIN IMMEDIATE")
            history = con.execute(
                "SELECT 1 FROM replay_history WHERE signed_proof_sha256=? OR idempotency_key=? LIMIT 1",
                (claim["signed_proof_sha256"], claim["idempotency_key"])).fetchone()
            if history:
                con.execute("ROLLBACK")
                return result("BLOCKED", "HISTORICAL_REPLAY")
            row = con.execute("SELECT owner,lease_id,expires,sequence,source_head,source_tree "
                              "FROM current_state WHERE resource=?", (claim["resource"],)).fetchone()
            if row:
                owner, lease, expires, seq, head, tree = row
                if head != self._source_head or tree != self._source_tree:
                    con.execute("ROLLBACK")
                    return result("UNKNOWN", "STORED_SOURCE_DRIFT")
                if claim["sequence"] <= seq:
                    con.execute("ROLLBACK")
                    return result("BLOCKED", "SEQUENCE_REGRESSION")
                if expires > now and (owner != claim["owner"] or lease != claim["lease_id"]):
                    con.execute("ROLLBACK")
                    return result("WAITING_RESOURCE", "ACTIVE_LEASE_OWNED")
            con.execute("INSERT INTO replay_history "
                "(signed_proof_sha256,idempotency_key,resource,sequence,actor) VALUES(?,?,?,?,?)",
                (claim["signed_proof_sha256"],claim["idempotency_key"],claim["resource"],
                 claim["sequence"],claim["owner"]))
            con.execute("INSERT INTO current_state "
                "(resource,owner,lease_id,expires,sequence,proof,source_head,source_tree)"
                " VALUES(?,?,?,?,?,?,?,?) ON CONFLICT(resource) DO UPDATE SET "
                "owner=excluded.owner,lease_id=excluded.lease_id,expires=excluded.expires,"
                "sequence=excluded.sequence,proof=excluded.proof,"
                "source_head=excluded.source_head,source_tree=excluded.source_tree",
                (claim["resource"],claim["owner"],claim["lease_id"],until,
                 claim["sequence"],claim["signed_proof_sha256"],
                 self._source_head,self._source_tree))
            con.execute("COMMIT")
            row = con.execute("SELECT owner,lease_id,sequence,proof FROM current_state WHERE resource=?",
                              (claim["resource"],)).fetchone()
            if row != (claim["owner"],claim["lease_id"],claim["sequence"],claim["signed_proof_sha256"]):
                return result("UNKNOWN", "POST_COMMIT_READBACK_DRIFT")
            return result("RECORDED_READ_ONLY", "DURABLE_TRANSACTION_AND_READBACK")
        except (sqlite3.Error, OSError, ValueError, TypeError):
            if con:
                try: con.execute("ROLLBACK")
                except sqlite3.Error: pass
            return result("UNKNOWN", "STORAGE_OR_CAS_UNAVAILABLE")
        finally:
            if con:
                try: con.close()
                except sqlite3.Error: pass

    def history_count(self):
        with closing(self._connect()) as con:
            return con.execute("SELECT COUNT(*) FROM replay_history").fetchone()[0]

    def current_sequence(self, resource):
        with closing(self._connect()) as con:
            row = con.execute("SELECT sequence FROM current_state WHERE resource=?", (resource,)).fetchone()
            return row[0] if row else None

    def pragmas(self):
        with closing(self._connect()) as con:
            return {"journal_mode": con.execute("PRAGMA journal_mode").fetchone()[0],
                    "synchronous": con.execute("PRAGMA synchronous").fetchone()[0]}
