"use strict";

const REPORT_INDEX_URL = "./report_index.json";
const FIXTURE_INDEX_URL = "./fixture/report_index.json";
const MISSING = "UNKNOWN";
const KNOWN_DATA_STATES = new Set(["CURRENT", "STALE", "DEGRADED", "MISSING", "UNKNOWN", "UNAVAILABLE"]);
let reportIndex;
let usedCachedData = false;

const app = document.querySelector("#app");
const projectMeta = document.querySelector("#project-meta");
const dataWarning = document.querySelector("#data-warning");
const globalStateNode = document.querySelector("#global-state");
const lastUpdatedNode = document.querySelector("#last-updated");

function valueOf(value, fallback = MISSING) {
  return value === undefined || value === null || value === "" ? fallback : String(value);
}

function escapeHtml(value) {
  return valueOf(value).replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
  })[character]);
}

function stateName(value, fallback = "UNKNOWN") {
  const state = valueOf(value, fallback).toUpperCase();
  return /^[A-Z][A-Z0-9_]{0,63}$/.test(state) ? state : fallback;
}

function stateClass(value) {
  return `state-${stateName(value).toLowerCase()}`;
}

function badge(value) {
  const state = stateName(value);
  return `<span class="badge ${stateClass(state)}" aria-label="State: ${escapeHtml(state)}">${escapeHtml(state)}</span>`;
}

function getRecord(id) {
  return (reportIndex.eas || []).find((record) => record.id === id);
}

function route() {
  const raw = location.hash.slice(1) || "home";
  const [page, id] = raw.split("/");
  return { page, id: decodeURIComponent(id || "") };
}

