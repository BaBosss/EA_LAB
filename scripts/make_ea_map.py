#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""make_ea_map.py - regenerate EA_LAB_MAP.html (visual canvas map of the whole lab).

Inspired by jaturapornchai/mongomodeleditor: a canvas of cards + click-to-inspect panel,
but the "collections" here are EAs and the "relationships" are the VERDICT GATE funnel.

Source of truth  : EA_MASTER_INDEX.csv  (hook-enforced, updated with every verdict)
Output           : EA_LAB_MAP.html      (single self-contained file, no CDN, works offline)

Run after any EA_MASTER_INDEX.csv change:
    python scripts/make_ea_map.py

Do NOT hand-edit EA_LAB_MAP.html - it is overwritten on every run.
"""

import csv
import io
import json
import os
import re
import subprocess
import sys
from collections import Counter
from datetime import datetime

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "EA_MASTER_INDEX.csv")
OUT = os.path.join(REPO, "EA_LAB_MAP.html")

# --- funnel order: left-to-right = further along the VERDICT GATE tree -------------
# legacy status values in the CSV mapped onto the canonical vocabulary (CLAUDE.md PART 0)
STATUS_META = [
    ("UNTESTED", "ยังไม่ได้แตะ", "ยังไม่เข้า gate - ของดิบรอ smoke", "slate"),
    ("DEAD", "DEAD-*", "ตายแล้ว (structural หรือ optimized ครบ ladder)", "red"),
    ("REJECT", "REJECT (legacy)", "ตกรอบก่อนมี vocabulary ใหม่ - อ่านเป็น DEAD-OPTIMIZED", "red"),
    ("PARKED", "PARKED-VERIFY", "ยังไม่ตาย รอ user เคาะ / รอหลักฐานเพิ่ม", "purple"),
    ("WATCH", "BUILD-ON", "PF>1 แต่ยังใต้บาร์ deploy - ต่อยอดได้", "amber"),
    ("CANDIDATE", "CANDIDATE", "ผ่านบาร์ pre-registered แล้ว รอ deploy funnel", "blue"),
    ("DEMO", "DEMO", "รันเดโมอยู่ - นับ 3 เดือนเพื่อ judge", "green"),
    ("LIVE", "LIVE", "เงินจริง", "gold"),
]
STATUS_ORDER = [s[0] for s in STATUS_META]

RISK_TIER = [
    # (matcher, label, tone)  - tone drives the card's left rail colour
    (lambda v: v in ("martingale", "martingale/grid"), "martingale ไม่ปิดหาง", "danger"),
    (lambda v: v == "grid", "grid ดิบ", "danger"),
    (lambda v: "grid-log-capped" in v, "grid มี cap", "warn"),
    (lambda v: "pyramid" in v, "pyramid", "warn"),
    (lambda v: "grid" in v, "ผสม grid", "warn"),
    (lambda v: v in ("fixed",), "lot คงที่", "safe"),
]

PF_RE = re.compile(r"(?<![\d.])(\d{1,2}\.\d{1,2})(?![\d])")


def clean(s):
    return (s or "").replace("\xa0", " ").strip()


def short_name(name):
    """EA_MASTER_INDEX mixes friendly names with raw windows paths - show the leaf."""
    n = clean(name).replace("\\", "/")
    return n.rsplit("/", 1)[-1] if "/" in n else n


def risk_tier(risk):
    v = clean(risk).lower()
    for match, label, tone in RISK_TIER:
        if match(v):
            return label, tone
    return "ไม่ทราบ", "unknown"


def best_pf(best_result):
    """Largest PF-looking number recorded in best_result. Display only - the raw
    string is always shown next to it, because best_result mixes IS/OOS/M4 numbers."""
    vals = [float(x) for x in PF_RE.findall(clean(best_result))]
    vals = [v for v in vals if 0.2 <= v <= 20.0]
    return max(vals) if vals else None


def symbol_of(home_cell):
    hc = clean(home_cell)
    if not hc or hc == "-":
        return "ยังไม่มีบ้าน"
    first = hc.split()[0]
    if "/" in first or len(first) > 12:
        return "หลายสัญลักษณ์"
    return first


def timeframe_of(home_cell):
    m = re.search(r"\b(M1|M5|M15|M30|H1|H4|D1|W1)\b", clean(home_cell))
    return m.group(1) if m else "-"


def strategy_of(strategy):
    s = clean(strategy)
    if not s or s in ("-", "unknown"):
        return "ไม่ระบุ"
    return s


def load_rows():
    with io.open(SRC, encoding="utf-8-sig") as fh:
        raw = list(csv.DictReader(fh))
    out = []
    for i, r in enumerate(raw):
        status = clean(r.get("status")) or "UNTESTED"
        if status not in STATUS_ORDER:
            status = "UNTESTED"
        risk_label, risk_tone = risk_tier(r.get("risk_mech"))
        home = clean(r.get("home_cell"))
        out.append({
            "id": i,
            "name": short_name(r.get("name")),
            "full": clean(r.get("name")),
            "status": status,
            "origin": clean(r.get("origin")) or "-",
            "path": clean(r.get("file_path")) or "-",
            "lang": clean(r.get("lang")) or "-",
            "home": home or "-",
            "symbol": symbol_of(home),
            "tf": timeframe_of(home),
            "strategy": strategy_of(r.get("strategy")),
            "risk": clean(r.get("risk_mech")) or "-",
            "riskLabel": risk_label,
            "riskTone": risk_tone,
            "best": clean(r.get("best_result")) or "-",
            "pf": best_pf(r.get("best_result")),
            "note": clean(r.get("note")) or "-",
            "next": clean(r.get("next_action")) or "-",
            "ref": clean(r.get("detail_ref")) or "-",
            "conf": clean(r.get("confidence")) or "0",
            "updated": clean(r.get("updated")) or "-",
        })
    return out


def git_head():
    try:
        return subprocess.check_output(
            ["git", "-C", REPO, "rev-parse", "--short", "HEAD"],
            stderr=subprocess.DEVNULL).decode().strip()
    except Exception:
        return "unknown"


def build():
    rows = load_rows()
    counts = Counter(r["status"] for r in rows)
    payload = {
        "rows": rows,
        "statusMeta": [
            {"key": k, "label": lbl, "desc": d, "tone": t, "n": counts.get(k, 0)}
            for k, lbl, d, t in STATUS_META
        ],
        "generated": datetime.now().strftime("%Y-%m-%d %H:%M"),
        "commit": git_head(),
        "total": len(rows),
    }
    html = TEMPLATE.replace("/*__EA_DATA__*/null", json.dumps(payload, ensure_ascii=False))
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(html)
    print("wrote %s (%d EA rows, %d live-track)" %
          (OUT, len(rows), counts.get("DEMO", 0) + counts.get("LIVE", 0)))


TEMPLATE = u"""<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>EA_LAB — แผนที่ทั้งแล็บ</title>
<style>
:root{
  --bg:#0d1117; --panel:#161b22; --card:#1c2129; --border:#30363d; --border2:#21262d;
  --text:#e6edf3; --dim:#8b949e; --faint:#6e7681;
  --green:#3fb950; --red:#f85149; --amber:#d29922; --blue:#58a6ff;
  --purple:#bc8cff; --gold:#e3b341; --slate:#6e7681;
  --shadow:0 1px 3px rgba(0,0,0,.4);
}
@media (prefers-color-scheme: light){
  :root{
    --bg:#f6f8fa; --panel:#fff; --card:#fff; --border:#d0d7de; --border2:#eaeef2;
    --text:#1f2328; --dim:#59636e; --faint:#818b98;
    --green:#1a7f37; --red:#cf222e; --amber:#9a6700; --blue:#0969da;
    --purple:#8250df; --gold:#9a6700; --slate:#6e7781;
    --shadow:0 1px 3px rgba(31,35,40,.12);
  }
}
:root[data-theme="dark"]{
  --bg:#0d1117; --panel:#161b22; --card:#1c2129; --border:#30363d; --border2:#21262d;
  --text:#e6edf3; --dim:#8b949e; --faint:#6e7681;
  --green:#3fb950; --red:#f85149; --amber:#d29922; --blue:#58a6ff;
  --purple:#bc8cff; --gold:#e3b341; --slate:#6e7681;
  --shadow:0 1px 3px rgba(0,0,0,.4);
}
:root[data-theme="light"]{
  --bg:#f6f8fa; --panel:#fff; --card:#fff; --border:#d0d7de; --border2:#eaeef2;
  --text:#1f2328; --dim:#59636e; --faint:#818b98;
  --green:#1a7f37; --red:#cf222e; --amber:#9a6700; --blue:#0969da;
  --purple:#8250df; --gold:#9a6700; --slate:#6e7781;
  --shadow:0 1px 3px rgba(31,35,40,.12);
}
*{box-sizing:border-box}
html,body{height:100%}
body{margin:0;background:var(--bg);color:var(--text);
  font-family:'Segoe UI',system-ui,-apple-system,'Noto Sans Thai',sans-serif;
  font-size:14px;line-height:1.5;overflow:hidden}

