#!/usr/bin/env python3
import argparse, bisect, csv, hashlib, json, math, subprocess
from collections import deque
from datetime import date, datetime, timedelta, timezone
from pathlib import Path

CLASSIFIER_ID = "BOSS19_P4_REGIME_CLASSIFIER_V1"
CLASSIFIER_VERSION = "1.0.0"
BUILDER_VERSION = "1.0.0"
START = datetime(2020, 1, 1, tzinfo=timezone.utc)
END = datetime(2026, 1, 1, tzinfo=timezone.utc)
TF_MINUTES = {"M15": 15, "H1": 60, "H4": 240}
SYMBOLS = ["XAUUSD", "EURUSD", "GBPUSD", "AUDUSD", "USDJPY", "BTCUSD"]
TFS = ["M15", "H1", "H4"]
MACRO_NAMES = ["AUDJPY", "USDJPY", "VIX", "DXY", "XAUUSD", "BTCUSD", "US10Y_JP10Y", "COPPER"]
MRIS_SHA = "84a20e03e5babebc95a116fa808d808316c2df3b55d0d9f82e28a44b693a0da0"
BAROMETERS_SHA = "0ea8a658d625e1f1317ea8a2095a55befc84ba5a7bc07da08192f2cc30e49347"
FRAMEWORK_BLOB = "7fe7ffcd26bcf9b62aca91cd6ca223e14053c5f8"
METHOD_BLOB = "d709c129ee3c7846307be3dfaed7147bbbda419b"
MACRO_MANIFEST_SHA = "7268f3d71c33fd882823570fb35791b5fc956b27fa7829b7cb7ddfc2c803f01a"
LOCAL_MANIFEST_SHA = "3a88ed02d8a2f6a244ab78c4c9c1a0545a7b6c6761cc736071b9abb471bd0fb4"

def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def iso(dt: datetime | None) -> str:
    return "" if dt is None else dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def fnum(value) -> str:
    if value is None or not math.isfinite(float(value)):
        return ""
    return format(float(value), ".12g")


def mris_output_ri(value):
    return None if value is None else round(float(value), 3)


def canonical_json(path: Path, value) -> str:
    text = json.dumps(value, sort_keys=True, indent=2, ensure_ascii=True) + "\n"
    path.write_text(text, encoding="utf-8", newline="\n")
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def git_blob(repo: Path, rel: str) -> str:
    return subprocess.check_output(["git", "-C", str(repo), "rev-parse", f"HEAD:{rel}"], text=True).strip()

class Fenwick:
    def __init__(self, values):
        self.values = sorted(set(values))
        self.index = {v: i + 1 for i, v in enumerate(self.values)}
        self.tree = [0] * (len(self.values) + 1)
        self.total = 0

    def add(self, value, delta):
        i = self.index[value]
        self.total += delta
        while i < len(self.tree):
            self.tree[i] += delta
            i += i & -i

    def kth(self, rank):
        if rank < 1 or rank > self.total:
            raise ValueError("rank outside Fenwick population")
        idx = 0
        bit = 1 << (len(self.tree).bit_length() - 1)
        while bit:
            nxt = idx + bit
            if nxt < len(self.tree) and self.tree[nxt] < rank:
                idx = nxt
                rank -= self.tree[nxt]
            bit >>= 1
        return self.values[idx]

    def quantile(self, p):
        return self.kth(math.ceil(p * self.total))

