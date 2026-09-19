(function (root, factory) {
  "use strict";
  const api = factory();
  if (typeof module === "object" && module.exports) module.exports = api;
  if (root) root.EALabResearchWorkbook = api;
})(typeof window !== "undefined" ? window : globalThis, function () {
  "use strict";

  const SCHEMA = "EA_LAB_RESEARCH_WORKBOOK_V1";
  const STORAGE_KEY = "ea_lab.research_workbook.v1.current";
  const HISTORY_PREFIX = "ea_lab.research_workbook.v1.history.";
  const MAX_IMPORT_BYTES = 2 * 1024 * 1024;
  const AUTOSAVE_DELAY_MS = 650;
  const FORBIDDEN_KEYS = new Set(["__proto__", "prototype", "constructor"]);
  const ALLOWED_MODELS = new Set(["", "M1_M1_OHLC_RESEARCH", "M0_GENERATED_TICK", "M2_OPEN_PRICE_DIAGNOSTIC_ONLY", "M4_REAL_TICK_FIDELITY"]);
  const SERIES_KINDS = new Set(["equity_native", "balance_native", "dd_native", "equity_reconstructed", "balance_reconstructed", "dd_reconstructed"]);
  const UNVERIFIED_SOURCE_STATES = new Set(["OWNER_ENTERED_UNVERIFIED", "IMPORTED_UNVERIFIED"]);
  const NUMERIC_TABLE_FIELDS = {
    parameters: new Set(["range_min","range_step","range_max"]),
    optimizer_sets: new Set(["seed","estimated_combinations","pass_budget"]),
    results: new Set(["gross_profit","gross_loss","profit_factor","net_profit","return_pct","equity_dd_native","balance_dd_native","trades","wins","losses","expectancy","recovery","concentration","exposure","episodes"]),
    timeseries: new Set(["value"]),
    sensitivity: new Set(["value_x","value_y","metric_value"])
  };
  const ROW_LIMITS = { parameters: 500, universe: 100, optimizer_sets: 100, filters_modules: 200, stage_plan: 100, results: 1000, timeseries: 10000, sensitivity: 500, published_evidence: 200 };
  const STANDARD_STAGES = ["SOURCE_IDENTITY_READINESS","FIXED_MAIN_CONTROL","FIXED_BWD_WHEN_EXACT_CONTRACT_PERMITS","OPTIONAL_MAIN_ONLY_PORTABILITY","WIDE_COARSE_MAIN_ONLY","REGION_SELECT_MAIN_ONLY","MEDIUM_REFINE_MAIN_ONLY","FINE_NEIGHBORS_MAIN_ONLY","ONE_CHANGE_FILTERS","QUALIFIED_INTERACTIONS_OR_STRUCTURAL_STUDIES","LOCKED_CONFIG_BWD","M4_MAIN_BWD_SAME_LINEAGE","TARGETED_PATH_STRESS_MC","HOLDOUT_SEPARATELY_AUTHORIZED"];

  const TABLES = {
    parameters: ["name", "type", "class", "owner_context", "unit", "source_default", "proposed_baseline", "search_state", "active_when", "dependencies", "range_min", "range_step", "range_max", "enum_values", "stage", "rationale", "source_locator"],
    universe: ["logical_symbol", "broker_symbol", "timeframe", "role", "home_state", "notes"],
    optimizer_sets: ["name", "stage", "base_preset_ref", "source_set_ref", "source_set_sha256", "optimizer_xml_ref", "effective_config_sha256", "method", "seed", "parameters", "locked_values", "estimated_combinations", "pass_budget", "preregistration_ref", "region_rule", "participation_rule", "concentration_rule", "exposure_rule", "uncertainty_rule", "stop_rule", "one_expansion_rule", "search_role", "status"],
    filters_modules: ["name", "family", "formula", "version", "source_ref", "role", "direction", "timing", "finality", "warmup", "equality", "readiness", "study_type", "interaction_components", "comparison_baseline", "reason", "falsifier", "risk_owner_reserved"],
    stage_plan: ["stage", "planned_inputs", "entry_gate", "exit_gate", "expected_result", "outputs", "falsifier_stop", "next_consumer", "contract_ref", "budget", "dependencies", "declared_status", "execution_state", "acceptance_state", "prior_bwd_exposure"],
    results: ["campaign_id", "variant_id", "parent_id", "run_id", "pass_id", "stage", "source_ref", "source_sha256", "build_ref", "build_sha256", "set_sha256", "effective_config_sha256", "installation_lineage", "data_identity", "symbol", "timeframe", "model", "window_role", "window_from", "window_to", "currency", "evidence_ref", "evidence_sha256", "mechanical_validity", "verification_state", "gross_profit", "gross_loss", "profit_factor", "net_profit", "return_pct", "equity_dd_native", "balance_dd_native", "trades", "wins", "losses", "expectancy", "recovery", "concentration", "year", "month", "exposure", "episodes", "notes"],
    timeseries: ["series_id", "run_id", "kind", "source_state", "source_ref", "source_sha256", "timestamp", "value", "unit"],
    sensitivity: ["series_id", "run_id", "parameter_x", "value_x", "parameter_y", "value_y", "metric", "metric_unit", "metric_value", "source_state", "source_ref", "source_sha256"],
    published_evidence: ["label", "record_id", "detail_hash", "report_href", "evidence_sha256", "notes"]
  };

  const FIELD_LABELS = {
    class: "Class (structural / entry / distance / exit / safety-risk)", search_state: "Fixed / Search", source_default: "Source default", proposed_baseline: "Proposed baseline",
    search_role: "Search role (MAIN only)", verification_state: "Verification", source_state: "Source state", equity_dd_native: "Native equity DD", balance_dd_native: "Native balance DD",
    risk_owner_reserved: "Risk change owner-reserved", home_state: "Proposed Home / Discovery", declared_status: "Declared status"
  };

  const STRATEGY_FIELDS = [
    ["summary", "Strategy summary"], ["buy_conditions", "BUY conditions"], ["sell_conditions", "SELL conditions"], ["side_asymmetry", "Side asymmetry"],
    ["indicator_semantics", "Indicators: formula/version/TF/equality/warmup/closed-bar/shift/finality"], ["signal_timing", "Signal timing"], ["entry_orders", "Market/pending entry + cancellation"],
    ["position_grid_stack", "Position / grid / stack"], ["lot_formula_ladder_caps", "Lot formula / ladder / caps"], ["recovery_hedge", "Recovery / hedge"],
    ["exit_sl_tp_trailing_partial_basket", "Exit / SL / TP / trailing / partial / basket"], ["filters", "Filters"], ["session_news_spread", "Session / news / spread"], ["safety_halt", "Safety / halt"]
  ];

  const IDENTITY_FIELDS = ["campaign_id", "revision_id", "family_id", "ea_id", "variant_id", "parent_id", "source_ref", "source_sha256", "parent_ref", "parent_sha256", "build_ref", "build_sha256", "config_ref", "config_sha256", "hypothesis", "observation", "expected_benefit", "expected_cost", "objective", "falsifier", "direct_consumer", "constraints", "not_to_repeat", "notes", "provenance"];
  const ENV_FIELDS = ["broker", "server_profile", "installation_lineage", "tester_model", "data_quality", "period", "timezone", "dst", "warmup", "spread", "commission", "swap", "slippage", "deposit", "currency", "leverage"];

  let templateCache = null;
  let state = null;
  let rootNode = null;
  let storage = null;
  let storageStatus = "NOT_CHECKED";
  let monitorStatus = { available: false, state: "UNKNOWN", records: [] };
  let dirty = false;
  let lastSaved = null;
  let autosaveTimer = null;
  let corruptDraftBlocked = false;
  let graphSelection = { resultGroup: "", resultMetric: "net_profit", seriesGroup: "", sensitivityGroup: "" };

  function clone(value) { return JSON.parse(JSON.stringify(value)); }
  function nowUtc() { return new Date().toISOString(); }
  function escapeHtml(value) { return String(value == null ? "" : value).replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"})[c]); }
  function safeText(value) { return value === null || value === undefined || value === "" ? "UNAVAILABLE" : String(value); }
  function title(value) { return FIELD_LABELS[value] || value.replaceAll("_", " ").replace(/\b\w/g, c => c.toUpperCase()); }
  function object(value) { return value && typeof value === "object" && !Array.isArray(value); }
  function finite(value) {
    if (typeof value === "number") return Number.isFinite(value);
    if (typeof value !== "string" || value.trim() === "") return false;
    return /^[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?$/.test(value.trim()) && Number.isFinite(Number(value));
  }
  function validTimestamp(value) {
    if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(value)) return false;
    const parsed = Date.parse(value);
    if (!Number.isFinite(parsed)) return false;
    const canonical = new Date(parsed).toISOString();
    return value.includes(".") ? canonical === value : canonical.replace(".000Z","Z") === value;
  }
  function supplied(value) { return value !== null && value !== undefined && value !== ""; }
  function validSha256(value) { return typeof value === "string" && /^[0-9a-fA-F]{64}$/.test(value); }
  function normalizeLocator(value) { return String(value || "").trim().replaceAll("\\", "/").replace(/\/+/g, "/").toLowerCase(); }
  function emptyRow(name) { return Object.fromEntries(TABLES[name].map(key => [key, key === "risk_owner_reserved" ? false : null])); }

  function scanDuplicateKeys(text) {
    let i = 0;
    const skip = () => { while (/\s/.test(text[i] || "")) i++; };
    const string = () => {
      const start = i++;
      while (i < text.length) {
        if (text[i] === "\\") { i += 2; continue; }
        if (text[i++] === '"') return JSON.parse(text.slice(start, i));
      }
      throw new Error("Unterminated JSON string");
    };
    const primitive = () => { while (i < text.length && !/[\s,\]}]/.test(text[i])) i++; };
    const value = () => {
      skip();
      if (text[i] === "{") return objectValue();
      if (text[i] === "[") return arrayValue();
      if (text[i] === '"') { string(); return; }
      primitive();
    };
    const objectValue = () => {
      i++; skip(); const keys = new Set();
      if (text[i] === "}") { i++; return; }
      while (i < text.length) {
        skip(); if (text[i] !== '"') throw new Error("Invalid JSON object key");
        const key = string();
        if (keys.has(key)) throw new Error(`Duplicate JSON key: ${key}`);
        if (FORBIDDEN_KEYS.has(key)) throw new Error(`Unsafe JSON key: ${key}`);
        keys.add(key); skip(); if (text[i++] !== ":") throw new Error("Invalid JSON object");
        value(); skip();
        if (text[i] === "}") { i++; return; }
        if (text[i++] !== ",") throw new Error("Invalid JSON object");
      }
      throw new Error("Unterminated JSON object");
    };
    const arrayValue = () => {
      i++; skip(); if (text[i] === "]") { i++; return; }
      while (i < text.length) { value(); skip(); if (text[i] === "]") { i++; return; } if (text[i++] !== ",") throw new Error("Invalid JSON array"); }
      throw new Error("Unterminated JSON array");
    };
    value(); skip(); if (i !== text.length) throw new Error("Trailing JSON content");
  }

  function parseImport(text) {
    if (typeof text !== "string" || new TextEncoder().encode(text).length > MAX_IMPORT_BYTES) throw new Error("Import exceeds 2 MiB or is not text");
    scanDuplicateKeys(text);
    const parsed = JSON.parse(text);
    const errors = validateWorkbook(parsed);
    if (errors.length) throw new Error(errors.slice(0, 8).join("; "));
    return parsed;
  }

  function structuralErrors(book) {
    const errors = [];
    if (!object(book) || book.schema_version !== SCHEMA) return ["Unsupported workbook schema"];
    const exactKeys = (value, allowed, label) => { if (object(value)) for (const key of Object.keys(value)) if (!allowed.includes(key)) errors.push(`${label} has unsupported field: ${key}`); };
    exactKeys(book, ["schema_version","document","identity","strategy","parameters","universe","environment","windows","optimizer_sets","filters_modules","stage_plan","results","timeseries","sensitivity","published_evidence","report"], "workbook");
    ["document", "identity", "strategy", "environment", "report"].forEach(key => { if (!object(book[key])) errors.push(`${key} must be an object`); });
    exactKeys(book.document, ["campaign_id","revision_id","previous_revision_id","created_at_utc","updated_at_utc","status","authority"], "document");
    exactKeys(book.identity, ["family_id","ea_id","variant_id","parent_id","source_ref","source_sha256","parent_ref","parent_sha256","build_ref","build_sha256","config_ref","config_sha256","hypothesis","observation","expected_benefit","expected_cost","objective","falsifier","direct_consumer","constraints","not_to_repeat","notes","provenance"], "identity");
    exactKeys(book.strategy, ["summary","buy_conditions","sell_conditions","side_asymmetry","indicator_semantics","signal_timing","entry_orders","position_grid_stack","lot_formula_ladder_caps","recovery_hedge","exit_sl_tp_trailing_partial_basket","filters","session_news_spread","safety_halt","flow_source_label","flow_steps"], "strategy");
    exactKeys(book.environment, ENV_FIELDS, "environment");
    exactKeys(book.report, ["observations","interpretations","decisions","missing_gates","next_action","limitations","review_request"], "report");
    Object.keys(ROW_LIMITS).forEach(key => {
      if (!Array.isArray(book[key])) errors.push(`${key} must be an array`);
      else if (book[key].length > ROW_LIMITS[key]) errors.push(`${key} exceeds ${ROW_LIMITS[key]} rows`);
      else book[key].forEach((row,index) => { if (!object(row)) errors.push(`${key} row ${index + 1} must be an object`); else exactKeys(row,TABLES[key],`${key} row ${index + 1}`); });
    });
    if (!Array.isArray(book.windows) || book.windows.length !== 3) errors.push("windows must contain MAIN, BWD and HOLDOUT");
    else {
      book.windows.forEach((row,index) => { if (!object(row)) errors.push(`window ${index + 1} must be an object`); else exactKeys(row,["role","from","to","purpose","state"],`window ${index + 1}`); });
      if (book.windows.every(object) && book.windows.map(row => row.role).join("|") !== "MAIN|BWD|HOLDOUT") errors.push("Window roles/order must remain MAIN, BWD, HOLDOUT");
    }
    if (object(book.document) && (book.document.status !== "OWNER_DRAFT_UNVERIFIED" || book.document.authority !== "PLANNING_PRESENTATION_ONLY")) errors.push("Draft cannot grant approval/readiness");
    if (Array.isArray(book.windows) && object(book.windows[2]) && book.windows[2].state !== "LOCKED_UNSPENT") errors.push("HOLDOUT must remain LOCKED_UNSPENT in this owner draft");
    if (object(book.strategy) && (!Array.isArray(book.strategy.flow_steps) || book.strategy.flow_steps.some(step => typeof step !== "string"))) errors.push("strategy flow_steps must be an array of strings");
    return errors;
  }

  function validateWorkbook(book) {
    const errors = structuralErrors(book);
    if (!object(book) || book.schema_version !== SCHEMA) return errors;
    if (object(book.document)) for (const key of ["created_at_utc","updated_at_utc"]) if (supplied(book.document[key]) && !validTimestamp(book.document[key])) errors.push(`document ${key} must be a UTC timestamp`);
    const stringIds = [[book.document,["campaign_id","revision_id","previous_revision_id"],"document"],[book.identity,["family_id","ea_id","variant_id","parent_id"],"identity"]];
    for (const [target,keys,label] of stringIds) if (object(target)) for (const key of keys) if (supplied(target[key]) && typeof target[key] !== "string") errors.push(`${label} ${key} must be a string so literal IDs and leading zeros are preserved`);
    if (object(book.environment) && !ALLOWED_MODELS.has(book.environment.tester_model || "")) errors.push("Unknown tester model label");
    for (const row of Array.isArray(book.optimizer_sets) ? book.optimizer_sets : []) {
      if (supplied(row.search_role) && row.search_role !== "MAIN_ONLY") errors.push("Optimizer search_role must be MAIN only (exact MAIN_ONLY) or blank");
      if (row.stage && !["WIDE_COARSE", "REGION_SELECT", "MEDIUM_REFINE", "FINE_NEIGHBORS", "LOCKED_CENTER", "SENSITIVITY"].includes(row.stage)) errors.push(`Invalid optimizer stage: ${row.stage}`);
      if (row.method && !["GRID","GENETIC"].includes(row.method)) errors.push(`Optimizer set ${row.name || "(unnamed)"} method must be GRID or GENETIC`);
      if (supplied(row.seed) && row.method !== "GENETIC") errors.push(`Optimizer set ${row.name || "(unnamed)"} seed only applies to GENETIC plans`);
      const known = new Set((Array.isArray(book.parameters) ? book.parameters : []).map(item => item.name).filter(Boolean));
      const referenced = String(row.parameters || "").split(/[,;\n]/).map(item => item.trim()).filter(Boolean);
      const missing = referenced.filter(name => !known.has(name));
      if (missing.length) errors.push(`Optimizer set ${row.name || "(unnamed)"} references missing parameter(s): ${missing.join(", ")}`);
      const estimate = combinationEstimate(book, row);
      if (supplied(row.estimated_combinations) && (!finite(row.estimated_combinations) || estimate.value === null || Number(row.estimated_combinations) !== estimate.value)) errors.push(`Optimizer set ${row.name || "(unnamed)"} estimated_combinations must match the prospective Cartesian estimate`);
      for (const key of ["seed","pass_budget"]) if (supplied(row[key]) && (!finite(row[key]) || !Number.isInteger(Number(row[key])) || Number(row[key]) < 0)) errors.push(`Optimizer set ${row.name || "(unnamed)"} ${key} must be a nonnegative integer or blank`);
    }
    for (const [idx, row] of (Array.isArray(book.parameters) ? book.parameters : []).entries()) {
      const parts = [row.range_min, row.range_step, row.range_max];
      if (parts.some(supplied) && !parts.every(supplied)) errors.push(`Parameter ${idx + 1} range requires min, step and max`);
      else if (parts.every(supplied) && !parts.every(finite)) errors.push(`Parameter ${idx + 1} range values must be finite numbers`);
      else if (parts.every(finite) && (Number(row.range_step) <= 0 || Number(row.range_min) > Number(row.range_max))) errors.push(`Parameter ${idx + 1} has invalid range`);
      else if (parts.every(finite) && ((Number(row.range_max) - Number(row.range_min)) / Number(row.range_step)) > 1000000) errors.push(`Parameter ${idx + 1} range is too large`);
    }
    const numericResultKeys = ["gross_profit","gross_loss","profit_factor","net_profit","return_pct","equity_dd_native","balance_dd_native","trades","wins","losses","expectancy","recovery","concentration","exposure","episodes"];
    const results = Array.isArray(book.results) ? book.results : [];
    const runCounts = new Map();
    for (const row of results) if (supplied(row.run_id)) runCounts.set(String(row.run_id),(runCounts.get(String(row.run_id))||0)+1);
    for (const [runId,count] of runCounts) if (count>1) errors.push(`Result run link has duplicate run_id: ${runId}`);
    for (const [idx, row] of results.entries()) {
      if (row.verification_state !== "OWNER_ENTERED_UNVERIFIED") errors.push(`Result ${idx + 1} must remain OWNER_ENTERED_UNVERIFIED`);
      if (supplied(row.mechanical_validity) && !["UNKNOWN","NOT_CHECKED","OWNER_ENTERED_UNVERIFIED"].includes(row.mechanical_validity)) errors.push(`Result ${idx + 1} mechanical validity cannot claim PASS in an owner draft`);
      numericResultKeys.forEach(key => { if (supplied(row[key]) && !finite(row[key])) errors.push(`Result ${idx + 1} ${key} must be numeric or blank`); });
      if (finite(row.gross_profit) && Number(row.gross_profit) < 0) errors.push(`Result ${idx + 1} gross_profit must be nonnegative`);
      for (const key of ["profit_factor","equity_dd_native","balance_dd_native","trades","wins","losses","concentration","exposure","episodes"]) if (finite(row[key]) && Number(row[key]) < 0) errors.push(`Result ${idx + 1} ${key} must be nonnegative`);
      for (const key of ["trades","wins","losses","episodes"]) if (finite(row[key]) && !Number.isInteger(Number(row[key]))) errors.push(`Result ${idx + 1} ${key} must be an integer`);
      const computed = profitFactor(row.gross_profit, row.gross_loss);
      if (finite(row.profit_factor) && computed.value !== null && Math.abs(Number(row.profit_factor) - computed.value) > 1e-9) errors.push(`Result ${idx + 1} PF conflicts with gross values`);
      if (supplied(row.profit_factor) && finite(row.gross_profit) && finite(row.gross_loss) && computed.value === null) errors.push(`Result ${idx + 1} profit_factor must be blank when gross loss is zero; PF is UNDEFINED_ZERO_LOSS`);
      if (row.model && !ALLOWED_MODELS.has(row.model)) errors.push(`Result ${idx + 1} has unknown model`);
      if (row.window_role && !["MAIN","BWD","HOLDOUT"].includes(row.window_role)) errors.push(`Result ${idx + 1} has unknown window role`);
      for (const key of ["campaign_id","variant_id","parent_id","run_id","pass_id"]) if (supplied(row[key]) && typeof row[key] !== "string") errors.push(`Result ${idx + 1} ${key} must be a string ID`);
    }
    for (const [idx,row] of (Array.isArray(book.filters_modules) ? book.filters_modules : []).entries()) {
      if (row.readiness && !["PLANNED","UNKNOWN","SOURCE_UNAVAILABLE","OWNER_DRAFT_UNVERIFIED"].includes(row.readiness)) errors.push(`Filter ${idx + 1} readiness cannot grant qualification`);
      if (String(row.study_type || "").toUpperCase() === "INTERACTION") {
        const components = String(row.interaction_components || "").split(/[,;\n]/).map(value => value.trim()).filter(Boolean);
        if (components.length < 2) errors.push(`Filter ${idx + 1} interaction requires at least two named components`);
        if (!supplied(row.comparison_baseline)) errors.push(`Filter ${idx + 1} interaction requires a comparison baseline`);
      }
    }
    for (const [idx,row] of (Array.isArray(book.optimizer_sets) ? book.optimizer_sets : []).entries()) if (row.status && !["PLANNED","DRAFT","BLOCKED","NOT_RUN"].includes(row.status)) errors.push(`Optimizer set ${idx + 1} status cannot grant readiness`);
    for (const [idx,row] of (Array.isArray(book.stage_plan) ? book.stage_plan : []).entries()) {
      if (row.declared_status && !["PLANNED","DRAFT","NOT_RUN","UNKNOWN","BLOCKED"].includes(row.declared_status)) errors.push(`Stage ${idx + 1} declared status cannot grant readiness`);
      if (row.execution_state && !["PLANNED","NOT_RUN","UNKNOWN","BLOCKED"].includes(row.execution_state)) errors.push(`Stage ${idx + 1} execution state cannot claim completion`);
      if (row.acceptance_state && !["NOT_REVIEWED","UNKNOWN","BLOCKED"].includes(row.acceptance_state)) errors.push(`Stage ${idx + 1} acceptance state cannot claim acceptance`);
    }
    const safeHref = value => typeof value === "string" && /^(?:#detail\/[A-Za-z0-9._~%+-]+|(?:\.\/)?[A-Za-z0-9_.~%+-]+(?:\/[A-Za-z0-9_.~%+-]+)*(?:#[A-Za-z0-9_.~%+-]+)?)$/.test(value) && !value.split(/[?#]/)[0].split("/").includes("..");
    for (const [idx,row] of (Array.isArray(book.published_evidence) ? book.published_evidence : []).entries()) if (row.report_href && !safeHref(row.report_href)) errors.push(`Published evidence ${idx + 1} has unsafe report href`);

    const resultByRun = new Map(results.filter(row => supplied(row.run_id) && runCounts.get(String(row.run_id)) === 1).map(row => [String(row.run_id), row]));
    const seriesPoints = new Map();
    for (const [idx,row] of (Array.isArray(book.timeseries) ? book.timeseries : []).entries()) {
      const label = `Timeseries ${idx + 1}`;
      if (!SERIES_KINDS.has(row.kind)) errors.push(`${label} has unknown kind`);
      if (!UNVERIFIED_SOURCE_STATES.has(row.source_state)) errors.push(`${label} source_state must remain UNVERIFIED`);
      if (!validTimestamp(row.timestamp)) errors.push(`${label} timestamp must be a valid UTC instant`);
      if (!finite(row.value)) errors.push(`${label} value must be finite numeric data`);
      if (!supplied(row.series_id) || !supplied(row.run_id)) errors.push(`${label} requires series_id and run_id`);
      if (!resultByRun.has(String(row.run_id || ""))) errors.push(`${label} has unresolved result run link`);
      if (!supplied(row.unit)) errors.push(`${label} requires an explicit unit`);
      if (!supplied(row.source_ref) || !supplied(row.source_sha256)) errors.push(`${label} requires source_ref and source_sha256 provenance`);
      const isDd = String(row.kind || "").startsWith("dd_");
      const unit = String(row.unit || "").toLowerCase();
      if (isDd && !["percent","pct","%"].includes(unit)) errors.push(`${label} DD unit must be percent`);
      if (!isDd && ["percent","pct","%"].includes(unit)) errors.push(`${label} equity/balance unit cannot be percent`);
      const linked = resultByRun.get(String(row.run_id || ""));
      if (linked && !isDd && supplied(linked.currency) && supplied(row.unit) && String(linked.currency).toLowerCase() !== unit) errors.push(`${label} unit conflicts with result currency`);
      const pointKey = [row.series_id,row.run_id,row.kind,row.timestamp,row.unit].map(value => String(value ?? "")).join("|");
      if (seriesPoints.has(pointKey) && String(seriesPoints.get(pointKey)) !== String(row.value)) errors.push(`${label} has a conflicting duplicate point`);
      else seriesPoints.set(pointKey,row.value);
    }
    for (const [idx,row] of (Array.isArray(book.sensitivity) ? book.sensitivity : []).entries()) {
      const label = `Sensitivity ${idx + 1}`;
      if (!UNVERIFIED_SOURCE_STATES.has(row.source_state)) errors.push(`${label} source_state must remain UNVERIFIED`);
      if (!supplied(row.series_id) || !supplied(row.run_id) || !resultByRun.has(String(row.run_id || ""))) errors.push(`${label} requires a resolved series/run link`);
      if (!finite(row.value_x) || !finite(row.metric_value)) errors.push(`${label} value_x and metric_value must be finite numbers`);
      if (supplied(row.value_y) && !finite(row.value_y)) errors.push(`${label} value_y must be finite or blank`);
      if (!supplied(row.parameter_x) || !supplied(row.metric) || !supplied(row.metric_unit)) errors.push(`${label} requires parameter_x, metric and metric_unit`);
      if (!supplied(row.source_ref) || !supplied(row.source_sha256)) errors.push(`${label} requires source provenance`);
    }

    const bindings = new Map();
    const sha = (hash, label) => {
      if (!supplied(hash)) return null;
      const normalized = String(hash).toLowerCase();
      if (!/^[0-9a-f]{64}$/.test(normalized)) { errors.push(`${label} hash must be SHA256 with exactly 64 hex characters`); return null; }
      return normalized;
    };
    const bind = (kind, locator, hash, label) => {
      const normalizedHash = sha(hash,label);
      if (!supplied(locator) || !normalizedHash) return;
      const key = `${kind}|${normalizeLocator(locator)}`;
      if (bindings.has(key) && bindings.get(key) !== normalizedHash) errors.push(`Conflicting ${kind} hashes for locator ${locator}`);
      else bindings.set(key, normalizedHash);
    };
    if (object(book.identity)) {
      bind("source",book.identity.source_ref,book.identity.source_sha256,"identity source");
      bind("parent",book.identity.parent_ref,book.identity.parent_sha256,"identity parent");
      bind("build",book.identity.build_ref,book.identity.build_sha256,"identity build");
      bind("config",book.identity.config_ref,book.identity.config_sha256,"identity config");
    }
    for (const row of Array.isArray(book.optimizer_sets) ? book.optimizer_sets : []) { bind("set",row.source_set_ref,row.source_set_sha256,"optimizer source set"); sha(row.effective_config_sha256,"optimizer effective config"); }
    for (const row of results) { bind("source",row.source_ref,row.source_sha256,"result source"); bind("build",row.build_ref,row.build_sha256,"result build"); sha(row.set_sha256,"result set"); sha(row.effective_config_sha256,"result effective config"); bind("evidence",row.evidence_ref,row.evidence_sha256,"result evidence"); }
    for (const row of Array.isArray(book.timeseries) ? book.timeseries : []) bind("series-source",row.source_ref,row.source_sha256,"timeseries source");
    for (const row of Array.isArray(book.sensitivity) ? book.sensitivity : []) bind("sensitivity-source",row.source_ref,row.source_sha256,"sensitivity source");
    for (const row of Array.isArray(book.published_evidence) ? book.published_evidence : []) bind("evidence",row.report_href,row.evidence_sha256,"published evidence");
    return errors;
  }

  function combinationEstimate(book, row) {
    const names = String(row?.parameters || "").split(/[,;\n]/).map(value => value.trim()).filter(Boolean);
    if (!names.length) return { value: null, label: "UNKNOWN", axes: [] };
    const parameters = new Map((Array.isArray(book?.parameters) ? book.parameters : []).filter(item => supplied(item.name)).map(item => [String(item.name),item]));
    const axes = [];
    let total = 1;
    for (const name of names) {
      const parameter = parameters.get(name);
      if (!parameter) return { value: null, label: "UNKNOWN", axes };
      const enums = String(parameter.enum_values || "").split(/[,;\n|]/).map(value => value.trim()).filter(Boolean);
      let count = enums.length;
      if (!count) {
        const parts = [parameter.range_min,parameter.range_step,parameter.range_max];
        if (!parts.every(finite) || Number(parameter.range_step) <= 0 || Number(parameter.range_min) > Number(parameter.range_max)) return { value: null, label: "UNKNOWN", axes };
        count = Math.floor((Number(parameter.range_max)-Number(parameter.range_min))/Number(parameter.range_step)+1e-10)+1;
      }
      if (!Number.isSafeInteger(count) || count < 1 || total > Number.MAX_SAFE_INTEGER / count) return { value: null, label: "UNKNOWN", axes };
      axes.push({name,count}); total *= count;
    }
    return { value: total, label: `${total} prospective Cartesian combinations`, axes };
  }

  function profitFactor(grossProfit, grossLoss) {
    if (!finite(grossProfit) || !finite(grossLoss)) return { value: null, label: "UNAVAILABLE", denominator: null };
    const loss = Math.abs(Number(grossLoss));
    if (loss === 0) return { value: null, label: "UNDEFINED_ZERO_LOSS", denominator: 0 };
    const value = Number(grossProfit) / loss;
    return { value, label: String(value), denominator: loss };
  }

  function compareRuns(a, b) {
    const fields = ["installation_lineage", "data_identity", "symbol", "timeframe", "model", "window_role", "window_from", "window_to", "currency", "source_ref", "source_sha256", "build_ref", "build_sha256"];
    const mismatches = fields.filter(key => String(a?.[key] ?? "") !== String(b?.[key] ?? ""));
    return { comparable: mismatches.length === 0 && fields.every(key => String(a?.[key] ?? "") !== ""), mismatches };
  }

  function resultIdentity(row) {
    const fields = ["installation_lineage","data_identity","symbol","timeframe","model","window_role","window_from","window_to","currency","source_ref","source_sha256","build_ref","build_sha256"];
    if (!fields.every(key => supplied(row?.[key]))) return null;
    if (!validSha256(row.source_sha256) || !validSha256(row.build_sha256)) return null;
    return fields.map(key => String(row[key])).join("¦");
  }

  function chartGroups(book) {
    const diagnostics = [];
    const resultMap = new Map();
    for (const [index,row] of (Array.isArray(book?.results) ? book.results : []).entries()) {
      const key = resultIdentity(row);
      if (!key) { diagnostics.push(`Result row ${index + 1}: incomplete or invalid source/build provenance; charts UNAVAILABLE for this row.`); continue; }
      if (row.verification_state !== "OWNER_ENTERED_UNVERIFIED") { diagnostics.push(`Result row ${index + 1}: invalid verification state; charts UNAVAILABLE for this row.`); continue; }
      if (!resultMap.has(key)) resultMap.set(key,{key,label:`${row.installation_lineage} · ${row.symbol}/${row.timeframe} · ${row.model} · ${row.window_role} · ${row.currency} · ${row.source_ref} · ${row.build_ref} · OWNER_ENTERED_UNVERIFIED`,rows:[]});
      resultMap.get(key).rows.push({...row,_index:index,_pf:profitFactor(row.gross_profit,row.gross_loss),_dd:finite(row.equity_dd_native)?Number(row.equity_dd_native):null});
    }
    const runRows=new Map();
    for(const row of (Array.isArray(book?.results)?book.results:[]))if(supplied(row.run_id)){const key=String(row.run_id);runRows.set(key,[...(runRows.get(key)||[]),row]);}
    const byRun=new Map([...runRows.entries()].filter(([,rows])=>rows.length===1).map(([key,rows])=>[key,rows[0]]));
    const seriesMap = new Map();
    for (const [index,row] of (Array.isArray(book?.timeseries) ? book.timeseries : []).entries()) {
      const linked = byRun.get(String(row.run_id || ""));
      if (!linked) { diagnostics.push(`Timeseries row ${index + 1}: missing result run link or ambiguous duplicate run_id; series UNAVAILABLE.`); continue; }
      const identity = resultIdentity(linked);
      const isDd = String(row.kind || "").startsWith("dd_");
      const unit = String(row.unit || "").toLowerCase();
      const unitValid = isDd ? ["percent","pct","%"].includes(unit) : supplied(linked.currency) && unit === String(linked.currency).toLowerCase();
      const valid = identity && linked.verification_state === "OWNER_ENTERED_UNVERIFIED" && SERIES_KINDS.has(row.kind) && UNVERIFIED_SOURCE_STATES.has(row.source_state) && validTimestamp(row.timestamp) && finite(row.value) && supplied(row.series_id) && unitValid && supplied(row.source_ref) && /^[0-9a-fA-F]{64}$/.test(String(row.source_sha256 || ""));
      if (!valid) { diagnostics.push(`Timeseries row ${index + 1}: incomplete/invalid provenance, kind, unit, timestamp or value; series UNAVAILABLE.`); continue; }
      const scale = isDd ? "percent" : `currency:${String(row.unit).toLowerCase()}`;
      const key = `${identity}¦${row.run_id}¦${row.series_id}¦${scale}¦${row.source_state}¦${normalizeLocator(row.source_ref)}¦${String(row.source_sha256).toLowerCase()}`;
      if (!seriesMap.has(key)) seriesMap.set(key,{key,label:`${row.run_id} · ${row.series_id} · ${scale} · ${row.source_state} · ${row.source_ref}`,rows:[],result:linked,scale});
      seriesMap.get(key).rows.push(row);
    }
    const sensitivityMap = new Map();
    for (const [index,row] of (Array.isArray(book?.sensitivity) ? book.sensitivity : []).entries()) {
      const linked = byRun.get(String(row.run_id || ""));
      const identity = linked && resultIdentity(linked);
      const valid = identity && linked.verification_state === "OWNER_ENTERED_UNVERIFIED" && UNVERIFIED_SOURCE_STATES.has(row.source_state) && supplied(row.series_id) && supplied(row.parameter_x) && finite(row.value_x) && supplied(row.metric) && supplied(row.metric_unit) && finite(row.metric_value) && supplied(row.source_ref) && /^[0-9a-fA-F]{64}$/.test(String(row.source_sha256 || ""));
      if (!valid) { diagnostics.push(`Sensitivity row ${index + 1}: incomplete/invalid run, metric, unit or provenance; view UNAVAILABLE.`); continue; }
      const key = `${identity}¦${row.run_id}¦${row.series_id}¦${row.metric}¦${row.metric_unit}¦${row.source_state}¦${normalizeLocator(row.source_ref)}¦${String(row.source_sha256).toLowerCase()}`;
      if (!sensitivityMap.has(key)) sensitivityMap.set(key,{key,label:`${row.run_id} · ${row.series_id} · ${row.metric} (${row.metric_unit}) · ${row.source_state} · ${row.source_ref}`,rows:[],result:linked});
      sensitivityMap.get(key).rows.push(row);
    }
    for (const [key,group] of [...seriesMap.entries()]) {
      const points=new Map(); let conflict=false;
      for (const row of group.rows) { const point=`${row.kind}|${row.timestamp}`; if(points.has(point)&&String(points.get(point))!==String(row.value))conflict=true;else points.set(point,row.value); }
      if (conflict) { seriesMap.delete(key); diagnostics.push(`Series ${group.label}: conflicting duplicate point; series UNAVAILABLE.`); }
    }
    return {results:[...resultMap.values()],series:[...seriesMap.values()],sensitivity:[...sensitivityMap.values()],diagnostics};
  }

  function exportText(book) { return JSON.stringify(book, null, 2) + "\n"; }
  function spreadsheetSafe(value) { return typeof value === "string" && /^[=+\-@]/.test(value) ? `'${value}` : value; }
  function revisionCopy(book, stamp = nowUtc()) {
    const next = clone(book);
    const previousId = String(book.document.revision_id || "");
    const baseId = `rev-${stamp.replace(/[^0-9]/g, "").slice(0, 17)}`;
    let candidate = baseId;
    if (previousId === baseId) candidate = `${baseId}-1`;
    else if (previousId.startsWith(`${baseId}-`)) {
      const suffix = previousId.slice(baseId.length + 1);
      if (/^\d+$/.test(suffix)) candidate = `${baseId}-${Number(suffix) + 1}`;
    }
    const occupied = new Set([previousId, String(book.document.previous_revision_id || "")].filter(Boolean));
    let suffix = 1;
    while (occupied.has(candidate)) candidate = `${baseId}-${suffix++}`;
    next.document.previous_revision_id = previousId || null;
    next.document.revision_id = candidate;
    next.document.created_at_utc = stamp;
    next.document.updated_at_utc = stamp;
    next.document.status = "OWNER_DRAFT_UNVERIFIED";
    next.document.authority = "PLANNING_PRESENTATION_ONLY";
    next.results = next.results.map(row => ({...row, verification_state: "OWNER_ENTERED_UNVERIFIED"}));
    return next;
  }

  function storageGet(key) { try { return storage ? storage.getItem(key) : null; } catch { storageStatus = "DENIED"; return null; } }
  function storageSet(key, value) { try { if (!storage) throw new Error(); storage.setItem(key, value); storageStatus = "AVAILABLE"; return true; } catch { storageStatus = "DENIED"; return false; } }
  function saveDraft() {
    if (!state) return false;
    if (autosaveTimer) { clearTimeout(autosaveTimer); autosaveTimer = null; }
    if (corruptDraftBlocked) { storageStatus = "CORRUPT_PRESERVED"; updateStatus(); return false; }
    state.document.updated_at_utc = nowUtc();
    const ok = storageSet(STORAGE_KEY, exportText(state));
    if (ok) { dirty = false; lastSaved = state.document.updated_at_utc; }
    updateStatus();
    return ok;
  }

  function loadDraft(template) {
    const raw = storageGet(STORAGE_KEY);
    if (!raw) return clone(template);
    try {
      scanDuplicateKeys(raw);
      const parsed = JSON.parse(raw);
      const errors = structuralErrors(parsed);
      if (errors.length) throw new Error(errors.join("; "));
      storageStatus = "AVAILABLE";
      return parsed;
    } catch {
      corruptDraftBlocked = true;
      storageStatus = "CORRUPT_PRESERVED";
      return clone(template);
    }
  }

  function getPath(book, path) { return path.split(".").reduce((value, key) => value?.[key], book); }
  function setPath(book, path, value) {
    const keys = path.split("."); let target = book;
    keys.slice(0, -1).forEach(key => { target = target[key]; });
    target[keys.at(-1)] = value;
  }

  function input(path, label, kind = "text", options = null) {
    const value = getPath(state, path);
    if (options) return `<label><span>${escapeHtml(label)}</span><select data-path="${escapeHtml(path)}"><option value=""></option>${options.map(option => `<option value="${escapeHtml(option)}" ${value === option ? "selected" : ""}>${escapeHtml(option)}</option>`).join("")}</select></label>`;
    if (kind === "textarea") return `<label class="rw-wide"><span>${escapeHtml(label)}</span><textarea data-path="${escapeHtml(path)}" rows="3">${escapeHtml(value ?? "")}</textarea></label>`;
    return `<label><span>${escapeHtml(label)}</span><input data-path="${escapeHtml(path)}" type="${kind}" value="${escapeHtml(value ?? "")}" autocomplete="off" /></label>`;
  }

  function renderIdentity() {
    return `<section class="rw-card" id="rw-identity"><h2>Identity & intent · ตัวตนและเป้าหมาย</h2><div class="rw-grid">${IDENTITY_FIELDS.map(key => {
      const path = ["campaign_id", "revision_id"].includes(key) ? `document.${key}` : `identity.${key}`;
      const long = ["hypothesis", "observation", "expected_benefit", "expected_cost", "objective", "falsifier", "direct_consumer", "constraints", "not_to_repeat", "notes", "provenance"].includes(key);
      return input(path, title(key), long ? "textarea" : "text");
    }).join("")}</div></section>`;
  }

  function renderStrategy() {
    const flow = state.strategy.flow_steps.length ? state.strategy.flow_steps.map((step, i) => `<li><input data-flow="${i}" value="${escapeHtml(step)}" /><button type="button" data-remove-flow="${i}">×</button></li>`).join("") : '<li class="rw-empty">No flow steps supplied · ยังไม่มีขั้นตอน</li>';
    return `<section class="rw-card" id="rw-strategy"><h2>Strategy & logic · กลยุทธ์และตรรกะ</h2><div class="rw-grid">${STRATEGY_FIELDS.map(([key,label]) => input(`strategy.${key}`, label, "textarea")).join("")}</div><div class="rw-sub"><div class="rw-section-head"><h3>Source-labelled flow preview</h3><button type="button" data-add-flow>Add step</button></div>${input("strategy.flow_source_label", "Flow source label")}<ol class="rw-flow">${flow}</ol></div></section>`;
  }

  function renderEnvironment() {
    return `<section class="rw-card" id="rw-environment"><h2>Universe & environment · ตลาดและสภาพแวดล้อม</h2><div class="rw-grid">${ENV_FIELDS.map(key => key === "tester_model" ? input(`environment.${key}`, title(key), "select", [...ALLOWED_MODELS].filter(Boolean)) : input(`environment.${key}`, title(key))).join("")}</div><h3>Window roles</h3><div class="rw-window-grid">${state.windows.map((row, index) => `<article><strong>${escapeHtml(row.role)}</strong><label>From<input type="date" data-window="${index}" data-key="from" value="${escapeHtml(row.from ?? "")}"></label><label>To<input type="date" data-window="${index}" data-key="to" value="${escapeHtml(row.to ?? "")}"></label><p>${escapeHtml(row.purpose)} · ${escapeHtml(row.state)}</p></article>`).join("")}</div></section>${renderTable("universe", "Symbol + TF plan", "Home is proposed only; timeframe is explicit and never inferred from indicator TF.")}`;
  }

  function selectOptions(groups, selected, emptyLabel) {
    return `<option value="">${escapeHtml(emptyLabel)}</option>${groups.map(group => `<option value="${escapeHtml(group.key)}" ${group.key === selected ? "selected" : ""}>${escapeHtml(group.label)}</option>`).join("")}`;
  }
  function selectedGroup(groups, key) { return groups.find(group => group.key === key) || groups[0] || null; }
  function groupedScatter(group) {
    const points = (group?.rows || []).filter(row => row._pf.value !== null && row._dd !== null);
    if (!points.length) return '<p class="rw-empty">UNAVAILABLE - selected compatible group lacks gross profit/loss and native equity DD.</p>';
    const maxX = Math.max(...points.map(point => point._dd),1), maxY = Math.max(...points.map(point => point._pf.value),1);
    return `<p class="rw-chart-source">${escapeHtml(group.label)}</p><svg viewBox="0 0 420 230" role="img" aria-label="PF ratio versus declared native equity drawdown percent"><path d="M45 10V195H410" class="rw-axis"/>${points.map(point => `<circle cx="${45+point._dd/maxX*350}" cy="${195-point._pf.value/maxY*170}" r="6"><title>${escapeHtml(point.run_id || `row ${point._index+1}`)} - PF ratio ${point._pf.value.toFixed(3)} - native equity DD ${point._dd}% - OWNER_ENTERED_UNVERIFIED</title></circle>`).join("")}<text x="145" y="224">Native equity DD (%)</text><text x="6" y="20">PF ratio</text></svg>`;
  }
  function groupedBars(group, metric) {
    const rows = (group?.rows || []).filter(row => supplied(row.year) && finite(row[metric]));
    const unit = metric === "return_pct" ? "percent" : group?.rows?.[0]?.currency || "UNAVAILABLE";
    if (!rows.length) return `<p class="rw-empty">UNAVAILABLE - selected compatible group lacks declared ${escapeHtml(metric)} period rows.</p>`;
    const width = Math.max(420,55+rows.length*42), max = Math.max(...rows.map(row => Math.abs(Number(row[metric]))),1);
    return `<p class="rw-chart-source">${escapeHtml(group.label)} - metric ${escapeHtml(metric)} - unit ${escapeHtml(unit)}</p><div class="rw-chart-scroll"><svg viewBox="0 0 ${width} 230" role="img" aria-label="Declared period ${escapeHtml(metric)} bars in ${escapeHtml(unit)}"><path d="M35 110H${width-10}" class="rw-axis"/>${rows.map((row,i) => { const amount=Number(row[metric]),h=Math.abs(amount)/max*90,y=amount>=0?110-h:110,label=`${row.year}${row.month?`-${row.month}`:""}`; return `<rect x="${45+i*42}" y="${y}" width="26" height="${h}" class="${amount>=0?"rw-positive":"rw-negative"}"><title>${escapeHtml(`${row.run_id || "UNAVAILABLE"} - ${label} - ${metric} ${amount} ${unit} - OWNER_ENTERED_UNVERIFIED`)}</title></rect><text x="${45+i*42}" y="220" transform="rotate(-45 ${45+i*42} 220)">${escapeHtml(label)}</text>`; }).join("")}</svg></div>`;
  }
  function groupedHeatmap(group) {
    const rows = group?.rows || [];
    if (!rows.length) return '<p class="rw-empty">UNAVAILABLE - select a complete sensitivity group with run, metric, unit and provenance.</p>';
    const max=Math.max(...rows.map(row=>Number(row.metric_value))),min=Math.min(...rows.map(row=>Number(row.metric_value))),span=max-min||1;
    return `<p class="rw-chart-source">${escapeHtml(group.label)}</p><div class="rw-heatmap">${rows.map(row => { const light=82-(Number(row.metric_value)-min)/span*45; return `<span style="background:hsl(188 55% ${light}%)"><strong>${escapeHtml(`${row.parameter_x}=${row.value_x}`)}</strong><small>${escapeHtml(row.parameter_y ? `${row.parameter_y}=${safeText(row.value_y)} - ` : "")}${escapeHtml(`${row.metric}=${row.metric_value} ${row.metric_unit}`)}</small></span>`; }).join("")}</div>`;
  }
  function groupedSeries(group) {
    const rows=group?.rows || [];
    if (!rows.length) return '<p class="rw-empty">UNAVAILABLE - no complete source-labelled series group; no curve is inferred.</p>';
    const grouped=rows.reduce((map,row)=>{ const key=`${row.kind} - ${row.source_state} - ${row.source_ref}`; map.set(key,[...(map.get(key)||[]),row]); return map; },new Map());
    const times=rows.map(row=>Date.parse(row.timestamp)),values=rows.map(row=>Number(row.value)),minT=Math.min(...times),maxT=Math.max(...times),timeSpan=maxT-minT||1,min=Math.min(...values),max=Math.max(...values),span=max-min||1;
    const colors=["#45c4c8","#f0b35b","#ef6e76","#9d8cff","#55d68b","#d989d5"];
    const lines=[...grouped.entries()].map(([key,series],i)=>{ const sorted=[...series].sort((a,b)=>Date.parse(a.timestamp)-Date.parse(b.timestamp)); const points=sorted.map(row=>`${35+(Date.parse(row.timestamp)-minT)/timeSpan*365},${195-(Number(row.value)-min)/span*170}`).join(" "); return `<polyline points="${points}" fill="none" stroke="${colors[i%colors.length]}" stroke-width="2"><title>${escapeHtml(`${key} - unit ${series[0]?.unit || "UNAVAILABLE"} - ${sorted.length} point(s)`)}</title></polyline><text x="45" y="${18+i*13}" fill="${colors[i%colors.length]}">${escapeHtml(key)}</text>`; }).join("");
    return `<p class="rw-chart-source">${escapeHtml(group.label)}</p><svg viewBox="0 0 420 230" role="img" aria-label="Source-labelled ${escapeHtml(group.scale)} series over proportional UTC time"><path d="M35 10V195H410" class="rw-axis"/>${lines}<text x="35" y="220">${escapeHtml(new Date(minT).toISOString())}</text><text x="270" y="220">${escapeHtml(new Date(maxT).toISOString())}</text></svg><p class="rw-chart-source">${rows.length} supplied point(s) - scale ${escapeHtml(group.scale)} - native/reconstructed declarations remain UNVERIFIED.</p>`;
  }
  function renderGraphBody(groups = chartGroups(state)) {
    const result=selectedGroup(groups.results,graphSelection.resultGroup),series=selectedGroup(groups.series,graphSelection.seriesGroup),sensitivity=selectedGroup(groups.sensitivity,graphSelection.sensitivityGroup);
    if(result)graphSelection.resultGroup=result.key;if(series)graphSelection.seriesGroup=series.key;if(sensitivity)graphSelection.sensitivityGroup=sensitivity.key;
    const comparison=result&&result.rows.length>=2?"Selected rows share the displayed complete identity and are descriptively comparable; no winner is selected.":"Comparison UNAVAILABLE - selected group has fewer than two complete compatible result rows.";
    return `<div class="rw-chart-grid"><article><h3>PF ratio vs native equity DD (%)</h3>${groupedScatter(result)}</article><article><h3>Declared period metric</h3>${groupedBars(result,graphSelection.resultMetric)}</article><article><h3>Parameter sensitivity</h3>${groupedHeatmap(sensitivity)}</article><article><h3>Equity / balance / DD (separate scales)</h3>${groupedSeries(series)}</article></div><p class="rw-note">${escapeHtml(comparison)} No row ranking, winner, average PF, Candidate promotion, source verification, or cross-install inference is produced.</p>${groups.diagnostics.length?`<details class="rw-diagnostics"><summary>Missing/incompatible chart data (${groups.diagnostics.length})</summary><ul>${groups.diagnostics.map(item=>`<li>${escapeHtml(item)}</li>`).join("")}</ul></details>`:""}`;
  }
  function renderGraphs() {
    const groups=chartGroups(state);
    const result=selectedGroup(groups.results,graphSelection.resultGroup),series=selectedGroup(groups.series,graphSelection.seriesGroup),sensitivity=selectedGroup(groups.sensitivity,graphSelection.sensitivityGroup);
    if(result)graphSelection.resultGroup=result.key;if(series)graphSelection.seriesGroup=series.key;if(sensitivity)graphSelection.sensitivityGroup=sensitivity.key;
    return `<section class="rw-card" id="rw-graphs"><h2>Graphs</h2><div class="rw-graph-controls"><label>Compatible result group<select id="rw-result-group">${selectOptions(groups.results,graphSelection.resultGroup,"UNAVAILABLE - no complete result group")}</select></label><label>Period metric<select id="rw-result-metric"><option value="net_profit" ${graphSelection.resultMetric==="net_profit"?"selected":""}>net_profit (result currency)</option><option value="return_pct" ${graphSelection.resultMetric==="return_pct"?"selected":""}>return_pct (percent)</option></select></label><label>Series / scale group<select id="rw-series-group">${selectOptions(groups.series,graphSelection.seriesGroup,"UNAVAILABLE - no compatible series")}</select></label><label>Sensitivity group<select id="rw-sensitivity-group">${selectOptions(groups.sensitivity,graphSelection.sensitivityGroup,"UNAVAILABLE - no compatible sensitivity")}</select></label></div><div class="rw-graph-body">${renderGraphBody(groups)}</div></section>`;
  }

  function renderTable(name, heading, note = "") {
    const rows=state[name],columns=TABLES[name];
    const standard=name==="stage_plan"?'<button type="button" id="rw-standard-stages">Add standard roadmap</button>':"";
    const resultFilter=name==="results"?'<label class="rw-table-filter">Filter result rows by literal text<input id="rw-result-filter" type="search" autocomplete="off" placeholder="run, stage, symbol, source"></label>':"";
    const body=rows.length?rows.map((row,index)=>`<tr data-workbook-row="${name}" data-search-text="${escapeHtml(Object.values(row).map(value=>String(value??"")).join(" ").toLowerCase())}">${columns.map(key=>{const value=row[key];return typeof value==="boolean"?`<td><input aria-label="${escapeHtml(title(key))}" data-table="${name}" data-row="${index}" data-key="${key}" type="checkbox" ${value?"checked":""}></td>`:`<td><input aria-label="${escapeHtml(title(key))}" data-table="${name}" data-row="${index}" data-key="${key}" value="${escapeHtml(value??"")}" /></td>`;}).join("")}<td><button type="button" data-remove-row="${name}" data-row="${index}" aria-label="Remove ${escapeHtml(name)} row ${index+1}">x</button></td></tr>`).join(""):`<tr><td colspan="${columns.length+1}" class="rw-empty">No rows - UNAVAILABLE</td></tr>`;
    const estimates=name==="optimizer_sets"&&rows.length?`<div class="rw-derived" id="rw-optimizer-estimates">${rows.map((row,index)=>`<p><strong>${escapeHtml(row.name||`Optimizer plan ${index+1}`)}:</strong> ${escapeHtml(combinationEstimate(state,row).label)}. Planning estimate only; genetic/pass execution is not predicted or authorized.</p>`).join("")}</div>`:"";
    return `<section class="rw-card" id="rw-${name.replaceAll("_","-")}"><div class="rw-section-head"><div><h2>${escapeHtml(heading)}</h2>${note?`<p>${escapeHtml(note)}</p>`:""}</div><div class="rw-row-actions">${standard}<button type="button" data-add-row="${name}">+ Add row</button></div></div>${resultFilter}<div class="rw-table-wrap"><table><thead><tr>${columns.map(key=>`<th>${escapeHtml(title(key))}</th>`).join("")}<th>Remove</th></tr></thead><tbody>${body}</tbody></table></div>${estimates}</section>`;
  }

  function renderEvidenceLinks() {
    const links = monitorStatus.records.slice(0, 30).map(record => `<option value="${escapeHtml(record.id)}">${escapeHtml(record.display_name || record.id)}</option>`).join("");
    return `<section class="rw-card"><h2>Published evidence · หลักฐานที่เผยแพร่</h2><p>Canonical Monitor records remain read-only and open in the existing detail route.</p><label>Open existing record<select id="rw-record-link"><option value="">Select canonical record</option>${links}</select></label><button type="button" id="rw-open-record">Open #detail</button>${renderTable("published_evidence", "Evidence link plan", "Editable references are declarations, not verified evidence.")}</section>`;
  }

  function printFields(titleText, value, keys) {
    return `<section class="rw-print-section"><h2>${escapeHtml(titleText)}</h2><dl>${keys.map(key=>`<div><dt>${escapeHtml(title(key))}</dt><dd>${escapeHtml(safeText(value?.[key]))}</dd></div>`).join("")}</dl></section>`;
  }
  function printRows(titleText, rows, keys) {
    return `<section class="rw-print-section"><h2>${escapeHtml(titleText)} (${rows.length})</h2>${rows.length?rows.map((row,index)=>`<article class="rw-print-record"><h3>${escapeHtml(titleText)} row ${index+1}</h3><dl>${keys.map(key=>`<div><dt>${escapeHtml(title(key))}</dt><dd>${escapeHtml(safeText(row?.[key]))}</dd></div>`).join("")}</dl></article>`).join(""):'<p>UNAVAILABLE - no rows supplied.</p>'}</section>`;
  }
  function printableResults(rows) {
    return rows.map(row => {
      const derived = profitFactor(row.gross_profit,row.gross_loss);
      let status = "OWNER_ENTERED_UNVERIFIED";
      if (derived.label === "UNDEFINED_ZERO_LOSS") status = supplied(row.profit_factor) ? "INVALID_SUPPLIED_PF_ZERO_LOSS" : "UNDEFINED_ZERO_LOSS";
      else if (derived.value !== null && supplied(row.profit_factor) && finite(row.profit_factor) && Math.abs(Number(row.profit_factor)-derived.value)>1e-9) status = "INVALID_SUPPLIED_PF_CONFLICT";
      else if (derived.value !== null) status = "DERIVED_FROM_GROSS_VALUES";
      return {...row,profit_factor_derived:derived.label,profit_factor_status:status};
    });
  }
  function renderPrintProjection() {
    const strategyKeys=STRATEGY_FIELDS.map(([key])=>key).concat(["flow_source_label"]);
    const groups=chartGroups(state);
    const estimates=state.optimizer_sets.map((row,index)=>{const estimate=combinationEstimate(state,row);return {name:row.name||`Optimizer plan ${index+1}`,prospective_cartesian_estimate:estimate.label,axes:estimate.axes.map(axis=>`${axis.name}=${axis.count}`).join(", ")||"UNAVAILABLE",authority:"PLANNING_ESTIMATE_ONLY_NOT_ACTUAL_PASSES"};});
    return `<article class="rw-print-projection" aria-label="Complete printable workbook report"><header><p>EA LAB RESEARCH WORKBOOK V1</p><h1>Complete owner-draft printable report</h1><p>OWNER_DRAFT_UNVERIFIED / PLANNING_PRESENTATION_ONLY. This report does not verify evidence or authorize execution.</p><p>Schema: ${escapeHtml(state.schema_version)}</p></header>${printFields("Document",state.document,["campaign_id","revision_id","previous_revision_id","created_at_utc","updated_at_utc","status","authority"])}${printFields("Identity and intent",state.identity,IDENTITY_FIELDS.filter(key=>!["campaign_id","revision_id"].includes(key)))}${printFields("Strategy and logic",state.strategy,strategyKeys)}${printRows("Strategy flow steps",state.strategy.flow_steps.map(step=>({step})),["step"])}${printRows("Parameters",state.parameters,TABLES.parameters)}${printFields("Environment",state.environment,ENV_FIELDS)}${printRows("Windows",state.windows,["role","from","to","purpose","state"])}${printRows("Optimizer-set plans",state.optimizer_sets,TABLES.optimizer_sets)}${printRows("Prospective combination estimates",estimates,["name","prospective_cartesian_estimate","axes","authority"])}${printRows("Filters and modules",state.filters_modules,TABLES.filters_modules)}${printRows("Stage roadmap",state.stage_plan,TABLES.stage_plan)}${printRows("Results",printableResults(state.results),TABLES.results.concat(["profit_factor_derived","profit_factor_status"]))}${printRows("Typed time series",state.timeseries,TABLES.timeseries)}${printRows("Sensitivity",state.sensitivity,TABLES.sensitivity)}${printRows("Published evidence declarations",state.published_evidence,TABLES.published_evidence)}<section class="rw-print-section rw-print-charts"><h2>Current charts and diagnostics</h2>${renderGraphBody(groups)}</section>${printFields("Observations, interpretations, decisions and limits",state.report,["observations","interpretations","decisions","missing_gates","next_action","limitations","review_request"])}<footer data-print-end="true">END OF COMPLETE WORKBOOK REPORT</footer></article>`;
  }
  function renderReport() {
    const fields=["observations","interpretations","decisions","missing_gates","next_action","limitations","review_request"];
    return `<section class="rw-card rw-report" id="rw-report"><h2>Printable report</h2><p class="rw-authority">OWNER_DRAFT / UNVERIFIED / PLANNING ONLY. Review request is not an attestation.</p><div class="rw-grid">${fields.map(key=>input(`report.${key}`,title(key),"textarea")).join("")}</div><p>The print action uses the complete current-state text projection below, including every field and row. No PDF engine is included.</p></section>${renderPrintProjection()}`;
  }

  function nav() {
    const items = [["identity","Identity"],["strategy","Logic"],["parameters","Inputs"],["environment","Universe"],["optimizer-sets","Optimize"],["filters-modules","Filters"],["stage-plan","Stages"],["results","Results"],["graphs","Graphs"],["report","Report"]];
    return `<nav class="rw-jump" aria-label="Workbook sections">${items.map(([id,label]) => `<a href="#rw-${id}" data-jump="${id}">${label}</a>`).join("")}</nav>`;
  }

  function shell() {
    const validation = validateWorkbook(state);
    return `<div class="research-workbook"><header class="rw-hero"><div><p class="rw-kicker">EA LAB · OWNER WORKBOOK V1</p><h1>Research Workbook · สมุดวางแผนวิจัย</h1><p>One lossless owner draft for planning, presentation and later review. It cannot run, approve, deploy or unlock HOLDOUT.</p></div><div class="rw-state"><strong>OWNER_DRAFT</strong><span>UNVERIFIED</span><span>Monitor truth: ${escapeHtml(monitorStatus.state || "UNKNOWN")}</span></div></header><div class="rw-actions"><button type="button" id="rw-save">Save local</button><button type="button" id="rw-download">Download plan</button><label class="rw-file">Import plan<input id="rw-import" type="file" accept="application/json,.json"></label><button type="button" id="rw-validate">Validate</button><button type="button" id="rw-revision">New revision</button><button type="button" id="rw-copy-review">Copy review request</button><button type="button" id="rw-print">Printable report</button></div><p id="rw-status" class="rw-status" role="status">${validation.length ? `${validation.length} validation issue(s)` : "Draft structure valid"}</p>${nav()}${renderIdentity()}${renderStrategy()}${renderTable("parameters", "Parameters · พารามิเตอร์", "Exact inventory is preserved; blank/null is not converted to zero.")}${renderEnvironment()}${renderTable("optimizer_sets", "Optimizer-set plans · แผนชุด optimize", "Plan only. MAIN search; no executable .set or command output.")}${renderTable("filters_modules", "Filters & modules · ฟิลเตอร์/โมดูล", "Singles and interactions remain explicit; risk/hedge/recovery is owner-reserved.")}${renderTable("stage_plan", "Stage roadmap · แผนขั้น", "Roadmap declarations are not a dispatch queue.")}${renderTable("results", "Result ledger · บันทึกผล", "All owner-entered rows remain UNVERIFIED; missing metrics stay blank.")}${renderTable("timeseries", "Typed time series", "Declare native versus reconstructed source state.")}${renderTable("sensitivity", "Sensitivity / heatmap data")}${renderGraphs()}${renderEvidenceLinks()}${renderReport()}</div>`;
  }

  function setStatus(message, kind = "info") {
    const node = rootNode?.querySelector("#rw-status"); if (!node) return;
    node.textContent = message; node.dataset.kind = kind;
  }
  function updateStatus() {
    const storageText = storageStatus === "AVAILABLE" ? `Saved ${lastSaved || "locally"}` : `Storage ${storageStatus}`;
    setStatus(`${dirty ? `Unsaved edits - ${storageText}` : storageText} - Monitor truth ${monitorStatus.state || "UNKNOWN"}`, ["DENIED","CORRUPT_PRESERVED"].includes(storageStatus) ? "warn" : "info");
  }
  function bindDerivedControls() {
    const bindSelect=(selector,key)=>rootNode?.querySelector(selector)?.addEventListener("change",event=>{graphSelection[key]=event.target.value;refreshDerived();});
    bindSelect("#rw-result-group","resultGroup"); bindSelect("#rw-result-metric","resultMetric"); bindSelect("#rw-series-group","seriesGroup"); bindSelect("#rw-sensitivity-group","sensitivityGroup");
    rootNode?.querySelector("#rw-result-filter")?.addEventListener("input",event=>{const query=event.target.value.toLowerCase();rootNode.querySelectorAll('[data-workbook-row="results"]').forEach(row=>{row.hidden=!!query&&!row.dataset.searchText.includes(query);});});
  }
  function refreshDerived() {
    if (!rootNode || !state) return;
    const graph=rootNode.querySelector("#rw-graphs");
    if (graph) { graph.outerHTML=renderGraphs(); bindDerivedControls(); }
    const projection=rootNode.querySelector(".rw-print-projection");
    if (projection) projection.outerHTML=renderPrintProjection();
    const estimates=rootNode.querySelector("#rw-optimizer-estimates");
    if (estimates) estimates.innerHTML=state.optimizer_sets.map((row,index)=>`<p><strong>${escapeHtml(row.name||`Optimizer plan ${index+1}`)}:</strong> ${escapeHtml(combinationEstimate(state,row).label)}. Planning estimate only; genetic/pass execution is not predicted or authorized.</p>`).join("");
  }
  function scheduleAutosave() {
    if (autosaveTimer) clearTimeout(autosaveTimer);
    autosaveTimer=setTimeout(()=>{autosaveTimer=null;if(!saveDraft())updateStatus();},AUTOSAVE_DELAY_MS);
  }
  function rerender(anchor) {
    const active = document.activeElement;
    const focus = active?.dataset?.path ? `[data-path="${CSS.escape(active.dataset.path)}"]` : active?.dataset?.table ? `[data-table="${CSS.escape(active.dataset.table)}"][data-row="${CSS.escape(active.dataset.row)}"][data-key="${CSS.escape(active.dataset.key)}"]` : null;
    rootNode.innerHTML = shell(); bind();
    if (anchor) rootNode.querySelector(anchor)?.scrollIntoView({block:"start"});
    if (focus) rootNode.querySelector(focus)?.focus();
  }
  function coerceInput(value) { return value === "" ? null : value; }
  function coerceTableInput(table,key,value,row,inputType) {
    if (inputType === "checkbox") return value;
    if (value === "") return null;
    const parameterType=String(row?.type||"").toLowerCase();
    const typedParameterNumeric=table==="parameters"&&["source_default","proposed_baseline"].includes(key)&&["int","integer","double","float","number","numeric"].includes(parameterType);
    const typedParameterBoolean=table==="parameters"&&["source_default","proposed_baseline"].includes(key)&&["bool","boolean"].includes(parameterType);
    if (typedParameterBoolean && /^(?:true|false)$/i.test(value)) return value.toLowerCase()==="true";
    if ((NUMERIC_TABLE_FIELDS[table]?.has(key)||typedParameterNumeric) && finite(value)) return Number(value);
    return value;
  }
  function mutate() { dirty = true; updateStatus(); scheduleAutosave(); setTimeout(refreshDerived,0); }

  function download(name, text, type = "application/json") {
    const blob = new Blob([text], {type}); const url = URL.createObjectURL(blob); const a = document.createElement("a");
    a.href = url; a.download = name; a.click(); setTimeout(() => URL.revokeObjectURL(url), 0);
  }
  function reviewRequest() {
    return [`EA Research Workbook review request`, `Campaign: ${safeText(state.document.campaign_id)}`, `Revision: ${safeText(state.document.revision_id)}`, `EA / variant: ${safeText(state.identity.ea_id)} / ${safeText(state.identity.variant_id)}`, `Hypothesis: ${safeText(state.identity.hypothesis)}`, `Direct consumer: ${safeText(state.identity.direct_consumer)}`, `Missing gates: ${safeText(state.report.missing_gates)}`, `Authority: OWNER_DRAFT_UNVERIFIED / PLANNING_PRESENTATION_ONLY`, `This request is not an attestation, approval, readiness declaration, or execution contract.`].join("\n");
  }

  function bind() {
    rootNode.querySelectorAll("[data-path]").forEach(node => node.addEventListener("input", () => { setPath(state, node.dataset.path, node.value); mutate(); }));
    rootNode.querySelectorAll("[data-table]").forEach(node => node.addEventListener("input", () => { const row=state[node.dataset.table][Number(node.dataset.row)]; row[node.dataset.key] = coerceTableInput(node.dataset.table,node.dataset.key,node.type==="checkbox"?node.checked:node.value,row,node.type); if (node.dataset.table === "results") row.verification_state = "OWNER_ENTERED_UNVERIFIED"; const tr=node.closest("tr");if(tr)tr.dataset.searchText=Object.values(row).map(value=>String(value??"")).join(" ").toLowerCase(); mutate(); }));
    rootNode.querySelectorAll("[data-window]").forEach(node => node.addEventListener("input", () => { state.windows[Number(node.dataset.window)][node.dataset.key] = node.value || null; mutate(); }));
    rootNode.querySelectorAll("[data-flow]").forEach(node => node.addEventListener("input", () => { state.strategy.flow_steps[Number(node.dataset.flow)] = node.value; mutate(); }));
    rootNode.querySelectorAll("[data-add-row]").forEach(node => node.addEventListener("click", () => { const name = node.dataset.addRow; if (state[name].length >= ROW_LIMITS[name]) return setStatus(`Row limit reached for ${name}`, "error"); const row = emptyRow(name); if (name === "results") row.verification_state = "OWNER_ENTERED_UNVERIFIED"; if (["timeseries","sensitivity"].includes(name)) row.source_state = "OWNER_ENTERED_UNVERIFIED"; if (name === "optimizer_sets") row.search_role = "MAIN_ONLY"; state[name].push(row); mutate(); rerender(`#rw-${name.replaceAll("_", "-")}`); }));
    rootNode.querySelectorAll("[data-remove-row]").forEach(node => node.addEventListener("click", () => { state[node.dataset.removeRow].splice(Number(node.dataset.row), 1); mutate(); rerender(`#rw-${node.dataset.removeRow.replaceAll("_", "-")}`); }));
    rootNode.querySelector("#rw-standard-stages")?.addEventListener("click", () => { const existing = new Set(state.stage_plan.map(row => row.stage)); for (const stage of STANDARD_STAGES) if (!existing.has(stage)) state.stage_plan.push({...emptyRow("stage_plan"),stage,declared_status:"PLANNED",execution_state:"NOT_RUN",acceptance_state:"NOT_REVIEWED"}); mutate(); rerender("#rw-stage-plan"); });
    rootNode.querySelector("[data-add-flow]")?.addEventListener("click", () => { state.strategy.flow_steps.push(""); mutate(); rerender("#rw-strategy"); });
    rootNode.querySelectorAll("[data-remove-flow]").forEach(node => node.addEventListener("click", () => { state.strategy.flow_steps.splice(Number(node.dataset.removeFlow),1); mutate(); rerender("#rw-strategy"); }));
    rootNode.querySelector("#rw-save").addEventListener("click", () => { if (!saveDraft()) setStatus(storageStatus === "CORRUPT_PRESERVED" ? "Corrupt stored bytes were preserved and not overwritten; current in-memory draft remains usable. Download to keep it." : "Local storage denied; current in-memory draft is preserved. Download to keep a copy.", "warn"); });
    rootNode.querySelector("#rw-download").addEventListener("click", () => download(`ea-research-workbook-${state.document.revision_id || "draft"}.json`, exportText(state)));
    rootNode.querySelector("#rw-import").addEventListener("change", async event => { const file = event.target.files[0]; if (!file) return; const current = state; try { const imported = parseImport(await file.text()); state = clone(imported); dirty = true; rerender(); setStatus("Import loaded in memory as OWNER_DRAFT_UNVERIFIED. Save/download explicitly.", "info"); } catch (error) { state = current; event.target.value = ""; setStatus(`Import refused; current draft preserved: ${error.message}`, "error"); } });
    rootNode.querySelector("#rw-validate").addEventListener("click", () => { const errors = validateWorkbook(state); setStatus(errors.length ? errors.join(" · ") : "Validation PASS for workbook structure only; no research/approval/readiness claim.", errors.length ? "error" : "ok"); });
    rootNode.querySelector("#rw-revision").addEventListener("click", () => { if(corruptDraftBlocked)return setStatus("New revision refused while corrupt current-storage bytes are preserved. Download the in-memory draft first.","error"); const snapshot = exportText(state); const oldId = state.document.revision_id || `unnamed-${Date.now()}`; const historyKey = `${HISTORY_PREFIX}${oldId}`; if (storageGet(historyKey) !== null) return setStatus(`New revision refused: frozen history ${oldId} already exists and will not be overwritten.`, "error"); if (!storageSet(historyKey, snapshot)) return setStatus("New revision refused: previous draft could not be preserved in local history. Download first.", "error"); state = revisionCopy(state); dirty = true; rerender(); scheduleAutosave(); setStatus(`New revision ${state.document.revision_id}; previous draft preserved locally as ${oldId}.`, "ok"); });
    rootNode.querySelector("#rw-copy-review").addEventListener("click", async () => { const text = reviewRequest(); try { await navigator.clipboard.writeText(text); setStatus("Review request copied. It is not an attestation.", "ok"); } catch { const area = document.createElement("textarea"); area.value = text; area.readOnly = true; area.className = "rw-copy-fallback"; rootNode.querySelector(".rw-actions").after(area); area.select(); setStatus("Clipboard unavailable; review request selected below.", "warn"); } });
    rootNode.querySelector("#rw-print").addEventListener("click", () => { refreshDerived(); window.print(); });
    rootNode.querySelector("#rw-open-record").addEventListener("click", () => { const id = rootNode.querySelector("#rw-record-link").value; if (id) location.hash = `detail/${encodeURIComponent(id)}`; });
    rootNode.querySelectorAll("[data-jump]").forEach(link => link.addEventListener("click", event => { event.preventDefault(); rootNode.querySelector(`#rw-${link.dataset.jump}`)?.scrollIntoView({behavior:"smooth",block:"start"}); }));
    bindDerivedControls();
  }

  async function loadTemplate() {
    if (templateCache) return templateCache;
    if (typeof fetch !== "function") throw new Error("Template fetch unavailable");
    const response = await fetch("./research_workbook.template.json", {cache:"no-store"});
    if (!response.ok) throw new Error(`Workbook template unavailable (${response.status})`);
    const text = await response.text();
    templateCache = parseImport(text);
    return templateCache;
  }

  async function mount(node, options = {}) {
    const template = state ? null : await loadTemplate();
    if (typeof options.isCurrent === "function" && !options.isCurrent()) return false;
    rootNode = node;
    if (options.storage !== undefined) storage = options.storage;
    else { try { storage = typeof localStorage !== "undefined" ? localStorage : null; } catch { storage = null; storageStatus = "DENIED"; } }
    monitorStatus = options.monitor || monitorStatus;
    if (!state) state = loadDraft(template);
    rootNode.innerHTML = shell(); bind(); updateStatus();
    return true;
  }
  function updateMonitor(monitor) { monitorStatus = monitor || monitorStatus; const token = rootNode?.querySelector(".rw-state span:last-child"); if (token) token.textContent = `Monitor truth: ${monitorStatus.state || "UNKNOWN"}`; updateStatus(); }
  function isMounted(node) { return rootNode === node && !!node?.querySelector(".research-workbook"); }

  return { SCHEMA, STORAGE_KEY, HISTORY_PREFIX, MAX_IMPORT_BYTES, TABLES, STANDARD_STAGES, parseImport, validateWorkbook, profitFactor, compareRuns, combinationEstimate, chartGroups, exportText, spreadsheetSafe, revisionCopy, mount, updateMonitor, isMounted, _resetForTests() { if(autosaveTimer)clearTimeout(autosaveTimer);autosaveTimer=null;state=null;rootNode=null;storage=null;templateCache=null;dirty=false;corruptDraftBlocked=false;graphSelection={resultGroup:"",resultMetric:"net_profit",seriesGroup:"",sensitivityGroup:""}; } };
});
