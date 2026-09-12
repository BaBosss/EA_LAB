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
  const ct = payload.control_tower;
  const states = new Set(["READY", "RUNNING", "WAITING", "REVIEW", "INTEGRATING", "BLOCKED", "PARKED", "PAUSED", "FROZEN", "DONE", "UNKNOWN", "CONFLICT"]);
  if (!ct || ct.version !== 3 || !ct.project || !ct.registry) throw new Error("Missing V3 projection");
  for (const rows of [ct.work, ct.need_boss, ct.runtime, ct.registry.rows, ct.project.current, ct.project.next]) {
    if (!Array.isArray(rows) || rows.some(item => !item || typeof item.id !== "string" || !states.has(item.state))) throw new Error("Invalid V3 collection");
    if (rows.some(item => item.source_kind === "GIT_CANONICAL" && (!item.provenance || item.provenance.canonical_sha !== project.canonical_sha))) throw new Error("Canonical V3 source SHA mismatch");
  }
  if (!ct.project.provenance || ct.project.provenance.canonical_sha !== project.canonical_sha) throw new Error("Canonical V3 source SHA mismatch");
  return payload;
}

function metricValue(value) {
  return valueOf(value, "UNKNOWN");
}

function metricCard(label, evidence) {
  if (!evidence || !Object.keys(evidence).length) return "";
  const rows = [
    ["PF", evidence.pf], ["Net", evidence.net], [evidence.eqdd_pct === undefined ? "DD %" : "EqDD %", evidence.eqdd_pct ?? evidence.dd_pct], ["Trades", evidence.trades], ["Cycles", evidence.cycles]
  ].filter(([, value]) => value !== undefined && value !== null && value !== "");
  if (!rows.length) return "";
  return `<article class="metric-card"><h3>${escapeHtml(label)}</h3><dl>${rows.map(([key, value]) => `<div><dt>${key}</dt><dd>${escapeHtml(metricValue(value))}</dd></div>`).join("")}</dl></article>`;
}

function globalMonitoringState() {
  const projectState = stateName(reportIndex.project && reportIndex.project.data_status);
  const monitoring = reportIndex.monitoring || {};
  const monitoringState = stateName(monitoring.status, "MISSING");
  if (!navigator.onLine || usedCachedData || projectState === "STALE" || observedFreshness(reportIndex.project.generated_at) !== "CURRENT") return "STALE";
  if (tower().project && tower().project.global_state === "DEGRADED_MONITORING") return "DEGRADED_MONITORING";
  if (["MISSING", "UNAVAILABLE"].includes(monitoringState)) return "MISSING";
  if (observedFreshness(monitoring.generated_at_utc, 30) !== "CURRENT") return "STALE";
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
  if (status === "STALE" || observedFreshness(reportIndex.project.generated_at) !== "CURRENT") warnings.push("STALE DATA / INVALID SNAPSHOT TIME");
  if (tower().project && tower().project.global_state === "DEGRADED_MONITORING") warnings.push("DEGRADED_MONITORING");
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
  const projection = reportIndex.safe_projection || { status: "MISSING", accounts: [], findings: [], reason: "NOT_PROVIDED" };
  // Existing SafeProjection timestamp has no timezone; never assume local browser time.
  return { ...projection, freshness: "UNKNOWN" };
}
function monitorCurrent() {
  const monitor = reportIndex.monitoring || {};
  return observationCurrent() && monitor.binding_state === "MATCHES_CANONICAL_SHA" && observedFreshness(monitor.generated_at_utc, 30) === "CURRENT";
}

