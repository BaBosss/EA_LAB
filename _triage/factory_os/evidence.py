# -*- coding: utf-8 -*-
"""evidence.py -- ORDER-670. Which bytes does a checker judge?

THE RULE (TIER_SNAPSHOT_DESIGN.md rev 2, one sentence):
    A BUILDER observes the world. A CHECKER judges the commit.

This module is the CHECKER half plus the builder's entry point:

    src = EvidenceSource.for_run()      one per process: index in hook mode, worktree otherwise
    src.read_committed(rel)             category A -- committed evidence
    src.exists_committed(rel)           category A -- existence is a judged fact too
    src.list_committed(pattern)         category A -- ENUMERATION is a judged read (design 3.2:
                                        glob() picks paths from the DISK; a staged file whose
                                        worktree copy was deleted is invisible to glob and
                                        present in the commit)
    observe(path)                       category B -- the disk, always, in both modes

The category is in the FUNCTION NAME at the call site, not in a comment beside it: a comment
does not choose the bytes, which is the whole finding this module answers (31 declared reads,
28 of judged evidence, zero declaring index -- in a pre-commit tier).

MODE ARRIVAL. The tier (run_fast_cages.ps1 -Hook) sets EA_LAB_EVIDENCE=index for its children;
default is worktree. A value that is NEITHER is refused, not defaulted -- a typo'd mode that
silently became worktree would be the old defect wearing a new hat. Every consumer prints
`marker()` exactly once so the tier can verify arrival per suite (an ALLOWLIST: a missing
marker fails; prose containing the word 'worktree' cannot forge one).

STATED LIMITS, here rather than discovered later (design section 4):
  * `git show :rel` returns repo-normalised text (LF); the worktree on this machine is CRLF.
    Both entry points normalise to LF, so PARSING is mode-independent -- but that means
    index-vintage and disk-vintage HASHES are incommensurable here, and no criterion may
    equate a sha256 computed by observe() with one computed over committed bytes. Under
    core.autocrlf they can never agree for any text file.
  * In hook mode this judges the INDEX git publishes to the hook -- for a partial commit
    (`git commit <paths>`, which is this repo's scheduled committer's only form) that is a
    TEMPORARY index reaching this process via GIT_INDEX_FILE inheritance. marker() records
    which index file was in force; this module never scrubs the environment of children.
  * A wrong CATEGORY call -- observe() where read_committed() belongs -- is judgement no lint
    reads. What changed is that the choice is a grep-able CALL, not a comment nobody reads.

EXCEPTIONS. ToolFailure means "this reader cannot answer", never "the answer is no". Callers
must keep the two apart (exit 2 vs exit 1 in every checker in this tree).
"""
import glob as _glob
import io
import os
import re
import subprocess

MODE_ENV = 'EA_LAB_EVIDENCE'
_MODES = ('index', 'worktree')
_HERE = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(_HERE, '..', '..'))


class ToolFailure(Exception):
    """The reader could not answer. NOT a violation -- different exit code, different fix."""


class ObservationUnstable(ToolFailure):
    """`observe()` saw the file CHANGE between its two fstats. Distinct from "could not read it".

    A subclass rather than a message string, because a caller has to tell them apart and message
    matching is not a contract. `snapshot_build._stat_evidence` is the reason: "there but
    unreadable" is a NAMED, recoverable outcome for it (`read_ok: False`, which the registry join
    turns into MANDATORY_SOURCE_UNREADABLE), while "it moved under me" must refuse the whole build
    because a hash and a timestamp from two different moments is the one error that pipeline
    exists to make impossible.

    Collapsing the two -- which is what a single ToolFailure did -- turned every permission error
    into a REFUSAL that blamed a mid-read mutation: the right severity for one input, the wrong
    diagnosis for the other, and a silent behaviour change for a case the repair never looked at.
    """


def _run_git(root, *args):
    # GIT_INDEX_FILE names an index of ONE repository -- the one whose hook set it. For THIS
    # repo it is exactly the thing to honour (a partial commit's hook publishes its temp index
    # through it, and judging that index is the design). For any OTHER root it is poison:
    # DISCOVERED LIVE 2026-07-31 -- a test fixture running `git -C <temp> add -A` inside this
    # repo's pre-commit hook inherited the variable, git resolved it against the FIXTURE repo,
    # `add -A` saw all 5,135 real entries as deleted-from-worktree and REMOVED them from the
    # REAL COMMIT'S index, leaving a false index containing one fixture file. Had the suite
    # not happened to go red on the wreckage, the commit would have written that tree.
    env = None
    # normcase both sides: Windows paths are case-insensitive, and a caller spelling the real
    # repo as d:/ea_lab must NOT be scrubbed -- that would silently judge .git/index instead
    # of the hook-published temp index, breaking the specificity half of the containment.
    if (os.path.normcase(os.path.abspath(root)) != os.path.normcase(REPO_ROOT)
            and 'GIT_INDEX_FILE' in os.environ):
        env = {k: v for k, v in os.environ.items() if k != 'GIT_INDEX_FILE'}
    p = subprocess.run(['git', '-C', root] + list(args), capture_output=True, env=env)
    return p.returncode, p.stdout, p.stderr


