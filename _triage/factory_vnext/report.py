# -*- coding: utf-8 -*-
"""Deterministic graph-first HTML report generator for Factory vNext.

This sidecar is intentionally non-authoritative. It renders evidence only and
never promotes Factory verdicts, grades, risk, deployment, or LIVE semantics.
"""
from __future__ import annotations

import hashlib
import html
import json
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple

from . import NON_AUTHORITATIVE
from .contracts import EVIDENCE_LABELS, canonical_json
from .derived_metrics import DerivedMetricsError, validate_metric_bundle
from .grade_confidence import GradeConfidenceError, validate_grade_evidence


class ReportError(ValueError):
    pass


SCHEMA_VERSION = "factory-vnext-report-v1"
AUTHORITY = "NON_AUTHORITATIVE_SIDECAR"
PAGE_IDS = (
    "overview",
    "trade-diagnostic",
    "optimization",
    "risk-recovery-hedge",
    "context-regime-broker",
)
IDENTITY_FIELDS = (
    "Strategy",
    "HomeContractID",
    "LogicalSymbol",
    "PhysicalSymbol",
    "ExecutionTF",
    "ProfileID",
    "BrokerData",
    "WindowContractID",
    "ParameterSetID",
    "RunID",
)


def _need_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ReportError("%s is required" % name)
    return value.strip()


def _stable_id(prefix: str, payload: Mapping[str, Any], hex_chars: int = 24) -> str:
    digest = hashlib.sha256(canonical_json(dict(payload)).encode("utf-8")).hexdigest()[:hex_chars]
    return "%s-%s" % (prefix, digest)


def _sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def _esc(value: Any) -> str:
    if value is None:
        return ""
    return html.escape(str(value), quote=True)


def _validate_identity(identity: Mapping[str, Any]) -> Dict[str, str]:
    if not isinstance(identity, Mapping):
        raise ReportError("identity must be a mapping")
    result = {field: _need_text(identity.get(field), field) for field in IDENTITY_FIELDS}
    if len(result["RunID"]) < 8:
        raise ReportError("RunID is too short")
    return result


def _validate_metric_bundle(metric_bundle: Mapping[str, Any]) -> Dict[str, Any]:
    if not isinstance(metric_bundle, Mapping):
        raise ReportError("metric_bundle must be a mapping")
    try:
        validate_metric_bundle(metric_bundle)
    except DerivedMetricsError as exc:
        raise ReportError(str(exc)) from exc
    return dict(metric_bundle)


def _validate_grade_evidence(grade_evidence: Mapping[str, Any]) -> Dict[str, Any]:
    if not isinstance(grade_evidence, Mapping):
        raise ReportError("grade_evidence must be a mapping")
    try:
        validate_grade_evidence(grade_evidence)
    except GradeConfidenceError as exc:
        raise ReportError(str(exc)) from exc
    return dict(grade_evidence)


def _visible_status(metric: Mapping[str, Any]) -> str:
    status = str(metric.get("Status") or "").strip()
    evidence_label = str(metric.get("evidence_label") or "").strip()
    if not status:
        return "UNTESTED"
    if status in ("UNTESTED", "UNAVAILABLE"):
        return status
    if evidence_label in EVIDENCE_LABELS:
        return evidence_label
    return status


def _metric_card(metric: Mapping[str, Any]) -> str:
    value = metric.get("Value")
    value_text = "UNAVAILABLE" if value is None else _esc(value)
    status = _esc(metric.get("Status"))
    evidence_label = _esc(metric.get("evidence_label"))
    why = _esc(metric.get("WHY"))
    action = _esc(metric.get("ACTION"))
    metric_id = _esc(metric.get("MetricID"))
    name = _esc(metric.get("Name"))
    source_ids = ", ".join(_esc(item) for item in (metric.get("source_event_ids") or []))
    return (
        '<article class="metric-card">'
        f'<div class="metric-title">{name}</div>'
        f'<div class="metric-id">{metric_id}</div>'
        f'<div class="metric-value">{value_text}</div>'
        f'<div class="metric-meta">Status: {status} | evidence: {evidence_label}</div>'
        f'<div class="metric-text"><strong>WHY</strong> {why}</div>'
        f'<div class="metric-text"><strong>ACTION</strong> {action}</div>'
        f'<div class="metric-text"><strong>Sources</strong> {source_ids or "none"}</div>'
        '</article>'
    )