function coverageValue() {
  const coverage = (reportIndex.monitoring && reportIndex.monitoring.coverage) || {};
  if (!monitorCurrent() || coverage.state !== "AVAILABLE_CURRENT_SNAPSHOT") return { value: "UNKNOWN", detail: "Current coverage evidence unavailable" };
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
  const status = monitorCurrent() ? stateName(monitoring.status, "MISSING") : "UNKNOWN";
  const sources = Array.isArray(monitoring.sources) ? monitoring.sources : [];
  const coverage = monitoring.coverage || {};
  const sourceRows = sources.length ? `<ul class="monitor-source-list">${sources.map((source) => `<li><div class="source-row"><strong>${escapeHtml(valueOf(source.name))}</strong>${badge(monitorCurrent() && observedFreshness(source.observed_at_utc, 30) === "CURRENT" ? source.state : "UNKNOWN")}</div><small>Age ${escapeHtml(valueOf(source.age_hours, "UNKNOWN"))}h · observed ${escapeHtml(valueOf(source.observed_at_utc, "UNKNOWN"))}</small></li>`).join("")}</ul>` : `<p class="empty-state">Monitoring sources MISSING.</p>`;
  const coverageText = monitorCurrent() && valueOf(coverage.state) === "AVAILABLE_CURRENT_SNAPSHOT"
    ? `Deal sensors ${escapeHtml(valueOf(coverage.deal_sensors_fresh))}/${escapeHtml(valueOf(coverage.deal_sensors_total))} · Floating sensors ${escapeHtml(valueOf(coverage.floating_sensors_fresh))}/${escapeHtml(valueOf(coverage.floating_sensors_total))}`
    : "Coverage unavailable because the enclosing monitoring snapshot is stale, invalid, or missing.";
  return `<section class="panel monitoring-panel"><div class="card-top"><div><p class="eyebrow">LOCAL MONITORING · NONCANONICAL</p><h2>Source health</h2></div>${badge(status)}</div>
    <p>${escapeHtml(coverageText)}</p>${sourceRows}
    <p class="muted">Binding ${escapeHtml(valueOf(monitoring.binding_state))} · generated ${escapeHtml(valueOf(monitoring.generated_at_utc))} · ${escapeHtml(valueOf(monitoring.authority, "READ_ONLY_NO_RUNTIME_AUTHORITY"))}</p>
    <details><summary>Monitoring revision provenance</summary><p>Runtime Git SHA: ${escapeHtml(valueOf(monitoring.repo_head))}</p><p>Snapshot Git SHA: ${escapeHtml(valueOf(monitoring.snapshot_revision && monitoring.snapshot_revision.git_head))}</p><p>${escapeHtml(valueOf(monitoring.snapshot_revision && monitoring.snapshot_revision.binding_state))}</p></details></section>`;
}

function renderPortfolioOverview() {
  const monitoring = reportIndex.monitoring || {};
  const projection = projectionData();
  const accounts = projection.status === "AVAILABLE" && Array.isArray(projection.accounts) ? projection.accounts : null;
  const healthy = "UNKNOWN";
  const attention = "UNKNOWN";
  return `<section class="dashboard-section"><div class="section-heading"><div><h2>Portfolio Overview</h2><p>SafeProjection summaries only; no money amount or account class is inferred.</p></div>${badge(monitoring.status || "MISSING")}</div>
    <div class="panel portfolio-grid"><div class="portfolio-stat"><span>Projected accounts</span><strong>${escapeHtml(accounts ? accounts.length : "UNKNOWN")}</strong></div><div class="portfolio-stat"><span>Fresh sensors</span><strong>${escapeHtml(healthy)}</strong></div><div class="portfolio-stat"><span>Needs attention</span><strong>${escapeHtml(attention)}</strong></div><div class="portfolio-stat"><span>P&amp;L / numeric DD</span><strong>UNKNOWN</strong></div></div>
  </section>`;
}