function safeRelativeHref(href) {
  if (typeof href !== "string" || href.trim() === "") return null;
  const normalized = href.trim();
  if (!/^(?![a-z][a-z0-9+.-]*:)(?!\/\/)(?!\\\\)[./A-Za-z0-9_#?&=~%+\-]+$/i.test(normalized)) return null;
  const pathPart = normalized.split(/[?#]/, 1)[0];
  if (pathPart.split("/").includes("..")) return null;
  return normalized;
}

function validUtcSecond(value) {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/.test(value)) return false;
  const parsed = new Date(value);
  return !Number.isNaN(parsed.valueOf()) && parsed.toISOString().replace(".000Z", "Z") === value;
}

function validateIndex(payload, fixtureMode) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) throw new Error("Invalid report index object");
  if (fixtureMode) {
    if (payload.fixture_only !== true) throw new Error("Fixture mode requires fixture-only data");
    return payload;
  }
  if (payload.fixture_only === true) throw new Error("Production view refuses fixture-only data");
  const project = payload.project;
  if (!project || typeof project !== "object") throw new Error("Missing project provenance");
  if (!/^[0-9a-f]{40}$/.test(valueOf(project.canonical_sha, ""))) throw new Error("Invalid canonical SHA");
  if (project.canonical_short_sha !== project.canonical_sha.slice(0, 12)) throw new Error("Canonical SHA mismatch");
  if (!validUtcSecond(project.generated_at)) throw new Error("Invalid project timestamp");
  if (!KNOWN_DATA_STATES.has(stateName(project.data_status))) throw new Error("Invalid project data state");
  if (!Array.isArray(payload.sources) || payload.sources.some((source) => !source || source.canonical_sha !== project.canonical_sha)) {
    throw new Error("Canonical source SHA mismatch");
  }
  if (!Array.isArray(payload.eas) || !Array.isArray(payload.queue)) throw new Error("Missing report collections");
  return payload;
}

function metricValue(value) {
  return valueOf(value, "UNKNOWN");
}

function metricCard(label, evidence) {
  if (!evidence || !Object.keys(evidence).length) return "";
  const rows = [
    ["PF", evidence.pf], ["DD %", evidence.dd_pct], ["Trades", evidence.trades], ["Cycles", evidence.cycles]
  ].filter(([, value]) => value !== undefined && value !== null && value !== "");
  if (!rows.length) return "";
  return `<article class="metric-card"><h3>${escapeHtml(label)}</h3><dl>${rows.map(([key, value]) => `<div><dt>${key}</dt><dd>${escapeHtml(metricValue(value))}</dd></div>`).join("")}</dl></article>`;
}

function globalMonitoringState() {
  const projectState = stateName(reportIndex.project && reportIndex.project.data_status);
  const monitoring = reportIndex.monitoring || {};
  const monitoringState = stateName(monitoring.status, "MISSING");
  if (!navigator.onLine || usedCachedData || projectState === "STALE") return "STALE";
  if (["MISSING", "UNAVAILABLE"].includes(monitoringState)) return "MISSING";
  if (projectState === "DEGRADED" || monitoringState === "DEGRADED" || monitoring.binding_state === "DIFFERENT_REPO_HEAD") return "DEGRADED";
  if (projectState !== "CURRENT" || monitoringState !== "CURRENT" || monitoring.binding_state !== "MATCHES_CANONICAL_SHA") return "UNKNOWN";
  return "CURRENT";
}

function renderWarning() {
  const status = stateName(reportIndex.project && reportIndex.project.data_status);
  const monitoringStatus = stateName(reportIndex.monitoring && reportIndex.monitoring.status, "MISSING");
  const warnings = [];
  if (reportIndex.fixture_only === true) warnings.push("FIXTURE ONLY - not production SOT");
  if (!navigator.onLine) warnings.push("OFFLINE");
  if (usedCachedData) warnings.push("CACHED DATA");
  if (status === "STALE") warnings.push("STALE DATA");
  if (["DEGRADED", "MISSING", "UNAVAILABLE", "UNKNOWN"].includes(monitoringStatus)) warnings.push(`MONITORING ${monitoringStatus}`);
  dataWarning.hidden = warnings.length === 0;
  dataWarning.textContent = warnings.join(" · ");
  const globalState = globalMonitoringState();
  globalStateNode.textContent = globalState;
  globalStateNode.className = `state-token ${stateClass(globalState)}`;
}

function renderProjectMeta() {
  const project = reportIndex.project || {};
  const monitoring = reportIndex.monitoring || {};
  const updated = validUtcSecond(monitoring.generated_at_utc) ? monitoring.generated_at_utc : (validUtcSecond(project.generated_at) ? project.generated_at : "UNKNOWN");
  lastUpdatedNode.textContent = updated;
  projectMeta.textContent = `Canonical SHA ${valueOf(project.canonical_short_sha, "UNKNOWN")} · ${valueOf(project.freshness, "UNKNOWN")} · READ_ONLY_PRESENTATION`;
  renderWarning();
}

function availableValues(field) {
  const values = (reportIndex.eas || []).map((record) => {
    if (field === "symbol") return record.home && record.home.symbol;
    if (field === "timeframe") return record.home && record.home.timeframe;
    return record[field];
  }).filter((value) => value !== undefined && value !== null && value !== "");
  return [...new Set(values)].sort();
}

function filterSelect(label, field, options) {
  return `<label>${escapeHtml(label)}<select data-filter="${escapeHtml(field)}"><option value="">All</option>${options.map((option) => `<option value="${escapeHtml(option)}">${escapeHtml(option)}</option>`).join("")}</select></label>`;
}

function recordMatchesFilters(record, filters) {
  const values = {
    lifecycle: record.lifecycle,
    family_id: record.family_id,
    symbol: record.home && record.home.symbol,
    timeframe: record.home && record.home.timeframe,
    quality_grade: record.quality_grade,
    evidence_confidence: record.evidence_confidence,
    research_state: record.research_state
  };
  return Object.entries(filters).every(([key, value]) => !value || String(values[key]) === value);
}

function recordCard(record) {
  const home = record.home || {};
  return `<article class="record-card">
    <div class="card-top"><div><p class="eyebrow">${escapeHtml(valueOf(record.family_id))} · ${escapeHtml(valueOf(record.variant_id))}</p><h3>${escapeHtml(record.display_name)}</h3></div>${badge(record.status || record.research_state)}</div>
    <p>${escapeHtml(valueOf(home.symbol))} / ${escapeHtml(valueOf(home.timeframe))} · ${escapeHtml(valueOf(record.lifecycle))}</p>
    <p class="muted">${escapeHtml(valueOf(record.verdict))}</p>
    <a class="button-link" href="#detail/${encodeURIComponent(record.id)}" aria-label="Open details for ${escapeHtml(record.display_name)}">Open details</a>
  </article>`;
}

function projectionData() {
  return reportIndex.safe_projection || { status: "MISSING", accounts: [], findings: [], reason: "NOT_PROVIDED" };
}

function coverageValue() {
  const coverage = (reportIndex.monitoring && reportIndex.monitoring.coverage) || {};
  if (coverage.state !== "AVAILABLE_CURRENT_SNAPSHOT") return { value: "UNKNOWN", detail: "Current coverage evidence unavailable" };
  return {
    value: `D ${valueOf(coverage.deal_sensors_fresh)}/${valueOf(coverage.deal_sensors_total)}`,
    detail: `Floating ${valueOf(coverage.floating_sensors_fresh)}/${valueOf(coverage.floating_sensors_total)}`
  };
}

function renderKpis() {
  const projection = projectionData();
  const findings = projection.status === "AVAILABLE" && Array.isArray(projection.findings) ? projection.findings : null;
  const critical = findings ? findings.filter((item) => ["CRITICAL", "REAL_MONEY"].includes(item.severity)).length : "UNKNOWN";
  const coverage = coverageValue();
  const projectedCount = projection.status === "AVAILABLE" && Array.isArray(projection.accounts) ? projection.accounts.length : "UNKNOWN";
  return `<section class="kpi-grid" aria-label="Monitoring KPIs">
    <article class="kpi-card"><span>Active Accounts</span><strong>UNKNOWN</strong><small>${escapeHtml(projectedCount)} projected; activity not supplied</small></article>
    <article class="kpi-card"><span>Alerts</span><strong>${escapeHtml(critical)}</strong><small>Critical findings · freshness ${escapeHtml(stateName(projection.freshness))}</small></article>
    <article class="kpi-card"><span>Coverage</span><strong>${escapeHtml(coverage.value)}</strong><small>${escapeHtml(coverage.detail)}</small></article>
  </section>`;
}

function renderMonitoring() {
  const monitoring = reportIndex.monitoring || {};
  const status = stateName(monitoring.status, "MISSING");
  const sources = Array.isArray(monitoring.sources) ? monitoring.sources : [];
  const coverage = monitoring.coverage || {};
  const sourceRows = sources.length ? `<ul class="monitor-source-list">${sources.map((source) => `<li><div class="source-row"><strong>${escapeHtml(valueOf(source.name))}</strong>${badge(source.state)}</div><small>Age ${escapeHtml(valueOf(source.age_hours, "UNKNOWN"))}h · observed ${escapeHtml(valueOf(source.observed_at_utc, "UNKNOWN"))}</small></li>`).join("")}</ul>` : `<p class="empty-state">Monitoring sources MISSING.</p>`;
  const coverageText = valueOf(coverage.state) === "AVAILABLE_CURRENT_SNAPSHOT"
    ? `Deal sensors ${escapeHtml(valueOf(coverage.deal_sensors_fresh))}/${escapeHtml(valueOf(coverage.deal_sensors_total))} · Floating sensors ${escapeHtml(valueOf(coverage.floating_sensors_fresh))}/${escapeHtml(valueOf(coverage.floating_sensors_total))}`
    : "Coverage unavailable because the enclosing monitoring snapshot is stale, invalid, or missing.";
  return `<section class="panel monitoring-panel"><div class="card-top"><div><p class="eyebrow">LOCAL MONITORING · NONCANONICAL</p><h2>Source health</h2></div>${badge(status)}</div>
    <p>${escapeHtml(coverageText)}</p>${sourceRows}
    <p class="muted">Binding ${escapeHtml(valueOf(monitoring.binding_state))} · generated ${escapeHtml(valueOf(monitoring.generated_at_utc))} · ${escapeHtml(valueOf(monitoring.authority, "READ_ONLY_NO_RUNTIME_AUTHORITY"))}</p></section>`;
}

function renderPortfolioOverview() {
  const monitoring = reportIndex.monitoring || {};
  const projection = projectionData();
  const accounts = projection.status === "AVAILABLE" && Array.isArray(projection.accounts) ? projection.accounts : null;
  const healthy = accounts ? accounts.filter((item) => item.sensor_state === "FRESH").length : "UNKNOWN";
  const attention = accounts ? accounts.filter((item) => item.sensor_state !== "FRESH").length : "UNKNOWN";
  return `<section class="dashboard-section"><div class="section-heading"><div><h2>Portfolio Overview</h2><p>SafeProjection summaries only; no money amount or account class is inferred.</p></div>${badge(monitoring.status || "MISSING")}</div>
    <div class="panel portfolio-grid"><div class="portfolio-stat"><span>Projected accounts</span><strong>${escapeHtml(accounts ? accounts.length : "UNKNOWN")}</strong></div><div class="portfolio-stat"><span>Fresh sensors</span><strong>${escapeHtml(healthy)}</strong></div><div class="portfolio-stat"><span>Needs attention</span><strong>${escapeHtml(attention)}</strong></div><div class="portfolio-stat"><span>P&amp;L / numeric DD</span><strong>UNKNOWN</strong></div></div>
  </section>`;
}

function accountCard(account) {
  const sensorState = stateName(account.sensor_state);
  return `<article class="account-card ${stateClass(sensorState)}"><div class="account-heading"><div><p class="eyebrow">MASKED ACCOUNT</p><h3>${escapeHtml(valueOf(account.account_masked))}</h3></div>${badge(sensorState)}</div>
    <div class="account-facts"><div class="account-fact"><span>Account type</span><strong>UNKNOWN</strong></div><div class="account-fact"><span>Activity</span><strong>UNKNOWN</strong></div><div class="account-fact"><span>P&amp;L</span><strong>UNKNOWN</strong></div><div class="account-fact"><span>DD band</span><strong>${escapeHtml(stateName(account.dd_pct_band))}</strong></div></div></article>`;
}

function renderAccounts(limit) {
  const projection = projectionData();
  const accounts = projection.status === "AVAILABLE" && Array.isArray(projection.accounts) ? projection.accounts : null;
  const shown = accounts && Number.isInteger(limit) ? accounts.slice(0, limit) : accounts;
  const content = shown && shown.length ? `<div class="account-grid">${shown.map(accountCard).join("")}</div>` : `<article class="panel"><p class="empty-state">Account monitoring ${escapeHtml(stateName(projection.status, "MISSING"))}: ${escapeHtml(valueOf(projection.reason, "UNKNOWN"))}.</p></article>`;
  return `<section class="dashboard-section"><div class="section-heading"><div><h2>Account cards</h2><p>Masked identifiers and detector-owned bands only.</p></div><div>${badge(projection.status || "MISSING")} ${badge(projection.freshness || "UNKNOWN")}</div></div>${content}</section>`;
}

function alertCard(item) {
  const severity = stateName(item.severity);
  return `<article class="alert-card severity-${severity.toLowerCase()}"><div class="alert-heading"><strong>${escapeHtml(valueOf(item.public_id))}</strong>${badge(severity)}</div><p>Finding state ${escapeHtml(stateName(item.state))} · details remain in the canonical local monitoring owner.</p></article>`;
}

function renderCriticalAlerts(all = false) {
  const projection = projectionData();
  const findings = projection.status === "AVAILABLE" && Array.isArray(projection.findings) ? projection.findings : null;
  const selected = findings ? (all ? findings : findings.filter((item) => ["CRITICAL", "REAL_MONEY"].includes(item.severity))) : null;
  let content;
  if (!selected) content = `<article class="panel"><p class="empty-state">Alerts ${escapeHtml(stateName(projection.status, "MISSING"))}: ${escapeHtml(valueOf(projection.reason, "UNKNOWN"))}.</p></article>`;
  else if (!selected.length) content = `<article class="panel"><p class="empty-state">No ${all ? "" : "critical "}findings in the supplied SafeProjection.</p></article>`;
  else content = `<div class="alert-list">${selected.map(alertCard).join("")}</div>`;
  return `<section class="dashboard-section"><div class="section-heading"><div><h2>${all ? "Alerts" : "Critical Alerts"}</h2><p>Opaque public IDs; no account or strategy identity is exposed.</p></div><div>${badge(projection.status || "MISSING")} ${badge(projection.freshness || "UNKNOWN")}</div></div>${content}</section>`;
}

function queueItem(item) {
  return `<li><div class="source-row"><strong>${escapeHtml(valueOf(item.id))}</strong>${badge(item.state)}</div><span>${escapeHtml(valueOf(item.blocker_type, "NOT_APPLICABLE"))} ${badge(valueOf(item.source_kind, "UNKNOWN_SOURCE"))} ${item.registry_classification ? badge(item.registry_classification) : ""} ${item.attention_required === true ? badge("ATTENTION") : ""}</span><p class="muted">${escapeHtml(valueOf(item.summary))}</p></li>`;
}

function renderQueuePreview() {
  const queue = Array.isArray(reportIndex.queue) ? reportIndex.queue : [];
  const items = queue.filter((item) => stateName(item.state) !== "DONE").slice(0, 3);
  return `<section class="dashboard-section"><div class="section-heading"><div><h2>Queue</h2><p>Presentation only; no execution controls.</p></div><a class="section-action" href="#queue">View all</a></div><div class="panel">${items.length ? `<ul class="queue-list">${items.map(queueItem).join("")}</ul>` : `<p class="empty-state">No active queue rows supplied.</p>`}</div></section>`;
}

function renderResearch() {
  const records = reportIndex.eas || [];
  const recent = records.filter((record) => record.status !== "INVENTORY_ONLY" && valueOf(record.latest_experiment, "UNKNOWN") !== "UNKNOWN").slice(-3).reverse();
  return `<section class="dashboard-section"><details><summary>Research reports</summary><div class="panel"><div class="section-heading"><div><h2>Read-only research</h2><p>Canonical report data from report_index.json.</p></div><a class="section-action" href="#compare">Compare</a></div><div class="filters" aria-label="EA filters"><label>Search<input id="search" type="search" placeholder="Name, family, symbol" autocomplete="off" /></label>${filterSelect("Lifecycle", "lifecycle", availableValues("lifecycle"))}${filterSelect("Family", "family_id", availableValues("family_id"))}${filterSelect("Symbol", "symbol", availableValues("symbol"))}${filterSelect("Timeframe", "timeframe", availableValues("timeframe"))}${filterSelect("Grade", "quality_grade", availableValues("quality_grade"))}${filterSelect("Evidence Confidence", "evidence_confidence", availableValues("evidence_confidence"))}${filterSelect("Research status", "research_state", availableValues("research_state"))}</div><div id="ea-results" class="card-list">${recent.map(recordCard).join("")}</div></div></details></section>`;
}

function bindResearchFilters() {
  const searchNode = document.querySelector("#search");
  if (!searchNode) return;
  const records = reportIndex.eas || [];
  const renderResults = () => {
    const search = searchNode.value.trim().toLowerCase();
    const filters = Object.fromEntries([...document.querySelectorAll("[data-filter]")].map((input) => [input.dataset.filter, input.value]));
    const matches = records.filter((record) => {
      const searchable = [record.display_name, record.family_id, record.variant_id, record.home && record.home.symbol, record.home && record.home.timeframe].join(" ").toLowerCase();
      return (!search || searchable.includes(search)) && recordMatchesFilters(record, filters);
    });
    document.querySelector("#ea-results").innerHTML = matches.length ? matches.map(recordCard).join("") : `<p class="empty-state">No matching EA records.</p>`;
  };
  searchNode.addEventListener("input", renderResults);
  document.querySelectorAll("[data-filter]").forEach((input) => input.addEventListener("change", renderResults));
}

function renderHome() {
  app.innerHTML = `<section class="page-heading"><h2>Monitoring Home</h2><p>Read-only projection of existing EA_LAB monitoring outputs.</p></section>${renderKpis()}${renderPortfolioOverview()}${renderAccounts(3)}${renderCriticalAlerts()}${renderQueuePreview()}${renderMonitoring()}${renderResearch()}`;
  bindResearchFilters();
}

function renderLive() {
  app.innerHTML = `<section class="page-heading"><h2>Live monitoring</h2><p>“Live” is a navigation label, not LIVE promotion or runtime authority.</p></section>${renderKpis()}${renderAccounts()}${renderMonitoring()}`;
}

function renderLinks(links) {
  const entries = Object.entries(links || {}).map(([label, href]) => [label, safeRelativeHref(href)]).filter(([, href]) => href);
  if (!entries.length) return "";
  const labels = { full_report: "Full Report", raw_evidence: "Raw Evidence", workflow: "Workflow", graph: "Graph" };
  return `<section class="panel"><h2>Source links</h2><div class="link-row">${entries.map(([key, href]) => `<a class="button-link secondary" href="${escapeHtml(href)}">${escapeHtml(labels[key] || key)}</a>`).join("")}</div></section>`;
}

function renderDetail(id) {
  const record = getRecord(id);
  if (!record) {
    app.innerHTML = `<section class="panel"><h2>Record unavailable</h2><p>The requested EA record is not in this report index.</p><a class="button-link" href="#home">Back to Home</a></section>`;
    return;
  }
  const evidence = record.evidence || {};
  const findings = Array.isArray(evidence.key_findings) ? evidence.key_findings : [];
  const weaknesses = Array.isArray(evidence.known_weaknesses) ? evidence.known_weaknesses : [];
  app.innerHTML = `<section class="page-heading"><a class="back-link" href="#home">← Back</a><p class="eyebrow">${escapeHtml(valueOf(record.family_id))} · ${escapeHtml(valueOf(record.variant_id))}</p><h2>${escapeHtml(record.display_name)}</h2><p>${badge(record.lifecycle)} ${badge(record.status || record.research_state)}</p></section>
    <section class="summary-grid"><article class="panel"><h3>Summary</h3><dl class="facts"><div><dt>Verdict</dt><dd>${escapeHtml(valueOf(record.verdict))}</dd></div><div><dt>Latest</dt><dd>${escapeHtml(valueOf(record.latest_experiment))}</dd></div><div><dt>Holdout</dt><dd>${escapeHtml(valueOf(evidence.holdout_state))}</dd></div><div><dt>Evidence basis</dt><dd>${escapeHtml(valueOf(evidence.basis_id))}</dd></div></dl></article><article class="panel"><h3>Quality / evidence</h3><dl class="facts"><div><dt>Grade</dt><dd>${escapeHtml(valueOf(record.quality_grade))}</dd></div><div><dt>Confidence</dt><dd>${escapeHtml(valueOf(record.evidence_confidence))}</dd></div><div><dt>Model</dt><dd>${escapeHtml(valueOf(evidence.model))}</dd></div><div><dt>Stage</dt><dd>${escapeHtml(valueOf(evidence.report_stage))}</dd></div></dl></article></section>
    <section class="metric-grid">${metricCard("MAIN", evidence.main)}${metricCard("BWD", evidence.bwd)}</section>
    ${(findings.length || weaknesses.length || record.blocker_reason || record.next_action) ? `<section class="panel"><h2>Finding / blocker / next action</h2>${findings.length ? `<h3>Key findings</h3><ul class="plain-list">${findings.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>` : ""}${weaknesses.length ? `<h3>Known weaknesses</h3><ul class="plain-list">${weaknesses.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>` : ""}${record.blocker_reason ? `<p><strong>${escapeHtml(valueOf(record.blocker_type, "BLOCKED"))}:</strong> ${escapeHtml(record.blocker_reason)}</p>` : ""}${record.next_action ? `<p><strong>Next action:</strong> ${escapeHtml(record.next_action)}</p>` : ""}</section>` : ""}${renderLinks(record.links)}`;
}

function comparisonRows(left, right) {
  const leftEvidence = left.evidence || {};
  const rightEvidence = right.evidence || {};
  const rows = [
    ["MAIN PF", leftEvidence.main && leftEvidence.main.pf, rightEvidence.main && rightEvidence.main.pf],
    ["MAIN DD %", leftEvidence.main && leftEvidence.main.dd_pct, rightEvidence.main && rightEvidence.main.dd_pct],
    ["MAIN trades", leftEvidence.main && leftEvidence.main.trades, rightEvidence.main && rightEvidence.main.trades],
    ["MAIN cycles", leftEvidence.main && leftEvidence.main.cycles, rightEvidence.main && rightEvidence.main.cycles],
    ["BWD PF", leftEvidence.bwd && leftEvidence.bwd.pf, rightEvidence.bwd && rightEvidence.bwd.pf],
    ["BWD DD %", leftEvidence.bwd && leftEvidence.bwd.dd_pct, rightEvidence.bwd && rightEvidence.bwd.dd_pct],
    ["BWD trades", leftEvidence.bwd && leftEvidence.bwd.trades, rightEvidence.bwd && rightEvidence.bwd.trades],
    ["BWD cycles", leftEvidence.bwd && leftEvidence.bwd.cycles, rightEvidence.bwd && rightEvidence.bwd.cycles],
    ["Grade", left.quality_grade, right.quality_grade], ["Evidence", left.evidence_confidence, right.evidence_confidence], ["Latest", left.latest_experiment, right.latest_experiment], ["Weakness", (leftEvidence.known_weaknesses || []).join("; "), (rightEvidence.known_weaknesses || []).join("; ")], ["Lifecycle", left.lifecycle, right.lifecycle]
  ];
  return `<div class="table-wrap"><table><thead><tr><th>Field</th><th>${escapeHtml(left.display_name)}</th><th>${escapeHtml(right.display_name)}</th></tr></thead><tbody>${rows.map(([field, leftValue, rightValue]) => `<tr><th>${escapeHtml(field)}</th><td>${escapeHtml(metricValue(leftValue))}</td><td>${escapeHtml(metricValue(rightValue))}</td></tr>`).join("")}</tbody></table></div>`;
}

function renderCompare() {
  const records = reportIndex.eas || [];
  app.innerHTML = `<section class="page-heading"><a class="back-link" href="#home">← Back</a><h2>Compare two records</h2><p>Select exactly two EA records. Numeric rows appear only when both records share an evidence basis.</p></section><section class="panel"><fieldset><legend>Choose records</legend><div class="compare-options">${records.map((record) => `<label class="check-card"><input type="checkbox" value="${escapeHtml(record.id)}" /> <span>${escapeHtml(record.display_name)}<small>${escapeHtml(valueOf(record.family_id))} · ${escapeHtml(valueOf(record.variant_id))}</small></span></label>`).join("")}</div></fieldset><p id="compare-note" class="muted">Choose exactly two records.</p><div id="compare-result"></div></section>`;
  const inputs = [...document.querySelectorAll(".compare-options input")];
  const update = () => {
    const selected = inputs.filter((input) => input.checked);
    inputs.forEach((input) => { input.disabled = !input.checked && selected.length >= 2; });
    const note = document.querySelector("#compare-note");
    const result = document.querySelector("#compare-result");
    if (selected.length !== 2) { note.textContent = "Choose exactly two records."; result.innerHTML = ""; return; }
    const [left, right] = selected.map((input) => getRecord(input.value));
    const sameBasis = left.evidence && right.evidence && left.evidence.basis_id && left.evidence.basis_id === right.evidence.basis_id && left.evidence.basis_id !== "UNAVAILABLE";
    if (!sameBasis) { note.textContent = "DIFFERENT BASIS - numeric comparison is not implied."; result.innerHTML = ""; return; }
    note.textContent = `Compatible basis: ${left.evidence.basis_id}`;
    result.innerHTML = comparisonRows(left, right);
  };
  inputs.forEach((input) => input.addEventListener("change", update));
}

function renderQueue() {
  const queue = reportIndex.queue || [];
  const groups = ["READY", "RUNNING", "BLOCKED", "DONE", "UNKNOWN"];
  app.innerHTML = `<section class="page-heading"><h2>Queue</h2><p>Queue state is descriptive only; this hub has no execution controls.</p></section>${groups.map((group) => {
    const items = queue.filter((item) => stateName(item.state) === group);
    return `<section class="panel"><div class="section-heading"><h2>${group}</h2>${badge(group)}</div>${items.length ? `<ul class="queue-list">${items.map(queueItem).join("")}</ul>` : `<p class="empty-state">No items.</p>`}</section>`;
  }).join("")}`;
}

function renderAlerts() {
  app.innerHTML = `<section class="page-heading"><h2>Alerts</h2><p>SafeProjection finding summaries only.</p></section>${renderCriticalAlerts(true)}${renderMonitoring()}`;
}

function renderRoute() {
  const current = route();
  const activePage = ["detail", "compare"].includes(current.page) ? "home" : current.page;
  document.querySelectorAll("[data-nav]").forEach((link) => link.classList.toggle("active", link.dataset.nav === activePage));
  if (current.page === "detail") renderDetail(current.id);
  else if (current.page === "compare") renderCompare();
  else if (current.page === "live") renderLive();
  else if (current.page === "queue") renderQueue();
  else if (current.page === "alerts") renderAlerts();
  else renderHome();
}

async function fetchIndex(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`Report index unavailable (${response.status})`);
  if (response.headers.get("X-EA-LAB-Cache") === "true") usedCachedData = true;
  return response.json();
}

