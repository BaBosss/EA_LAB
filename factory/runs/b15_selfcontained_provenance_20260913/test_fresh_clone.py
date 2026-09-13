"""Control Tower POST-COMMIT gate. No execution during worker handoff.

python -B test_fresh_clone.py <full-candidate-HEAD-SHA>

Creates a bundle of candidate HEAD only, then a non-shared clone. Requires the
historical rejected object to be absent, and runs validator plus negative tests.
Temporary bundle/clone are bounded new fixtures inside the invoking package.
Git and Python are the only child programs. Does not stage, commit, push or MT5.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
PACKAGE = 'factory/runs/b15_selfcontained_provenance_20260913'
REJECTED = 'a0a3b5b13cb5b1f4b9585954b91ee89ac17f5dc2'


def run(args, cwd=ROOT, expected=0):
    result = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if result.returncode != expected:
        raise ValueError('command failed: ' + repr(args) + '\n' + result.stdout + result.stderr)
    return result.stdout.strip()


def main():
    if len(sys.argv) != 2 or len(sys.argv[1]) != 40:
        raise ValueError('provide exact committed candidate HEAD SHA')
    candidate = sys.argv[1]
    if run(['git', 'rev-parse', 'HEAD']) != candidate:
        raise ValueError('candidate must equal this checkout HEAD')
    if run(['git', 'status', '--porcelain', '--untracked-files=all', '--', PACKAGE]):
        raise ValueError('candidate package must be committed and clean')
    tracked = run(['git', 'ls-tree', '-r', '--name-only', candidate, '--', PACKAGE]).splitlines()
    if PACKAGE + '/validate.py' not in tracked or PACKAGE + '/test_package.py' not in tracked:
        raise ValueError('candidate has no committed package')
    with tempfile.TemporaryDirectory(prefix='.b15-fresh-', dir=OUT) as tmp:
        base = Path(tmp); bundle = base / 'candidate.bundle'; clone = base / 'clone'
        run(['git', 'bundle', 'create', str(bundle), 'HEAD'])
        if run(['git', 'bundle', 'list-heads', str(bundle)]) != candidate + ' HEAD':
            raise ValueError('bundle must expose only candidate HEAD')
        run(['git', '-c', 'core.autocrlf=false', 'clone', '--no-local', '--no-checkout', str(bundle), str(clone)])
        run(['git', 'checkout', '--detach', candidate], clone)
        if (clone / '.git/objects/info/alternates').exists():
            raise ValueError('shared object database forbidden')
        probe = subprocess.run(['git', 'cat-file', '-e', REJECTED], cwd=clone, capture_output=True)
        if probe.returncode == 0:
            raise ValueError('rejected historical object is present')
        package = clone / PACKAGE
        validation = json.loads(run([sys.executable, '-B', str(package / 'validate.py'), '--audit'], clone))
        tests = json.loads(run([sys.executable, '-B', str(package / 'test_package.py')], clone))
        if validation['status'] != 'PASS' or tests['status'] != 'PASS':
            raise ValueError('clone checks did not PASS')
        if run(['git', 'status', '--porcelain', '--untracked-files=all'], clone):
            raise ValueError('fresh clone altered by validation')
        print(json.dumps(dict(status='PASS', candidate=candidate, bundle_refs=['HEAD'],
                              shared_objects=False, rejected_object='ABSENT',
                              validation=validation, negative_tests=tests), indent=2, sort_keys=True))


if __name__ == '__main__':
    main()
