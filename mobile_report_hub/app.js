"use strict";

const REPORT_INDEX_URL = "./report_index.json";
const MISSING = "UNAVAILABLE";
let reportIndex;
let usedCachedData = false;

const app = document.querySelector("#app");
const projectMeta = document.querySelector("#project-meta");
const dataWarning = document.querySelector("#data-warning");

function valueOf(value, fallback = MISSING) {
  return value === undefined || value === null || value === "" ? fallback : String(value);
}

function escapeHtml(value) {
  return valueOf(value).replace(/[&<>'"]/g, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;"
  })[character]);
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

function badge(value) {
  return `<span class="badge" aria-label="State: ${escapeHtml(valueOf(value))}">${escapeHtml(valueOf(value))}</span>`;
}

function renderWarning() {
  const status = valueOf(reportIndex.project && reportIndex.project.data_status, "UNKNOWN");
  const warnings = [];
  if (reportIndex.fixture_only === true) warnings.push("FIXTURE ONLY — not production SOT");
  if (!navigator.onLine) warnings.push("OFFLINE");
  if (usedCachedData) warnings.push("CACHED DATA");
  if (status === "STALE") warnings.push("STALE DATA");
  dataWarning.hidden = warnings.length === 0;
  dataWarning.textContent = warnings.join(" · ");
}

