#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
order091a_intake.py -- ORDER-091A (Wave 0 of ORDER-091 master plan).

Expands the fxDreema X-ray + concept catalog (ORDER-074/077, 1,050 unique EAs) to
cover 8 additional Forex-corpus folders named in AGENT_TASKBOARD.md ORDER-091 Wave 0.
Content-hash dedupe against the existing catalog. Inventory-only for binaries and
attached reports/sets (no strings-analysis, no parsing of report contents -- that is
Wave 3 / ORDER-091B).

This does NOT rescan the whole D:\\ drive -- that is scripts/fxdreema_xray.py's job.
It walks exactly the 8 folders below, so a rerun is cheap and bounded. It reuses
read_text()/parse_ea()/fmt_card() from fxdreema_xray.py unmodified except for the
small additive non-fxDreema SL-heuristic fallback added there for this order.

Outputs:
  _triage/FXDREEMA_XRAY.csv         -- new-unique source rows appended (old rows untouched)
  _triage/FXDREEMA_XRAY.md          -- new-unique source cards appended in a marked section
  _triage/ORDER091A_BINARIES.csv    -- binary (.ex4/.ex5) hash inventory for the 8 folders
  _triage/ORDER091A_REPORTS.csv     -- attached report/set inventory (BOT MOGUL + .Final EA)
  _triage/ORDER091A_COVERAGE.md     -- per-folder coverage table + headline counts

Usage:
  tools\\python312\\python.exe scripts\\order091a_intake.py
