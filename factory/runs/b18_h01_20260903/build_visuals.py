#!/usr/bin/env python3
import json
from pathlib import Path
from html import escape

PKG = Path(__file__).resolve().parent
OUT = PKG / "visuals"
OUT.mkdir(exist_ok=True)
S = json.loads((PKG / "summary.json").read_text(encoding="utf-8"))

def svg_open(title, w=760, h=360):
    return [f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">',
            '<rect width="100%" height="100%" fill="white"/>',
            f'<text x="30" y="36" font-family="sans-serif" font-size="22">{escape(title)}</text>']

def text(x, y, value, size=14, anchor="start"):
    return f'<text x="{x}" y="{y}" font-family="sans-serif" font-size="{size}" text-anchor="{anchor}">{escape(str(value))}</text>'

def write(name, lines):
    (OUT / name).write_text("\n".join(lines + ["</svg>", ""]), encoding="utf-8")

def heatmap(metric, label, fmt, name):
    lines = svg_open(label)
    for i, window in enumerate(("MAIN", "BWD")):
        x = 120 + i * 300
        value = S[window][metric]
        shade = 235 if i == 0 else 205
        lines += [text(x + 100, 82, window, 16, "middle"),
                  f'<rect x="{x}" y="110" width="200" height="130" fill="rgb({shade},{shade},{shade})" stroke="black"/>',
                  text(x + 100, 165, "XAUUSD / H1", 16, "middle"),
                  text(x + 100, 205, fmt(value), 24, "middle")]
    write(name, lines)

def scatter_pf_participation():
    lines = svg_open("PF vs active-month participation")
    x0, y0, w, h = 100, 290, 580, 190
    lines += [f'<line x1="{x0}" y1="{y0}" x2="{x0+w}" y2="{y0}" stroke="black"/>',
              f'<line x1="{x0}" y1="{y0}" x2="{x0}" y2="{y0-h}" stroke="black"/>',
              text(x0+w/2, 330, "Active-month share", 14, "middle"),
              text(35, y0-h/2, "PF", 14, "middle")]
    for window in ("MAIN", "BWD"):
        share = S[window]["active_month_share"]
        pf = S[window]["profit_factor"]
        x = x0 + share * w
        y = y0 - max(0, min(1.5, pf)) / 1.5 * h
        lines += [f'<circle cx="{x:.1f}" cy="{y:.1f}" r="7" fill="white" stroke="black"/>',
                  text(x-10, y-12, f"{window} PF={pf:.2f}", 13, "end")]
    write("pf_vs_participation.svg", lines)

def dd_scatter():
    lines = svg_open("Equity DD by validation window")
    x0, y0, w, h = 120, 290, 520, 190
    lines += [f'<line x1="{x0}" y1="{y0}" x2="{x0+w}" y2="{y0}" stroke="black"/>',
              f'<line x1="{x0}" y1="{y0}" x2="{x0}" y2="{y0-h}" stroke="black"/>']
    for i, window in enumerate(("MAIN", "BWD")):
        dd = S[window]["equity_drawdown_maximal_pct"]
        x = x0 + 150 + i * 250
        y = y0 - min(dd, 10.0) / 10.0 * h
        lines += [f'<circle cx="{x}" cy="{y:.1f}" r="8" fill="white" stroke="black"/>',
                  text(x, 320, window, 14, "middle"), text(x, y-14, f"{dd:.2f}%", 14, "middle")]
    write("dd_window_scatter.svg", lines)

heatmap("profit_factor", "R1 PF heatmap — XAUUSD / H1", lambda v: f"PF {v:.2f}", "pf_symbol_tf_heatmap.svg")
heatmap("active_month_share", "R1 participation heatmap — XAUUSD / H1", lambda v: f"{v:.0%} active months", "participation_heatmap.svg")
scatter_pf_participation()
dd_scatter()
print("VISUALS=4")