function accountCard(account) {
  const sensorState = "UNKNOWN";
  return `<article class="account-card ${stateClass(sensorState)}"><div class="account-heading"><div><p class="eyebrow">MASKED ACCOUNT</p><h3>${escapeHtml(valueOf(account.account_masked))}</h3></div>${badge(sensorState)}</div>
    <div class="account-facts"><div class="account-fact"><span>Account type</span><strong>UNKNOWN</strong></div><div class="account-fact"><span>Activity</span><strong>UNKNOWN</strong></div><div class="account-fact"><span>P&amp;L</span><strong>UNKNOWN</strong></div><div class="account-fact"><span>Observed sensor / DD band</span><strong>${escapeHtml(stateName(account.sensor_state))} / ${escapeHtml(stateName(account.dd_pct_band))}</strong><small>Historical observation; freshness UNKNOWN</small></div></div></article>`;
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
  const effectiveState = item.source_kind === "LANE_REGISTRY_NONCANONICAL" && (!observationCurrent() || observedFreshness(item.observed_at) !== "CURRENT") ? "UNKNOWN" : item.state;
  return `<li><div class="source-row"><strong>${escapeHtml(valueOf(item.id))}</strong>${badge(effectiveState)}</div><span>${escapeHtml(valueOf(item.blocker_type, "NOT_APPLICABLE"))} ${badge(valueOf(item.source_kind, "UNKNOWN_SOURCE"))} ${item.registry_classification ? badge(item.registry_classification) : ""} ${item.attention_required === true ? badge("ATTENTION") : ""}</span><p class="muted">${escapeHtml(valueOf(item.summary))}</p><small>Declared: ${escapeHtml(item.declared_state)} · Freshness: ${escapeHtml(item.freshness)} · Observed: ${escapeHtml(item.observed_at)}</small><details><summary>Provenance</summary><p>${escapeHtml(item.provenance && item.provenance.path)}:${escapeHtml(item.provenance && item.provenance.line)} · ${escapeHtml(item.provenance && item.provenance.canonical_sha)}</p></details></li>`;
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

function observedFreshness(stamp, hours = 24) {
  if (typeof stamp !== "string" || !/T.*(?:Z|[+-]\d{2}:\d{2})$/.test(stamp)) return "UNKNOWN";
  const age = (Date.now() - Date.parse(stamp)) / 3600000;
  if (!Number.isFinite(age)) return "UNKNOWN";
  return age < -5 / 60 ? "FUTURE" : age > hours ? "STALE" : "CURRENT";
}

function tower() { return reportIndex.control_tower || {}; }
function observationCurrent() {
  return navigator.onLine && !usedCachedData && observedFreshness(reportIndex.project.generated_at) === "CURRENT";
}
function ownerCards() {
  const items = tower().need_boss || [];
  const projection = workProjection();
  const graph = window.EALabAgentGraph;
  // Use Work's display-time qualification, including ambiguity and cached/offline gates.
  // The precomputed list supplies historical context only; it cannot grant current action.
  const nodes = graph ? graph.buildModel(projection, {cached: usedCachedData, offline: !navigator.onLine, correlateExactIds: true}).nodes : [];
  const sameEvidence = (a, b) => a.id === b.id && a.source_kind === b.source_kind;
  const current = nodes.filter(node => node.source_kind === "LANE_REGISTRY_NONCANONICAL" && node.owner_required);
  const historical = nodes.filter(node => !node.owner_required &&
    (node.source_kind === "LANE_REGISTRY_NONCANONICAL" && node.blocker === "OWNER_EXTERNAL" || items.some(item => sameEvidence(item, node))));
  const missing = items.filter(item => !nodes.some(node => sameEvidence(item, node)));
  const currentHtml = current.map(node => {
    const item = items.find(item => sameEvidence(item, node)) || {};
    return `<li><strong>${escapeHtml(node.id)}</strong> ${badge(node.state)} ${badge("CURRENT")}<p>${escapeHtml(item.reason || "Explicit Lane Registry E / OWNER_EXTERNAL blocker")}</p><small>${escapeHtml(node.source_kind)}</small><p>Next owner action: ${escapeHtml(item.owner_action || "UNKNOWN")}</p></li>`;
  }).join("");
  const historyHtml = [...historical, ...missing].map(node => {
    const item = items.find(item => sameEvidence(item, node)) || node;
    return `<li data-owner-history><strong>${escapeHtml(node.id)}</strong><p>No current owner action — historical / unqualified evidence.</p><p>${escapeHtml(item.reason || "Explicit OWNER_EXTERNAL observation")}</p><small>${escapeHtml(node.source_kind)} · Freshness: ${escapeHtml(node.freshness || "UNKNOWN")} · State: ${escapeHtml(nodes.includes(node) ? node.state : "UNKNOWN")} · Registry: ${escapeHtml(projection.registry.status || "UNAVAILABLE")} / ${escapeHtml(projection.registry.freshness || "UNKNOWN")} · ${escapeHtml(node.evidence_mode || "MISSING_ROW_OR_GRAPH_UNAVAILABLE")} · Observed: ${escapeHtml(node.observed_at || "UNKNOWN")}</small></li>`;
  }).join("");
  return `<section class="panel need-boss"><h2>NEED BOSS</h2>${!observationCurrent() ? '<p>Owner attention UNKNOWN — refresh current evidence.</p>' : ""}${currentHtml ? `<ul class="queue-list">${currentHtml}</ul>` : '<p>No owner action currently derived.</p><small>Canonical prose is not a structured owner request. Review the current plan below.</small>'}${historyHtml ? `<h3>Historical / unqualified owner evidence</h3><ul class="queue-list">${historyHtml}</ul>` : ""}</section>`;
}
function contextCards(items, empty) {
  return items && items.length ? items.slice(0, 3).map(item => `<article class="panel"><h3>${escapeHtml(item.title || item.id)}</h3><p>${escapeHtml(item.summary)}</p><details><summary>Source / authority</summary><p>${escapeHtml(item.source_kind)} · ${escapeHtml(item.authority || "PLAN_CONTEXT_ONLY")}</p><p>${escapeHtml(item.provenance && item.provenance.path)} · ${escapeHtml(item.provenance && item.provenance.canonical_sha)}</p></details></article>`).join("") : `<p class="empty-state">${empty}</p>`;
}
function renderHome() {
  const registry = tower().registry || {};
  const rows = registry.rows || [];
  const fresh = observationCurrent() && registry.status === "AVAILABLE" && registry.freshness === "CURRENT" && observedFreshness(registry.observed_at) === "CURRENT";
  const currentRows = rows.filter(item => !["UNKNOWN", "CONFLICT"].includes(item.state) && item.freshness === "CURRENT" && observedFreshness(item.observed_at) === "CURRENT");
  app.innerHTML = `<section class="page-heading"><h2>Overview</h2><p>Project: ${escapeHtml(tower().project && tower().project.global_state)} · Control Tower status: UNKNOWN</p></section><section><h2>WORK</h2><p class="muted">Fresh Lane Registry observations · noncanonical</p><div class="work-counts">${["RUNNING", "READY", "WAITING", "BLOCKED", "PARKED"].map(state => `<article><span>${state}</span><strong>${fresh && state !== "PARKED" ? currentRows.filter(item => item.state === state).length : "UNKNOWN"}</strong></article>`).join("")}</div><small>Unresolved observations: ${rows.length - currentRows.length}. Counts exclude these rows. PARKED: unavailable.</small></section>${ownerCards()}<section><h2>RUNTIME</h2><p>Workers / jobs, MT5, VPS: UNKNOWN</p><p>Monitoring: ${escapeHtml(globalMonitoringState())} · <a href="#runtime">Source health</a></p></section><section><h2>CURRENT WORK</h2><p class="muted">Canonical plan context; includes completed and constrained work.</p>${contextCards(tower().project && tower().project.current, "Current plan UNAVAILABLE")}</section><section><h2>NEXT</h2>${contextCards(tower().project && tower().project.next, "Next action UNAVAILABLE")}</section>`;
}

function renderRuntime() {
  app.innerHTML = `<section class="page-heading"><h2>Runtime</h2><p>Read-only observations; Git state is not process health.</p></section><div class="account-grid">${(tower().runtime || []).map(item => `<article class="panel"><h3>${escapeHtml(item.id)}</h3>${badge(item.state)}<p>${escapeHtml(item.reason)}</p><small>Observed: ${escapeHtml(item.observed_at)} · ${escapeHtml(item.source_kind)}</small></article>`).join("") || '<p>Runtime information UNAVAILABLE</p>'}</div>${renderMonitoring()}`;
}

function renderEALab() {
  app.innerHTML = `<section class="page-heading"><h2>EA Lab</h2><p>Portfolio, accounts and canonical research</p></section>${renderKpis()}${renderPortfolioOverview()}${renderAccounts()}${renderCriticalAlerts()}${renderResearch()}`;
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

const nativeObjectUrls = new Set();
let nativeRenderGeneration = 0;
let activeNativeRender = null;

function currentNativeRender(render) {
  const current = route();
  return activeNativeRender === render && render.generation === nativeRenderGeneration &&
    current.page === "detail" && current.id === render.record.id && getRecord(current.id) === render.record;
}
function ownerText(value) {
  return escapeHtml(valueOf(value).replace(/(?:[A-Za-z]:[\\/]|https?:\/\/|file:\/\/|\\\\)\S+/gi, "[LOCAL OR EXTERNAL REFERENCE OMITTED]"));
}

function graphBinding(record, role) {
  const graph = record.native_graphs?.[role];
  if (!graph || graph.state === "MISSING") return {state: "MISSING"};
  if (graph.state !== "AVAILABLE") return {state: "REFUSED"};
  const hash = /^[0-9a-f]{64}$/;
  const match = /^artifacts\/native\/([0-9a-f]{40})\/([0-9a-f]{32})\/(main|bwd)\/([0-9a-f]{64})\.(png|gif|jpg)$/.exec(graph.href || "");
  const other = record.native_graphs?.[role === "main" ? "bwd" : "main"];
  if (!match || match[1] !== reportIndex.project.canonical_sha || match[3] !== role || match[4] !== graph.asset_sha256 ||
      graph.canonical_sha !== reportIndex.project.canonical_sha || graph.ea_id !== record.id || graph.basis_id !== record.evidence?.basis_id ||
      graph.role !== role.toUpperCase() || !hash.test(graph.package_sha256) || !hash.test(graph.report_sha256) ||
      !/^[A-Za-z0-9_.-]{1,128}$/.test(graph.package_id || "") ||
      !/^\d{4}\.\d{2}\.\d{2}$/.test(graph.window?.from || "") || !/^\d{4}\.\d{2}\.\d{2}$/.test(graph.window?.to || "") ||
      graph.window.from >= graph.window.to || other?.href === graph.href ||
      !["image/png", "image/gif", "image/jpeg"].includes(graph.media_type)) return {state: "REFUSED"};
  return graph;
}

function renderNativeWindow(record, role) {
  const graph = graphBinding(record, role);
  const source = record.native_graphs?.[role];
  const label = role.toUpperCase();
  const eligible = ["MODEL_0", "MODEL_1", "MODEL_4"].includes(record.evidence?.model);
  return `<section class="panel native-window" data-role="${role}"><h2>${label}</h2>
    <p class="muted">${ownerText(source?.window?.from)} → ${ownerText(source?.window?.to)}</p>
    <div class="native-graph" data-native-role="${role}"><p class="graph-state" role="status">${graph.state === "AVAILABLE" ? "GRAPH ASSET VERIFYING" : `GRAPH ASSET ${graph.state}`}</p></div>
    ${eligible ? metricCard(`${label} metrics`, record.evidence?.[role]) : '<p>Research performance unavailable for this diagnostic or unknown model.</p>'}
    <details><summary>Graph source</summary><dl class="facts"><div><dt>Report SHA256</dt><dd>${ownerText(source?.report_sha256)}</dd></div><div><dt>Package</dt><dd>${ownerText(source?.package_id)}</dd></div><div><dt>References / available assets</dt><dd>${ownerText(source?.references)} / ${ownerText(source?.available_assets)}</dd></div></dl></details></section>`;
}

async function digestHex(bytes) {
  return Array.from(new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)), b => b.toString(16).padStart(2, "0")).join("");
}