def _svg_bar_chart(metrics: Sequence[Mapping[str, Any]], title: str) -> str:
    usable = [metric for metric in metrics if isinstance(metric.get("Value"), (int, float)) and not isinstance(metric.get("Value"), bool)]
    if not usable:
        return _empty_state_svg(title)
    values = [float(metric["Value"]) for metric in usable]
    max_value = max(abs(v) for v in values) or 1.0
    bars: List[str] = []
    width = 640
    height = 220
    chart_height = 140
    bar_width = max(24, int((width - 80) / max(1, len(usable))))
    gap = 12
    x = 30
    for metric in usable:
        value = float(metric["Value"])
        bar_h = max(2, int((abs(value) / max_value) * chart_height))
        y = 40 + (chart_height - bar_h)
        bars.append(
            f'<g><rect x="{x}" y="{y}" width="{bar_width}" height="{bar_h}" rx="4" ry="4"></rect>'
            f'<text x="{x + bar_width / 2:.1f}" y="200" text-anchor="middle">{_esc(metric.get("MetricID"))}</text>'
            f'<text x="{x + bar_width / 2:.1f}" y="{y - 6}" text-anchor="middle">{_esc(metric.get("Value"))}</text></g>'
        )
        x += bar_width + gap
    return (
        f'<svg viewBox="0 0 {width} {height}" role="img" aria-label="{_esc(title)}">'
        f'<title>{_esc(title)}</title>'
        '<rect x="0" y="0" width="640" height="220" fill="none" stroke="none"></rect>'
        '<g class="bars">' + "".join(bars) + '</g></svg>'
    )


def _empty_state_svg(title: str) -> str:
    return (
        '<svg viewBox="0 0 640 220" role="img" aria-label="%s">'
        '<title>%s</title>'
        '<rect x="18" y="18" width="604" height="184" rx="12" ry="12"></rect>'
        '<text x="320" y="96" text-anchor="middle">UNAVAILABLE / UNTESTED</text>'
        '<text x="320" y="132" text-anchor="middle">%s</text>'
        '</svg>'
    ) % (_esc(title), _esc(title), _esc(title))


def _identity_header(identity: Mapping[str, str], variant_id: Optional[str]) -> str:
    items = [
        ("Strategy", identity["Strategy"]),
        ("HomeContractID", identity["HomeContractID"]),
        ("LogicalSymbol", identity["LogicalSymbol"]),
        ("PhysicalSymbol", identity["PhysicalSymbol"]),
        ("ExecutionTF", identity["ExecutionTF"]),
        ("ProfileID", identity["ProfileID"]),
        ("BrokerData", identity["BrokerData"]),
        ("WindowContractID", identity["WindowContractID"]),
        ("ParameterSetID", identity["ParameterSetID"]),
        ("RunID", identity["RunID"]),
    ]
    if variant_id:
        items.append(("VariantID", variant_id))
    return '<div class="identity-header">' + "".join(
        f'<span><b>{_esc(label)}</b>: {_esc(value)}</span>' for label, value in items
    ) + "</div>"


def _page_section(page_id: str, title: str, identity: Mapping[str, str], variant_id: Optional[str], body: str) -> str:
    return (
        f'<section id="{_esc(page_id)}" class="page">'
        f'<h2>{_esc(title)}</h2>'
        f'{_identity_header(identity, variant_id)}'
        f'{body}'
        "</section>"
    )


def _render_page_metrics(title: str, metrics: Sequence[Mapping[str, Any]]) -> str:
    return (
        f'<div class="chart">{_svg_bar_chart(metrics, title)}</div>'
        '<div class="metrics">' + "".join(_metric_card(metric) for metric in metrics) + "</div>"
    )