function renderUnavailable(error) {
  projectMeta.textContent = "Canonical provenance UNKNOWN";
  globalStateNode.textContent = "MISSING";
  globalStateNode.className = "state-token state-missing";
  lastUpdatedNode.textContent = "UNKNOWN";
  dataWarning.hidden = false;
  dataWarning.textContent = !navigator.onLine ? "OFFLINE - no cached report index is available." : "MISSING - report index could not be loaded or validated.";
  app.innerHTML = `<section class="panel"><h2>Monitoring unavailable</h2><p>${escapeHtml(error.message)}</p><p class="muted">No account, alert, coverage, queue, freshness, or canonical identity is inferred.</p></section>`;
}

async function start() {
  try {
    const fixtureMode = new URLSearchParams(window.location.search).get("fixture") === "1";
    const payload = await fetchIndex(fixtureMode ? FIXTURE_INDEX_URL : REPORT_INDEX_URL);
    reportIndex = validateIndex(payload, fixtureMode);
    renderProjectMeta();
    renderRoute();
    window.addEventListener("hashchange", renderRoute);
    window.addEventListener("online", renderWarning);
    window.addEventListener("offline", renderWarning);
    if ("serviceWorker" in navigator) navigator.serviceWorker.register("./sw.js", { scope: "./" }).catch(() => {});
  } catch (error) {
    renderUnavailable(error);
  }
}

start();