/* ---------- shell ---------- */
.app{display:flex;flex-direction:column;height:100vh}
header{display:flex;align-items:center;gap:14px;flex-wrap:wrap;
  padding:10px 16px;background:var(--panel);border-bottom:1px solid var(--border);flex:none}
header h1{margin:0;font-size:16px;font-weight:700;white-space:nowrap}
header .meta{color:var(--dim);font-size:11.5px;font-family:Consolas,monospace}
.tabs{display:flex;gap:4px;margin-left:auto}
.tab{padding:5px 14px;border-radius:7px;border:1px solid transparent;background:none;
  color:var(--dim);font:inherit;font-size:13px;cursor:pointer}
.tab:hover{color:var(--text)}
.tab.on{background:var(--card);border-color:var(--border);color:var(--text);font-weight:600}

.body{display:flex;flex:1;min-height:0}

/* ---------- left rail ---------- */
.rail{width:224px;flex:none;background:var(--panel);border-right:1px solid var(--border);
  padding:12px;overflow-y:auto}
.rail h3{margin:0 0 7px;font-size:10.5px;letter-spacing:.09em;text-transform:uppercase;color:var(--faint)}
.rail section{margin-bottom:18px}
.rail input[type=search]{width:100%;padding:7px 9px;background:var(--bg);color:var(--text);
  border:1px solid var(--border);border-radius:7px;font:inherit;font-size:13px}
.rail select{width:100%;padding:6px 8px;background:var(--bg);color:var(--text);
  border:1px solid var(--border);border-radius:7px;font:inherit;font-size:13px}