async function mountNativeGraphs(record, render) {
  // Capture BOTH role slots before yielding. An old MAIN completion must never
  // acquire the next record's BWD slot, even when that record has no graph.
  await Promise.all(["main", "bwd"].map(async role => {
    const graph = graphBinding(record, role);
    if (graph.state !== "AVAILABLE") return;
    const slot = render.slots[role];
    const binding = JSON.stringify(graph);
    const ownsSlot = () => currentNativeRender(render) && slot.isConnected &&
      app.querySelector(`[data-native-role="${role}"]`) === slot &&
      JSON.stringify(graphBinding(record, role)) === binding;
    try {
      const namespace = (await digestHex(new TextEncoder().encode(graph.package_id + graph.package_sha256 + record.id))).slice(0,32);
      if (!ownsSlot()) return;
      if (!graph.href.includes(`/${namespace}/${role}/`)) throw new Error("binding mismatch");
      const response = await fetch(graph.href, {cache: "no-store", redirect: "error"});
      if (!ownsSlot()) return;
      if (!response.ok) throw new Error("unavailable");
      const bytes = await response.arrayBuffer();
      if (await digestHex(bytes) !== graph.asset_sha256) throw new Error("content mismatch");
      if (!ownsSlot()) return;
      const blobUrl = URL.createObjectURL(new Blob([bytes], {type: graph.media_type}));
      const img = new Image();
      img.alt = `${role.toUpperCase()} source-bound native MT5 graph`;
      img.src = blobUrl;
      try { await img.decode(); } catch (error) { URL.revokeObjectURL(blobUrl); throw error; }
      if (!ownsSlot()) { URL.revokeObjectURL(blobUrl); return; }
      nativeObjectUrls.add(blobUrl);
      const link = document.createElement("a");
      link.href = blobUrl; link.target = "_blank"; link.rel = "noopener";
      link.setAttribute("aria-label", `Open ${role.toUpperCase()} graph larger`);
      link.append(img);
      slot.querySelector(".graph-state").textContent = "GRAPH ASSET AVAILABLE";
      slot.append(link);
    } catch {
      if (ownsSlot()) {
        slot.querySelector(".graph-state").textContent = "GRAPH ASSET REFUSED";
        render.status.textContent = "INCOMPLETE";
      }
    }
  }));
}

