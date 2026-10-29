"""Offline-only stage/agent manifest comparisons; no terminal/runtime access.

These checks classify differences in already captured receipts. File names and
SHA digests are not authentication of data producers, native test execution,
agent consumption, or Owner T3 approval.
"""
from collections.abc import Mapping
import re

HASH = re.compile(r"[0-9a-f]{64}\Z")


def _sha(s):
    return isinstance(s, str) and bool(HASH.fullmatch(s)) and s != '0' * 64


def _rows(obj):
    """Normalize a path-keyed inventory. Duplicate paths must be caught at ingestion."""
    if not isinstance(obj, dict) or not obj:
        return None
    for path, row in obj.items():
        if not isinstance(path, str) or not path or '\\' in path or path.startswith('/') or '..' in path.split('/') or ':' in path or '\x00' in path:
            return None
        if not isinstance(row, dict) or not _sha(row.get('sha256')) or type(row.get('bytes')) is not int or row['bytes'] < 0:
            return None
    return obj


def compare_stage_data(checkpoints, expected_count=106):
    """Classify phase of every protected data-file delta, fail closed.

    Ordered keys S0/S1/S2/S3 must carry raw captured inventories. No changed
    protected broker metadata is white-listed based on extension/time alone.
    """
    names=('S0','S1','S2','S3')
    if not isinstance(checkpoints, dict) or set(checkpoints)!=set(names):
        return {'classification':'BLOCKED', 'reasons':['S0_S1_S2_S3_MISSING'], 'deltas':{}}
    arrays=[]
    reasons=[]
    for name in names:
        data=_rows(checkpoints[name])
        if data is None:
            return {'classification':'BLOCKED','reasons':['INVALID_STAGE_FILE_INVENTORY:'+name], 'deltas':{}, 'native_acceptance':False}
        if len(data) != expected_count:
            reasons.append('STAGE_FILE_COUNT_MISMATCH:'+name)
        arrays.append(data)
    out={}
    for index, phase in enumerate(('PREPROBE','TESTER','POSTPROBE')):
        a,b=arrays[index:index+2]
        changes=[]
        for path in sorted(set(a)|set(b)):
            if a.get(path) != b.get(path):
                changes.append({'path':path,'before':a.get(path),'after':b.get(path)})
                reasons.append('UNCLASSIFIED_'+phase+'_DATA_CHANGE:'+path)
        out[phase]=changes
    return {'classification':'BLOCKED' if reasons else 'STRUCTURAL_IDENTICAL_NO_NATIVE_ACCEPTANCE',
            'reasons': reasons, 'deltas':out, 'native_acceptance':False}


def compare_agent_cache(pre, post, policy):
    """Compare agent cache transition to one immutable preregistered policy.

    EMPTY: newly created file names are exactly predeclared, no deletion/update.
    PINNED_NONEMPTY: every SHA and size must remain identical, no creation.
    Both are STRUCTURAL comparisons only; source->agent/consumed bars proof is
    a separate necessary requirement.
    """
    if not isinstance(pre, dict) or not isinstance(post, dict) or not isinstance(policy, dict):
        return {'classification':'BLOCKED','reasons':['INVALID_AGENT_INPUT'], 'native_acceptance':False}
    if any(_rows({'x':v}) is None for v in [*pre.values(),*post.values()]):
        return {'classification':'BLOCKED','reasons':['INVALID_AGENT_HASH_OR_BYTES'], 'native_acceptance':False}
    if any(not isinstance(k,str) or k.startswith('/') or '..' in k.split('/') or '\\' in k or ':' in k or '\x00' in k for k in set(pre)|set(post)):
        return {'classification':'BLOCKED','reasons':['INVALID_AGENT_PATH'], 'native_acceptance':False}
    mode=policy.get('mode')
    if mode not in ('EMPTY','PINNED_NONEMPTY'):
        return {'classification':'BLOCKED','reasons':['AGENT_MODE_UNDECLARED'], 'native_acceptance':False}
    if not _sha(policy.get('preregistered_contract_sha256')):
        return {'classification':'BLOCKED','reasons':['AGENT_POLICY_NOT_PREREG_HASH_BOUND'], 'native_acceptance':False}
    reasons=[]
    if mode=='EMPTY':
        if pre:
            reasons.append('AGENT_BASELINE_EXPECTED_EMPTY')
        expected=policy.get('expected_created')
        if (not isinstance(expected,list) or any(not isinstance(x,str) or not x or x.startswith('/') or '\\' in x or ':' in x or '..' in x.split('/') for x in expected)
                or len(expected)!=len(set(expected))):
            reasons.append('AGENT_CREATE_ALLOWLIST_INVALID')
        elif set(post)!=set(expected):
            reasons.append('AGENT_CREATED_SET_MISMATCH')
    else:
        if not pre:
            reasons.append('AGENT_PINNED_NONEMPTY_EXPECTED')
        if pre!=post:
            reasons.append('AGENT_PINNED_CACHE_CHANGED')
        if policy.get('expected_created',[])!=[]:
            reasons.append('AGENT_CREATE_NOT_ALLOWED_IN_PINNED')
    return {'classification':'BLOCKED' if reasons else 'AGENT_STRUCTURAL_MATCH_NOT_CONSUMPTION_PROOF',
            'reasons': sorted(set(reasons)), 'native_acceptance':False}
