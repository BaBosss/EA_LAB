#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fxdreema_xray.py — ORDER-074: deterministic X-ray of fxDreema-exported EAs.

fxDreema generates thousands of lines of boilerplate around a small strategy core.
This parser extracts a ~40-line summary card per EA so Claude never reads raw files.

Anatomy of an fxDreema export (learned from ground truth (ST) EA03 Count MACD v1):
  - "// Block N (Label)" comment markers carry human-readable block labels
  - "class BlockNN : public MDL_<Type><...>" = strategy blocks; constructor bodies
    hold the per-block config overrides (StopLossMode = "none"; etc.)
  - template-library defaults carry a "(string)"/"(double)" cast; block overrides don't
  - generated "class MDL_Formula_N" / ModifyVariables classes embed the target user
    variable:  v::<var> = formula(compare, lo, ro);
  - "class MDLIC_indicators_iXXX" wrappers are generated ONLY for indicators actually
    wired into the strategy (authoritative indicator list)

Usage:
  tools\\python312\\python.exe scripts\\fxdreema_xray.py
        [--roots D:\\ "D:\\OneDrive...\\Desktop\\Metatrader"]
        [--md _triage\\FXDREEMA_XRAY.md] [--csv _triage\\FXDREEMA_XRAY.csv]
"""
import argparse
import csv
import hashlib
import io
import os
import re
import sys

# ----------------------------------------------------------------------------- discovery

DEFAULT_ROOTS = [
    "D:\\",
    "D:\\OneDrive - The Siam Cement Public Company Limited\\Desktop\\Metatrader",
]

# top-level (or anywhere) directory names to skip when walking a root
SKIP_DIR_NAMES = {
    "node_modules", ".git", ".claude", "__pycache__", "$recycle.bin",
    "system volume information", ".venv", "venv",
}
# D:\ top-level dirs to skip (terminal installs / cloud-sync mirrors handled separately)
SKIP_TOP_LEVEL = {
    "meta 5", "meta 5b", "meta 5c", "meta4", "meta4b",
    "metatraderdata",
    "onedrive - the siam cement public company limited",   # only Desktop\Metatrader subtree is scanned (explicit root)
    "the siam cement public company limited",               # second cloud-sync mirror; grep-verified no hits
}

SIGNATURE = "fxdreema"


def read_text(path):
    """Read MQL source tolerating UTF-8 / UTF-16 / legacy codepages."""
    with open(path, "rb") as fh:
        raw = fh.read()
    if raw[:2] in (b"\xff\xfe", b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    if raw[:3] == b"\xef\xbb\xbf":
        return raw[3:].decode("utf-8", errors="replace")
    # ORDER-091A fix: BOM-less UTF-16 (MetaEditor sometimes saves without BOM).
    # Detected by NUL-byte density -- ASCII-range UTF-16 text is ~50% NULs, while
    # no legit UTF-8/legacy-codepage source contains NULs at all. Without this,
    # such files decode as NUL-interleaved garbage: every regex (signature,
    # inputs, blocks) silently matches nothing (this is why 539 Wave-0 files
    # produced empty cards on the first ORDER-091A pass, and why the ORDER-074
    # drive-wide scan never saw them).
    sample = raw[:4096]
    if sample and sample.count(b"\x00") > len(sample) // 3:
        enc = "utf-16-le" if raw[1:2] == b"\x00" else "utf-16-be"
        return raw.decode(enc, errors="replace")
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp874", errors="replace")  # Thai legacy fallback


def discover(roots):
    """Yield absolute paths of .mq4/.mq5 files containing the fxDreema signature."""
    seen = set()
    for root in roots:
        root = os.path.abspath(root)
        is_drive_root = os.path.splitdrive(root)[1] in ("\\", "/")
        for dirpath, dirnames, filenames in os.walk(root, onerror=lambda e: None):
            low = [d.lower() for d in dirnames]
            keep = []
            for d, dl in zip(dirnames, low):
                if dl in SKIP_DIR_NAMES:
                    continue
                if is_drive_root and os.path.normpath(dirpath) == os.path.normpath(root) \
                        and dl in SKIP_TOP_LEVEL:
                    continue
                keep.append(d)
            dirnames[:] = keep
            for fn in filenames:
                if not fn.lower().endswith((".mq4", ".mq5")):
                    continue
                full = os.path.normpath(os.path.join(dirpath, fn))
                key = full.lower()
                if key in seen:
                    continue
                seen.add(key)
                try:
                    text = read_text(full)
                except OSError:
                    continue
                if SIGNATURE in text.lower():
                    yield full, text


# ----------------------------------------------------------------------------- parsing

RE_INPUT = re.compile(
    r"^\s*(?:input|extern|sinput)\s+"
    r"(?!group\b)([A-Za-z_][\w:]*)\s+"          # type
    r"([A-Za-z_]\w*)\s*=\s*([^;\n]+?)\s*;"       # name = default
    r"\s*(?://+\s*(.*))?$",                       # optional trailing comment
    re.MULTILINE,
)
RE_BLOCK_MARKER = re.compile(r"^//\s*Block\s+(\d+)\s*\(([^)]*)\)", re.MULTILINE)
RE_BLOCK_CLASS = re.compile(
    r"^class\s+(Block\d+)\s*:\s*public\s+(MDL_\w+)\s*(?:<([^\n{]*)>)?", re.MULTILINE)
RE_MDL_CLASS = re.compile(r"^(?:template<[^\n]*>\s*\n)?class\s+(MDL_\w+)\b", re.MULTILINE)
RE_FORMULA_TARGET = re.compile(r"v::(\w+)\s*=\s*formula\(")
RE_ASSIGN = re.compile(r"^\s*([A-Za-z_][\w.]*)\s*=\s*([^;\n]+?)\s*;", re.MULTILINE)
RE_IND_CLASS = re.compile(r"class\s+MDLIC_indicators_i(\w+)\b")
RE_IND_RAW = re.compile(
    r"\bi(RSI|MACD|ATR|MAOnArray|MA|BandsOnArray|Bands|Stochastic|CCI|ADX|SAR|Ichimoku|"
    r"Momentum|WPR|DeMarker|RVI|Force|AO|AC|Alligator|Fractals|StdDev|Envelopes|OBV|MFI|"
    r"Volumes|BullsPower|BearsPower|OsMA|Custom|Highest|Lowest|BWMFI|Gator|AMA|DEMA|TEMA|"
    r"FrAMA|TriX|VIDyA|Chaikin)\s*\(")

# block base classes that OPEN trades
OPEN_MARKET = {"MDL_BuyNow", "MDL_SellNow", "MDL_OpenOrder", "MDL_BuyOrSell"}
OPEN_PENDING_PAT = re.compile(r"MDL_(Buy|Sell)(Stop|Limit)|MDL_.*Pending", re.I)
CLOSE_BASES_PAT = re.compile(r"MDL_Close|MDL_DeletePending", re.I)
MODIFY_BASES_PAT = re.compile(r"MDL_Modify(Stops|Order)|MDL_Trailing", re.I)

BETTING_MODES = {"martingale", "fibonacci", "1326", "dalembert", "labouchere", "sequence"}
LOTVAR_PAT = re.compile(r"lot|volume", re.I)
ATTR_MAP = {"0": "count", "1": "profit", "2": "openLots", "3": "initialLots",
            "4": "SL", "5": "TP"}
RETMODE_MAP = {"0": "sum", "1": "avg", "2": "max", "3": "min"}

INTERESTING_KEYS = (
    "StopLossMode", "StopLossPips", "TakeProfitMode", "TakeProfitPips",
    "VolumeMode", "VolumeSize", "VolumePercent", "VolumeRisk", "compare",
    "BuysOrSells", "LoopLimit", "TrailingStopMode", "TrailingStopPips",
)


def html_unescape(s):
    for a, b in (("&lt;", "<"), ("&gt;", ">"), ("&amp;", "&"), ("&quot;", '"'), ("&#39;", "'")):
        s = s.replace(a, b)
    return s


def class_body(text, start):
    """Return substring from class declaration to its terminating newline+'};'."""
    end = text.find("\n};", start)
    if end < 0:
        end = min(len(text), start + 20000)
    return text[start:end]


def strip_cast(v):
    return re.sub(r"^\((?:string|double|int|bool|color|datetime|uint|long|ulong)\)\s*", "", v).strip()


def parse_ea(text):
    """Extract everything needed for one summary card. Returns dict."""
    d = {}
    d["lines"] = text.count("\n") + 1

    # --- inputs -------------------------------------------------------------
    inputs = []
    for m in RE_INPUT.finditer(text):
        typ, name, default, comment = m.group(1), m.group(2), m.group(3).strip(), (m.group(4) or "").strip()
        inputs.append((typ, name, default, comment))
    d["inputs"] = inputs

    # --- block markers (labels) ----------------------------------------------
    labels = {}          # user_number -> label
    census = {}          # label -> count
    for m in RE_BLOCK_MARKER.finditer(text):
        lab = html_unescape(m.group(2)).strip()
        labels[m.group(1)] = lab
        census[lab] = census.get(lab, 0) + 1
    d["labels"] = labels
    d["census"] = census
    d["n_blocks"] = sum(census.values())

    # --- generated MDL classes: formula-target map + compare defaults ---------
    formula_targets = {}   # MDL class name -> [user vars assigned via formula()]
    compare_defaults = {}  # MDL class name -> default compare op
    for m in RE_MDL_CLASS.finditer(text):
        cname = m.group(1)
        body = class_body(text, m.start())
        tgts = RE_FORMULA_TARGET.findall(body)
        if tgts:
            formula_targets[cname] = list(dict.fromkeys(tgts))
            cm = re.search(r'compare\s*=\s*\(string\)"([^"]*)"', body)
            if cm:
                compare_defaults[cname] = cm.group(1)

    # --- Block classes ---------------------------------------------------------
    blocks = []
    for m in RE_BLOCK_CLASS.finditer(text):
        cls, base, targs = m.group(1), m.group(2), (m.group(3) or "")
        body = class_body(text, m.start())
        assigns = {}
        for am in RE_ASSIGN.finditer(body):
            k, v = am.group(1), strip_cast(am.group(2))
            if k.startswith(("__", "int ___", "_")) or k in ("exist",):
                continue
            assigns.setdefault(k, v)   # first assignment wins (constructor before overrides)
        un = re.search(r'__block_user_number\s*=\s*"(\d+)"', body)
        user_no = un.group(1) if un else "?"
        blocks.append({
            "cls": cls, "base": base, "targs": targs, "user_no": user_no,
            "label": labels.get(user_no, ""), "assigns": assigns,
        })
    d["blocks"] = blocks

    # --- trade-open / close / pending accounting -------------------------------
    open_blocks, close_blocks, modify_blocks = [], [], []
    for b in blocks:
        if b["base"] in OPEN_MARKET or OPEN_PENDING_PAT.match(b["base"]):
            b["pending"] = bool(OPEN_PENDING_PAT.match(b["base"]))
            open_blocks.append(b)
        elif CLOSE_BASES_PAT.match(b["base"]):
            close_blocks.append(b)
        elif MODIFY_BASES_PAT.match(b["base"]):
            modify_blocks.append(b)
    d["open_blocks"], d["close_blocks"], d["modify_blocks"] = open_blocks, close_blocks, modify_blocks

    # --- SL / TP per open block -------------------------------------------------
    sl_evidence, has_sl, sl_unknown = [], False, False
    for b in open_blocks:
        slm = b["assigns"].get("StopLossMode")
        tpm = b["assigns"].get("TakeProfitMode")
        if slm is None:
            sl_unknown = True
            sl_txt = "StopLossMode NOT SET (template default 'fixed' 50p — verify)"
        else:
            sl_txt = "StopLossMode=%s" % slm
            if slm.strip('"') != "none":
                has_sl = True
        tp_txt = "TakeProfitMode=%s" % (tpm if tpm is not None else "NOT SET")
        sl_evidence.append('Block %s "%s" [%s]: %s · %s' % (
            b["user_no"], b["label"] or b["base"], b["base"].replace("MDL_", ""), sl_txt, tp_txt))
    # legacy fallback: raw trade-call counts (hand-written MQL or old exports)
    n_ordersend = len(re.findall(r"\bOrderSend\s*\(", text))
    d["n_trade_calls"] = (
        len(re.findall(r"\btrade\s*\.\s*(Buy|Sell)\s*\(", text))
        + len(re.findall(r"\b(PositionOpen|OrderOpen)\s*\(", text)))
    d["n_pending_calls"] = len(re.findall(r"\btrade\s*\.\s*(Buy|Sell)(Stop|Limit)\s*\(", text))
    d["sl_evidence"] = sl_evidence
    d["has_sl"] = has_sl
    d["sl_unknown"] = sl_unknown
    d["has_tp"] = any(
        (b["assigns"].get("TakeProfitMode") or "").strip('"') not in ("", "none")
        for b in open_blocks)
    d["n_ordersend"] = n_ordersend

    # --- ORDER-091A: generic SL heuristic for non-fxDreema (block-less) sources ------
    # fxDreema exports always parse into Block classes; hand-written/AI_GEN sources
    # (Wave 0 folders: AI_GEN, Course jobot, .Final EA hand code, etc.) don't, so
    # has_sl/sl_unknown above default to False/False ("no SL") regardless of truth.
    # This additive-only fallback (guarded by `not blocks`) never touches fxDreema
    # cards' results — it only fills the gap for cards that have zero open_blocks.
    d["sl_heuristic"] = False
    if not blocks:
        sl_pat = re.compile(
            r"(?i)\bOrderStopLoss\b|\bStopLoss\w*\b|\bstop\s*loss\b|"
            r"\.sl\s*=|\bsl\s*=\s*(?!0\s*[;,)])[^;\n]+[;,)]|PositionModify\s*\(|request\.sl\b")
        d["sl_heuristic"] = True
        if sl_pat.search(text):
            d["has_sl"] = True
        else:
            d["sl_unknown"] = True  # can't prove no-SL from regex alone — flag for manual spot-check

    # --- trailing stop presence ---------------------------------------------------
    d["has_trailing"] = bool(modify_blocks) or "TrailingStop" in text

    # --- lot law -------------------------------------------------------------------
    lot_lines = []       # human-readable lot-law facts
    escalation = False

    def describe_operand(side, b):
        """side='Lo'/'Ro' -> short operand description from template args + assigns."""
        targ_list = [t.strip() for t in b["targs"].split(",")] if b["targs"] else []
        # template args come in (type, valuetype) pairs; Lo=arg0, Ro=arg~middle — heuristic:
        cand = [t for t in targ_list if t.startswith("MDLIC_")]
        name = ""
        if cand:
            name = cand[0] if side == "Lo" else cand[-1]
            name = name.replace("MDLIC_", "")
        val = b["assigns"].get(side + ".Value")
        attr = b["assigns"].get(side + ".Attribute")
        rmode = b["assigns"].get(side + ".ReturnMode")
        bits = []
        if val:
            bits.append(val)
        elif name and name != "value_value":
            bits.append(name)
        if attr:
            bits.append(ATTR_MAP.get(attr, "attr" + attr))
        if rmode:
            bits.append(RETMODE_MAP.get(rmode, "mode" + rmode) )
        return ".".join(bits) if bits else (name or "?")

    for b in blocks:
        tgts = formula_targets.get(b["base"])
        if not tgts:
            continue
        cmp_op = (b["assigns"].get("compare") or compare_defaults.get(b["base"], "+")).strip('"')
        lo, ro = describe_operand("Lo", b), describe_operand("Ro", b)
        line = "v::%s = %s %s %s   (Block %s, compare=\"%s\")" % (
            ", v::".join(tgts), lo, cmp_op, ro, b["user_no"], cmp_op)
        if any(LOTVAR_PAT.search(t) for t in tgts):
            lot_lines.append(line)
            if cmp_op in ("+", "*"):
                escalation = True
        elif any(LOTVAR_PAT.search(x) for x in (lo, ro)):
            lot_lines.append(line)

    # VolumeMode / VolumeSize overrides on open blocks
    for b in open_blocks:
        vm = (b["assigns"].get("VolumeMode") or "").strip('"')
        vs = b["assigns"].get("VolumeSize")
        if vm:
            lot_lines.append('Block %s "%s": VolumeMode="%s"' % (b["user_no"], b["label"], vm))
            if vm in BETTING_MODES:
                escalation = True
        if vs:
            lot_lines.append('Block %s "%s": VolumeSize = %s' % (b["user_no"], b["label"], vs))

    # legacy / free-form lot arithmetic — ONLY when no MDL block structure exists
    # (in block-based exports every raw hit is fxDreema template-library noise:
    #  NormalizeLots rounding, Bet1326/BetMartingale internals, DynamicLots dispatch)
    NOISE = ("DynamicLots(Symbol", "else if (VolumeMode", "lots = Bet", "size=(value",
             "double DynamicLots", "values[i] = OrderLots", "avgLots", "return OrderLots",
             "lots = PositionGetDouble", "lots = _dVolumeSize_", "lots0 =",
             "MathRound(lots", "MathRound(lowerlots", "MathRound(upperlots",
             "initialLots", "LotStep", "MODE_MINLOT", "MODE_MAXLOT", "SYMBOL_VOLUME")
    for ln in ([] if blocks else text.splitlines()):
        s = ln.strip()
        if not s or s.startswith("//") or any(n in s for n in NOISE):
            continue
        if re.search(r"(?i)\b\w*lot\w*\s*(\*|\+)?=\s*[^=].*(\*|MathMin|MathMax|AccountBalance|AccountEquity|OrderLots)", s) \
                and "formula(" not in s:
            if len(lot_lines) < 14 and s not in lot_lines:
                lot_lines.append("raw: " + s[:160])
            if re.search(r"(?i)\b\w*lot\w*\s*\*=|\blot\w*\s*=\s*\w*lot\w*\s*\*", s):
                escalation = True
    d["lot_lines"] = lot_lines[:14]
    d["lot_escalation"] = escalation

    # lot cap evidence
    cap = bool(re.search(r"(?i)MathMin\s*\([^)\n]*lot", text)) or \
          any(re.search(r"(?i)(max\w*lot|lot\w*max|lot\w*cap|cap\w*lot)", n) for _, n, _, _ in inputs)
    d["has_cap"] = cap

    # --- indicators -------------------------------------------------------------
    wired = sorted(set("i" + n for n in RE_IND_CLASS.findall(text)))
    d["indicators_wired"] = wired
    if not wired:
        raw = {}
        for m in RE_IND_RAW.finditer(text):
            raw["i" + m.group(1)] = raw.get("i" + m.group(1), 0) + 1
        # drop shim definitions noise: keep only names with >0 anyway (fallback only)
        d["indicators_wired"] = sorted(raw.keys())
    # indicator params: constructor defaults inside MDLIC_indicators classes
    ind_params = []
    for m in re.finditer(r"class\s+(MDLIC_indicators_i\w+)\b", text):
        body = class_body(text, m.start())
        ret = re.search(r"return\s+(i\w+)\s*\(([^;]*)\)\s*;", body)
        ctor = re.findall(r"^\s*(\w+)\s*=\s*([^;\n]+?)\s*;", body, re.M)
        keep = [(k, strip_cast(v)) for k, v in ctor
                if k not in ("Symbol", "Shift", "Mode") and not k.startswith("_")]
        sig = ", ".join("%s=%s" % kv for kv in keep[:6])
        ind_params.append("%s(%s)" % (m.group(1).replace("MDLIC_indicators_", ""), sig))
    d["indicator_params"] = sorted(set(ind_params))

    # --- danger flags --------------------------------------------------------------
    flags = []
    have_open_evidence = bool(open_blocks) or d.get("sl_heuristic")
    if have_open_evidence and not d["has_sl"] and not d["sl_unknown"]:
        flags.append("NO_SL")
    elif have_open_evidence and not d["has_sl"] and d["sl_unknown"]:
        flags.append("SL_UNKNOWN")
    if d.get("sl_heuristic"):
        flags.append("SL_HEURISTIC")  # ORDER-091A: non-fxDreema file — SL verdict is regex-based, spot-check before trusting
    if escalation:
        flags.append("LOT_ESCALATION")
        if not cap:
            flags.append("NO_CAP")
    if re.search(r'^\s*#import\s+"', text, re.M):
        flags.append("DLL_IMPORT")
    if re.search(r"\bWebRequest\s*\(", text) or re.search(r"(?i)wininet", text):
        flags.append("WEBREQUEST")
    if re.search(r"[<>]=?\s*D'20\d\d", text) or re.search(r"D'20\d\d[^']*'\s*[<>]", text) \
            or re.search(r"(?i)TimeCurrent\s*\(\s*\)\s*[<>]=?\s*\d{9,}", text):
        flags.append("TIMELOCK")
    d["flags"] = flags
    return d


# ----------------------------------------------------------------------------- cards

def fmt_card(name, platform, paths, size, d):
    L = []
    L.append("## %s" % name)
    L.append("")
    L.append("- **platform:** %s · **size:** %s KB · **lines:** %s · **fxDreema blocks:** %s"
             % (platform.upper(), f"{size/1024:.0f}", f"{d['lines']:,}", d["n_blocks"]))
    if len(paths) > 1:
        L.append("- **paths (%d copies, identical content):**" % len(paths))
        for p in paths:
            L.append("  - `%s`" % p)
    else:
        L.append("- **path:** `%s`" % paths[0])
    flags = ", ".join(d["flags"]) if d["flags"] else "(none)"
    L.append("- **danger flags:** %s" % flags)

    L.append("- **inputs (%d):**" % len(d["inputs"]))
    for typ, nm, dv, cm in d["inputs"][:25]:
        c = ("  // " + cm) if cm else ""
        L.append("  - `%s %s = %s`%s" % (typ, nm, dv, c))
    if len(d["inputs"]) > 25:
        L.append("  - ... (+%d more)" % (len(d["inputs"]) - 25))

    if d["indicators_wired"]:
        L.append("- **indicators wired:** %s" % ", ".join(d["indicators_wired"]))
        if d["indicator_params"]:
            for ip in d["indicator_params"][:6]:
                L.append("  - `%s`" % ip)
    else:
        L.append("- **indicators wired:** (none found)")

    if d["census"]:
        top = sorted(d["census"].items(), key=lambda kv: -kv[1])[:14]
        L.append("- **block census (top):** " + " · ".join("%s x%d" % (k, v) for k, v in top))

    n_open = len(d["open_blocks"])
    n_pend = sum(1 for b in d["open_blocks"] if b.get("pending"))
    L.append("- **order actions:** open-blocks=%d (market=%d, pending=%d) · close-blocks=%d · modify/trailing=%d · raw OrderSend()=%d · raw trade.Buy/Sell/PositionOpen=%d (pending=%d)"
             % (n_open, n_open - n_pend, n_pend, len(d["close_blocks"]), len(d["modify_blocks"]),
                d["n_ordersend"], d["n_trade_calls"], d["n_pending_calls"]))

    if d["sl_evidence"]:
        L.append("- **SL/TP evidence:**")
        for e in d["sl_evidence"][:8]:
            L.append("  - %s" % e)
    if d["lot_lines"]:
        L.append("- **lot law:**")
        for e in d["lot_lines"]:
            L.append("  - `%s`" % e)
    else:
        L.append("- **lot law:** no dynamic lot logic found (fixed VolumeSize / template default)")
    L.append("")
    return "\n".join(L)


# ----------------------------------------------------------------------------- main

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--roots", nargs="*", default=DEFAULT_ROOTS)
    ap.add_argument("--md", default=os.path.join("_triage", "FXDREEMA_XRAY.md"))
    ap.add_argument("--csv", default=os.path.join("_triage", "FXDREEMA_XRAY.csv"))
    args = ap.parse_args()

    # discover + dedupe by content hash
    by_hash = {}     # sha1 -> {"paths": [...], "text": str, "size": int}
    n_seen = 0
    for path, text in discover(args.roots):
        n_seen += 1
        h = hashlib.sha1(text.encode("utf-8", "replace")).hexdigest()
        e = by_hash.setdefault(h, {"paths": [], "text": text, "size": os.path.getsize(path)})
        e["paths"].append(path)
        print("found: %s" % path, file=sys.stderr)

    entries = []
    for h, e in by_hash.items():
        paths = sorted(e["paths"], key=lambda p: (len(p), p.lower()))
        name = os.path.splitext(os.path.basename(paths[0]))[0].strip()
        platform = os.path.splitext(paths[0])[1].lstrip(".").lower()
        d = parse_ea(e["text"])
        entries.append((name, platform, paths, e["size"], d))
    entries.sort(key=lambda t: t[0].lower())

    total_mb = sum(sz * len(p) for _, _, p, sz, _ in entries) / (1024 * 1024)

    # --- markdown ------------------------------------------------------------
    md = io.StringIO()
    md.write("# FXDREEMA X-RAY (ORDER-074)\n\n")
    md.write("Deterministic summary cards for every fxDreema-exported EA found on this machine.\n")
    md.write("Generated by `scripts/fxdreema_xray.py` — DO NOT hand-edit; re-run the script.\n\n")
    md.write("**Corpus:** %d files on disk → %d unique EAs (dedup by content hash) · %.1f MB total\n\n"
             % (n_seen, len(entries), total_mb))
    md.write("**Cards are raw data — NO verdicts here (ORDER-074 ห้าม verdict ต่อ EA).**\n\n---\n\n")
    for name, platform, paths, size, d in entries:
        md.write(fmt_card(name, platform, paths, size, d))
        md.write("\n---\n\n")

    os.makedirs(os.path.dirname(args.md) or ".", exist_ok=True)
    with open(args.md, "w", encoding="utf-8") as fh:
        fh.write(md.getvalue())

    # --- csv -------------------------------------------------------------------
    with open(args.csv, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["name", "platform", "size_kb", "lines", "blocks", "n_inputs",
                    "indicators", "open_blocks", "pending", "close_blocks", "raw_trade_calls",
                    "has_sl", "has_tp", "lot_escalation", "flags", "n_copies", "path"])
        for name, platform, paths, size, d in entries:
            n_open = len(d["open_blocks"])
            n_pend = sum(1 for b in d["open_blocks"] if b.get("pending"))
            w.writerow([
                name, platform, round(size / 1024), d["lines"], d["n_blocks"],
                len(d["inputs"]), ";".join(d["indicators_wired"]),
                n_open, n_pend, len(d["close_blocks"]),
                d["n_ordersend"] + d["n_trade_calls"],
                ("yes" if d["has_sl"] else ("unknown" if d["sl_unknown"] else "no")),
                "yes" if d["has_tp"] else "no",
                "yes" if d["lot_escalation"] else "no",
                ";".join(d["flags"]), len(paths), paths[0],
            ])

    print("\nwrote %s + %s  (%d unique EAs from %d files, %.1f MB)"
          % (args.md, args.csv, len(entries), n_seen, total_mb))


if __name__ == "__main__":
    main()
