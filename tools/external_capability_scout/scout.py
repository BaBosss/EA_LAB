from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CATALOG_PATH = ROOT / "catalog_snapshot.json"
CAPABILITIES_PATH = ROOT / "ea_lab_capabilities.json"
DANGEROUS_SECTIONS = {"Brokerage / exchange trading", "Brokerage execution & portfolio"}
DANGEROUS_TERMS = {
    "live trading", "order placement", "private key", "wallet", "transaction broadcasting",
    "execute trades", "execution hook", "paper or live trading", "trade through", "exchange trading",
}


def read_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def tokens(text: str) -> set[str]:
    return {x for x in re.findall(r"[a-z0-9]+", text.lower()) if len(x) > 2}


def capability_match(query: str, entry: dict) -> int:
    q = tokens(query)
    corpus = " ".join([entry["capability"], *entry.get("aliases", [])])
    return len(q & tokens(corpus))


def catalog_score(query: str, entry: dict) -> int:
    q = tokens(query)
    corpus = " ".join([entry["name"], entry["category"], entry["section"], entry["description"]])
    return len(q & tokens(corpus))

def danger_reasons(entry: dict) -> list[str]:
    reasons = []
    if entry["section"] in DANGEROUS_SECTIONS:
        reasons.append("dangerous catalog section")
    lowered = entry["description"].lower()
    for term in sorted(DANGEROUS_TERMS):
        if term in lowered:
            reasons.append(f"description contains '{term}'")
    return reasons


def find_existing(query: str, capabilities: list[dict]) -> tuple[dict | None, int]:
    scored = [(capability_match(query, item), item) for item in capabilities]
    scored.sort(key=lambda pair: pair[0], reverse=True)
    if scored and scored[0][0] > 0:
        return scored[0][1], scored[0][0]
    return None, 0


def shortlist(query: str, entries: list[dict], limit: int = 5) -> list[dict]:
    scored = []
    for entry in entries:
        score = catalog_score(query, entry)
        if score <= 0:
            continue
        reasons = danger_reasons(entry)
        decision = "PARK_BLOCKED_BY_DESIGN" if reasons else "ADAPT_CANDIDATE"
        authority = "EXECUTION_EXPOSED" if reasons else "RESEARCH_ONLY_CANDIDATE"
        scored.append((score, entry["name"].lower(), {
            "name": entry["name"], "url": entry["url"], "category": entry["category"],
            "section": entry["section"], "description": entry["description"],
            "score": score, "authority_class": authority, "decision": decision,
            "security_reasons": reasons, "install_state": "NOT_INSTALLED",
        }))
    scored.sort(key=lambda row: (-row[0], row[1]))
    return [row[2] for row in scored[:limit]]

def scout(query: str, limit: int = 5) -> dict:
    catalog = read_json(CATALOG_PATH)
    capabilities_doc = read_json(CAPABILITIES_PATH)
    capabilities = capabilities_doc["entries"]
    existing, match_score = find_existing(query, capabilities)
    base = {
        "query": query,
        "catalog_upstream_sha": catalog["upstream_sha"],
        "catalog_readme_sha256": catalog["readme_sha256"],
        "catalog_license": catalog["license"],
        "catalog_entry_count": catalog["entry_count"],
        "automatic_install": False,
    }
    if existing and existing["status"] == "BLOCKED_BY_DESIGN":
        return {**base, "decision": "BLOCKED_BY_DESIGN", "existing": existing, "shortlist": []}
    if existing and existing["status"] in {"COVERED", "BUILDING"}:
        return {**base, "decision": "USE_EXISTING", "existing": existing, "shortlist": []}
    candidates = shortlist(query, catalog["entries"], limit=limit)
    return {
        **base,
        "decision": "SCOUT",
        "existing": existing,
        "existing_match_score": match_score,
        "shortlist": candidates,
        "next_step": "separate bounded capability-adoption review; no installation from scout",
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="EA_LAB external capability scout")
    parser.add_argument("query")
    parser.add_argument("--limit", type=int, default=5)
    args = parser.parse_args()
    print(json.dumps(scout(args.query, args.limit), indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