.chk{display:flex;align-items:center;gap:8px;padding:4px 0;cursor:pointer;font-size:12.5px;color:var(--dim)}
.chk:hover{color:var(--text)}
.chk input{accent-color:var(--blue);margin:0}
.chk .n{margin-left:auto;font-family:Consolas,monospace;font-size:11px;color:var(--faint)}
.legend{font-size:11.5px;color:var(--dim)}
.legend div{display:flex;align-items:center;gap:7px;padding:2.5px 0}
.swatch{width:11px;height:11px;border-radius:3px;flex:none}
.railbtn{width:100%;padding:6px;margin-top:6px;background:var(--bg);color:var(--dim);
  border:1px solid var(--border);border-radius:7px;font:inherit;font-size:12px;cursor:pointer}
.railbtn:hover{color:var(--text);border-color:var(--faint)}

/* ---------- canvas ---------- */
.canvaswrap{flex:1;min-width:0;position:relative;overflow:auto;padding:16px}
.zoombar{position:absolute;right:14px;bottom:14px;display:flex;gap:4px;z-index:4;
  background:var(--panel);border:1px solid var(--border);border-radius:8px;padding:3px;box-shadow:var(--shadow)}
.zoombar button{width:28px;height:26px;background:none;border:none;color:var(--dim);
  font:inherit;font-size:14px;cursor:pointer;border-radius:5px}
.zoombar button:hover{background:var(--card);color:var(--text)}
.zoombar .lvl{min-width:44px;text-align:center;font-size:11px;color:var(--faint);
  font-family:Consolas,monospace;line-height:26px}

.board{display:flex;gap:12px;align-items:flex-start;transform-origin:0 0;width:max-content;padding-bottom:24px}
.lane{width:250px;flex:none;background:var(--panel);border:1px solid var(--border);
  border-radius:11px;padding:9px}
.lane.empty{opacity:.42}
.lanehead{display:flex;align-items:baseline;gap:7px;padding:2px 3px 8px;border-bottom:1px solid var(--border2);margin-bottom:8px}
.lanehead .dot{width:8px;height:8px;border-radius:50%;flex:none;align-self:center}
.lanehead .t{font-weight:700;font-size:12.5px}
.lanehead{cursor:pointer;user-select:none}
.lanehead:hover .t{color:var(--blue)}
.lanehead .n{margin-left:auto;font-family:Consolas,monospace;font-size:11.5px;color:var(--faint)}
.lane.folded{width:172px}
.unfold{width:100%;padding:9px 6px;background:var(--card);color:var(--dim);border:1px dashed var(--border);
  border-radius:8px;font:inherit;font-size:11.5px;cursor:pointer}
.unfold:hover{color:var(--text);border-color:var(--blue)}
.lanedesc{font-size:11px;color:var(--faint);margin:-4px 3px 8px;line-height:1.4}
.lanebody{display:flex;flex-direction:column;gap:7px;max-height:none}

.card{background:var(--card);border:1px solid var(--border);border-left-width:3px;
  border-radius:8px;padding:8px 9px;cursor:pointer;position:relative;transition:border-color .1s}
.card:hover{border-color:var(--blue)}
.card.sel{border-color:var(--blue);box-shadow:0 0 0 1px var(--blue)}
.card .nm{font-size:12.5px;font-weight:600;line-height:1.35;word-break:break-word}
.card .row{display:flex;flex-wrap:wrap;gap:4px;margin-top:5px}
.card .best{margin-top:5px;font-size:10.5px;color:var(--dim);font-family:Consolas,monospace;
  word-break:break-word;line-height:1.35}
.pill{display:inline-block;padding:1px 7px;border-radius:20px;font-size:10px;font-weight:600;
  white-space:nowrap;border:1px solid transparent}
.pf{position:absolute;top:8px;right:9px;font-family:Consolas,monospace;font-size:11.5px;font-weight:700}

.tone-danger{border-left-color:var(--red)} .tone-warn{border-left-color:var(--amber)}
.tone-safe{border-left-color:var(--green)} .tone-unknown{border-left-color:var(--border)}

.p-sym{background:color-mix(in srgb,var(--blue) 15%,transparent);color:var(--blue)}
.p-str{background:color-mix(in srgb,var(--purple) 15%,transparent);color:var(--purple)}
.p-tf{background:color-mix(in srgb,var(--slate) 22%,transparent);color:var(--dim)}
.p-risk-danger{background:color-mix(in srgb,var(--red) 15%,transparent);color:var(--red)}
.p-risk-warn{background:color-mix(in srgb,var(--amber) 15%,transparent);color:var(--amber)}
.p-risk-safe{background:color-mix(in srgb,var(--green) 15%,transparent);color:var(--green)}
.p-risk-unknown{background:color-mix(in srgb,var(--slate) 18%,transparent);color:var(--faint)}

/* ---------- inspector ---------- */
.inspect{width:310px;flex:none;background:var(--panel);border-left:1px solid var(--border);
  overflow-y:auto;padding:14px}
.inspect.ph-only{width:0;padding:0;border-left:none;overflow:hidden}
.inspect .ph{color:var(--faint);font-size:12.5px;text-align:center;margin-top:34px;line-height:1.7}
.hint{color:var(--faint);font-size:11.5px;line-height:1.6;border-top:1px solid var(--border2);padding-top:10px}
.inspect h2{margin:0 0 3px;font-size:14.5px;line-height:1.4;word-break:break-word}
.inspect .sub{color:var(--dim);font-size:11.5px;margin-bottom:12px;font-family:Consolas,monospace;word-break:break-all}
.field{border-top:1px solid var(--border2);padding:8px 0}
.field .k{font-size:10px;letter-spacing:.07em;text-transform:uppercase;color:var(--faint);margin-bottom:2px}
.field .v{font-size:12.5px;word-break:break-word;line-height:1.5}
.field .v.mono{font-family:Consolas,monospace;font-size:11.5px;color:var(--dim)}
.close{float:right;background:none;border:none;color:var(--faint);font-size:17px;cursor:pointer;line-height:1;padding:0 0 0 8px}
.close:hover{color:var(--text)}