def build_report(identity: Mapping[str, Any], metric_bundle: Mapping[str, Any], grade_evidence: Mapping[str, Any]) -> Dict[str, Any]:
    ident = _validate_identity(identity)
    bundle = _validate_metric_bundle(metric_bundle)
    grade = _validate_grade_evidence(grade_evidence)
    if bundle.get("RunID") != ident["RunID"] or grade.get("RunID") != ident["RunID"]:
        raise ReportError("RunID mismatch between identity, metric bundle, and grade evidence")
    if bundle.get("VariantID") != grade.get("VariantID"):
        raise ReportError("VariantID mismatch between metric bundle and grade evidence")
    if identity.get("VariantID") is not None and _need_text(identity.get("VariantID"), "VariantID") != grade.get("VariantID"):
        raise ReportError("VariantID mismatch with identity")
    if identity.get("VariantID") is None:
        raise ReportError("VariantID is required in identity")
    if bundle.get("MetricBundleID") != grade.get("MetricBundleID"):
        raise ReportError("MetricBundleID mismatch between metric bundle and grade evidence")

    overview = list(bundle["sections"]["Overview"])
    trade = list(bundle["sections"]["TradeDiagnostic"])
    optimization = list(bundle["sections"]["Optimization"])
    category_records = list(grade["category_records"])

    strategy = ident["Strategy"]
    page_bodies = {
        "overview": _page_section(
            "overview",
            "Overview",
            ident,
            identity.get("VariantID"),
            _render_page_metrics("Overview metrics", overview) + _render_outside_contract_block(grade),
        ),
        "trade-diagnostic": _page_section(
            "trade-diagnostic",
            "Trade Diagnostic",
            ident,
            identity.get("VariantID"),
            _render_page_metrics("Trade Diagnostic metrics", trade),
        ),
        "optimization": _page_section(
            "optimization",
            "Optimization",
            ident,
            identity.get("VariantID"),
            _render_page_metrics("Optimization metrics", optimization),
        ),
        "risk-recovery-hedge": _page_section(
            "risk-recovery-hedge",
            "Risk / Recovery / Hedge",
            ident,
            identity.get("VariantID"),
            _render_category_page(category_records, "Recovery/Hedge Safety", "Risk / Recovery / Hedge"),
        ),
        "context-regime-broker": _page_section(
            "context-regime-broker",
            "Context / Regime / Broker",
            ident,
            identity.get("VariantID"),
            _render_category_page(category_records, "Broker Portability", "Context / Regime / Broker"),
        ),
    }
    report_context = {
        "Strategy": ident["Strategy"],
        "HomeContractID": ident["HomeContractID"],
        "LogicalSymbol": ident["LogicalSymbol"],
        "PhysicalSymbol": ident["PhysicalSymbol"],
        "ExecutionTF": ident["ExecutionTF"],
        "ProfileID": ident["ProfileID"],
        "BrokerData": ident["BrokerData"],
        "WindowContractID": ident["WindowContractID"],
        "ParameterSetID": ident["ParameterSetID"],
        "RunID": ident["RunID"],
        "VariantID": identity["VariantID"],
        "MetricBundleID": bundle["MetricBundleID"],
        "GradeEvidenceID": grade["GradeEvidenceID"],
    }
    html_doc = _render_document(strategy, page_bodies)
    html_doc = html_doc.replace(
        "<body><div class='report'>",
        "<body><div class='report'><meta name='factory-vnext-report' content='%s'>" % _esc(canonical_json(report_context)),
        1,
    )
    report_id_payload = {**report_context, "html_sha256": _sha256_text(html_doc)}
    report_id = _stable_id("RPT", report_id_payload, hex_chars=32)
    record = {
        "schema_version": SCHEMA_VERSION,
        "authority": AUTHORITY,
        "ReportID": report_id,
        "html_sha256": report_id_payload["html_sha256"],
        "html": html_doc,
        "RunID": ident["RunID"],
        "VariantID": identity["VariantID"],
        "MetricBundleID": bundle["MetricBundleID"],
        "GradeEvidenceID": grade["GradeEvidenceID"],
        "page_ids": list(PAGE_IDS),
    }
    validate_report_record(record)
    return record


def _render_outside_contract_block(grade: Mapping[str, Any]) -> str:
    if grade.get("home_status") != "OUTSIDE_VALIDATED_CONTRACT":
        return ""
    return (
        '<aside class="outside-contract">'
        '<h3>OUTSIDE_VALIDATED_CONTRACT</h3>'
        '<p>This record is visible outside the validated contract and does not inherit PASS or Grade.</p>'
        '</aside>'
    )