"""
import csv
import hashlib
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fxdreema_xray import read_text, parse_ea, fmt_card, SIGNATURE  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
XRAY_CSV = os.path.join(REPO, "_triage", "FXDREEMA_XRAY.csv")
XRAY_MD = os.path.join(REPO, "_triage", "FXDREEMA_XRAY.md")
BIN_CSV = os.path.join(REPO, "_triage", "ORDER091A_BINARIES.csv")
REPORT_CSV = os.path.join(REPO, "_triage", "ORDER091A_REPORTS.csv")
COVERAGE_MD = os.path.join(REPO, "_triage", "ORDER091A_COVERAGE.md")

FOLDERS = [
    ("wait_Fxdreema MT5", r"D:\Forex\01_INBOX_NEW\2.1 review EA\wait_Fxdreema MT5"),
    ("3. ready to use", r"D:\Forex\01_INBOX_NEW\2.1 review EA\3. ready to use"),
    ("review EA-Jobot", r"D:\Forex\01_INBOX_NEW\2.1 review EA\Jobot"),
    ("BOT MOGUL Bundles", r"D:\Forex\10_EA_PROJECTS\0. Jobot\1000+ EA BOT MOGUL Bundles"),
    ("AI_GEN", r"D:\Forex\10_EA_PROJECTS\0. Jobot\AI_GEN"),
    ("Course jobot", r"D:\Forex\10_EA_PROJECTS\0. Jobot\Course jobot"),
    ("04_FxDreema_Learner", r"D:\Forex\50_KNOWLEDGE\04_FxDreema_Learner"),
    (".Final EA", r"D:\Forex\10_EA_PROJECTS\.Final EA"),
]
USER_EXPECTED = {
    "wait_Fxdreema MT5": "~151 src",
    "3. ready to use": "~38 src + 102 bin",
    "review EA-Jobot": "~1,556 bin",
    "BOT MOGUL Bundles": "~2,905 bin incl ~713 attached reports/sets",
    "AI_GEN": "~168 src",
    "Course jobot": "~375 src",
    "04_FxDreema_Learner": "~221 src",
    ".Final EA": "~189 src + ~4,514 bin incl ~389 attached reports",
}

# Two more copies of the BOT MOGUL bundle exist elsewhere (per ORDER-091 spec note).
# NOT scanned here (hash-dedupe would collapse them into the same unique set anyway;
# scanning 3x the binaries for zero new information is not mechanical, it's wasteful).
# Recorded for the coverage report only.
BUNDLE_DUP_CANDIDATES = [
    r"D:\Forex\50_KNOWLEDGE\02_Courses\File\1000+ EA BOT MOGUL Bundles",
    r"D:\Forex\50_KNOWLEDGE\02_Courses\File\0. Jobot\1000+ EA BOT MOGUL Bundles",
]

SRC_EXT = {".mq4", ".mq5"}
BIN_EXT = {".ex4", ".ex5"}
REPORT_FOLDERS = {"BOT MOGUL Bundles", ".Final EA"}
REPORT_EXT = {".htm", ".html", ".set"}
SKIP_DIR_NAMES = {"node_modules", ".git", "__pycache__", "$recycle.bin", "system volume information"}

CSV_FIELDS = ["name", "platform", "size_kb", "lines", "blocks", "n_inputs",
              "indicators", "open_blocks", "pending", "close_blocks", "raw_trade_calls",
              "has_sl", "has_tp", "lot_escalation", "flags", "n_copies", "path", "concept"]


def sha1_bytes(b):
    return hashlib.sha1(b).hexdigest()


def sha1_text(text):
    return hashlib.sha1(text.encode("utf-8", "replace")).hexdigest()


def walk(root):
    for dirpath, dirnames, filenames in os.walk(
            root, onerror=lambda e: print("WALK ERROR: %s" % e, file=sys.stderr)):
        dirnames[:] = [d for d in dirnames if d.lower() not in SKIP_DIR_NAMES]
        for fn in filenames:
            yield os.path.normpath(os.path.join(dirpath, fn))


def load_existing_hashes():
    """Re-hash the canonical path of every existing CSV row -> set of known hashes.
    The existing CSV has no persisted hash column (verified: 18 cols, none named hash) --
    this rehash reproduces the same sha1-of-decoded-text the original xray run used."""
    with open(XRAY_CSV, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    hashes = set()
    unreadable = []
    for r in rows:
        p = r["path"]
        try:
            text = read_text(p)
        except OSError as e:
            unreadable.append((p, str(e)))
            continue
        hashes.add(sha1_text(text))
    return hashes, rows, unreadable


def bundle_dup_note():
    lines = []
    for root in BUNDLE_DUP_CANDIDATES:
        if not os.path.isdir(root):
            lines.append("  - NOT FOUND: `%s`" % root)
            continue
        n = 0
        for _ in walk(root):
            n += 1
        lines.append("  - `%s` -- %d files (NOT scanned; hash-dedupe would collapse into the primary copy)" % (root, n))
    return lines


def main():
    t0 = time.time()
    print("=== ORDER-091A intake starting %s ===" % time.strftime("%Y-%m-%d %H:%M:%S"), file=sys.stderr)
    existing_hashes, existing_rows, unreadable_existing = load_existing_hashes()
    print("existing catalog: %d rows -> %d unique hashes rehashed (%d unreadable)"
          % (len(existing_rows), len(existing_hashes), len(unreadable_existing)), file=sys.stderr)

    per_folder = {}
    new_src_by_hash = {}      # hash -> {"paths":[...], "text":..., "size":..., "folder":...}
    bin_rows = []
    report_rows = []
    bin_hash_seen = {}        # hash -> first path (within this scan)
    src_name_registry = {}    # (dirname_lower, basename_noext_lower) -> full path
    anomalies = []

    for label, root in FOLDERS:
        stats = {"files": 0, "src": 0, "bin": 0, "reports": 0, "other": 0,
                 "new_unique": 0, "dup_existing": 0, "dup_within_new": 0, "unreadable": 0}
        if not os.path.isdir(root):
            anomalies.append("MISSING FOLDER: %s (%s)" % (label, root))
            per_folder[label] = stats
            continue
        print("\n=== scanning %s ===\n    %s" % (label, root), file=sys.stderr)

        # pass 1 (cheap, names only): register source basenames for binary-twin detection
        for full in walk(root):
            ext = os.path.splitext(full)[1].lower()
            if ext in SRC_EXT:
                key = (os.path.dirname(full).lower(), os.path.splitext(os.path.basename(full))[0].lower())
                src_name_registry[key] = full

        n = 0
        for full in walk(root):
            n += 1
            stats["files"] += 1
            ext = os.path.splitext(full)[1].lower()
            if n % 1000 == 0:
                print("  ...%d files scanned (%.0fs elapsed)" % (n, time.time() - t0), file=sys.stderr)

            if ext in SRC_EXT:
                stats["src"] += 1
                try:
                    text = read_text(full)
                except OSError as e:
                    stats["unreadable"] += 1
                    anomalies.append("UNREADABLE SRC: %s (%s)" % (full, e))
                    continue
                h = sha1_text(text)
                if h in existing_hashes:
                    stats["dup_existing"] += 1
                    continue
                if h in new_src_by_hash:
                    new_src_by_hash[h]["paths"].append(full)
                    stats["dup_within_new"] += 1
                    continue
                new_src_by_hash[h] = {"paths": [full], "text": text,
                                       "size": os.path.getsize(full), "folder": label}
                stats["new_unique"] += 1

            elif ext in BIN_EXT:
                stats["bin"] += 1
                try:
                    with open(full, "rb") as fh:
                        raw = fh.read()
                except OSError as e:
                    stats["unreadable"] += 1
                    anomalies.append("UNREADABLE BIN: %s (%s)" % (full, e))
                    continue
                h = sha1_bytes(raw)
                dup_status = "unique"
                if h in bin_hash_seen:
                    dup_status = "dup-of: %s" % bin_hash_seen[h]
                else:
                    bin_hash_seen[h] = full
                twin_key = (os.path.dirname(full).lower(), os.path.splitext(os.path.basename(full))[0].lower())
                twin = src_name_registry.get(twin_key, "")
                bin_rows.append({
                    "path": full, "name": os.path.basename(full), "folder": label,
                    "size_bytes": len(raw), "sha1": h, "dedup": dup_status,
                    "compiled_twin_of_source": twin,
                })

            elif label in REPORT_FOLDERS and ext in REPORT_EXT:
                stats["reports"] += 1
                report_rows.append({
                    "path": full, "parent_ea_folder": os.path.basename(os.path.dirname(full)),
                    "type": ext.lstrip("."), "scan_folder": label,
                })
            else:
                stats["other"] += 1

        per_folder[label] = stats
        print("  folder done: %s" % stats, file=sys.stderr)

    # ---------------- build cards for new-unique sources -------------------------
    new_entries = []   # (name, platform, paths, size, d, is_fxdreema, folder)
    for h, e in new_src_by_hash.items():
        paths = sorted(e["paths"], key=lambda p: (len(p), p.lower()))
        name = os.path.splitext(os.path.basename(paths[0]))[0].strip()
        platform = os.path.splitext(paths[0])[1].lstrip(".").lower()
        d = parse_ea(e["text"])
        is_fxd = SIGNATURE in e["text"].lower()
        new_entries.append((name, platform, paths, e["size"], d, is_fxd, e["folder"]))
    new_entries.sort(key=lambda t: t[0].lower())
    print("\nnew-unique source cards built: %d" % len(new_entries), file=sys.stderr)

    # ---------------- CSV: append new rows (schema-identical, concept blank) -----
    with open(XRAY_CSV, "a", encoding="utf-8-sig", newline="") as fh:
        w = csv.writer(fh)
        for name, platform, paths, size, d, is_fxd, folder in new_entries:
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
                ";".join(d["flags"]), len(paths), paths[0], "",
            ])
    print("appended %d rows to %s" % (len(new_entries), XRAY_CSV), file=sys.stderr)

    # ---------------- MD: append new cards in a clearly marked section -----------
    with open(XRAY_MD, "a", encoding="utf-8") as fh:
        fh.write("\n\n---\n\n# ORDER-091A APPEND (%s)\n\n"
                  % time.strftime("%Y-%m-%d"))
        fh.write("%d additional unique EA cards from the 8 Wave-0 intake folders "
                  "(content-hash deduped against the %d cards above). "
                  "New corpus total: %d unique EAs. Still raw data -- no verdicts.\n\n---\n\n"
                  % (len(new_entries), len(existing_rows), len(existing_rows) + len(new_entries)))
        for name, platform, paths, size, d, is_fxd, folder in new_entries:
            card = fmt_card(name, platform, paths, size, d)
            if not is_fxd:
                card = card.replace(
                    "## %s\n" % name,
                    "## %s  _(non-fxDreema source -- generic parse, SL/escalation via regex heuristic; spot-check before trusting)_\n" % name,
                    1)
            fh.write(card)
            fh.write("\n---\n\n")
    print("appended %d cards to %s" % (len(new_entries), XRAY_MD), file=sys.stderr)

    # ---------------- binaries CSV -------------------------------------------------
    with open(BIN_CSV, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["path", "name", "folder", "size_bytes", "sha1",
                                            "dedup", "compiled_twin_of_source"])
        w.writeheader()
        for r in bin_rows:
            w.writerow(r)
    print("wrote %d binary rows to %s" % (len(bin_rows), BIN_CSV), file=sys.stderr)

    # ---------------- reports CSV ---------------------------------------------------
    with open(REPORT_CSV, "w", encoding="utf-8-sig", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["path", "parent_ea_folder", "type", "scan_folder"])
        w.writeheader()
        for r in report_rows:
            w.writerow(r)
    print("wrote %d report rows to %s" % (len(report_rows), REPORT_CSV), file=sys.stderr)

    # ---------------- coverage report -----------------------------------------------
    lines = []
    lines.append("# ORDER-091A COVERAGE (Wave 0 of ORDER-091 master plan)\n")
    lines.append("Generated by `scripts/order091a_intake.py` on %s. Mechanical inventory only "
                 "-- no verdicts, no EA reads beyond the deterministic parser.\n" % time.strftime("%Y-%m-%d"))
    lines.append("## Per-folder coverage\n")
    lines.append("| folder | files found | src | bin | reports | new-unique src | dup-of-existing | dup-within-new | unreadable | user-expected |")
    lines.append("|---|---|---|---|---|---|---|---|---|---|")
    tot = {"files": 0, "src": 0, "bin": 0, "reports": 0, "new_unique": 0,
           "dup_existing": 0, "dup_within_new": 0, "unreadable": 0}
    for label, _ in FOLDERS:
        s = per_folder[label]
        for k in tot:
            tot[k] += s[k]
        lines.append("| %s | %d | %d | %d | %d | %d | %d | %d | %d | %s |" % (
            label, s["files"], s["src"], s["bin"], s["reports"],
            s["new_unique"], s["dup_existing"], s["dup_within_new"], s["unreadable"],
            USER_EXPECTED.get(label, "")))
    lines.append("| **TOTAL** | **%d** | **%d** | **%d** | **%d** | **%d** | **%d** | **%d** | **%d** | |" % (
        tot["files"], tot["src"], tot["bin"], tot["reports"],
        tot["new_unique"], tot["dup_existing"], tot["dup_within_new"], tot["unreadable"]))

    lines.append("\n## Merged catalog total\n")
    lines.append("- Existing (pre-091A): **%d** unique EAs (`_triage/FXDREEMA_XRAY.csv`, ORDER-074/077)" % len(existing_rows))
    lines.append("- New-unique from Wave 0: **%d**" % len(new_entries))
    lines.append("- **Merged total: %d unique EAs**" % (len(existing_rows) + len(new_entries)))
    lines.append("- Binary inventory rows written: **%d** (`_triage/ORDER091A_BINARIES.csv`)" % len(bin_rows))
    lines.append("- Attached report/set inventory rows written: **%d** (`_triage/ORDER091A_REPORTS.csv`)" % len(report_rows))

    lines.append("\n## Top new-EA clusters by folder (all 8 -- fewer than 10 folders exist)\n")
    lines.append("| rank | folder | new-unique EAs |")
    lines.append("|---|---|---|")
    ranked = sorted(((label, per_folder[label]["new_unique"]) for label, _ in FOLDERS),
                     key=lambda kv: -kv[1])
    for i, (label, cnt) in enumerate(ranked, 1):
        lines.append("| %d | %s | %d |" % (i, label, cnt))

    lines.append("\n## BOT MOGUL bundle duplicate copies (NOT scanned -- per spec note)\n")
    lines.extend(bundle_dup_note())

    lines.append("\n## Anomalies\n")
    if not anomalies and not unreadable_existing:
        lines.append("(none)")
    else:
        for a in anomalies[:200]:
            lines.append("- %s" % a)
        if len(anomalies) > 200:
            lines.append("- ... (+%d more, see script stderr log)" % (len(anomalies) - 200))
        if unreadable_existing:
            lines.append("- %d existing-catalog canonical paths could not be reread for hash-verification "
                          "(moved/renamed since ORDER-074? not touched by this order):" % len(unreadable_existing))
            for p, e in unreadable_existing[:20]:
                lines.append("  - `%s` (%s)" % (p, e))

    lines.append("\n## Runtime\n")
    lines.append("Total elapsed: %.1f minutes\n" % ((time.time() - t0) / 60))

    with open(COVERAGE_MD, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")
    print("\nwrote %s" % COVERAGE_MD, file=sys.stderr)
    print("=== DONE in %.1f min ===" % ((time.time() - t0) / 60), file=sys.stderr)


if __name__ == "__main__":
    main()