function renderProjectMeta() {
  const project = reportIndex.project || {};
  projectMeta.textContent = `SHA ${valueOf(project.canonical_short_sha, "UNKNOWN")} · ${valueOf(project.generated_at, "UNKNOWN")} · ${valueOf(project.data_status, "UNKNOWN")}`;
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

function renderHome() {
  const records = reportIndex.eas || [];
  const groupNames = ["Active", "DEMO", "Candidate", "Research", "Blocked"];
  const counts = groupNames.map((name) => {
    const count = records.filter((record) => String(record.lifecycle).toLowerCase() === name.toLowerCase() || String(record.research_state).toLowerCase() === name.toLowerCase()).length;
    return `<article class="count-card"><span>${escapeHtml(name)}</span><strong>${count}</strong></article>`;
  }).join("");
  const blockers = records.filter((record) => String(record.status).toUpperCase() === "BLOCKED" || String(record.research_state).toUpperCase() === "BLOCKED");

  app.innerHTML = `<section class="page-heading"><h2>Research at a glance</h2><p>Canonical report data is rendered read-only from report_index.json.</p></section>
    <section class="count-grid" aria-label="EA counts">${counts}</section>
    <section class="panel"><h2>Latest / recent</h2><div class="card-list">${records.slice(0, 3).map(recordCard).join("") || "<p class=\"empty-state\">No EA records available.</p>"}</div></section>
    <section class="panel"><h2>Blockers</h2>${blockers.length ? `<ul class="plain-list">${blockers.map((record) => `<li><strong>${escapeHtml(record.display_name)}</strong>: ${escapeHtml(valueOf(record.blocker_type, "BLOCKED"))} — ${escapeHtml(valueOf(record.blocker_reason, "UNAVAILABLE"))}</li>`).join("")}</ul>` : "<p class=\"empty-state\">No blocked records reported.</p>"}</section>
    <section class="panel"><h2>EA list</h2><div class="filters" aria-label="EA filters"><label>Search<input id="search" type="search" placeholder="Name, family, symbol" autocomplete="off" /></label>${filterSelect("Lifecycle", "lifecycle", availableValues("lifecycle"))}${filterSelect("Family", "family_id", availableValues("family_id"))}${filterSelect("Symbol", "symbol", availableValues("symbol"))}${filterSelect("Timeframe", "timeframe", availableValues("timeframe"))}${filterSelect("Grade", "quality_grade", availableValues("quality_grade"))}${filterSelect("Evidence Confidence", "evidence_confidence", availableValues("evidence_confidence"))}${filterSelect("Research status", "research_state", availableValues("research_state"))}</div><div id="ea-results" class="card-list"></div></section>`;

  const renderResults = () => {
    const search = document.querySelector("#search").value.trim().toLowerCase();
    const filters = Object.fromEntries([...document.querySelectorAll("[data-filter]")].map((input) => [input.dataset.filter, input.value]));
    const matches = records.filter((record) => {
      const searchable = [record.display_name, record.family_id, record.variant_id, record.home && record.home.symbol, record.home && record.home.timeframe].join(" ").toLowerCase();
      return (!search || searchable.includes(search)) && recordMatchesFilters(record, filters);
    });
    document.querySelector("#ea-results").innerHTML = matches.length ? matches.map(recordCard).join("") : "<p class=\"empty-state\">No matching EA records.</p>";
  };
  document.querySelector("#search").addEventListener("input", renderResults);
  document.querySelectorAll("[data-filter]").forEach((input) => input.addEventListener("change", renderResults));
  renderResults();
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
  app.innerHTML = `<section class="page-heading"><h2>Compare two records</h2><p>Select exactly two EA records. Numeric rows appear only when both records share an evidence basis.</p></section><section class="panel"><fieldset><legend>Choose records</legend><div class="compare-options">${records.map((record) => `<label class="check-card"><input type="checkbox" value="${escapeHtml(record.id)}" /> <span>${escapeHtml(record.display_name)}<small>${escapeHtml(valueOf(record.family_id))} · ${escapeHtml(valueOf(record.variant_id))}</small></span></label>`).join("")}</div></fieldset><p id="compare-note" class="muted">Choose exactly two records.</p><div id="compare-result"></div></section>`;
  const inputs = [...document.querySelectorAll(".compare-options input")];
  const update = () => {
    const selected = inputs.filter((input) => input.checked);
    inputs.forEach((input) => { input.disabled = !input.checked && selected.length >= 2; });
    const note = document.querySelector("#compare-note");
    const result = document.querySelector("#compare-result");
    if (selected.length !== 2) { note.textContent = "Choose exactly two records."; result.innerHTML = ""; return; }
    const [left, right] = selected.map((input) => getRecord(input.value));
    const sameBasis = left.evidence && right.evidence && left.evidence.basis_id && left.evidence.basis_id === right.evidence.basis_id && left.evidence.basis_id !== "UNAVAILABLE";
    if (!sameBasis) { note.textContent = "DIFFERENT BASIS — numeric comparison is not implied."; result.innerHTML = ""; return; }
    note.textContent = `Compatible basis: ${left.evidence.basis_id}`;
    result.innerHTML = comparisonRows(left, right);
  };
  inputs.forEach((input) => input.addEventListener("change", update));
}

function renderQueue() {
  const queue = reportIndex.queue || [];
  const groups = ["READY", "RUNNING", "BLOCKED", "DONE"];
  app.innerHTML = `<section class="page-heading"><h2>Research queue</h2><p>Queue state is descriptive only; this hub has no execution controls.</p></section>${groups.map((state) => {
    const items = queue.filter((item) => String(item.state).toUpperCase() === state);
    return `<section class="panel"><h2>${state}</h2>${items.length ? `<ul class="queue-list">${items.map((item) => `<li><strong>${escapeHtml(valueOf(item.id))}</strong><span>${badge(item.state)} ${escapeHtml(valueOf(item.blocker_type, "NOT_APPLICABLE"))}</span><p>${escapeHtml(valueOf(item.summary))}</p></li>`).join("")}</ul>` : "<p class=\"empty-state\">No items.</p>"}</section>`;
  }).join("")}`;
}

function renderRoute() {
  const current = route();
  document.querySelectorAll("[data-nav]").forEach((link) => link.classList.toggle("active", link.dataset.nav === current.page));
  if (current.page === "detail") renderDetail(current.id);
  else if (current.page === "compare") renderCompare();
  else if (current.page === "queue") renderQueue();
  else renderHome();
}

async function fetchIndex(url) {
  const response = await fetch(url, { cache: "no-store" });
  if (!response.ok) throw new Error(`Report index unavailable (${response.status})`);
  if (response.headers.get("X-EA-LAB-Cache") === "true") usedCachedData = true;
  return response.json();
}

async function start() {
  try {
    const fixtureMode = new URLSearchParams(window.location.search).get("fixture") === "1";
    if (fixtureMode) {
      reportIndex = await fetchIndex(FIXTURE_INDEX_URL);
      usedFixture = true;
    } else {
      reportIndex = await fetchIndex(REPORT_INDEX_URL);
    }
    renderProjectMeta();
    renderRoute();
    window.addEventListener("hashchange", renderRoute);
    window.addEventListener("online", renderWarning);
    window.addEventListener("offline", renderWarning);
    if ("serviceWorker" in navigator) navigator.serviceWorker.register("./sw.js").catch(() => {});
  } catch (error) {
    projectMeta.textContent = "Report index unavailable";
    dataWarning.hidden = false;
    dataWarning.textContent = !navigator.onLine ? "OFFLINE — no cached report index is available." : "UNAVAILABLE — report index could not be loaded.";
    app.innerHTML = `<section class="panel"><h2>Report unavailable</h2><p>${escapeHtml(error.message)}</p></section>`;
  }
}

start();