def _render_category_page(categories: Sequence[Mapping[str, Any]], category_name: str, title: str) -> str:
    match = next((item for item in categories if item.get("Category") == category_name), None)
    if match is None:
        return _empty_state_panel(title, "UNAVAILABLE / UNTESTED", "Missing evidence category")
    return (
        '<div class="category-panel">'
        f'<div class="category-status">Status: {_esc(match.get("Status"))}</div>'
        f'<div class="category-why"><strong>WHY</strong> {_esc(match.get("WHY"))}</div>'
        f'<div class="category-action"><strong>ACTION</strong> {_esc(match.get("ACTION"))}</div>'
        f'<div class="category-src"><strong>Sources</strong> {", ".join(_esc(x) for x in (match.get("source_metric_ids") or [])) or "none"}</div>'
        '</div>'
    )


def _empty_state_panel(title: str, status: str, note: str) -> str:
    return (
        f'<div class="empty-state"><h3>{_esc(status)}</h3>'
        f'<p>{_esc(note)}</p>'
        f'{_empty_state_svg(title)}</div>'
    )


def _render_document(strategy: str, pages: Mapping[str, str]) -> str:
    styles = """
<style>
body{font-family:Arial,sans-serif;background:#f4f1ea;color:#16202a;margin:0;padding:24px}
.report{max-width:1200px;margin:0 auto}
.page{background:#fff;border:1px solid #c9d1d9;border-radius:16px;padding:18px 20px;margin:0 0 22px 0;box-shadow:0 2px 10px rgba(0,0,0,.04)}
.identity-header{display:flex;flex-wrap:wrap;gap:10px 14px;padding:12px 14px;border:1px solid #d5dbe3;border-radius:12px;background:#fafbfc;margin:10px 0 16px}
.identity-header span{font-size:12px;line-height:1.35}
.chart svg{width:100%;height:auto;background:#fbfbfb;border:1px solid #d8dee5;border-radius:12px}
.bars rect,.empty-state svg rect{fill:#c7d3df;stroke:#51606f}
.metric-card,.category-panel,.outside-contract,.empty-state{border:1px solid #d8dee5;border-radius:12px;padding:12px 14px;margin:10px 0;background:#fcfcfd}
.metric-title,.category-status{font-weight:700}
.metric-id{font-size:12px;opacity:.75}
.metric-value{font-size:18px;font-weight:700;margin:6px 0}
.metric-text{margin-top:6px}
.outside-contract{background:#fff6f0;border-color:#d8a77d}
</style>
""".strip()
    body = "".join(pages[page_id] for page_id in PAGE_IDS)
    return (
        "<!doctype html><html><head><meta charset='utf-8'>"
        f"<title>{_esc(strategy)} Factory vNext Report</title>{styles}</head>"
        f"<body><div class='report'>{body}</div></body></html>"
    )


def validate_report_record(record: Mapping[str, Any]) -> None:
    if not isinstance(record, Mapping):
        raise ReportError("record must be a mapping")
    if record.get("authority") != AUTHORITY or not NON_AUTHORITATIVE:
        raise ReportError("report authority boundary is missing")
    for name in ("schema_version", "ReportID", "html_sha256", "html", "RunID", "VariantID", "MetricBundleID", "GradeEvidenceID"):
        _need_text(record.get(name), name)
    page_ids = record.get("page_ids")
    if list(page_ids or []) != list(PAGE_IDS):
        raise ReportError("page_ids must match the frozen five-page order")
    html_text = record["html"]
    if not isinstance(html_text, str):
        raise ReportError("html must be a string")
    expected_hash = _sha256_text(html_text)
    if record["html_sha256"] != expected_hash:
        raise ReportError("html_sha256 does not match html")
    context = _extract_report_context(html_text)
    expected_report_id = _stable_id("RPT", {**context, "html_sha256": record["html_sha256"]}, hex_chars=32)
    if record["ReportID"] != expected_report_id:
        raise ReportError("ReportID does not match its immutable identity chain")
    if "<script" in html_text.lower() or "http://" in html_text.lower() or "https://" in html_text.lower() or "cdn" in html_text.lower():
        raise ReportError("html must not contain script tags or external assets")


def _extract_report_context(html_text: str) -> Dict[str, Any]:
    marker = "<meta name='factory-vnext-report' content='"
    pos = html_text.find(marker)
    if pos == -1:
        raise ReportError("missing report context meta")
    start = pos + len(marker)
    end = html_text.find("'>", start)
    if end == -1:
        raise ReportError("missing report context terminator")
    raw = html.unescape(html_text[start:end])
    try:
        context = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise ReportError("report context meta is not valid JSON") from exc
    if not isinstance(context, dict):
        raise ReportError("report context meta must be a JSON object")
    return context