def _decode(raw, errors='strict'):
    try:
        text = raw.decode('utf-8-sig', errors=errors)
    except UnicodeDecodeError as exc:
        raise ToolFailure('undecodable bytes: %s' % exc)
    return text.replace('\r\n', '\n')


class EvidenceSource(object):
    """One source of committed evidence, chosen ONCE per process.

    mode='index'    -> the commit's bytes, via `git show :rel`. NO worktree fallback of any
                       kind: tracked-but-unreadable and untracked are both ToolFailure. The
                       fallback is how a checker approves bytes the commit does not contain
                       (ORDER-615 S1, Spec4 -- paid for twice).
    mode='worktree' -> the disk. Manual-run semantics: a green manual run is a claim about
                       the working tree, and marker() says so.
    """

    def __init__(self, mode, root=None, _git=None):
        if mode not in _MODES:
            raise ToolFailure('evidence mode %r is not one of %s -- refused, not defaulted: a '
                              'typo that silently became worktree would judge the wrong bytes '
                              'with no sign anything happened' % (mode, list(_MODES)))
        self.mode = mode
        self.root = REPO_ROOT if root is None else root
        self._git = _git or (lambda *a: _run_git(self.root, *a))

    @classmethod
    def for_run(cls, root=None):
        return cls(os.environ.get(MODE_ENV, 'worktree'), root=root)

    def marker(self, component):
        """The one tier-verifiable line. Structured so prose cannot forge it by accident."""
        return '##EVIDENCE-MODE## %s %s git_index=%s' % (
            component, self.mode, os.environ.get('GIT_INDEX_FILE', 'default'))

    # -- category A ----------------------------------------------------------------------

    def read_committed(self, rel, errors='strict'):
        rel = rel.replace(os.sep, '/')
        if self.mode == 'index':
            rc, out, err = self._git('show', ':%s' % rel)
            if rc == 0:
                return _decode(out, errors)
            rc2, _o, _e = self._git('ls-files', '--cached', '--error-unmatch', '--', rel)
            if rc2 == 0:
                raise ToolFailure('%s is in the index but not readable from it: %s'
                                  % (rel, err.decode('utf-8', 'replace').strip()))
            on_disk = os.path.isfile(os.path.join(self.root, rel.replace('/', os.sep)))
            raise ToolFailure(
                '%s is not in the index%s. In hook mode this reader judges what the commit '
                'will contain; reading the disk instead would approve bytes the commit does '
                'not have, so there is no fallback.'
                % (rel, ' (it exists in the working tree)' if on_disk else ''))
        path = os.path.join(self.root, rel.replace('/', os.sep))
        if not os.path.isfile(path):
            raise ToolFailure('%s does not exist in the working tree' % rel)
        with io.open(path, 'rb') as fh:  # snapshot: worktree -- manual-run mode, and it says so
            return _decode(fh.read(), errors)

    def read_committed_bytes(self, rel):
        """read_committed's twin, WITHOUT decoding or newline normalisation.

        It exists because three checks in this repo are about BYTES, not text, and every one of
        them hand-rolled its own `git show :path` because the reader offered no byte entry point:
        an append-only PREFIX rule (`A7`/`G5`), a bundle sha256 DIGEST, and a blob-id comparison.
        A missing primitive does not stop the read happening -- it decides where the read gets
        reimplemented, and a second implementation is a second decider of which bytes count.

        NO NORMALISATION HERE, deliberately, and it is the difference between this and its twin.
        `read_committed` decodes utf-8-sig and folds CRLF, which is right for parsing and WRONG
        for a digest: stripping a BOM or rewriting a line ending changes the fingerprint of the
        bytes the caller believes it is fingerprinting. Callers that want folded newlines fold
        them where the reader can see it happening.

        Same no-fallback contract as read_committed, for the same reason paid for twice.
        """
        rel = rel.replace(os.sep, '/')
        if self.mode == 'index':
            rc, out, err = self._git('show', ':%s' % rel)
            if rc == 0:
                return out
            rc2, _o, _e = self._git('ls-files', '--cached', '--error-unmatch', '--', rel)
            if rc2 == 0:
                raise ToolFailure('%s is in the index but not readable from it: %s'
                                  % (rel, err.decode('utf-8', 'replace').strip()))
            on_disk = os.path.isfile(os.path.join(self.root, rel.replace('/', os.sep)))
            raise ToolFailure(
                '%s is not in the index%s. In hook mode this reader judges what the commit '
                'will contain; reading the disk instead would approve bytes the commit does '
                'not have, so there is no fallback.'
                % (rel, ' (it exists in the working tree)' if on_disk else ''))
        path = os.path.join(self.root, rel.replace('/', os.sep))
        if not os.path.isfile(path):
            raise ToolFailure('%s does not exist in the working tree' % rel)
        with io.open(path, 'rb') as fh:  # snapshot: worktree -- manual-run mode, and it says so
            return fh.read()

    def exists_committed(self, rel):
        rel = rel.replace(os.sep, '/')
        if self.mode == 'index':
            rc, _o, _e = self._git('ls-files', '--cached', '--error-unmatch', '--', rel)
            return rc == 0
        return os.path.isfile(os.path.join(self.root, rel.replace('/', os.sep)))

    # -- category P ----------------------------------------------------------------------

    def read_blob(self, sha, why):
        """A PINNED object, by sha. Independent of mode, and that is the whole point.

        Design section 2 named this entry point; ORDER-670 part 1 shipped without it, so `blob`
        stayed a DECLARATION with no call form -- and T7 has to keep allowing `# snapshot: blob`
        on a bare open() for exactly as long as that is true. This closes it.

        `why` is required and unused by the mechanism: a pinned read is a claim that some
        specific historical object is the right yardstick, and a sha with no stated reason is
        the one form of provenance a reader cannot reconstruct. It is echoed in every failure.

        NO FALLBACK, for the reason a pin exists: if the object is not in the store, the answer
        is "I cannot read the yardstick", never "here is today's copy of that path". Substituting
        a live file for a pinned blob is `A2`'s crime -- a pinned vintage joined to a live one
        inside one verdict -- and it is the failure mode a pin is bought to prevent.
        """
        if not isinstance(sha, str) or not re.match(r'^[0-9a-f]{7,40}$', sha):
            raise ToolFailure('read_blob(%r): not an object name. A pin is a sha, and a pin that '
                              'is not one cannot be checked against anything.' % (sha,))
        rc, out, err = self._git('cat-file', 'blob', sha)
        if rc != 0:
            raise ToolFailure(
                'pinned blob %s is not readable from this object store (%s). It is pinned '
                'because %s -- so there is no substitute: reading the current copy of that path '
                'instead would join a live vintage to a pinned one inside one verdict.'
                % (sha, err.decode('utf-8', 'replace').strip(), why))
        return out

    def list_committed(self, pattern):
        """Enumerate committed paths matching a /-separated glob (no `**`; `*` stays inside
        one segment, matching glob.glob's behaviour so the two modes agree on scope).

        This is the entry point that closes design 3.2: `git add rogue.py` + delete the
        worktree copy leaves glob() blind to a file the commit contains -- A7's exact shape
        through the channel nothing had named.
        """
        pattern = pattern.replace(os.sep, '/')
        if self.mode == 'index':
            # :(glob) magic: `*` does NOT cross `/` (verified against this repo: with it,
            # scripts/*.ps1 excludes scripts/_test/*; without it, it does not).
            rc, out, err = self._git('ls-files', '--cached', '--', ':(glob)%s' % pattern)
            if rc != 0:
                raise ToolFailure('ls-files failed for %r: %s'
                                  % (pattern, err.decode('utf-8', 'replace').strip()))
            return sorted(l for l in out.decode('utf-8', 'replace').splitlines() if l)
        hits = _glob.glob(os.path.join(self.root, pattern.replace('/', os.sep)))
        rels = []
        for h in hits:
            if os.path.isfile(h):
                rels.append(os.path.relpath(h, self.root).replace(os.sep, '/'))
        return sorted(rels)


# -- category B ---------------------------------------------------------------------------

def observe(path):
    """-> (bytes, stat) for a file on THIS machine, now. The disk, in every mode.

    An index blob has no mtime that means anything, and several observed sources are written
    by MT5 and are not the commit's business at all -- reading category B from the index is
    exactly as wrong as reading category A from the worktree.

    One handle; fstat BEFORE and AFTER the read, refusing if the file changed in between
    (snapshot_build round-4 S3: one handle stops the PATH being swapped, not the opened file
    being rewritten -- it cannot be prevented, so it is detected).
    """
    try:
        with io.open(path, 'rb') as fh:  # snapshot: worktree -- category B: observed world
            before = os.fstat(fh.fileno())
            data = fh.read()
            after = os.fstat(fh.fileno())
    except OSError as exc:
        raise ToolFailure('cannot observe %s: %s' % (path, exc))
    if (before.st_mtime_ns, before.st_size) != (after.st_mtime_ns, after.st_size):
        raise ObservationUnstable(
            '%s changed while being observed (mtime/size moved between the two '
            'fstats) -- bytes and timestamp cannot be pinned to one moment, so '
            'this observation is refused rather than published with a guess.' % path)
    return data, after