def load_daily(path: Path):
    rows = []
    with path.open("r", encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            rows.append({"date": date.fromisoformat(r["utc_date"]), "open": float(r["open"]),
                         "high": float(r["high"]), "low": float(r["low"]), "close": float(r["close"])})
    if any(rows[i]["date"] >= rows[i + 1]["date"] for i in range(len(rows) - 1)):
        raise ValueError(f"daily dates not strictly increasing: {path}")
    trs = []
    for i, r in enumerate(rows):
        prev = rows[i - 1]["close"] if i else r["close"]
        trs.append(max(r["high"] - r["low"], abs(r["high"] - prev), abs(r["low"] - prev)))
    for i, r in enumerate(rows):
        r["sma200"] = sum(x["close"] for x in rows[i - 199:i + 1]) / 200 if i >= 199 else None
        r["atr20"] = sum(trs[i - 19:i + 1]) / 20 if i >= 19 else None
        r["r5"] = ((r["close"] / rows[i - 5]["close"]) - 1.0) * 100.0 if i >= 5 and rows[i - 5]["close"] else None
        r["usable"] = r["sma200"] is not None and r["atr20"] is not None and r["r5"] is not None
    return rows


def macro_signal(name, row, vix_row):
    c, sma, atr, r5 = row["close"], row["sma200"], row["atr20"], row["r5"]
    flags = []
    if name == "AUDJPY":
        b = c < sma; f = r5 <= -3.0 * atr / c * 100.0
        return (-2.0 if b and f else -1.5 if f else -1.0 if b else 1.0 if r5 >= 0 else 0.5), flags
    if name == "USDJPY":
        f = r5 <= -2.0 * atr / c * 100.0
        if f: return -2.0, flags
        if c >= 158: flags.append("LOADED_FUSE"); return 0.5, flags
        return 0.0, flags
    if name == "VIX":
        if c >= 30: flags.append("VIX_STRESS"); return -2.0, flags
        if c >= 20: return -1.0, flags
        if c <= 15: return 1.0, flags
        return 0.0, flags
    if name == "DXY": return (-1.0 if r5 >= 1.5 else 0.0), flags
    if name == "XAUUSD":
        vr5 = vix_row["r5"] if vix_row and vix_row.get("usable") else None
        return (-1.0 if r5 >= 1.0 and vr5 is not None and vr5 >= 10.0 else 0.0), flags
    if name in {"BTCUSD", "COPPER"}:
        b = c < sma; f = r5 <= -3.0
        return (-2.0 if b and f else -1.5 if f else -1.0 if b else 1.0 if r5 >= 0 else 0.5), flags
    if name == "US10Y_JP10Y":
        bp5 = (c - c / (1.0 + r5 / 100.0)) * 100.0
        return (-1.0 if bp5 <= -15 else 0.5 if bp5 >= 15 else 0.0), flags
    raise ValueError(f"unknown macro series {name}")

def build_macro_events(macro_root: Path, manifest):
    series = {}; meta = {x["logical"]: x for x in manifest["series"]}
    for name in MACRO_NAMES:
        p = macro_root / meta[name]["normalized_file"]
        if sha256_file(p) != meta[name]["normalized_sha256"]: raise ValueError(f"macro hash mismatch {name}")
        series[name] = load_daily(p)
    dates = sorted({r["date"] for rows in series.values() for r in rows})
    ptr = {name: -1 for name in MACRO_NAMES}; weights = {"AUDJPY":3,"USDJPY":2,"VIX":2,"DXY":1,"XAUUSD":1,"BTCUSD":1,"US10Y_JP10Y":2,"COPPER":1}
    events = []
    for d in dates:
        snap = {}
        for name in MACRO_NAMES:
            rows = series[name]; i = ptr[name]
            while i + 1 < len(rows) and rows[i + 1]["date"] <= d: i += 1
            ptr[name] = i
            if i >= 0 and rows[i]["usable"]: snap[name] = rows[i]
        missing = sorted(set(MACRO_NAMES) - set(snap)); signals = {}; flags = []
        for name, row in snap.items():
            sig, fl = macro_signal(name, row, snap.get("VIX")); signals[name] = sig; flags.extend(fl)
        if not signals: state, ri, conf = "UNKNOWN", None, "LOW"
        else:
            wsum = sum(weights[n] for n in signals); ri = sum(signals[n] * weights[n] for n in signals) / wsum
            vix = snap.get("VIX"); vix_spot = vix["close"] if vix else None
            state = "STRESS" if (vix_spot is not None and vix_spot >= 30) or ri < -1.0 else "RISK_ON" if ri >= 0.5 else "NEUTRAL" if ri >= -0.25 else "RISK_OFF"
            nz = [v for v in signals.values() if v != 0]; sgn = 1 if ri >= 0 else -1
            frac = sum(1 for v in nz if (1 if v > 0 else -1) == sgn) / len(nz) if nz else 0.0
            conf = "HIGH" if frac >= .75 else "MED" if frac >= .50 else "LOW"
        eligible = datetime(d.year, d.month, d.day, tzinfo=timezone.utc) + timedelta(days=1)
        events.append((eligible, {"macro_state":state, "macro_as_of_utc":iso(eligible), "macro_source_date":d.isoformat(),
                                  "macro_ri":mris_output_ri(ri), "macro_confidence":conf, "macro_coverage":f"{len(signals)}/8",
                                  "macro_missing_inputs":";".join(missing), "macro_partial":len(signals)<8,
                                  "macro_flags":";".join(sorted(set(flags))) }))
    events = [(t, r) for t, r in events if t < END]
    with_expiry = []
    for i, (t, r) in enumerate(events):
        with_expiry.append((t, r)); nxt = events[i + 1][0] if i + 1 < len(events) else END
        expiry = t + timedelta(hours=120)
        if r["macro_state"] != "UNKNOWN" and expiry < nxt and expiry < END:
            u = dict(r); u.update({"macro_state":"UNKNOWN", "macro_ri":None, "macro_confidence":"LOW",
                                   "macro_coverage":"0/8", "macro_missing_inputs":"STALE_GT_120H", "macro_partial":True,
                                   "macro_flags":"MACRO_STALE_GT_120H"})
            with_expiry.append((expiry, u))
    with_expiry.sort(key=lambda x: x[0])
    return with_expiry


def load_local(path: Path, tf: str):
    bars=[]; delta=timedelta(minutes=TF_MINUTES[tf])
    with path.open("r",encoding="utf-8-sig",newline="") as f:
        for r in csv.DictReader(f):
            o=datetime.strptime(r["open_time_utc"],"%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
            bars.append({"open_time":o,"close_time":o+delta,"open":float(r["open"]),"high":float(r["high"]),"low":float(r["low"]),"close":float(r["close"])})
    if any(bars[i]["open_time"] >= bars[i+1]["open_time"] for i in range(len(bars)-1)): raise ValueError(f"local times not increasing {path}")
    return bars

def local_indicator_events(bars):
    n=len(bars); e20=[None]*n; e50=[None]*n; atr=[None]*n; dval=[None]*n; aval=[None]*n; vval=[None]*n
    a20=2.0/21.0; a50=2.0/51.0; tr=[]
    for i,b in enumerate(bars):
        c=b["close"]
        e20[i]=c if i==0 else a20*c+(1-a20)*e20[i-1]
        e50[i]=c if i==0 else a50*c+(1-a50)*e50[i-1]
        prev=bars[i-1]["close"] if i else c
        tr.append(max(b["high"]-b["low"],abs(b["high"]-prev),abs(b["low"]-prev)))
        if i==19: atr[i]=sum(tr[:20])/20.0
        elif i>19: atr[i]=(atr[i-1]*19.0+tr[i])/20.0
        if i>=49 and atr[i] is not None and atr[i]>0:
            dval[i]=(e20[i]-e50[i])/atr[i]; aval[i]=abs(dval[i])
        if atr[i] is not None and atr[i]>0 and c>0: vval[i]=100.0*atr[i]/c
    af=Fenwick([x for x in aval if x is not None]); vf=Fenwick([x for x in vval if x is not None])
    aq=deque(); vq=deque(); cross=[False]*n; events=[]
    for i in range(1,n):
        a,b=dval[i-1],dval[i]
        cross[i]=a is not None and b is not None and a!=b and (a==0 or b==0 or a*b<0)
    for i,b in enumerate(bars):
        t=b["close_time"]; cutoff=t-timedelta(days=252)
        while aq and aq[0][0] < cutoff: _,x=aq.popleft(); af.add(x,-1)
        while vq and vq[0][0] < cutoff: _,x=vq.popleft(); vf.add(x,-1)
        qtrend=af.quantile(.60) if af.total>=250 else None
        q20=vf.quantile(.20) if vf.total>=250 else None; q80=vf.quantile(.80) if vf.total>=250 else None; q95=vf.quantile(.95) if vf.total>=250 else None
        if dval[i] is None or qtrend is None:
            local="UNKNOWN"
        elif any(cross[max(1,i-3):i+1]):
            local="TRANSITION"
        elif dval[i] >= qtrend: local="TREND_UP"
        elif dval[i] <= -qtrend: local="TREND_DOWN"
        else: local="RANGE"
        if vval[i] is None or q20 is None:
            vol="UNKNOWN"
        elif vval[i] <= q20: vol="LOW"
        elif vval[i] <= q80: vol="NORMAL"
        elif vval[i] <= q95: vol="HIGH"
        else: vol="EXTREME"
        events.append((t,{"local_state":local,"local_bar_close_utc":iso(t),"local_d":dval[i],"local_qtrend":qtrend,
                          "vol_state":vol,"vol_bar_close_utc":iso(t),"vol_natr_pct":vval[i],"vol_q20":q20,"vol_q80":q80,"vol_q95":q95,
                          "local_unknown_reason":"" if local!="UNKNOWN" and vol!="UNKNOWN" else "INDICATOR_OR_CALIBRATION_UNAVAILABLE"}))
        if aval[i] is not None: af.add(aval[i],1); aq.append((t,aval[i]))
        if vval[i] is not None: vf.add(vval[i],1); vq.append((t,vval[i]))
    return events


def quarantine_starts(path: Path):
    dates=set()
    with path.open("r",encoding="utf-8-sig",newline="") as f:
        for r in csv.DictReader(f):
            if r.get("reason")!="UNKNOWN_DST_TRANSITION": raise ValueError(f"unexpected quarantine reason {path}")
            dates.add(datetime.strptime(r["time_server"],"%Y.%m.%d %H:%M:%S").date())
    return [datetime(d.year,d.month,d.day,tzinfo=timezone.utc)-timedelta(hours=3) for d in sorted(dates)]

FIELDS=["valid_from_utc","valid_to_utc","symbol","tf","macro_state","macro_as_of_utc","macro_source_date","macro_ri","macro_confidence",
        "macro_coverage","macro_missing_inputs","macro_partial","macro_flags","local_state","local_bar_close_utc","local_d","local_qtrend",
        "vol_state","vol_bar_close_utc","vol_natr_pct","vol_q20","vol_q80","vol_q95","local_unknown_reason","classification_status","classifier_id","classifier_version"]


def unknown_macro(reason="NO_PRIOR_ELIGIBLE_STATE"):
    return {"macro_state":"UNKNOWN","macro_as_of_utc":"","macro_source_date":"","macro_ri":None,"macro_confidence":"LOW",
            "macro_coverage":"0/8","macro_missing_inputs":reason,"macro_partial":True,"macro_flags":""}


def unknown_local(reason="NO_PRIOR_CLOSED_BAR"):
    return {"local_state":"UNKNOWN","local_bar_close_utc":"","local_d":None,"local_qtrend":None,
            "vol_state":"UNKNOWN","vol_bar_close_utc":"","vol_natr_pct":None,"vol_q20":None,"vol_q80":None,"vol_q95":None,
            "local_unknown_reason":reason}


def latest(events, t, default):
    times=[x[0] for x in events]; i=bisect.bisect_right(times,t)-1
    return dict(events[i][1]) if i>=0 else dict(default)


def write_cell(writer, symbol, tf, macro_events, local_events):
    mmap={t:r for t,r in macro_events}; lmap={t:r for t,r in local_events}
    times=sorted({START,END,*[t for t,_ in macro_events if START<t<END],*[t for t,_ in local_events if START<t<END]})
    m=latest(macro_events,START,unknown_macro()); l=latest(local_events,START,unknown_local())
    counts={"full":0,"partial":0,"unknown":0,"rows":0}; first=None; last=None
    for i,t in enumerate(times[:-1]):
        if t in mmap: m=dict(mmap[t])
        if t in lmap: l=dict(lmap[t])
        nxt=times[i+1]
        if nxt<=t: continue
        unknown=m["macro_state"]=="UNKNOWN" or l["local_state"]=="UNKNOWN" or l["vol_state"]=="UNKNOWN"
        status="UNKNOWN" if unknown else "CLASSIFIED"
        counts["unknown" if unknown else "partial" if m["macro_partial"] else "full"]+=1; counts["rows"]+=1
        row={"valid_from_utc":iso(t),"valid_to_utc":iso(nxt),"symbol":symbol,"tf":tf,"classification_status":status,
             "classifier_id":CLASSIFIER_ID,"classifier_version":CLASSIFIER_VERSION}
        row.update(m); row.update(l)
        for k in ("macro_ri","local_d","local_qtrend","vol_natr_pct","vol_q20","vol_q80","vol_q95"): row[k]=fnum(row[k])
        row["macro_partial"]="true" if row["macro_partial"] else "false"
        writer.writerow(row); first=first or t; last=nxt
    counts.update({"symbol":symbol,"tf":tf,"first_timestamp":iso(first),"last_timestamp":iso(last)})
    return counts


def combined_local_events(local_root:Path, cell):
    norm=local_root/cell["normalized_file"]; q=local_root/cell["quarantine_file"]
    if sha256_file(norm)!=cell["normalized_sha256"] or sha256_file(q)!=cell["quarantine_sha256"]: raise ValueError(f"local hash mismatch {cell['symbol']}/{cell['tf']}")
    events=local_indicator_events(load_local(norm,cell["tf"])); mapping={t:r for t,r in events}
    for t in quarantine_starts(q): mapping[t]=unknown_local("DST_QUARANTINE_ENVELOPE")
    return sorted(mapping.items(),key=lambda x:x[0])


def verify_contract_sources(repo:Path):
    if sha256_file(repo/"scripts/mris/mris_classify.ps1")!=MRIS_SHA: raise ValueError("MRIS source hash drift")
    if sha256_file(repo/"scripts/mris/barometers.json")!=BAROMETERS_SHA: raise ValueError("barometers hash drift")
    subprocess.check_call(["git","-C",str(repo),"cat-file","-e",FRAMEWORK_BLOB+"^{blob}"])
    subprocess.check_call(["git","-C",str(repo),"cat-file","-e",METHOD_BLOB+"^{blob}"])

def build(args):
    repo=Path(args.repo).resolve(); macro_root=Path(args.macro_root).resolve(); local_root=Path(args.local_root).resolve(); out=Path(args.out).resolve()
    out.mkdir(parents=True,exist_ok=True); verify_contract_sources(repo)
    macro_path=macro_root/"macro_manifest.json"; local_path=local_root/"local_ohlc_manifest.json"
    if sha256_file(macro_path)!=MACRO_MANIFEST_SHA: raise ValueError("macro manifest identity mismatch")
    if sha256_file(local_path)!=LOCAL_MANIFEST_SHA: raise ValueError("local manifest identity mismatch")
    macro_manifest=json.loads(macro_path.read_text(encoding="utf-8")); local_manifest=json.loads(local_path.read_text(encoding="utf-8"))
    if local_manifest.get("tester_model")!=1 or local_manifest.get("optimization")!=0 or local_manifest.get("holdout_included") is not False: raise ValueError("local evidence authority mismatch")
    cells={(c["symbol"],c["tf"]):c for c in local_manifest["cells"]}
    if set(cells)!={(s,t) for s in SYMBOLS for t in TFS}: raise ValueError("local 18-cell matrix mismatch")
    input_manifest={"schema_version":"BOSS19_P4_MARKET_INPUT_MANIFEST_V1","macro_manifest_sha256":MACRO_MANIFEST_SHA,
                    "local_manifest_sha256":LOCAL_MANIFEST_SHA,"macro_calendar_rule":"UNION_OF_EIGHT_COMPLETED_UTC_SOURCE_DATES",
                    "local_timestamp_basis":local_manifest["timestamp_basis"],"local_missing_bar_policy":local_manifest["missing_bar_policy"],
                    "holdout_included":False,"attribution_range_utc":"2020-01-01T00:00:00Z..2026-01-01T00:00:00Z_EXCLUSIVE"}
    input_sha=canonical_json(out/"market_input_manifest.json",input_manifest)
    macro_events=build_macro_events(macro_root,macro_manifest); coverage=[]; timeline=out/"classifier_timeline.csv"
    with timeline.open("w",encoding="utf-8",newline="") as f:
        writer=csv.DictWriter(f,fieldnames=FIELDS,lineterminator="\n",quoting=csv.QUOTE_MINIMAL); writer.writeheader()
        for symbol in SYMBOLS:
            for tf in TFS:
                coverage.append(write_cell(writer,symbol,tf,macro_events,combined_local_events(local_root,cells[(symbol,tf)])))
    timeline_sha=sha256_file(timeline); row_count=sum(c["rows"] for c in coverage)
    created=args.created_utc or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    manifest={"schema_version":"BOSS19_P4_CLASSIFIER_TIMELINE_MANIFEST_V1","classifier_id":CLASSIFIER_ID,"classifier_version":CLASSIFIER_VERSION,
              "classifier_contract_path":"docs/research/BOSS19_P4_REGIME_CLASSIFIER_V1.md","classifier_contract_git_blob":git_blob(repo,"docs/research/BOSS19_P4_REGIME_CLASSIFIER_V1.md"),
              "mris_source_sha256":MRIS_SHA,"barometers_config_sha256":BAROMETERS_SHA,"regime_framework_git_blob":FRAMEWORK_BLOB,"method_source_git_blob":METHOD_BLOB,
              "raw_market_input_manifest_sha256":input_sha,"macro_manifest_sha256":MACRO_MANIFEST_SHA,"local_manifest_sha256":LOCAL_MANIFEST_SHA,
              "semantic_decisions":{"macro_calendar":"UNION_OF_EIGHT_COMPLETED_UTC_SOURCE_DATES","macro_semantic_review":"PASS_UNION_CALENDAR",
                                    "ema_seed":"FIRST_CLOSE_CONVENTIONAL","ema_seed_sensitivity":"EXACT_EQUIVALENCE_2020_2025_ALL_18_CELLS"},
              "timeline_file":"classifier_timeline.csv","timeline_sha256":timeline_sha,"serialization":{"format":"CSV","encoding":"UTF-8","line_endings":"LF","quoting":"RFC4180_MINIMAL","columns":FIELDS},
              "row_count":row_count,"first_timestamp":min(c["first_timestamp"] for c in coverage),"last_timestamp":max(c["last_timestamp"] for c in coverage),
              "cell_coverage":coverage,"builder_version":BUILDER_VERSION,"builder_sha256":sha256_file(Path(__file__)),
              "creation_command":"python tools/boss19_p4b_timeline/build_timeline.py --repo <REPO> --macro-root <PINNED_MACRO_PACKAGE> --local-root <PINNED_LOCAL_PACKAGE> --out <OUTPUT>",
              "created_utc":created,"h3_outcome_content_opened":False,"holdout_included":False}
    msha=canonical_json(out/"classifier_timeline_manifest.json",manifest)
    (out/"classifier_timeline_manifest.sha256").write_text(msha+"  classifier_timeline_manifest.json\n",encoding="ascii",newline="\n")
    print(f"P4_TIMELINE_PASS rows={row_count} timeline_sha256={timeline_sha} manifest_sha256={msha} input_manifest_sha256={input_sha}")
    return manifest


def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--repo",required=True); ap.add_argument("--macro-root",required=True); ap.add_argument("--local-root",required=True); ap.add_argument("--out",required=True); ap.add_argument("--created-utc")
    args=ap.parse_args(); build(args)


if __name__=="__main__": main()