/* ---------- gate view ---------- */
.gate{flex:1;overflow-y:auto;padding:20px 24px}
.gate .inner{max-width:1000px;margin:0 auto}
.gate h2{font-size:17px;margin:0 0 4px}
.gate p.lede{color:var(--dim);font-size:13px;margin:0 0 18px}
.gate svg{width:100%;height:auto;display:block;background:var(--panel);
  border:1px solid var(--border);border-radius:11px;padding:8px 0}
.gate h3{font-size:14px;margin:24px 0 8px}
table{width:100%;border-collapse:collapse;font-size:12.5px;background:var(--panel);
  border:1px solid var(--border);border-radius:11px;overflow:hidden}
th{text-align:left;font-size:10.5px;letter-spacing:.06em;text-transform:uppercase;color:var(--faint);
  padding:8px 11px;border-bottom:1px solid var(--border);font-weight:600}
td{padding:8px 11px;border-bottom:1px solid var(--border2);vertical-align:top}
tr:last-child td{border-bottom:none}
td b{font-family:Consolas,monospace}
.vocab{display:flex;flex-wrap:wrap;gap:6px;margin:10px 0 0}
.vocab .pill{font-size:11.5px;padding:3px 11px}

.hide{display:none!important}
@media(max-width:1100px){ .inspect{width:264px} .rail{width:196px} }
@media(max-width:820px){
  .rail{display:none} .inspect{position:fixed;right:0;top:0;bottom:0;width:min(88vw,330px);z-index:20;box-shadow:-6px 0 24px rgba(0,0,0,.3)}
  .inspect.ph-only{display:none}
}
</style>
</head>
<body>
<div class="app">
<header>
  <h1>🗺️ EA_LAB — แผนที่ทั้งแล็บ</h1>
  <span class="meta" id="hmeta"></span>
  <div class="tabs">
    <button class="tab on" data-view="board">แผนผัง EA</button>
    <button class="tab" data-view="gate">ผังตัดสิน (VERDICT GATE)</button>
  </div>
</header>

