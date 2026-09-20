"use strict";

const REPORT_INDEX_URL = "./report_index.json";
const FIXTURE_INDEX_URL = "./fixture/report_index.json";
const MISSING = "UNKNOWN";
const KNOWN_DATA_STATES = new Set(["CURRENT", "STALE", "DEGRADED", "MISSING", "UNKNOWN", "UNAVAILABLE"]);
let reportIndex;
let usedCachedData = false;
let startError = null;
let researchMountGeneration = 0;
let knowledgeMountGeneration = 0;

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

// Cross-field validation mirrors the producer; display-time freshness is a separate gate.
function validateOwnerObservationRelations(operations, canonicalSha) {
  const exactObject = (value, keys) => value && typeof value === "object" && !Array.isArray(value) && Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key));
  const envelopeKeys = ["schema_version", "status", "freshness", "source_kind", "timestamp_basis", "authority", "binding_state", "observed_at_utc", "canonical_observed_sha", "source_sha256", "observations", "reason"];
  const rowKeys = ["lane_id", "job_id", "checked_utc", "freshness", "observed_state", "durable_state", "runner_alive", "child_alive", "postcondition_alive", "heartbeat_age_sec", "retry_decision", "result", "local_head", "deliverable_status", "review_status", "canonical_status"];
  const active = new Set(["STARTING", "RUNNING", "POSTCONDITION_RUNNING", "CANCEL_REQUESTED"]);
  const fail = () => { throw new Error("Invalid owner operations relationship"); };
  if (!exactObject(operations, envelopeKeys) || !Array.isArray(operations.observations)) fail();
  const knownPin = typeof operations.canonical_observed_sha === "string" && /^[0-9a-f]{40}$/.test(operations.canonical_observed_sha);
  const knownSource = typeof operations.source_sha256 === "string" && /^[0-9a-f]{64}$/.test(operations.source_sha256);
  if (operations.binding_state === "UNKNOWN") {
    const missing = ["NOT_PROVIDED", "UNREADABLE_INPUT"].includes(operations.reason);
    if (operations.status !== "UNAVAILABLE" || operations.freshness !== "UNKNOWN" || operations.observed_at_utc !== "UNKNOWN" || operations.canonical_observed_sha !== "UNKNOWN" || operations.observations.length || !(missing || operations.reason === "INVALID_INPUT") || (missing ? operations.source_sha256 !== "UNKNOWN" : !knownSource)) fail();
    return;
  }
  if (!knownPin || !knownSource || !validUtcSecond(operations.observed_at_utc)) fail();
  const binding = operations.canonical_observed_sha === canonicalSha ? "MATCHES_CANONICAL_SHA" : "DIFFERENT_CANONICAL_SHA";
  if (operations.binding_state !== binding) fail();
  const available = binding === "MATCHES_CANONICAL_SHA" && operations.freshness === "CURRENT" && operations.observations.every(row => row && row.freshness === "CURRENT");
  const reason = available ? "AVAILABLE_SNAPSHOT" : binding !== "MATCHES_CANONICAL_SHA" ? "CANONICAL_BINDING_MISMATCH" : operations.freshness === "FUTURE" || operations.observations.some(row => row && row.freshness === "FUTURE") ? "FUTURE_OBSERVATION" : operations.freshness === "STALE" || operations.observations.some(row => row && row.freshness === "STALE") ? "STALE_OBSERVATION" : "UNQUALIFIED_OBSERVATION";
  if (operations.status !== (available ? "AVAILABLE" : "UNAVAILABLE") || operations.reason !== reason) fail();
  for (const row of operations.observations) {
    if (!exactObject(row, rowKeys) || !exactObject(row.result, ["state", "exit", "postcondition", "ended"])) fail();
    const sensitive = /(?:^|[._-])(?:account|acct|login|password|credential|secret|token|api[_-]?key)(?:$|[._-])|(?<![0-9])[0-9]{9,}(?![0-9])/i;
    if ([row.lane_id, row.job_id].some(id => typeof id !== "string" || !/^[A-Za-z][A-Za-z0-9._-]{0,127}$/.test(id) || sensitive.test(id))) fail();
    if (!validUtcSecond(row.checked_utc) || Date.parse(row.checked_utc) > Date.parse(operations.observed_at_utc)) fail();
    const result = row.result;
    if (result.ended !== "UNKNOWN" && (!validUtcSecond(result.ended) || Date.parse(result.ended) > Date.parse(row.checked_utc))) fail();
    if (active.has(row.durable_state)) {
      if (![row.durable_state, "LOST_PROCESS", "UNKNOWN"].includes(row.observed_state)) fail();
    } else if (row.durable_state !== "UNKNOWN" && row.observed_state !== row.durable_state) fail();
    if (active.has(row.durable_state) || row.durable_state === "UNKNOWN") {
      if (result.state !== "UNKNOWN" || result.exit !== "UNKNOWN" || result.ended !== "UNKNOWN" || !["UNKNOWN", "RUNNING"].includes(result.postcondition)) fail();
    } else {
      if (result.state !== row.durable_state || !validUtcSecond(result.ended)) fail();
      if (result.state === "COMPLETE" && (result.exit !== 0 || !["PASSED", "NOT_CONFIGURED"].includes(result.postcondition))) fail();
      if (result.state === "FAILED" && result.exit === 0) fail();
      if (result.state === "POSTCONDITION_FAILED" && result.postcondition !== "FAILED") fail();
      if (row.child_alive === true || row.postcondition_alive === true) fail();
    }
    if (row.observed_state === "LOST_PROCESS" && row.runner_alive === true) fail();
    if (row.retry_decision === "ALLOW_RETRY" && [row.runner_alive, row.child_alive, row.postcondition_alive].includes(true)) fail();
  }
}

