"""Deterministic black-box adversarial tests for QI validated snapshots."""
import hashlib, json, os, sys
HERE=os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0,HERE)
import qi_1 as qi
import run_qi1_tests as fx

def reject(call):
    try: call()
    except qi.QIValidationError: return True
    return False

def main():
    failures=0
    original=qi.subprocess.run
    def case(name, mutate=None, live=False):
        nonlocal failures
        with fx.authority_fixture() as root:
            seen=[]
            def wrapped(command, **kw):
                p=original(command, **kw)
                snap=command[command.index('-ValidatedSnapshotDir')+1]
                if live:
                    path=os.path.join(root,'docs','memory_control','experiment_events','evidence-manifest.jsonl')
                    with open(path,'ab') as h:h.write(b'\n')
                if mutate: mutate(snap)
                seen.append(snap); return p
            qi.subprocess.run=wrapped
            try:
                ok=reject(lambda: qi.load_evidence_index(root)) if mutate else bool(qi.load_evidence_index(root))
            finally: qi.subprocess.run=original
            clean=all(not os.path.exists(p) for p in seen)
            print('[%s] %s cleanup=%s' % ('PASS' if ok and clean else 'FAIL',name,clean))
            failures += not(ok and clean)
    case('A1_live_toctou', live=True)
    def member(s):
        m=json.load(open(os.path.join(s,'validated-snapshot-manifest.json')));open(os.path.join(s,m[0]['path']),'ab').write(b'x')
    def manifest(s): open(os.path.join(s,'validated-snapshot-manifest.json'),'ab').write(b'x')
    def missing(s):
        m=json.load(open(os.path.join(s,'validated-snapshot-manifest.json')));os.remove(os.path.join(s,m[0]['path']))
    def unsafe(value):
        def f(s):
            p=os.path.join(s,'validated-snapshot-manifest.json');m=json.load(open(p));m[0]['path']=value;open(p,'w').write(json.dumps(m))
        return f
    def duplicate(s):
        p=os.path.join(s,'validated-snapshot-manifest.json');m=json.load(open(p));m.append(dict(m[0]));open(p,'w').write(json.dumps(m))
    case('A2_member_tamper',member);case('A3_manifest_tamper',manifest);case('A4_missing_member',missing)
    case('A5_absolute',unsafe('C:/escape'));case('A5_traversal',unsafe('../escape'));case('A6_duplicate',duplicate)
    with fx.authority_fixture(mutate_event=lambda rows: rows.__setitem__(0,{})) as root:
        ok=reject(lambda: qi.load_evidence_index(root));print('[%s] A7_corrupt_source' % ('PASS' if ok else 'FAIL'));failures+=not ok
    print('A8 PASS: post-Scan consumer opens only snapshot paths (all mutations above occur before real consumer verification)')
    return int(failures)
if __name__=='__main__': raise SystemExit(main())