<div class="body">
  <!-- left rail -->
  <div class="rail" id="rail">
    <section>
      <h3>ค้นหา</h3>
      <input type="search" id="q" placeholder="ชื่อ / สัญลักษณ์ / โน้ต…">
    </section>
    <section>
      <h3>จัดกลุ่มตาม</h3>
      <select id="groupby">
        <option value="status">สถานะ (สายพาน verdict)</option>
        <option value="strategy">กลยุทธ์</option>
        <option value="riskLabel">กลไกความเสี่ยง</option>
        <option value="symbol">สัญลักษณ์ (บ้าน)</option>
        <option value="origin">ที่มา</option>
      </select>
      <button class="railbtn" id="toggleUntested">ซ่อน UNTESTED</button>
    </section>
    <section>
      <h3>สถานะ</h3>
      <div id="statusFilters"></div>
    </section>
    <section>
      <h3>แถบสีซ้ายของการ์ด = ความเสี่ยง</h3>
      <div class="legend">
        <div><span class="swatch" style="background:var(--red)"></span>martingale / grid ไม่ปิดหาง</div>
        <div><span class="swatch" style="background:var(--amber)"></span>grid มี cap / pyramid</div>
        <div><span class="swatch" style="background:var(--green)"></span>lot คงที่</div>
        <div><span class="swatch" style="background:var(--border)"></span>ยังไม่ทราบ</div>
      </div>
    </section>
    <section>
      <div class="hint">คลิก <b>การ์ด</b> = ดูรายละเอียดทุกช่อง<br>คลิก <b>หัวคอลัมน์</b> = พับ/กางกอง<br>เลข <b>มุมขวาบนการ์ด</b> = PF ดีสุดที่บันทึกไว้</div>
    </section>
  </div>

  <!-- canvas -->
  <div class="canvaswrap" id="canvaswrap">
    <div class="board" id="board"></div>
    <div class="zoombar">
      <button id="zout" title="ย่อ">−</button>
      <span class="lvl" id="zlvl">100%</span>
      <button id="zin" title="ขยาย">+</button>
      <button id="zfit" title="รีเซ็ต">⤢</button>
    </div>
  </div>

  <!-- gate tree -->
  <div class="gate hide" id="gateview">
    <div class="inner">
      <h2>ผังตัดสิน — หลักฐานเข้า แล้วออกมาเป็น verdict อะไร</h2>
      <p class="lede">ต้นฉบับข้อความ = <b>CLAUDE.md § VERDICT GATE</b> · ผังนี้คือภาพของต้นไม้เดียวกัน ห้ามตัดสิน EA จนกว่าจะเดินครบทุกกิ่ง</p>
      <svg viewBox="0 0 940 660" role="img" aria-label="แผนผังต้นไม้ตัดสิน EA">
        <defs>
          <marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
            <path d="M0,0 L10,5 L0,10 z" fill="currentColor"/>
          </marker>
        </defs>
        <g font-family="'Segoe UI','Noto Sans Thai',sans-serif" font-size="13">

        <!-- evidence -->
        <rect x="374" y="16" width="192" height="36" rx="9" fill="none" stroke="var(--blue)" stroke-width="1.5"/>
        <text x="470" y="39" text-anchor="middle" fill="var(--blue)" font-weight="700">หลักฐานเข้า</text>
        <path d="M470,52 L470,70" stroke="var(--faint)" fill="none" marker-end="url(#ar)" color="var(--faint)"/>

        <!-- Q1 structural -->
        <path d="M470,72 L660,124 L470,176 L280,124 Z" fill="color-mix(in srgb,var(--red) 10%,transparent)" stroke="var(--red)" stroke-width="1.5"/>
        <text x="470" y="118" text-anchor="middle" fill="var(--text)" font-weight="700">1 · โครงสร้างพังไหม?</text>
        <text x="470" y="137" text-anchor="middle" fill="var(--dim)" font-size="10.5">martingale คือ edge เอง · ruin ไม่มี cap</text>
        <text x="470" y="153" text-anchor="middle" fill="var(--dim)" font-size="10.5">cracked · fill-artifact</text>
        <path d="M660,124 L742,124" stroke="var(--red)" fill="none" marker-end="url(#ar)" color="var(--red)"/>
        <text x="668" y="116" text-anchor="middle" fill="var(--red)" font-size="11" font-weight="700">ใช่</text>
        <rect x="744" y="104" width="180" height="40" rx="9" fill="color-mix(in srgb,var(--red) 13%,transparent)" stroke="var(--red)" stroke-width="1.5"/>
        <text x="834" y="121" text-anchor="middle" fill="var(--red)" font-weight="700" font-size="12.5">DEAD-STRUCTURAL</text>
        <text x="834" y="136" text-anchor="middle" fill="var(--dim)" font-size="10">ฆ่าได้ทันที ไม่ต้อง optimize</text>

        <path d="M470,176 L470,196" stroke="var(--faint)" fill="none" marker-end="url(#ar)" color="var(--faint)"/>
        <text x="486" y="192" fill="var(--dim)" font-size="11">ไม่ใช่</text>

        <!-- right home + ladder -->
        <rect x="300" y="198" width="340" height="56" rx="9" fill="var(--panel)" stroke="var(--border)" stroke-width="1.5"/>
        <text x="470" y="218" text-anchor="middle" fill="var(--text)" font-weight="700">2 · PARAMETRIC — ยังฆ่าไม่ได้</text>
        <text x="470" y="235" text-anchor="middle" fill="var(--dim)" font-size="10.5">หา RIGHT HOME ก่อน (reversion→ranger · momentum→trender)</text>
        <text x="470" y="249" text-anchor="middle" fill="var(--dim)" font-size="10.5">แล้วเดิน ladder ≥3 lever × ≥2 TF บนบ้านที่ถูก</text>

        <path d="M470,254 L470,276 M180,276 L790,276 M180,276 L180,300 M470,276 L470,300 M790,276 L790,300"
              stroke="var(--faint)" fill="none"/>
        <path d="M180,296 L180,308 M470,296 L470,308 M790,296 L790,308" stroke="var(--faint)" fill="none" marker-end="url(#ar)" color="var(--faint)"/>

        <!-- 2a -->
        <rect x="46" y="310" width="268" height="82" rx="9" fill="var(--panel)" stroke="var(--red)" stroke-width="1.5"/>
        <text x="180" y="330" text-anchor="middle" fill="var(--text)" font-weight="700" font-size="12.5">2a · เพดาน &lt; 1.0 ทั้งสอง window</text>
        <text x="180" y="347" text-anchor="middle" fill="var(--dim)" font-size="10.5">บนบ้านที่ถูก และ</text>
        <text x="180" y="363" text-anchor="middle" fill="var(--amber)" font-size="10.5" font-weight="700">ทำ LAST-OPTIMIZE รอบสุดท้ายแล้ว</text>
        <text x="180" y="380" text-anchor="middle" fill="var(--dim)" font-size="10.5">(บังคับ 1 รอบบน lever ที่ยังไม่แตะ)</text>
        <path d="M180,392 L180,418" stroke="var(--red)" fill="none" marker-end="url(#ar)" color="var(--red)"/>
        <rect x="60" y="420" width="240" height="42" rx="9" fill="color-mix(in srgb,var(--red) 13%,transparent)" stroke="var(--red)" stroke-width="1.5"/>
        <text x="180" y="438" text-anchor="middle" fill="var(--red)" font-weight="700" font-size="12.5">DEAD-OPTIMIZED</text>
        <text x="180" y="453" text-anchor="middle" fill="var(--dim)" font-size="10">ปิดที่ระดับ CELL เป็น default</text>

        <!-- 2b -->
        <rect x="336" y="310" width="268" height="82" rx="9" fill="var(--panel)" stroke="var(--amber)" stroke-width="1.5"/>
        <text x="470" y="330" text-anchor="middle" fill="var(--text)" font-weight="700" font-size="12.5">2b · PF &gt; 1 ที่ไหนก็ได้</text>
        <text x="470" y="347" text-anchor="middle" fill="var(--dim)" font-size="10.5">แต่ยังใต้บาร์ deploy</text>
        <text x="470" y="365" text-anchor="middle" fill="var(--dim)" font-size="10.5">ขยาย symbol×TF · ปรับกลไก</text>
        <text x="470" y="381" text-anchor="middle" fill="var(--dim)" font-size="10.5">แกะ mechanism เข้า EDGE_CATALOG</text>
        <path d="M470,392 L470,418" stroke="var(--amber)" fill="none" marker-end="url(#ar)" color="var(--amber)"/>
        <rect x="350" y="420" width="240" height="42" rx="9" fill="color-mix(in srgb,var(--amber) 13%,transparent)" stroke="var(--amber)" stroke-width="1.5"/>
        <text x="470" y="438" text-anchor="middle" fill="var(--amber)" font-weight="700" font-size="12.5">BUILD-ON</text>
        <text x="470" y="453" text-anchor="middle" fill="var(--dim)" font-size="10">ค่า default — ห้ามทิ้งเงียบ</text>
        <path d="M590,441 L666,441" stroke="var(--purple)" fill="none" marker-end="url(#ar)" color="var(--purple)"/>
        <rect x="668" y="420" width="216" height="42" rx="9" fill="color-mix(in srgb,var(--purple) 13%,transparent)" stroke="var(--purple)" stroke-width="1.5"/>
        <text x="776" y="438" text-anchor="middle" fill="var(--purple)" font-weight="700" font-size="12.5">PARKED-VERIFY (user)</text>
        <text x="776" y="453" text-anchor="middle" fill="var(--dim)" font-size="10">ดีแต่ยังไม่ผ่าน → brief 3 บรรทัด</text>

        <!-- 2c -->
        <rect x="626" y="310" width="268" height="82" rx="9" fill="var(--panel)" stroke="var(--green)" stroke-width="1.5"/>
        <text x="760" y="330" text-anchor="middle" fill="var(--text)" font-weight="700" font-size="12.5">2c · ผ่านบาร์ที่ประกาศไว้ล่วงหน้า</text>
        <text x="760" y="348" text-anchor="middle" fill="var(--green)" font-size="11" font-weight="700">MAIN ≥ 1.2 (hard) · BWD ≥ 1.0 (soft)</text>
        <text x="760" y="366" text-anchor="middle" fill="var(--dim)" font-size="10.5">plateau จริง ไม่ใช่ spike</text>
        <text x="760" y="382" text-anchor="middle" fill="var(--dim)" font-size="10.5">→ VALIDATED CANDIDATE</text>

        <!-- deploy funnel -->
        <path d="M894,351 L920,351 L920,500 L470,500 L470,516" stroke="var(--green)" fill="none" marker-end="url(#ar)" color="var(--green)"/>
        <rect x="150" y="518" width="640" height="46" rx="9" fill="var(--panel)" stroke="var(--green)" stroke-width="1.5"/>
        <text x="470" y="537" text-anchor="middle" fill="var(--text)" font-weight="700" font-size="12.5">deploy funnel</text>
        <text x="470" y="554" text-anchor="middle" fill="var(--dim)" font-size="10.5">lock .set ที่กลาง plateau → both-window → sensitivity fan → holdout → Monte Carlo (ruin ≤2%) → Model-4 → corr vs cohort</text>

        <path d="M470,564 L470,586" stroke="var(--green)" fill="none" marker-end="url(#ar)" color="var(--green)"/>
        <rect x="286" y="588" width="164" height="44" rx="9" fill="color-mix(in srgb,var(--green) 13%,transparent)" stroke="var(--green)" stroke-width="1.5"/>
        <text x="368" y="606" text-anchor="middle" fill="var(--green)" font-weight="700" font-size="12.5">DEMO</text>
        <text x="368" y="621" text-anchor="middle" fill="var(--dim)" font-size="10">+ แถวใน DEPLOYMENTS.csv</text>
        <path d="M450,610 L508,610" stroke="var(--gold)" fill="none" marker-end="url(#ar)" color="var(--gold)"/>
        <text x="479" y="602" text-anchor="middle" fill="var(--dim)" font-size="9.5">≥3 เดือน</text>
        <rect x="510" y="588" width="164" height="44" rx="9" fill="color-mix(in srgb,var(--gold) 15%,transparent)" stroke="var(--gold)" stroke-width="1.5"/>
        <text x="592" y="606" text-anchor="middle" fill="var(--gold)" font-weight="700" font-size="12.5">LIVE (เงินจริง)</text>
        <text x="592" y="621" text-anchor="middle" fill="var(--dim)" font-size="10">Codex second opinion บังคับ</text>
        </g>
      </svg>

      <h3>ตารางบาร์ — หนึ่งตัวเลขต่อหนึ่งการข้ามขั้น</h3>
      <table>
        <tr><th>ขั้นที่ข้าม</th><th>บาร์</th></tr>
        <tr><td>smoke pulse → เดินต่อ</td><td>หนึ่ง cell naked PF ≥ <b>1.2</b> (WATCH = 1.0–1.2)</td></tr>
        <tr><td>optimize → CANDIDATE</td><td><b>MAIN ≥ 1.2</b> (hard) และ <b>BWD ≥ 1.0</b> (soft) + plateau ไม่ใช่ spike<br><span style="color:var(--dim)">BWD ตก = ไม่ auto-kill → PARKED-VERIFY(user)</span></td></tr>
        <tr><td>holdout</td><td>PF ≥ <b>1.2</b> → deploy track · <b>1.0–1.2</b> → BUILD-ON · &lt;1.0 → selection-fit</td></tr>
        <tr><td>Monte Carlo</td><td>ruin ≤ <b>2%</b> (resize-first ได้ถึง 10%) · PF-5th ≥ <b>1.0</b></td></tr>
        <tr><td>Model-4</td><td>both-window PF ≥ <b>1.0</b> ยังอยู่ และ largest-loss ไม่ระเบิด</td></tr>
        <tr><td>demo → LIVE</td><td>≥ <b>3 เดือน</b> · judge PF ≥ <b>1.40</b> ที่ ≥ <b>30 trades</b></td></tr>
        <tr><td>demo kill (default)</td><td>eqDD &gt; <b>12%</b> · 3-mo PF &lt; <b>0.8</b> ที่ ≥ <b>15 trades</b></td></tr>
      </table>

      <h3>คำศัพท์ verdict ที่ใช้ได้ (นอกจากนี้ retired หมด)</h3>
      <div class="vocab">
        <span class="pill p-risk-danger">DEAD-STRUCTURAL</span>
        <span class="pill p-risk-danger">DEAD-OPTIMIZED</span>
        <span class="pill p-str">PARKED-VERIFY(user)</span>
        <span class="pill p-risk-warn">BUILD-ON</span>
        <span class="pill p-sym">CANDIDATE</span>
        <span class="pill p-risk-safe">DEMO</span>
        <span class="pill p-risk-safe">LIVE</span>
      </div>
      <p class="lede" style="margin-top:12px">DEAD-STRUCTURAL = ความตายที่ถูกอย่างเดียว (ฆ่าทันที แกะ concept เก็บได้) · DEAD-OPTIMIZED = ต้อง <i>ทำให้ได้มา</i> หลัง ladder เต็ม + last-optimize · <b>ที่เหลือทั้งหมดห้ามทิ้ง</b></p>
    </div>
  </div>

  <!-- inspector -->
  <div class="inspect ph-only" id="inspect">
    <div class="ph">คลิกการ์ด EA ใดก็ได้<br>เพื่อดูรายละเอียดทุกช่อง</div>
  </div>
