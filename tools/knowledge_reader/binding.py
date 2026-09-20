"""Local provenance verification; a hash field supplied by an index is not authority."""
from __future__ import annotations
import hashlib,json
from typing import Any
AUTHORITY='READ_ONLY_RESEARCH_NAVIGATION_NO_RUNTIME_OR_STRATEGY_AUTHORITY'
_TOKEN=object()
def stable_json(value: Any) -> str:
    return json.dumps(value,ensure_ascii=False,sort_keys=True,separators=(',',':'),allow_nan=False)
def digest(value: Any) -> str:
    return hashlib.sha256(stable_json(value).encode('utf8')).hexdigest()
class VerifiedIndex(dict):
    def __init__(self,value: dict,token: object):
        if token is not _TOKEN: raise ValueError('Use exact-source reconstruction, not a supplied verification flag')
        super().__init__(value);self._verified_digest=digest(value)
def seal_built_index(value: dict) -> VerifiedIndex:
    """Internal build boundary. Caller has just read exact Git + expected manifest bytes."""
    return VerifiedIndex(value,_TOKEN)
def require_verified(value: dict) -> None:
    if not isinstance(value,VerifiedIndex) or value._verified_digest!=digest(value):
        raise ValueError('Unverified or mutated index: reconstruct against exact Git and explicit prepared manifest')
def public_binding(value: VerifiedIndex) -> dict:
    require_verified(value)
    return {'schema_version':'ea-lab-knowledge-binding/1','canonical_sha':value['canonical']['sha'],'data_sha256':digest(value),'trust_basis':'GENERATED_WITH_VERIFIED_SOURCE_ASSETS_NOT_A_REMOTE_ATTESTATION'}
