#!/usr/bin/env python
"""chatgpt_export_inventory.py - inventory an OpenAI conversations export (ORDER-064).

Usage:
  python chatgpt_export_inventory.py <export.json> [--out inventory.csv] [--extract-dir DIR --top N]

Pass 1 (always): one CSV row per conversation - title, times, message count, total chars,
mql_hits (strategy-relevant keyword count). Sort by mql_hits desc.
Pass 2 (--extract-dir): dump the top-N conversations (by mql_hits) as readable .txt
(role: text blocks in tree order) so a subagent can skim them without JSON noise.
"""
import json, sys, csv, re, os, argparse

KEYWORDS = re.compile(
    r"OnTick|OnInit|OrderSend|CTrade|iATR|iMA\(|iRSI|iBands|MqlTick|StopLoss|TakeProfit|"
    r"mql[45]?|MetaTrader|MT[45]\b|backtest|EA\b|Expert Advisor|grid|martingale|hedg|"
    r"breakout|scalp|swing|indicator|strategy tester", re.IGNORECASE)


def conv_texts(conv):
    """Yield (role, text). Supports OpenAI export (mapping tree) AND Open WebUI export
    (conv.chat.messages list of {role, content:str})."""
    chat = conv.get("chat") or {}
    msgs = chat.get("messages") or []
    if msgs:  # Open WebUI format
        for m in msgs:
            content = m.get("content")
            if isinstance(content, str) and content.strip():
                yield m.get("role", "?"), content
        return
    mapping = conv.get("mapping") or {}
    for node in mapping.values():
        msg = node.get("message") or {}
        content = msg.get("content") or {}
        parts = content.get("parts") or []
        role = (msg.get("author") or {}).get("role", "?")
        for p in parts:
            if isinstance(p, str) and p.strip():
                yield role, p


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("export")
    ap.add_argument("--out", default="chatgpt_inventory.csv")
    ap.add_argument("--extract-dir")
    ap.add_argument("--top", type=int, default=10)
    a = ap.parse_args()

    print(f"loading {a.export} ...", flush=True)
    with open(a.export, "r", encoding="utf-8") as f:
        data = json.load(f)
    convs = data if isinstance(data, list) else data.get("conversations", [])
    print(f"conversations: {len(convs)}", flush=True)

    rows = []
    for i, c in enumerate(convs):
        title = (c.get("title") or "untitled").strip()
        n_msg, chars, hits = 0, 0, 0
        for role, t in conv_texts(c):
            n_msg += 1
            chars += len(t)
            hits += len(KEYWORDS.findall(t))
        rows.append({"idx": i, "title": title[:80], "messages": n_msg,
                     "chars": chars, "mql_hits": hits,
                     "create": str(c.get("create_time", ""))[:10],
                     "update": str(c.get("update_time", ""))[:10]})
    rows.sort(key=lambda r: -r["mql_hits"])
    with open(a.out, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)
    print(f"inventory -> {a.out}")
    for r in rows[:15]:
        print(f"  [{r['idx']:>3}] hits={r['mql_hits']:>5} msgs={r['messages']:>4} "
              f"chars={r['chars']:>8} | {r['title']}")

    if a.extract_dir:
        os.makedirs(a.extract_dir, exist_ok=True)
        for r in rows[: a.top]:
            c = convs[r["idx"]]
            safe = re.sub(r"[^\w\- ]", "_", r["title"])[:50].strip() or "untitled"
            path = os.path.join(a.extract_dir, f"{r['idx']:03d}_{safe}.txt")
            with open(path, "w", encoding="utf-8") as f:
                f.write(f"# {r['title']}  (msgs={r['messages']} chars={r['chars']} mql_hits={r['mql_hits']})\n\n")
                for role, t in conv_texts(c):
                    f.write(f"----- [{role}] -----\n{t}\n\n")
            print(f"extracted -> {path}")


if __name__ == "__main__":
    main()