function ownerObservationDisplay(operations) {
  if (!navigator.onLine) return {status: "UNAVAILABLE", freshness: "OFFLINE"};
  if (usedCachedData) return {status: "UNAVAILABLE", freshness: "CACHED"};
  const projectFreshness = observedFreshness(reportIndex.project.generated_at);
  if (projectFreshness !== "CURRENT") return {status: "UNAVAILABLE", freshness: projectFreshness};
  const envelopeFreshness = observedFreshness(operations.observed_at_utc);
  if (envelopeFreshness !== "CURRENT") return {status: "UNAVAILABLE", freshness: envelopeFreshness};
  const bound = operations.status === "AVAILABLE" && operations.binding_state === "MATCHES_CANONICAL_SHA" && operations.canonical_observed_sha === reportIndex.project.canonical_sha && /^[0-9a-f]{64}$/.test(operations.source_sha256) && operations.freshness === "CURRENT";
  const rowsCurrent = operations.observations.every(row => row.freshness === "CURRENT" && observedFreshness(row.checked_utc) === "CURRENT");
  return bound && rowsCurrent ? {status: "AVAILABLE", freshness: "CURRENT"} : {status: "UNAVAILABLE", freshness: "UNKNOWN"};
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
  const factory = payload.factory_pilots;
  const factoryStates = new Set(["VALID", "MISSING_ARTIFACT", "INVALID_ARTIFACT"]);
  if (!factory || factory.schema !== "factory_pilot_projection/1" || factory.canonical_sha !== project.canonical_sha ||
      !validUtcSecond(factory.observed_at_utc) || !Array.isArray(factory.rows) || !Array.isArray(factory.issues)) {
    throw new Error("Invalid factory pilot projection");
  }
  if (factory.rows.some(row => !row || typeof row.id !== "string" || !factoryStates.has(row.state) ||
      row.source_kind !== "GIT_CANONICAL" || row.authority !== "READ_ONLY_PRESENTATION_NO_STRATEGY_AUTHORITY" ||
      !row.provenance || row.provenance.canonical_sha !== project.canonical_sha ||
      (row.report && (!safeRelativeHref(row.report.href) || row.report.local_paths_redacted !== true)))) {
    throw new Error("Invalid factory pilot row");
  }
  if (/[A-Za-z]:\\|file:\/\//i.test(JSON.stringify(factory))) throw new Error("Factory projection leaked local path");
  const ct = payload.control_tower;
  const states = new Set(["READY", "RUNNING", "WAITING", "REVIEW", "INTEGRATING", "BLOCKED", "PARKED", "PAUSED", "FROZEN", "DONE", "UNKNOWN", "CONFLICT"]);
  if (!ct || ct.version !== 3 || !ct.project || !ct.registry) throw new Error("Missing V3 projection");
  for (const rows of [ct.work, ct.need_boss, ct.runtime, ct.registry.rows, ct.project.current, ct.project.next]) {
    if (!Array.isArray(rows) || rows.some(item => !item || typeof item.id !== "string" || !states.has(item.state))) throw new Error("Invalid V3 collection");
    if (rows.some(item => item.source_kind === "GIT_CANONICAL" && (!item.provenance || item.provenance.canonical_sha !== project.canonical_sha))) throw new Error("Canonical V3 source SHA mismatch");
  }
  if (!ct.project.provenance || ct.project.provenance.canonical_sha !== project.canonical_sha) throw new Error("Canonical V3 source SHA mismatch");
  const operations = payload.owner_operations;
  if (operations !== undefined) {
    const jobStates = new Set(["STARTING", "RUNNING", "POSTCONDITION_RUNNING", "CANCEL_REQUESTED", "COMPLETE", "FAILED", "POSTCONDITION_FAILED", "TIMED_OUT", "CANCELLED", "LOST_PROCESS", "UNKNOWN"]);
    const freshnessStates = new Set(["CURRENT", "STALE", "FUTURE", "UNKNOWN"]);
    const retryStates = new Set(["ALLOW_RETRY", "REFUSE_RETRY", "WAIT_EXTERNAL", "NOT_APPLICABLE", "UNKNOWN"]);
    const postconditionStates = new Set(["PASSED", "FAILED", "NOT_CONFIGURED", "RUNNING", "UNKNOWN"]);
    const operationReasons = new Set(["NOT_PROVIDED", "UNREADABLE_INPUT", "INVALID_INPUT", "AVAILABLE_SNAPSHOT", "CANONICAL_BINDING_MISMATCH", "FUTURE_OBSERVATION", "STALE_OBSERVATION", "UNQUALIFIED_OBSERVATION"]);
    const safeId = /^[A-Za-z][A-Za-z0-9._-]{0,127}$/;
    if (!operations || operations.schema_version !== "EA_LAB_OWNER_OPERATIONS_V1" ||
        !["AVAILABLE", "UNAVAILABLE"].includes(operations.status) ||
        !freshnessStates.has(operations.freshness) ||
        operations.source_kind !== "LOCAL_DURABLE_JOB_STATUS" ||
        operations.timestamp_basis !== "CALLER_SUPPLIED_SNAPSHOT_AT_CHECKED_UTC" ||
        operations.authority !== "READ_ONLY_PRESENTATION_NO_PROCESS_CONTROL" ||
        !["MATCHES_CANONICAL_SHA", "DIFFERENT_CANONICAL_SHA", "UNKNOWN"].includes(operations.binding_state) ||
        !(validUtcSecond(operations.observed_at_utc) || operations.observed_at_utc === "UNKNOWN") ||
        !(/^[0-9a-f]{40}$/.test(operations.canonical_observed_sha) || operations.canonical_observed_sha === "UNKNOWN") ||
        !Array.isArray(operations.observations) ||
        !(/^[0-9a-f]{64}$/.test(operations.source_sha256) || operations.source_sha256 === "UNKNOWN") ||
        !operationReasons.has(operations.reason) ||
        /[A-Za-z]:[\\/]|https?:\/\/|(?:account|acct|login|password|credential|secret|token)[._=-]/i.test(JSON.stringify(operations))) {
      throw new Error("Invalid owner operations projection");
    }
    const laneIds = new Set();
    const jobIds = new Set();
    for (const row of operations.observations) {
      if (!row || !safeId.test(row.lane_id) || !safeId.test(row.job_id) || !validUtcSecond(row.checked_utc) ||
          /(?:account|acct|login)[._-]*[0-9]+|(^|[^0-9])[0-9]{9,}([^0-9]|$)/i.test(`${row.lane_id} ${row.job_id}`) ||
          laneIds.has(row.lane_id) || jobIds.has(row.job_id) || !freshnessStates.has(row.freshness) ||
          !jobStates.has(row.observed_state) || !jobStates.has(row.durable_state) ||
          ![true, false, "UNKNOWN"].includes(row.runner_alive) ||
          ![true, false, "UNKNOWN"].includes(row.child_alive) ||
          ![true, false, "UNKNOWN"].includes(row.postcondition_alive) ||
          !(row.heartbeat_age_sec === "UNKNOWN" || typeof row.heartbeat_age_sec === "number" && Number.isFinite(row.heartbeat_age_sec) && row.heartbeat_age_sec >= 0 && row.heartbeat_age_sec <= Number.MAX_SAFE_INTEGER) ||
          !retryStates.has(row.retry_decision) || !row.result || !jobStates.has(row.result.state) ||
          !(row.result.exit === "UNKNOWN" || Number.isSafeInteger(row.result.exit)) ||
          !postconditionStates.has(row.result.postcondition) ||
          !(validUtcSecond(row.result.ended) || row.result.ended === "UNKNOWN") ||
          !(/^[0-9a-f]{40}$/.test(row.local_head) || row.local_head === "UNKNOWN") ||
          row.deliverable_status !== "UNKNOWN" || row.review_status !== "UNKNOWN" || row.canonical_status !== "UNKNOWN") {
        throw new Error("Invalid owner operations row");
      }
      laneIds.add(row.lane_id);
      jobIds.add(row.job_id);
    }
  }
  if (operations !== undefined) validateOwnerObservationRelations(operations, project.canonical_sha);
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
function ownerOperations() {
  return reportIndex.owner_operations || {
    status: "UNAVAILABLE", freshness: "UNKNOWN", binding_state: "UNKNOWN",
    observed_at_utc: "UNKNOWN", source_sha256: "UNKNOWN", observations: [],
    source_kind: "LOCAL_DURABLE_JOB_STATUS", timestamp_basis: "CALLER_SUPPLIED_SNAPSHOT_AT_CHECKED_UTC",
    authority: "READ_ONLY_PRESENTATION_NO_PROCESS_CONTROL", reason: "NOT_PROVIDED"
  };
}
function observationCurrent() {
  return navigator.onLine && !usedCachedData && observedFreshness(reportIndex.project.generated_at) === "CURRENT";
}
function jobObservationQualified(operations, row) {
  return ownerObservationDisplay(operations).status === "AVAILABLE" && row.freshness === "CURRENT" &&
    observedFreshness(row.checked_utc) === "CURRENT";
}

function observedProcess(value, qualified) {
  if (!qualified || typeof value !== "boolean") return "UNKNOWN";
  return value ? "OBSERVED_ALIVE" : "OBSERVED_NOT_ALIVE";
}
function renderObservedJobs() {
  const operations = ownerOperations();
  const display = ownerObservationDisplay(operations);
  const rows = Array.isArray(operations.observations) ? operations.observations : [];
  const body = rows.map(row => {
    const qualified = jobObservationQualified(operations, row);
    const result = qualified && row.result ? `${stateName(row.result.state)} / exit ${valueOf(row.result.exit)} / ${stateName(row.result.postcondition)} / ended ${valueOf(row.result.ended)}` : "UNKNOWN";
    const heartbeat = qualified ? valueOf(row.heartbeat_age_sec) : "UNKNOWN";
    const localHead = qualified && /^[0-9a-f]{40}$/.test(valueOf(row.local_head, "")) ? row.local_head : "UNKNOWN";
    return `<tr><td><strong>${escapeHtml(row.lane_id)}</strong><br><span class="muted">${escapeHtml(row.job_id)}</span></td><td>${escapeHtml(observedProcess(row.runner_alive, qualified))}</td><td>${escapeHtml(observedProcess(row.child_alive, qualified))}<br><span class="muted">postcondition ${escapeHtml(observedProcess(row.postcondition_alive, qualified))}</span></td><td>${escapeHtml(row.checked_utc)}<br>${badge(qualified ? "CURRENT" : "UNKNOWN")}</td><td>${escapeHtml(heartbeat)}</td><td class="mono">${escapeHtml(localHead)}</td><td>${escapeHtml(result)}<br><span class="muted">retry ${escapeHtml(qualified ? stateName(row.retry_decision) : "UNKNOWN")}</span></td><td>${escapeHtml(row.deliverable_status)} / ${escapeHtml(row.review_status)} / ${escapeHtml(row.canonical_status)}</td></tr>`;
  }).join("");
  const unavailable = rows.length ? "" : display.status === "AVAILABLE" ? '<p class="empty-state">No job rows in the supplied current snapshot.</p>' : '<p class="empty-state">Job observations UNAVAILABLE. No qualified current snapshot is available.</p>';
  return `<section class="panel observed-jobs"><div class="section-heading"><div><h2>Observed jobs</h2><p>Snapshot / last observed only. This is not continuous live monitoring.</p></div><div>${badge(display.status)} ${badge(display.freshness)}</div></div>${unavailable}${rows.length ? `<div class="table-wrap"><table class="job-observation-table"><thead><tr><th>Lane / job</th><th>Runner</th><th>Child / postcondition</th><th>Checked</th><th>Heartbeat age (sec)</th><th>Local head</th><th>Process result</th><th>Deliverable / review / canonical</th></tr></thead><tbody>${body}</tbody></table></div>` : ""}<details><summary>Source / authority / limits</summary><p>${escapeHtml(operations.source_kind)} · ${escapeHtml(operations.timestamp_basis)} · ${escapeHtml(operations.authority)}</p><p>Observed ${escapeHtml(operations.observed_at_utc)} · binding ${escapeHtml(operations.binding_state)} · reason ${escapeHtml(operations.reason)}</p><p>Source SHA256 <span class="mono">${escapeHtml(operations.source_sha256)}</span></p><p>Process booleans describe only checked_utc. Exit 0 / COMPLETE does not establish deliverable, review, or canonical PASS.</p></details></section>`;
}
function renderBlockerGroups() {
  const registry = workProjection().registry || {};
  const currentEnvelope = observationCurrent() && registry.status === "AVAILABLE" && registry.freshness === "CURRENT" && observedFreshness(registry.observed_at) === "CURRENT";
  if (!currentEnvelope) return '<section class="panel"><h2>Observed blocker classes</h2><p class="empty-state">Current blocker classes UNAVAILABLE. The Registry snapshot is unqualified; historical evidence remains in Detailed lanes.</p></section>';
  const rows = (registry.rows || []).filter(row => !["DONE", "UNKNOWN", "CONFLICT"].includes(row.state) && row.freshness === "CURRENT" && observedFreshness(row.observed_at) === "CURRENT" && /^[A-E]$/.test(valueOf(row.blocker_class, "")));
  if (!rows.length) return '<section class="panel"><h2>Observed blocker classes</h2><p class="empty-state">No qualified current blocker-class observations. Historical or unresolved rows remain in Detailed lanes.</p></section>';
  const labels = {A: "PRODUCT_DEFECT", B: "HARNESS_TEST", C: "ENVIRONMENT_DEPENDENCY", D: "EXECUTION_INCOMPLETE", E: "WAIT_EXTERNAL"};
  const groups = [...new Set(rows.map(row => row.blocker_class))].sort();
  return `<section class="panel"><h2>Observed blocker classes</h2><p class="muted">Lane Registry observations only. Literal dependency IDs are shown without interpreting worker prose. E-class is WAIT_EXTERNAL and does not create a NEED BOSS action.</p>${groups.map(group => `<details ${group === "A" ? "open" : ""}><summary>${escapeHtml(group)} · ${escapeHtml(labels[group])} (${rows.filter(row => row.blocker_class === group).length})</summary><ul class="queue-list">${rows.filter(row => row.blocker_class === group).map(row => `<li><strong>${escapeHtml(row.id)}</strong>${badge(row.state)}<span>Dependencies: ${Array.isArray(row.direct_dependencies) ? row.direct_dependencies.map(escapeHtml).join(", ") || "NONE_DECLARED" : "UNKNOWN"}</span></li>`).join("")}</ul></details>`).join("")}</section>`;
}
function ownerCards() {
  const items = tower().need_boss || [];
  const projection = workProjection();
  projection.registry = {...projection.registry, rows: (projection.registry.rows || []).filter(item => item.state !== "DONE")};
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
  const unfinishedRows = rows.filter(item => item.state !== "DONE");
  const currentRows = unfinishedRows.filter(item => !["UNKNOWN", "CONFLICT"].includes(item.state) && item.freshness === "CURRENT" && observedFreshness(item.observed_at) === "CURRENT");
  app.innerHTML = `<section class="page-heading"><h2>Overview</h2><p>Project: ${escapeHtml(tower().project && tower().project.global_state)} · Control Tower status: UNKNOWN</p></section><section><h2>WORK</h2><p class="muted">Fresh Lane Registry observations · noncanonical</p><div class="work-counts">${["RUNNING", "READY", "WAITING", "BLOCKED", "PARKED"].map(state => `<article><span>${state}</span><strong>${fresh && state !== "PARKED" ? currentRows.filter(item => item.state === state).length : "UNKNOWN"}</strong></article>`).join("")}</div><small>Unresolved observations: ${unfinishedRows.length - currentRows.length}. Counts exclude these rows. Registry rows are cumulative history, not concurrent agents. PARKED: unavailable.</small></section>${ownerCards()}<section><h2>RUNTIME</h2><p>Workers / jobs, MT5, VPS: UNKNOWN</p><p>Monitoring: ${escapeHtml(globalMonitoringState())} · <a href="#runtime">Source health</a></p></section><section><h2>CURRENT WORK</h2><p class="muted">Canonical plan context; includes completed and constrained work.</p>${contextCards(tower().project && tower().project.current, "Current plan UNAVAILABLE")}</section><section><h2>NEXT</h2>${contextCards(tower().project && tower().project.next, "Next action UNAVAILABLE")}</section>`;
}

function renderRuntime() {
  app.innerHTML = `<section class="page-heading"><h2>Runtime</h2><p>Read-only observations; Git state is not process health.</p></section><div class="account-grid">${(tower().runtime || []).map(item => `<article class="panel"><h3>${escapeHtml(item.id)}</h3>${badge(item.state)}<p>${escapeHtml(item.reason)}</p><small>Observed: ${escapeHtml(item.observed_at)} · ${escapeHtml(item.source_kind)}</small></article>`).join("") || '<p>Runtime information UNAVAILABLE</p>'}</div>${renderObservedJobs()}${renderMonitoring()}`;
}

function renderFactoryPilots() {
  const factory = reportIndex.factory_pilots || {};
  const summary = factory.summary || {};
  const rows = Array.isArray(factory.rows) ? factory.rows : [];
  const issueCount = Number.isInteger(summary.issue_count) ? summary.issue_count : "UNKNOWN";
  const validCount = Number.isInteger(summary.valid_pilots) ? summary.valid_pilots : "UNKNOWN";
  const total = Number.isInteger(summary.pilot_directories) ? summary.pilot_directories : "UNKNOWN";
  const body = rows.map(row => {
    const reportHref = row.report && safeRelativeHref(row.report.href);
    const report = reportHref ? `<a class="button-link secondary" href="${escapeHtml(reportHref)}">Report</a>` : "UNAVAILABLE";
    const missing = Array.isArray(row.missing_artifacts) && row.missing_artifacts.length ? row.missing_artifacts.join(", ") : "None";
    return `<tr><td class="mono">${escapeHtml(row.id)}</td><td>${badge(row.state)}</td><td>${escapeHtml(valueOf(row.strategy))}</td><td>${escapeHtml(valueOf(row.symbol))} / ${escapeHtml(valueOf(row.timeframe))}</td><td>${escapeHtml(row.evidence_completeness)}</td><td>${escapeHtml(missing)}</td><td>${report}</td></tr>`;
  }).join("");
  return `<section class="panel"><h2>Factory evidence completeness</h2><p>${badge(factory.status || "UNKNOWN")} ${escapeHtml(validCount)} complete / ${escapeHtml(total)} pilot directories · ${escapeHtml(issueCount)} explicit evidence issue(s).</p><p class="muted">Evidence completeness only — not strategy quality, trading loss, runtime health, deployment state or Candidate authority.</p>${rows.length ? `<div class="table-wrap"><table><thead><tr><th>Pilot</th><th>State</th><th>Strategy</th><th>Home</th><th>Evidence</th><th>Missing</th><th>Report</th></tr></thead><tbody>${body}</tbody></table></div>` : '<p class="empty-state">Factory pilot evidence UNAVAILABLE.</p>'}<details><summary>Source / observation / limits</summary><p>${escapeHtml(factory.source_kind || "UNKNOWN")} · Observed ${escapeHtml(factory.observed_at_utc || "UNKNOWN")} · ${escapeHtml(factory.timestamp_basis || "UNKNOWN")}</p><p>${escapeHtml(factory.provenance && factory.provenance.path)} · ${escapeHtml(factory.canonical_sha || "UNKNOWN")}</p><ul class="plain-list">${(factory.limitations || []).map(item => `<li>${escapeHtml(item)}</li>`).join("")}</ul></details></section>`;
}

function operationalPresentationAlerts() {
  const registry = tower().registry || {};
  const rows = registry.rows || [];
  const current = observationCurrent() && registry.status === "AVAILABLE" && registry.freshness === "CURRENT" && observedFreshness(registry.observed_at) === "CURRENT";
  const blocked = current ? rows.filter(row => row.state !== "DONE" && row.freshness === "CURRENT" && observedFreshness(row.observed_at) === "CURRENT" && row.state === "BLOCKED").length : "UNKNOWN";
  const unqualified = current ? rows.filter(row => row.state !== "DONE" && (row.freshness !== "CURRENT" || observedFreshness(row.observed_at) !== "CURRENT" || ["UNKNOWN", "CONFLICT"].includes(row.state))).length : "UNKNOWN";
  const factory = reportIndex.factory_pilots || {};
  const issues = factory.summary && Number.isInteger(factory.summary.issue_count) ? factory.summary.issue_count : "UNKNOWN";
  return `<section class="panel"><h2>Work / evidence alerts</h2><p><strong>Current blocked lane observations:</strong> ${escapeHtml(blocked)}</p><p><strong>Stale / unqualified lane observations:</strong> ${escapeHtml(unqualified)}</p><p><strong>Factory evidence issues:</strong> ${escapeHtml(issues)}</p><p class="muted">These are work/evidence conditions only. They do not imply trading loss, abnormal market behavior, EA malfunction or runtime failure.</p></section>`;
}
function renderEALab() {
  app.innerHTML = `<section class="page-heading"><h2>EA Lab</h2><p>Portfolio, accounts, canonical research and source-bound Factory evidence completeness</p><a class="button-link" href="#research">Open Research Workbook · เปิดสมุดวิจัย</a></section>${renderKpis()}${renderPortfolioOverview()}${renderAccounts()}${renderFactoryPilots()}${renderCriticalAlerts()}${renderResearch()}`;
  bindResearchFilters();
}

async function renderResearchWorkbook(generation) {
  const workbook = window.EALabResearchWorkbook;
  if (!workbook) {
    app.innerHTML = '<section class="panel"><h2>Research Workbook unavailable</h2><p>The local workbook module did not load.</p></section>';
    return;
  }
  const monitor = {
    available: !!reportIndex,
    state: reportIndex ? globalMonitoringState() : "UNKNOWN",
    records: reportIndex && Array.isArray(reportIndex.eas) ? reportIndex.eas : []
  };
  if (workbook.isMounted(app)) workbook.updateMonitor(monitor);
  else {
    app.innerHTML = '<p class="empty-state">Loading local owner workbook...</p>';
    try { await workbook.mount(app, {monitor, isCurrent: () => generation === researchMountGeneration && route().page === "research"}); }
    catch (error) { if (generation === researchMountGeneration && route().page === "research") app.innerHTML = `<section class="panel"><h2>Research Workbook unavailable</h2><p>${escapeHtml(error.message)}</p><p>Monitor truth remains ${reportIndex ? escapeHtml(globalMonitoringState()) : "UNKNOWN"}.</p></section>`; }
  }
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

function recipePresentation(record) {
  const p = record.parameters;
  const hash = p?.source_sha256;
  const bound = /^[0-9a-f]{64}$/.test(hash || "") && hash === record.tested_setup?.set_sha256 &&
    record.package_status === "INTEGRITY_VALIDATED_REVIEW_UNKNOWN" &&
    ["main", "bwd"].every(role => boundReportRole(record, role)?.package_id === record.tested_setup?.package_id);
  const rows = p?.all;
  const valid = bound && Array.isArray(rows) && rows.length &&
    rows.every(r => r && typeof r.name === "string" && r.name && ["string", "number", "boolean"].includes(typeof r.value)) &&
    new Set(rows.map(r => r.name)).size === rows.length;
  return {source: valid ? hash : "UNAVAILABLE", reason: valid ? "EXPLICIT_RESOLUTION_REQUIRED" : "REQUEST_SOURCE_UNAVAILABLE_OR_AMBIGUOUS",
    rows: valid ? rows.map(r => ({name:r.name, requested:r.value, effective:"UNKNOWN", state:"SEMANTICS_REQUIRED", reason:"EXPLICIT_RESOLUTION_REQUIRED"})) : []};
}

function boundReportRole(record, role) {
  const g = record.native_graphs?.[role];
  const other = record.native_graphs?.[role === "main" ? "bwd" : "main"];
  return g && ["AVAILABLE", "MISSING"].includes(g.state) && g.ea_id === record.id &&
    g.basis_id === record.evidence?.basis_id && g.canonical_sha === reportIndex.project.canonical_sha &&
    g.role === role.toUpperCase() && /^[0-9a-f]{64}$/.test(g.report_sha256 || "") &&
    /^[0-9a-f]{64}$/.test(g.package_sha256 || "") && typeof g.package_id === "string" && g.package_id &&
    /^\d{4}\.\d{2}\.\d{2}$/.test(g.window?.from || "") && /^\d{4}\.\d{2}\.\d{2}$/.test(g.window?.to || "") &&
    g.window.from < g.window.to && g.report_sha256 !== other?.report_sha256 ? g : null;
}

function exposurePresentation(record, role) {
  const g = boundReportRole(record, role), e = record.exposure?.[role];
  const keys = ["ea_id", "basis_id", "canonical_sha", "role", "report_sha256", "package_id", "package_sha256"];
  const bound = g && e && keys.every(k => e[k] === g[k]) && e.window?.from === g.window.from && e.window?.to === g.window.to &&
    e.source?.canonical_sha === g.canonical_sha && /^[0-9a-f]{64}$/.test(e.source?.sha256 || "") && safeRelativeHref(e.source?.path) &&
    record.provenance?.some(p => p.path === e.source.path && p.sha256 === e.source.sha256 && p.canonical_sha === e.source.canonical_sha);
  const numeric = k => bound && typeof e.values?.[k] === "string" && /^\d+(?:\.\d+)?$/.test(e.values[k]) && Number.isFinite(Number(e.values[k])) ? e.values[k] : "UNAVAILABLE";
  return {reason: bound ? "SOURCE_BOUND_OBSERVATION" : "NO_QUALIFIED_EXPOSURE_FOR_BOUND_ROLE", source: bound ? `${e.source.path} SHA256 ${e.source.sha256}` : "UNAVAILABLE",
    rows: [["Observed max depth", numeric("max_depth")], ["Observed max total lots", numeric("max_lots")],
      ["Max concurrent positions", "UNAVAILABLE: no explicit position-count evidence"],
      ["Max grid span / unit", "UNAVAILABLE: no qualified span evidence"], ["L1...Ln lot ladder", "UNAVAILABLE: no qualified ladder evidence"]]};
}

function renderOwnerPresentations(record) {
  const recipe = recipePresentation(record);
  return `<section class="panel owner-recipe"><h2>Owner Recipe</h2><p>Requested → Effective → State → Reason</p><p>${ownerText(recipe.reason)} · Set SHA256: ${ownerText(recipe.source)}</p>
    <p>Effective controls UNKNOWN: no validated Owner Recipe source bundle is bound to this report.</p>
    <details><summary>Requested controls (${recipe.rows.length})</summary>${recipe.rows.map(r => `<article><h3>${ownerText(r.name)}</h3><dl class="facts">${["requested", "effective", "state", "reason"].map(k => `<div><dt>${k}</dt><dd>${ownerText(r[k])}</dd></div>`).join("")}</dl></article>`).join("") || "UNAVAILABLE"}</details></section>
    <section class="panel exposure"><h2>Grid / exposure</h2>${["main", "bwd"].map(role => { const e = exposurePresentation(record, role); return `<h3>${role.toUpperCase()} exposure</h3><p>${ownerText(e.reason)}</p><dl class="facts">${e.rows.map(([k,v]) => `<div><dt>${k}</dt><dd>${ownerText(v)}</dd></div>`).join("")}</dl><p class="muted">${ownerText(e.source)}</p>`; }).join("")}</section>
    <section class="panel"><h2>Chat Report Card</h2><p>Deterministic source summary · READ_ONLY_PRESENTATION</p><textarea id="chat-report-card" aria-label="Chat Report Card" readonly rows="14"></textarea><button id="copy-report-card" type="button">Copy report card</button><p id="copy-report-status" role="status"></p></section>`;
}

function chatReportCard(record) {
  const lines = ["Chat Report Card | READ_ONLY_PRESENTATION", `Record: ${record.id}`, `Source SHA: ${reportIndex.project.canonical_sha}`,
    `EA: ${valueOf(record.display_name)}`, `Home: ${valueOf(record.home?.symbol)} / ${valueOf(record.home?.timeframe)}`,
    `Basis: ${valueOf(record.evidence?.basis_id)}`, `Model: ${valueOf(record.evidence?.model)}`,
    `Execution lane: ${valueOf(record.tested_setup?.lane)}`, `Execution status: ${valueOf(record.status)}`, `Research conclusion: ${valueOf(record.verdict)}`, `Package / review status: ${valueOf(record.package_status)}`];
  for (const role of ["main", "bwd"]) {
    const g = boundReportRole(record, role);
    lines.push(`${role.toUpperCase()} window: ${g ? `${g.window.from} -> ${g.window.to}` : "UNAVAILABLE: role/window binding missing or refused"}`);
    if (g) {
      lines.push(`Report SHA256: ${g.report_sha256}`, `Package: ${g.package_id} SHA256 ${g.package_sha256}`);
      if (["MODEL_0", "MODEL_1", "MODEL_4"].includes(record.evidence?.model))
        for (const k of ["pf", "net", "eqdd_pct", "dd_pct", "trades", "cycles"]) lines.push(`${role.toUpperCase()} ${k}: ${valueOf(record.evidence?.[role]?.[k])}`);
    }
    const e = exposurePresentation(record, role);
    lines.push(`${role.toUpperCase()} exposure: ${e.reason}`, ...e.rows.map(([k,v]) => `${k}: ${v}`), `Exposure source: ${e.source}`);
  }
  const recipe = recipePresentation(record);
  lines.push(`Owner Recipe: ${recipe.reason}`, `Set SHA256: ${recipe.source}`, "Requested -> Effective -> State -> Reason",
    ...recipe.rows.map(r => `${r.name}: ${r.requested} -> ${r.effective} -> ${r.state} -> ${r.reason}`));
  return lines.join("\n").replace(/(?:[A-Za-z]:[\\/]|https?:\/\/|file:\/\/|\\\\)\S+/gi, "[LOCAL OR EXTERNAL REFERENCE OMITTED]");
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
    ${renderOwnerPresentations(record)}
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
  const card = app.querySelector("#chat-report-card"), copyStatus = app.querySelector("#copy-report-status");
  card.value = chatReportCard(record);
  app.querySelector("#copy-report-card").addEventListener("click", async () => {
    if (!currentNativeRender(render)) return;
    try {
      await navigator.clipboard.writeText(card.value);
      if (currentNativeRender(render)) copyStatus.textContent = "Copied";
    } catch {
      if (!currentNativeRender(render)) return;
      card.focus(); card.select(); copyStatus.textContent = "Clipboard unavailable. Copy the selected text.";
    }
  });
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
  const sections = [["Canonical taskboard declarations", tower().work || [], "Pinned Git headers; not proof of execution readiness."], ["Lane observations", (registry.rows || []).map(item => ({...item, state: item.state === "DONE" ? "DONE" : observationCurrent() && registry.status === "AVAILABLE" && registry.freshness === "CURRENT" && observedFreshness(registry.observed_at) === "CURRENT" && item.freshness === "CURRENT" ? item.state : item.state === "CONFLICT" ? "CONFLICT" : "UNKNOWN"})), `NONCANONICAL · ${registry.status || "UNAVAILABLE"} · ${registry.freshness || "UNKNOWN"}`]];
  const qualifiedRows = (registry.rows || []).filter(item => observationCurrent() && registry.status === "AVAILABLE" && registry.freshness === "CURRENT" && observedFreshness(registry.observed_at) === "CURRENT" && item.state !== "DONE" && !["UNKNOWN", "CONFLICT"].includes(item.state) && item.freshness === "CURRENT" && observedFreshness(item.observed_at) === "CURRENT");
  const unfinishedRows = qualifiedRows;
  const doneRows = (registry.rows || []).filter(item => item.state === "DONE");
  app.innerHTML = `<section class="page-heading"><h2>Work</h2><p>Canonical declarations, lane observations and job snapshots remain separate.</p></section><section class="panel"><h2>Summary</h2><p><strong>${unfinishedRows.length}</strong> qualified unfinished lane observation(s) · <strong>${doneRows.length}</strong> DONE historical record(s) · ${(registry.rows || []).length} cumulative Registry record(s).</p><p class="muted">Registry row count is accumulated work history, not the number of agents running concurrently. Process health remains UNKNOWN unless separately evidenced.</p><p>Registry: ${escapeHtml(registry.status)} / ${escapeHtml(registry.freshness)}</p></section>${renderObservedJobs()}${renderBlockerGroups()}<section class="work-graph-area"><h2>Agent Graph</h2><p>Tap a task to inspect evidence or copy context. Scroll each source graph horizontally.</p><div id="work-agent-graph"></div><aside id="agent-inspect" class="panel" aria-label="Agent inspection" hidden></aside></section><h2>Detailed lanes</h2>${sections.map(([title, rows, note]) => `<section><h2>${title}</h2><p>${escapeHtml(note)}</p>${rows.length ? groups.map(group => { const items = rows.filter(item => stateName(item.state) === group); return items.length ? `<details class="panel" ${["RUNNING", "BLOCKED", "CONFLICT"].includes(group) ? "open" : ""}><summary>${group} (${items.length})</summary><ul class="queue-list">${items.map(queueItem).join("")}</ul></details>` : ""; }).join("") : '<p class="empty-state">No rows supplied; source availability must be checked.</p>'}</section>`).join("")}`;
  const graphProjection = {...projection, registry: {...registry, rows: (registry.rows || []).filter(item => item.state !== "DONE")}};
  mountWorkGraph(graphProjection);
}

function renderAlerts() {
  app.innerHTML = `<section class="page-heading"><h2>Alerts</h2><p>Source freshness, work blockers and missing evidence. No trading-loss inference.</p></section>${ownerCards()}${operationalPresentationAlerts()}${renderBlockerGroups()}<section class="panel"><h2>Source warnings</h2><p>Canonical: ${escapeHtml(observedFreshness(reportIndex.project.generated_at))} · Registry: ${escapeHtml(tower().registry && tower().registry.freshness)} · Factory: ${escapeHtml(reportIndex.factory_pilots && reportIndex.factory_pilots.status)}</p><p>Conflicting declarations: ${(tower().work || []).filter(item => item.state === "CONFLICT").length}. See Work for provenance.</p></section>${renderCriticalAlerts(true)}${renderMonitoring()}`;
}

async function renderKnowledgeReader(generation) {
  app.innerHTML = '<p class="empty-state">กำลังเปิด Second Brain Reader…</p>';
  const reader = window.EALabKnowledgeReader;
  if (!reader) {
    app.innerHTML = '<section class="panel"><h2>Second Brain Reader unavailable</h2><p>Reader module did not load. Monitor views remain available.</p></section>';
    return;
  }
  try {
    await reader.mount(app, {url: "./knowledge_index.json", binding:window.EALabKnowledgeBinding, getExpectedSha: () => reportIndex && reportIndex.project.canonical_sha, isCurrent: () => generation === knowledgeMountGeneration && route().page === "knowledge"});
  } catch (error) {
    if (generation === knowledgeMountGeneration && route().page === "knowledge" && !app.querySelector(".kr-failure")) {
      app.innerHTML = `<section class="panel"><h2>Second Brain Reader unavailable</h2><p>${escapeHtml(error.message)}</p><p>Monitor views remain available.</p></section>`;
    }
  }
}

function renderRoute() {
  // Invalidate pending success/error callbacks on every navigation, including
  // leaving detail and A -> B -> A. The route replaces graph DOM synchronously.
  nativeRenderGeneration++;
  researchMountGeneration++;
  knowledgeMountGeneration++;
  activeNativeRender = null;
  for (const url of nativeObjectUrls) URL.revokeObjectURL(url);
  nativeObjectUrls.clear();
  const current = route();
  if (current.page !== "knowledge") app.classList.remove("kr-root");
  const activePage = ["detail", "compare", "live", "research"].includes(current.page) ? "ealab" : current.page === "queue" ? "work" : current.page;
  document.querySelectorAll("[data-nav]").forEach((link) => link.classList.toggle("active", link.dataset.nav === activePage));
  if (current.page === "knowledge") { if (!reportIndex) { app.innerHTML='<section class="kr-failure" role="alert"><h2>Second Brain unavailable</h2><p>Monitor canonical pin unavailable. ใช้ไฟล์อ่านออฟไลน์ที่มี binding ครบแทนได้</p></section>'; return; } renderKnowledgeReader(knowledgeMountGeneration); return; }
  if (current.page === "research") { renderResearchWorkbook(researchMountGeneration); return; }
  if (!reportIndex) { renderUnavailable(startError || new Error("Report index unavailable")); return; }
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
  app.innerHTML = `<section class="panel"><h2>Monitoring unavailable</h2><p>${escapeHtml(error.message)}</p><p class="muted">No account, alert, coverage, queue, freshness, or canonical identity is inferred.</p><a class="button-link" href="#research">Open local Research Workbook · เปิดสมุดวิจัย</a></section>`;
}

async function start() {
  window.addEventListener("hashchange", renderRoute);
  const refreshView = () => { if (reportIndex) renderProjectMeta(); renderRoute(); };
  window.addEventListener("online", refreshView);
  window.addEventListener("offline", refreshView);
  window.setInterval(refreshView, 60000);
  if ("serviceWorker" in navigator) navigator.serviceWorker.register("./sw.js", { scope: "./" }).catch(() => {});
  try {
    const fixtureMode = new URLSearchParams(window.location.search).get("fixture") === "1";
    const payload = await fetchIndex(fixtureMode ? FIXTURE_INDEX_URL : REPORT_INDEX_URL);
    reportIndex = validateIndex(payload, fixtureMode);
    renderProjectMeta();
    renderRoute();
  } catch (error) {
    startError = error;
    renderRoute();
  }
}

start();
