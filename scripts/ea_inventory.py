#!/usr/bin/env python3
"""ea_inventory.py - catalog a messy downloaded-EA folder tree.

Walks the tree, hashes every file (dedupe), classifies by extension +
cheap content sniff (mq4/mq5 source: grid/martingale keywords, EA vs
indicator vs script), writes one CSV. Deterministic - no LLM needed.

Usage: python ea_inventory.py "<root>" "<out.csv>"
"""
import csv
import hashlib
import re
import sys
from pathlib import Path

EA_EXT = {'.mq4', '.mq5', '.ex4', '.ex5'}
SKIP_EXT = {'.zip', '.rar', '.7z'}  # archives already extracted per user

GRID_PAT = re.compile(r'martingale|grid|recovery|averag|lotmult|multiplier\s*=|hedge', re.I)
IND_PAT = re.compile(r'#property\s+indicator|OnCalculate', re.I)
SCRIPT_PAT = re.compile(r'#property\s+script|OnStart', re.I)
EA_PAT = re.compile(r'OnTick|OrderSend|trade\.Buy|trade\.Sell|CTrade', re.I)


def sniff(path):
    try:
        txt = path.read_text(encoding='utf-8', errors='replace')[:60000]
    except OSError:
        return 'unreadable', ''
    if IND_PAT.search(txt) and not EA_PAT.search(txt):
        kind = 'indicator-src'
    elif SCRIPT_PAT.search(txt) and not EA_PAT.search(txt):
        kind = 'script-src'
    elif EA_PAT.search(txt):
        kind = 'ea-src'
    else:
        kind = 'other-src'
    flags = 'grid' if GRID_PAT.search(txt) else ''
    return kind, flags


def main():
    root, out = Path(sys.argv[1]), sys.argv[2]
    rows, seen = [], {}
    for p in root.rglob('*'):
        if not p.is_file():
            continue
        ext = p.suffix.lower()
        if ext in SKIP_EXT:
            kind, flags = 'archive', ''
        try:
            h = hashlib.md5(p.read_bytes()).hexdigest()
        except OSError:
            h = 'READ_ERROR'
        dup_of = seen.get(h, '')
        if not dup_of and h != 'READ_ERROR':
            seen[h] = str(p)
        kind, flags = 'other', ''
        if ext in ('.mq4', '.mq5'):
            kind, flags = sniff(p)
        elif ext in ('.ex4', '.ex5'):
            kind = 'compiled'
        elif ext == '.pdf':
            kind = 'pdf'
        elif ext in ('.set', '.ini'):
            kind = 'settings'
        elif ext in SKIP_EXT:
            kind = 'archive'
        rows.append({
            'path': str(p.relative_to(root)), 'ext': ext, 'kb': p.stat().st_size // 1024,
            'kind': kind, 'flags': flags, 'md5': h, 'dup_of': dup_of,
        })
    with open(out, 'w', newline='', encoding='utf-8-sig') as f:
        w = csv.DictWriter(f, fieldnames=['path', 'ext', 'kb', 'kind', 'flags', 'md5', 'dup_of'])
        w.writeheader()
        w.writerows(rows)
    # summary
    from collections import Counter
    kinds = Counter(r['kind'] for r in rows)
    dups = sum(1 for r in rows if r['dup_of'])
    grids = sum(1 for r in rows if r['flags'] == 'grid' and r['kind'] == 'ea-src')
    print(f'total files: {len(rows)} | duplicates: {dups} | unique: {len(rows)-dups}')
    for k, n in kinds.most_common():
        print(f'  {k:>14}: {n}')
    print(f'  ea-src flagged grid/martingale: {grids}')


if __name__ == '__main__':
    main()