function renderParameters(record) {
  const parameters = record.parameters || {};
  const rows = (items, changed = false) => Array.isArray(items) && items.length ? `<dl class="facts parameter-rows">${items.map(p => `<div data-parameter><dt>${ownerText(p.name)}</dt><dd>${changed ? `${ownerText(p.parent)} → ` : ""}${ownerText(p.value)}</dd></div>`).join("")}</dl>` : '<p class="muted">UNAVAILABLE</p>';
  const boundParent = /^[0-9a-f]{64}$/.test(parameters.parent_sha256 || "") && parameters.parent;
  return `<section class="panel"><h2>Changed from parent</h2>${boundParent ? `<p>${ownerText(parameters.parent)}</p>${rows(parameters.changed, true)}` : '<p>Parent relationship UNAVAILABLE</p>'}</section>
    <section class="panel"><h2>Key parameters</h2>${rows(parameters.key)}</section>
    <section class="panel"><details><summary>Full parameters</summary><p class="muted">Set SHA256: ${ownerText(parameters.source_sha256)}</p><label for="parameter-search">Search parameters</label><input id="parameter-search" type="search" placeholder="Name or value" /><div id="full-parameters">${rows(parameters.all)}</div><p id="parameter-count" role="status"></p></details></section>`;
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
  const setup = record.tested_setup || {};
  const setupRows = [["EA / strategy", record.display_name], ["Symbol", record.home?.symbol], ["Timeframe", record.home?.timeframe], ["Model", evidence.model], ["Set", setup.set], ["Leverage", setup.leverage], ["Install / lane", setup.lane], ["Package", setup.package_id], ["Evidence basis", evidence.basis_id], ["Source SHA", reportIndex.project.canonical_sha]];
  const graphsReady = ["main", "bwd"].every(role => graphBinding(record, role).state === "AVAILABLE");
  app.innerHTML = `<section class="page-heading"><a class="back-link" href="#home">← Back</a><p class="eyebrow">${escapeHtml(valueOf(record.family_id))} · ${escapeHtml(valueOf(record.variant_id))}</p><h2>${escapeHtml(record.display_name)}</h2><p>${badge(record.lifecycle)} ${badge(record.status || record.research_state)}</p></section>
    <section class="panel tested-setup"><h2>Exact tested setup</h2><dl class="facts">${setupRows.map(([k,v]) => `<div><dt>${k}</dt><dd>${ownerText(v)}</dd></div>`).join("")}</dl></section>
    <div class="native-windows">${renderNativeWindow(record, "main")}${renderNativeWindow(record, "bwd")}</div>
    <section class="panel report-status"><h2>Evidence status</h2><dl class="facts"><div><dt>Graph evidence</dt><dd id="graph-evidence-status">${graphsReady ? "VERIFYING" : "INCOMPLETE"}</dd></div><div><dt>Execution status</dt><dd>${ownerText(record.status)}</dd></div><div><dt>Research conclusion</dt><dd>${ownerText(record.verdict)}</dd></div><div><dt>Package / review status</dt><dd>${ownerText(record.package_status)}</dd></div></dl><p class="muted">READ_ONLY_PRESENTATION · Graph availability does not change the research conclusion.</p></section>
    ${record.explanation ? `<section class="panel"><h2>Source explanation</h2>${["evidence", "interpretation", "decision"].map(k => `<h3>${k[0].toUpperCase()+k.slice(1)}</h3><p>${ownerText(record.explanation[k])}</p>`).join("")}</section>` : ""}
    ${renderParameters(record)}
    <section class="summary-grid"><article class="panel"><h3>Summary</h3><dl class="facts"><div><dt>Verdict</dt><dd>${escapeHtml(valueOf(record.verdict))}</dd></div><div><dt>Latest</dt><dd>${escapeHtml(valueOf(record.latest_experiment))}</dd></div><div><dt>Holdout</dt><dd>${escapeHtml(valueOf(evidence.holdout_state))}</dd></div><div><dt>Evidence basis</dt><dd>${escapeHtml(valueOf(evidence.basis_id))}</dd></div></dl></article><article class="panel"><h3>Quality / evidence</h3><dl class="facts"><div><dt>Grade</dt><dd>${escapeHtml(valueOf(record.quality_grade))}</dd></div><div><dt>Confidence</dt><dd>${escapeHtml(valueOf(record.evidence_confidence))}</dd></div><div><dt>Model</dt><dd>${escapeHtml(valueOf(evidence.model))}</dd></div><div><dt>Stage</dt><dd>${escapeHtml(valueOf(evidence.report_stage))}</dd></div></dl></article></section>
    ${(findings.length || weaknesses.length || record.blocker_reason || record.next_action) ? `<section class="panel"><h2>Finding / blocker / next action</h2>${findings.length ? `<h3>Key findings</h3><ul class="plain-list">${findings.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>` : ""}${weaknesses.length ? `<h3>Known weaknesses</h3><ul class="plain-list">${weaknesses.map((item) => `<li>${escapeHtml(item)}</li>`).join("")}</ul>` : ""}${record.blocker_reason ? `<p><strong>${escapeHtml(valueOf(record.blocker_type, "BLOCKED"))}:</strong> ${escapeHtml(record.blocker_reason)}</p>` : ""}${record.next_action ? `<p><strong>Next action:</strong> ${escapeHtml(record.next_action)}</p>` : ""}</section>` : ""}${renderLinks(record.links)}`;
  app.querySelector("#parameter-search")?.addEventListener("input", event => {
    const query = event.target.value.toLowerCase();
    const rows = [...app.querySelectorAll("#full-parameters [data-parameter]")];
    rows.forEach(row => { row.hidden = !row.textContent.toLowerCase().includes(query); });
    app.querySelector("#parameter-count").textContent = `${rows.filter(row => !row.hidden).length} / ${rows.length} parameters`;
  });
  const render = {generation: nativeRenderGeneration, record,
    slots: Object.fromEntries(["main", "bwd"].map(role => [role, app.querySelector(`[data-native-role="${role}"]`)])),
    status: app.querySelector("#graph-evidence-status")};
  activeNativeRender = render;
  mountNativeGraphs(record, render).then(() => {
    if (currentNativeRender(render) && graphsReady && Object.values(render.slots).every(slot => slot.querySelector('.graph-state').textContent === "GRAPH ASSET AVAILABLE")) render.status.textContent = "AVAILABLE";
  });
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

// Requalify timestamps at display time; never upgrade projected freshness.
function workProjection() {
  const registry = tower().registry || {};
  return {...tower(), registry: {...registry,
    freshness: !observationCurrent() ? "UNKNOWN" : registry.freshness === "CURRENT" ? observedFreshness(registry.observed_at) : registry.freshness,
    rows: (registry.rows || []).map(row => ({...row,
      freshness: row.freshness === "CURRENT" ? observedFreshness(row.observed_at) : row.freshness,
      owner_required: row.owner_required === true && observationCurrent()
    }))
  }};
}

function mountWorkGraph(projection) {
  const graph = window.EALabAgentGraph;
  const host = document.querySelector("#work-agent-graph");
  if (!graph) { host.textContent = "Agent Graph UNAVAILABLE: local asset missing."; return; }
  const model = graph.buildModel(projection, {cached: usedCachedData, offline: !navigator.onLine, correlateExactIds: true});
  graph.render(host, model);
  const panel = document.querySelector("#agent-inspect");
  host.querySelectorAll("[data-inspect-key]").forEach(button => button.addEventListener("click", () => {
    const key = button.dataset.inspectKey;
    const detail = graph.inspect(model, key), node = detail.node;
    const fields = [
      ["Task", node.id], ["Title", node.title], ["Objective", node.objective],
      ["Worker", node.worker], ["Role", node.role], ["Provider / model / PID / session", "UNKNOWN"],
      ["State", node.state], ["Declared state", node.declared_state], ["Freshness", node.freshness],
      ["Evidence mode", node.evidence_mode], ["Ref", node.ref], ["Full head SHA", node.head_sha],
      ["Worktree basename", node.worktree], ["Blocker class", node.blocker_class], ["Blocker type", node.blocker],
      ["Review state", node.review_state], ["Reviewer", node.reviewer], ["Reviewed head", node.reviewed_head],
      ["Registry classification", node.registry_classification], ["Observed at", node.observed_at],
      ["NEED BOSS", node.owner_required ? "Qualified current owner blocker" : "No current owner action derived"],
      ["Dependency evidence", node.dependency_evidence], ["Dependencies", JSON.stringify(node.direct_dependencies)],
      ["Relations", JSON.stringify(detail.relations)], ["Unresolved relations", JSON.stringify(detail.unresolved_relations)], ["Issues", JSON.stringify(detail.issues)],
      ["Source", node.source_kind], ["Authority", node.authority], ["Provenance", JSON.stringify(node.provenance)]
    ];
    panel.innerHTML = `<h3 tabindex="-1">Inspect</h3><dl class="agent-inspect-facts">${fields.map(([label, value]) => `<dt>${escapeHtml(label)}</dt><dd>${escapeHtml(value)}</dd>`).join("")}</dl><div class="agent-context-actions">${["STEERING", "TASK", "REVIEW"].map(mode => `<button type="button" data-context-mode="${mode}">COPY ${mode} CONTEXT</button>`).join("")}</div><p class="agent-copy-status" role="status"></p><label>Generated context<textarea readonly aria-label="Generated context"></textarea></label>`;
    panel.hidden = false;
    panel.querySelector("h3").focus();
    panel.querySelectorAll("[data-context-mode]").forEach(button => button.addEventListener("click", async () => {
      const current = graph.buildModel(workProjection(), {cached: usedCachedData, offline: !navigator.onLine, correlateExactIds: true});
      const context = graph.steeringContext(current, key, button.dataset.contextMode);
      panel.querySelector("textarea").value = context;
      const status = panel.querySelector(".agent-copy-status");
      try { await navigator.clipboard.writeText(context); status.textContent = "Context copied. Read-only evidence; no action performed."; }
      catch { status.textContent = "Clipboard unavailable. Select the generated text to copy."; }
    }));
  }));
}

function renderQueue() {
  const groups = ["READY", "RUNNING", "WAITING", "REVIEW", "INTEGRATING", "BLOCKED", "PARKED", "PAUSED", "FROZEN", "CONFLICT", "UNKNOWN", "DONE"];
  const projection = workProjection();
  const registry = projection.registry;
  const sections = [["Canonical taskboard declarations", tower().work || [], "Pinned Git headers; not proof of execution readiness."], ["Lane observations", (registry.rows || []).map(item => ({...item, state: observationCurrent() && registry.status === "AVAILABLE" && registry.freshness === "CURRENT" && item.freshness === "CURRENT" ? item.state : item.state === "CONFLICT" ? "CONFLICT" : "UNKNOWN"})), `NONCANONICAL · ${registry.status || "UNAVAILABLE"} · ${registry.freshness || "UNKNOWN"}`]];
  app.innerHTML = `<section class="page-heading"><h2>Work</h2><p>Canonical declarations and operational observations remain separate.</p></section><section class="panel"><h2>Summary</h2><p>${(tower().work || []).length} Git declarations / ${(registry.rows || []).length} lane observations. Process health UNKNOWN.</p><p>Registry: ${escapeHtml(registry.status)} / ${escapeHtml(registry.freshness)}</p></section><section class="work-graph-area"><h2>Agent Graph</h2><p>Tap a task to inspect evidence or copy context. Scroll each source graph horizontally.</p><div id="work-agent-graph"></div><aside id="agent-inspect" class="panel" aria-label="Agent inspection" hidden></aside></section><h2>Detailed lanes</h2>${sections.map(([title, rows, note]) => `<section><h2>${title}</h2><p>${escapeHtml(note)}</p>${rows.length ? groups.map(group => { const items = rows.filter(item => stateName(item.state) === group); return items.length ? `<details class="panel" ${["RUNNING", "BLOCKED", "CONFLICT"].includes(group) ? "open" : ""}><summary>${group} (${items.length})</summary><ul class="queue-list">${items.map(queueItem).join("")}</ul></details>` : ""; }).join("") : '<p class="empty-state">No rows supplied; source availability must be checked.</p>'}</section>`).join("")}`;
  mountWorkGraph(projection);
}

function renderAlerts() {
  app.innerHTML = `<section class="page-heading"><h2>Alerts</h2><p>SafeProjection finding summaries only.</p></section>${ownerCards()}<section class="panel"><h2>Source warnings</h2><p>Canonical: ${escapeHtml(observedFreshness(reportIndex.project.generated_at))} · Registry: ${escapeHtml(tower().registry && tower().registry.freshness)}</p><p>Conflicting declarations: ${(tower().work || []).filter(item => item.state === "CONFLICT").length}. See Work for provenance.</p></section>${renderCriticalAlerts(true)}${renderMonitoring()}`;
}

function renderRoute() {
  // Invalidate pending success/error callbacks on every navigation, including
  // leaving detail and A -> B -> A. The route replaces graph DOM synchronously.
  nativeRenderGeneration++;
  activeNativeRender = null;
  for (const url of nativeObjectUrls) URL.revokeObjectURL(url);
  nativeObjectUrls.clear();
  const current = route();
  const activePage = ["detail", "compare", "live"].includes(current.page) ? "ealab" : current.page === "queue" ? "work" : current.page;
  document.querySelectorAll("[data-nav]").forEach((link) => link.classList.toggle("active", link.dataset.nav === activePage));
  if (current.page === "detail") renderDetail(current.id);
  else if (current.page === "compare") renderCompare();
  else if (current.page === "live") renderLive();
  else if (["queue", "work"].includes(current.page)) renderQueue();
  else if (current.page === "runtime") renderRuntime();
  else if (current.page === "ealab") renderEALab();
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
    const refreshView = () => { renderProjectMeta(); renderRoute(); };
    window.addEventListener("online", refreshView);
    window.addEventListener("offline", refreshView);
    window.setInterval(refreshView, 60000);
    if ("serviceWorker" in navigator) navigator.serviceWorker.register("./sw.js", { scope: "./" }).catch(() => {});
  } catch (error) {
    renderUnavailable(error);
  }
}

start();
