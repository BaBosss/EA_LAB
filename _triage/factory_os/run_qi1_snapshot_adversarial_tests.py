"""Deterministic black-box adversarial tests for QI validated snapshots."""
import builtins, hashlib, json, os, sys
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
    with fx.authority_fixture() as root:
        phase=['before']; snapshot=[]; trace=[]; run=qi.subprocess.run; real_open=builtins.open
        authority=os.path.abspath(os.path.join(root,'docs','memory_control','experiment_events'))
        def classify(path):
            path=os.path.abspath(os.fspath(path))
            if path.startswith(authority+os.sep): return 'LIVE_EVIDENCE_MANIFEST' if path.endswith('evidence-manifest.jsonl') else 'LIVE_EVENT'
            if snapshot and path.startswith(snapshot[0]+os.sep): return 'SNAPSHOT_EVIDENCE_MANIFEST' if path.endswith('evidence-manifest.jsonl') else 'SNAPSHOT_EVENT'
            return 'OTHER'
        def traced(path,*args,**kwargs):
            if phase[0]=='after': trace.append((classify(path),os.path.abspath(os.fspath(path))))
            return real_open(path,*args,**kwargs)
        def scanned(command,**kwargs):
            result=run(command,**kwargs); snapshot[:] = [command[command.index('-ValidatedSnapshotDir')+1]]; phase[0]='after'; return result
        qi.subprocess.run=scanned; builtins.open=traced
        try:
            phase[0]='after'
            with builtins.open(os.path.join(authority,'evidence-manifest.jsonl'),'rb') as h: h.read(1)
            sanity=any(kind.startswith('LIVE_') for kind,_ in trace); trace[:]=[]
            phase[0]='before'
            ok=bool(qi.load_evidence_index(root)); clean=not os.path.exists(snapshot[0])
        finally:
            qi.subprocess.run=run; builtins.open=real_open
        snap_reads=[p for k,p in trace if k.startswith('SNAPSHOT_')]; live_reads=[p for k,p in trace if k.startswith('LIVE_')]
        pass_a8=sanity and ok and snap_reads and not live_reads and clean
        print('[%s] A8 tracer_sanity_live_detected=%s post_scan_snapshot_reads=%d post_scan_live_reads=%d cleanup=%s' % ('PASS' if pass_a8 else 'FAIL',sanity,len(snap_reads),len(live_reads),clean))
        failures += not pass_a8
    return int(failures)
if __name__=='__main__': raise SystemExit(main())
