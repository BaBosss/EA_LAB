"""Pinned DF03 byte-preserving compatibility generator; never executes MQL."""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
from functools import lru_cache
import json
from pathlib import Path
import re

PARENT_SHA256 = "2aba9437319e214c82b63313a049f73da364052eddfa24f7f1661279593ffd89"
ROOT = Path(__file__).resolve().parents[2]
DEST = ROOT / "ea_template/compat/df03"
PARENT = DEST / "parent.mq5"
VARIABLES = {n: "DF03_Compat" + n for n in ("Bars", "Digits", "Point")}
EVENTS = {n: "DF03_Source" + n for n in
          ("OnInit", "OnTick", "OnTrade", "OnTimer", "OnChartEvent", "OnDeinit", "__OnTick__")}
# A byte lexer, not text replacement. Literals/comments consume their entire spans.
LEX = re.compile(rb'(?P<comment>//[^\r\n]*|/\*.*?\*/)|'
                 rb'(?P<string>"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')|'
                 rb'(?P<space>\s+)|(?P<id>[A-Za-z_][A-Za-z_0-9]*)|'
                 rb'(?P<number>[0-9]+(?:\.[0-9]+)?)|(?P<punct>::|==|!=|<=|>=|.)', re.S)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def tokens(data: bytes):
    return [(m.group(), m.start(), m.end(), m.lastgroup) for m in LEX.finditer(data)
            if m.lastgroup not in ("comment", "space")]


def code(data: bytes) -> str:
    """Whitespace-normalized token stream, retaining literal values."""
    return " ".join(t[0].decode("utf-8") for t in tokens(data))


def transform(data: bytes, lifecycle: bool = True):
    """Internal lexical primitive. Public build always pins the input first."""
    ts = tokens(data)
    names = VARIABLES | (EVENTS if lifecycle else {})
    records = []
    chunks = []
    cursor = 0
    delta = 0
    for i, (raw, start, end, kind) in enumerate(ts):
        if kind != "id" or raw.decode() not in names:
            continue
        name = raw.decode()
        if name in VARIABLES and i + 1 < len(ts) and ts[i + 1][0] == b"(":
            continue  # Built-in Bars(...) (also ::Bars(...)) is never a variable.
        replacement = names[name].encode()
        records.append({"parent_offset": start, "generated_offset": start + delta,
                        "line": data.count(b"\n", 0, start) + 1,
                        "old": name, "new": replacement.decode()})
        chunks.extend((data[cursor:start], replacement))
        cursor = end
        delta += len(replacement) - len(raw)
    chunks.append(data[cursor:])
    return b"".join(chunks), records


def inverse(data: bytes, records: list[dict]) -> bytes:
    chunks = []
    cursor = 0
    for record in records:
        start = record["generated_offset"]
        new = record["new"].encode()
        require(start >= cursor and data[start:start + len(new)] == new,
                "changed token/offset drift")
        chunks.extend((data[cursor:start], record["old"].encode()))
        cursor = start + len(new)
    chunks.append(data[cursor:])
    return b"".join(chunks)


def braced(text: str, opening: int) -> str:
    # Called on the token stream; braces inside literals are skipped by lexing.
    ts = tokens(text[opening:].encode())
    depth = 0
    for raw, _, end, kind in ts:
        if kind == "punct" and raw == b"{":
            depth += 1
        elif kind == "punct" and raw == b"}":
            depth -= 1
            if depth == 0:
                return text[opening:opening + end]
    raise ValueError("unbalanced source body")