</div>
</div>

<script>
const DATA = /*__EA_DATA__*/null;
const $ = s => document.querySelector(s);
const esc = s => String(s == null ? "" : s).replace(/[&<>"]/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));

const META = {};
DATA.statusMeta.forEach(m => META[m.key] = m);
// UNTESTED starts folded: 88 raw cards would push the stages you actually judge off-screen.
const state = { q:"", groupby:"status", hidden:new Set(), hideUntested:false,
                collapsed:new Set(["UNTESTED"]), sel:null, zoom:1 };

$("#hmeta").textContent = DATA.total + " EA · สร้างเมื่อ " + DATA.generated + " · commit " + DATA.commit;

/* ---- status filter checkboxes ---- */
$("#statusFilters").innerHTML = DATA.statusMeta.map(m => `
  <label class="chk" title="${esc(m.desc)}">
    <input type="checkbox" data-st="${m.key}" checked>
    <span class="swatch" style="background:var(--${m.tone})"></span>
    <span>${esc(m.label)}</span><span class="n">${m.n}</span>
  </label>`).join("");
$("#statusFilters").addEventListener("change", e => {
  const k = e.target.dataset.st;
  if (!k) return;
  e.target.checked ? state.hidden.delete(k) : state.hidden.add(k);
  render();
});

/* ---- grouping ---- */
function groupKeyOf(r){
  if (state.groupby === "status") return r.status;
  return r[state.groupby] || "-";
}
function lanes(rows){
  if (state.groupby === "status")
    return DATA.statusMeta.map(m => ({ key:m.key, title:m.label, desc:m.desc, tone:m.tone,
      items: rows.filter(r => r.status === m.key) }));
  const buckets = new Map();
  rows.forEach(r => {
    const k = groupKeyOf(r);
    if (!buckets.has(k)) buckets.set(k, []);
    buckets.get(k).push(r);
  });
  return [...buckets.entries()]
    .sort((a,b) => b[1].length - a[1].length || String(a[0]).localeCompare(String(b[0])))
    .map(([k, items]) => ({ key:k, title:k, desc:"", tone:"slate", items }));
}

function matches(r){
  if (state.hidden.has(r.status)) return false;
  if (state.hideUntested && r.status === "UNTESTED") return false;
  if (!state.q) return true;
  const q = state.q.toLowerCase();
  return [r.name, r.home, r.strategy, r.risk, r.note, r.best, r.next, r.origin]
    .some(v => String(v).toLowerCase().includes(q));
}

function cardHTML(r){
  const pfCol = r.pf == null ? "var(--faint)"
    : r.pf >= 1.2 ? "var(--green)" : r.pf >= 1.0 ? "var(--amber)" : "var(--red)";
  const pf = r.pf == null ? "" : `<span class="pf" style="color:${pfCol}">${r.pf.toFixed(2)}</span>`;
  const pills = [];
  if (r.symbol !== "ยังไม่มีบ้าน") pills.push(`<span class="pill p-sym">${esc(r.symbol)}</span>`);
  if (r.tf !== "-") pills.push(`<span class="pill p-tf">${esc(r.tf)}</span>`);
  if (r.strategy !== "ไม่ระบุ") pills.push(`<span class="pill p-str">${esc(r.strategy)}</span>`);
  pills.push(`<span class="pill p-risk-${r.riskTone}">${esc(r.riskLabel)}</span>`);
  return `<div class="card tone-${r.riskTone} ${state.sel===r.id?"sel":""}" data-id="${r.id}">
    ${pf}<div class="nm" style="${r.pf!=null?"padding-right:34px":""}">${esc(r.name)}</div>
    <div class="row">${pills.join("")}</div>
    ${r.best !== "-" ? `<div class="best">${esc(r.best)}</div>` : ""}
  </div>`;
}

function render(){
  const rows = DATA.rows.filter(matches);
  $("#board").innerHTML = lanes(rows).map(l => {
    // a search always wins over a folded lane - otherwise hits vanish silently
    const folded = state.collapsed.has(l.key) && !state.q && l.items.length > 0;
    return `<div class="lane ${l.items.length?"":"empty"} ${folded?"folded":""}">
      <div class="lanehead" data-lane="${esc(l.key)}">
        <span class="dot" style="background:var(--${l.tone})"></span>
        <span class="t">${esc(l.title)}</span>
        <span class="n">${l.items.length}${l.items.length?" "+(folded?"▸":"▾"):""}</span>
      </div>
      ${l.desc ? `<div class="lanedesc">${esc(l.desc)}</div>` : ""}
      <div class="lanebody">${
        folded ? `<button class="unfold" data-lane="${esc(l.key)}">แสดง ${l.items.length} ตัว</button>`
        : (l.items.map(cardHTML).join("") ||
           `<div style="color:var(--faint);font-size:11.5px;padding:6px 3px">— ว่าง —</div>`)}</div>
    </div>`;
  }).join("");
  fit();
}

$("#board").addEventListener("click", e => {
  const lane = e.target.closest("[data-lane]");
  if (lane){
    const k = lane.dataset.lane;
    state.collapsed.has(k) ? state.collapsed.delete(k) : state.collapsed.add(k);
    return render();
  }
  const c = e.target.closest(".card");
  if (c) select(Number(c.dataset.id));
});

function select(id){
  state.sel = id;
  const r = DATA.rows.find(x => x.id === id);
  const m = META[r.status];
  const f = (k, v, mono) => v && v !== "-"
    ? `<div class="field"><div class="k">${k}</div><div class="v${mono?" mono":""}">${esc(v)}</div></div>` : "";
  $("#inspect").classList.remove("ph-only");
  $("#inspect").innerHTML = `
    <button class="close" id="closeIns">×</button>
    <h2>${esc(r.name)}</h2>
    <div class="sub">${esc(r.lang)} · อัปเดต ${esc(r.updated)}</div>
    <div class="row" style="display:flex;flex-wrap:wrap;gap:5px;margin-bottom:4px">
      <span class="pill" style="background:color-mix(in srgb,var(--${m.tone}) 16%,transparent);color:var(--${m.tone})">${esc(m.label)}</span>
      <span class="pill p-risk-${r.riskTone}">${esc(r.riskLabel)}</span>
    </div>
    <div class="field"><div class="k">สถานะนี้แปลว่า</div><div class="v" style="color:var(--dim)">${esc(m.desc)}</div></div>
    ${f("บ้าน (symbol × TF)", r.home)}
    ${f("กลยุทธ์", r.strategy)}
    ${f("กลไกความเสี่ยง", r.risk)}
    ${f("ผลดีที่สุดที่บันทึกไว้", r.best, true)}
    ${r.pf != null ? `<div class="field"><div class="k">PF สูงสุดที่อ่านได้จากบรรทัดบน</div><div class="v mono">${r.pf.toFixed(2)}</div></div>` : ""}
    ${f("โน้ต", r.note)}
    ${f("ก้าวถัดไป", r.next)}
    ${f("ความมั่นใจในการทดสอบ (0–3)", r.conf)}
    ${f("ที่มา", r.origin)}
    ${f("อ้างอิงรายละเอียด", r.ref, true)}
    ${f("ไฟล์", r.path, true)}`;
  $("#closeIns").onclick = () => {
    state.sel = null;
    $("#inspect").classList.add("ph-only");
    $("#inspect").innerHTML = `<div class="ph">คลิกการ์ด EA ใดก็ได้<br>เพื่อดูรายละเอียดทุกช่อง</div>`;
    render();
  };
  render();
}

/* ---- controls ---- */
$("#q").addEventListener("input", e => { state.q = e.target.value.trim(); render(); });
$("#groupby").addEventListener("change", e => { state.groupby = e.target.value; render(); });
$("#toggleUntested").addEventListener("click", e => {
  state.hideUntested = !state.hideUntested;
  e.target.textContent = state.hideUntested ? "แสดง UNTESTED" : "ซ่อน UNTESTED";
  render();
});

/* CSS zoom (not transform: scale) so the scroll box shrinks with the content
   and no phantom scrollbars appear at <100% */
function setZoom(z, manual){
  state.zoom = Math.min(1.5, Math.max(0.4, z));
  if (manual) state.userZoom = true;
  $("#board").style.zoom = state.zoom;
  $("#zlvl").textContent = Math.round(state.zoom * 100) + "%";
}
/* fit the whole funnel into view, like a canvas app does on open - never below 0.6
   or the Thai card text stops being readable, at which point scrolling is kinder */
function fit(force){
  if (state.userZoom && !force) return;
  $("#board").style.zoom = 1;
  const avail = $("#canvaswrap").clientWidth - 32;
  const w = $("#board").scrollWidth;
  state.userZoom = false;
  setZoom(w > avail ? Math.max(0.6, avail / w) : 1);
}
$("#zin").onclick = () => setZoom(state.zoom + 0.1, true);
$("#zout").onclick = () => setZoom(state.zoom - 0.1, true);
$("#zfit").onclick = () => fit(true);
addEventListener("resize", () => fit());

document.querySelectorAll(".tab").forEach(t => t.onclick = () => {
  document.querySelectorAll(".tab").forEach(x => x.classList.remove("on"));
  t.classList.add("on");
  const gate = t.dataset.view === "gate";
  $("#gateview").classList.toggle("hide", !gate);
  $("#canvaswrap").classList.toggle("hide", gate);
  $("#rail").classList.toggle("hide", gate);
  $("#inspect").classList.toggle("hide", gate);
});

render();
</script>
</body>
</html>
"""


if __name__ == "__main__":
    if not os.path.exists(SRC):
        sys.exit("missing %s" % SRC)
    build()