@lru_cache(maxsize=2)
def causal_manifest(data: bytes) -> dict:
    text = code(data)
    blocks = []
    for m in re.finditer(r"\bclass (Block(\d+)) : public ([^{]+)\{", text):
        body = braced(text, m.end() - 1)
        number = int(m[2])
        require(re.search(rf"__block_number = {number} ;", body) is not None,
                "block identity mismatch")
        user = re.search(r'__block_user_number = "([^"]+)" ;', body)
        out = re.search(r"int ___outbound_blocks \[ (\d+) \] = \{ ([^}]+) \}", body)
        outs = [int(n) for n in re.findall(r"\d+", out[2])] if out else []
        require(not out or int(out[1]) == len(outs), "outbound count mismatch")
        cb = re.search(r"void _callback_ \( int value \) \{", body)
        require(cb is not None and user is not None, "missing callback/identity")
        callback = braced(body, cb.end() - 1)
        edges = [{"target": int(e[1]), "caller": int(e[2])} for e in
                 re.finditer(r"_blocks_ \[ (\d+) \] \. run \( (\d+) \)", callback)]
        require(all(e["caller"] == number for e in edges), "callback caller mismatch")
        require(set(outs) == {e["target"] for e in edges}, "callback/outbound mismatch")
        blocks.append({"id": number, "user_id": user[1], "type": m[3].strip(),
                       "outbound_array": outs, "ordered_callback_edges": edges,
                       "callback_tokens": callback, "body_token_sha256": sha(body.encode())})
    require([b["id"] for b in blocks] == list(range(126)), "expected all 126 blocks")
    roots = {}
    lifecycle = {}
    for name in EVENTS:
        m = re.search(rf"\bvoid {name} \([^{{]*\{{", text)
        require(m is not None, "missing lifecycle " + name)
        body = braced(text, m.end() - 1)
        lifecycle[name] = {"signature": m[0][:-1].strip(),
                           "body_token_sha256": sha(body.encode()),
                           "ordered_native_calls": re.findall(
                               r"\b(" + "|".join(EVENTS) + r") \(", body)}
        for r in re.finditer(r"blocks_to_run \[ \] = \{ ([^}]+) \}", body):
            require(name not in roots, "duplicate event roots")
            roots[name] = [int(n) for n in re.findall(r"\d+", r[1])]
    require(roots == {"OnInit": [8], "__OnTick__": [14,16,24,26,34,36,44,46,71,76,83,84,88,90,92],
                      "OnTrade": [11,12]}, "event root drift")
    inputs = re.findall(r"\binput [^;]+ ;", text)
    require(len(inputs) == 14, "input count drift")
    gates = []
    numeric = re.search(r"class MDLIC_value_value \{", text)
    require(numeric is not None, "missing numeric operand type")
    numeric_body = braced(text, numeric.end() - 1)
    require("Value = ( double ) 1.0 ;" in numeric_body, "inherited hedge operand drift")
    for block in blocks:
        m = re.search(rf"\bclass Block{block['id']} : public [^{{]+\{{", text)
        body = braced(text, m.end() - 1)
        if "Lo . Value = c :: Hedging_mode_1_on_0_off ;" in body:
            require('compare = "==" ;' in body and 'Ro . Value =' not in body
                    and block['type'] == 'MDL_Condition < MDLIC_value_value , double , string , MDLIC_value_value , double , int >',
                    "hedge equality gate drift")
            gates.append(block["id"])
    require(len(gates) == 10, "hedge gate count drift")
    closures = {}
    for event, seeds in roots.items():
        seen = set()
        def visit(n):
            if n in seen:
                return
            require(0 <= n < len(blocks), "invalid root/edge target")
            seen.add(n)
            for e in blocks[n]["ordered_callback_edges"]:
                visit(e["target"])
        for seed in seeds:
            visit(seed)
        closures[event] = sorted(seen)
    return {"inputs": inputs, "blocks": blocks, "event_roots": roots,
            "root_closures": closures, "lifecycle": lifecycle, "hedge_gate_blocks": gates,
            "hedge_rhs": "MDLIC_value_value constructor: Value = (double)1.0; no block override",
            "period_d1_tokens": sum(t[0] == b"PERIOD_D1" for t in tokens(data)),
            "current_timeframe_calls": text.count("CurrentTimeframe ("),
            "swapped_stop_assignments": text.count("StopLossPips = ( double ) c :: TP_pip ;"),
            "swapped_target_assignments": text.count("TakeProfitPips = ( double ) c :: SL_pip ;"),
            "enum_to_candle_find_assignments": text.count("ObjPrice1 . ModeCandleFindBy = c :: Timeframe ;")}


def verify(parent: bytes, generated: bytes, records: list[dict], lifecycle=True) -> dict:
    require(sha(parent) == PARENT_SHA256, "immutable parent SHA256 mismatch")
    expected, expected_records = transform(parent, lifecycle)
    require(records == expected_records, "token map drift")
    restored = inverse(generated, records)
    # Byte equality is the authoritative preservation gate: every input, state,
    # chart/order parameter, callback and even comments/newlines must survive.
    require(restored == parent, "inverse parent-byte reconstruction mismatch")
    require(generated == expected, "generated dependency drift")
    source_manifest = causal_manifest(parent)
    require(causal_manifest(restored) == source_manifest, "causal manifest drift")
    return source_manifest


def build(parent: bytes):
    require(sha(parent) == PARENT_SHA256, "immutable parent SHA256 mismatch; no output")
    generated, changes = transform(parent)
    graph = verify(parent, generated, changes)
    return generated, {"schema": "df03-compat/1", "parent_sha256": sha(parent),
                       "parent_bytes": len(parent), "generated_sha256": sha(generated),
                       "generator_sha256": sha(Path(__file__).read_bytes()),
                       "transform_counts": dict(sorted(Counter(c["old"] for c in changes).items())),
                       "changes": changes, "causal": graph}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--parent", type=Path, default=PARENT)
    parser.add_argument("--out", type=Path, default=DEST)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    generated, manifest = build(args.parent.read_bytes())  # validate before any mkdir/write
    outputs = {"DF03_Generated.mqh": generated,
               "manifest.json": (json.dumps(manifest, indent=2, ensure_ascii=False) + "\n").encode()}
    if args.check:
        for name, content in outputs.items():
            require((args.out / name).read_bytes() == content, "output drift: " + name)
    else:
        args.out.mkdir(parents=True, exist_ok=True)
        for name, content in outputs.items():
            (args.out / name).write_bytes(content)
    print(json.dumps({k: v for k, v in manifest.items() if k not in ("changes", "causal")}))


if __name__ == "__main__":
    main()
