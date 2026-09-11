'use strict';
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const graph = require('../../../mobile_report_hub/agent_graph.js');
let passed = 0;
function test(name, fn) { fn(); passed++; console.log('PASS ' + name); }
const git = (id, extra = {}) => ({id, source_kind: 'GIT_CANONICAL', state: 'READY', ...extra});
const lane = (id, extra = {}) => ({id, source_kind: 'LANE_REGISTRY_NONCANONICAL', state: 'RUNNING', freshness: 'CURRENT', ...extra});
const projection = (work = [], rows = [], extra = {}) => ({version: 3, work, registry: {status: 'AVAILABLE', freshness: 'CURRENT', rows}, ...extra});
const endpoint = (id, source_kind = 'GIT_CANONICAL') => ({id, source_kind});
const edge = (from, to, type = 'DEPENDENCY') => ({from: endpoint(from), to: endpoint(to), type});

test('empty and malformed optional inputs remain fail-visible', () => {
  for (const input of [undefined, null, {}, {work: 'bad', registry: null}]) {
    const model = graph.buildModel(input);
    assert.equal(model.nodes.length, 0);
    assert.match(graph.renderHTML(model), /Empty graph.*UNKNOWN/);
  }
  assert.equal(graph.buildModel({work: [{id: 'X', state: 'RUNNING'}]}).nodes[0].state, 'UNKNOWN');
});
test('stale worker is an observation, never process health', () => {
  const model = graph.buildModel(projection([], [lane('A', {worker: 'Codex', freshness: 'STALE'})]));
  assert.equal(model.nodes[0].freshness, 'STALE');
  assert.equal(model.nodes[0].state, 'UNKNOWN');
  assert.match(graph.renderHTML(model), /process health UNKNOWN/);
  assert.doesNotMatch(graph.renderHTML(model), /\blive\b/i);
});
test('missing worker/provider and authority stay UNKNOWN', () => {
  const node = graph.buildModel(projection([git('A')])).nodes[0];
  for (const field of ['worker', 'provider', 'authority', 'ref', 'worktree', 'objective']) assert.equal(node[field], 'UNKNOWN');
});

test('structured Registry review claims require current exact evidence', () => {
  const metadata = {worker:'Codex-Primary', ref:'ct/monitor-v31-final-r2-20260911',
    worktree:'monitor-v31-final-r2-20260911', reviewer:'ChatGPT-Control-Tower',
    head_sha:'a'.repeat(40), reviewed_head:'a'.repeat(40), review_state:'REVIEWED_EXACT_HEAD', registry_classification:'ACTIVE_CURRENT'};
  const row = lane('metadata', metadata);
  const model = graph.buildModel(projection([], [row]));
  for (const [field, value] of Object.entries(metadata)) assert.equal(model.nodes[0][field], value);
  assert.equal(graph.inspect(model, model.nodes[0].key).node.review_state, 'REVIEWED_EXACT_HEAD');
  for (const options of [{cached:true}, {offline:true}]) {
    assert.equal(graph.buildModel(projection([], [row]), options).nodes[0].review_state, 'UNKNOWN');
    const active = {...row, state:'REVIEW', review_state:'REVIEW_ACTIVE'};
    assert.equal(graph.buildModel(projection([], [active]), options).nodes[0].review_state, 'UNKNOWN');
  }
  for (const changes of [{freshness:'STALE'}, {state:'CONFLICT'}, {registry_classification:'ACTIVE_AGED'},
    {head_sha:'UNKNOWN', reviewed_head:'UNKNOWN'}, {reviewed_head:'b'.repeat(40)},
    {head_sha:'a'.repeat(40)+'\n', reviewed_head:'a'.repeat(40)+'\n'}]) {
    assert.equal(graph.buildModel(projection([], [{...row, ...changes}])).nodes[0].review_state, 'UNKNOWN');
  }
  for (const registry of [{status:'UNAVAILABLE',freshness:'CURRENT'}, {status:'AVAILABLE',freshness:'STALE'}]) {
    assert.equal(graph.buildModel({work:[],registry:{...registry,rows:[row]}}).nodes[0].review_state,'UNKNOWN');
  }
  assert.ok(graph.buildModel(projection([], [row,row])).nodes.every(n=>n.review_state==='UNKNOWN'));
  assert.equal(graph.buildModel(projection([], [{...row,state:'REVIEW',review_state:'REVIEW_ACTIVE'}])).nodes[0].review_state,'REVIEW_ACTIVE');
  assert.equal(graph.buildModel(projection([], [{...row,review_state:'REVIEW_ACTIVE'}])).nodes[0].review_state,'UNKNOWN');
});
test('exact Git/Lane identity correlates visually without merging authority', () => {
  const input = projection([git('A', {authority: 'HEADER_DECLARATION_ONLY'})], [lane('A')]);
  assert.equal(graph.buildModel(input).edges.length, 0);
  const model = graph.buildModel(input, {correlateExactIds: true});
  assert.equal(model.nodes.length, 2);
  assert.equal(new Set(model.nodes.map(n => n.key)).size, 2);
  assert.equal(model.nodes[0].authority, 'HEADER_DECLARATION_ONLY');
  assert.equal(model.nodes[1].authority, 'UNKNOWN');
  assert.equal(model.edges[0].type, 'OBSERVATION_CORRELATION');
});
test('duplicate identifiers reject ambiguous edges and surface conflict', () => {
  const model = graph.buildModel(projection([git('A'), git('A'), git('B')]), {edges: [edge('A', 'B')]});
  assert.equal(model.edges.length, 0);
  assert.equal(model.nodes.filter(n => n.state === 'CONFLICT').length, 2);
  assert.equal(new Set(model.nodes.map(n => n.key)).size, 3);
  assert.match(graph.renderHTML(model), /AMBIGUOUS_ID/);
});
test('unknown dependency and similar titles cannot create edges', () => {
  const model = graph.buildModel(projection([git('A', {title: 'same', direct_dependencies: ['MISSING']}), git('B', {title: 'same'})]));
  assert.equal(model.edges.length, 0);
  assert.ok(model.issues.includes('UNRESOLVED_OR_INVALID_EDGE'));
});
test('all supplied edge types and direct dependencies use exact endpoints', () => {
  const model = graph.buildModel(projection([git('A'), git('B', {direct_dependencies: ['A']})]), {edges: graph.EDGE_TYPES.map(type => edge('A', 'B', type))});
  assert.equal(model.edges.length, 5);
  assert.deepEqual(new Set(model.edges.map(e => e.type)), new Set(graph.EDGE_TYPES));
});
test('NEED BOSS requires a supplied boolean, not prose or blocker names', () => {
  for (const row of [lane('A', {summary: 'NEED BOSS', blocker_type: 'OWNER_EXTERNAL'}), lane('A', {owner_required: 'true'}), lane('A', {attention_required: true})]) {
    assert.equal(graph.buildModel(projection([], [row])).nodes[0].owner_required, false);
  }
  const model = graph.buildModel(projection([], [lane('A', {owner_required: true, attention_required: true})]));
  assert.match(graph.renderHTML(model), /NEED BOSS — supplied owner flag/);
  assert.equal(graph.layout(model).columns[6].nodes.length, 1);
});
test('offline/cache and stale envelope withhold current observation and owner claim', () => {
  for (const flag of ['offline', 'cached']) {
    for (const atRoot of [true, false]) {
      const input = projection([], [lane('A', {owner_required: true})], atRoot ? {[flag]: true} : {});
      const model = graph.buildModel(input, atRoot ? {} : {[flag]: true});
      assert.equal(model.nodes[0].state, 'UNKNOWN');
      assert.equal(model.nodes[0].owner_required, false);
      assert.doesNotMatch(graph.renderHTML(model), /\blive\b/i);
      assert.match(graph.renderHTML(model), new RegExp(flag.toUpperCase()));
    }
  }
  const model = graph.buildModel({registry: {status: 'UNAVAILABLE', freshness: 'STALE', rows: [lane('A')]}});
  assert.equal(model.nodes[0].state, 'UNKNOWN');
  assert.equal(model.nodes[0].freshness, 'STALE');
});
test('unresolved historical registry observations remain unresolved', () => {
  const node = graph.buildModel(projection([], [lane('old', {state: 'UNKNOWN', declared_state: 'RUNNING', freshness: 'STALE', registry_classification: 'HISTORICAL_UNRESOLVED'})])).nodes[0];
  assert.equal(node.state, 'UNKNOWN');
  assert.equal(node.declared_state, 'RUNNING');
  assert.equal(node.registry_classification, 'HISTORICAL_UNRESOLVED');
});
test('long hostile evidence is escaped in text and attributes without identity truncation', () => {
  const hostile = '\"><img src=x onerror=alert(1)>&\'' + 'x'.repeat(10000);
  const model = graph.buildModel(projection([git(hostile, {title: hostile, objective: hostile, worktree: hostile})]));
  const html = graph.renderHTML(model);
  assert.equal(model.nodes[0].id, hostile);
  assert.ok(html.includes('&lt;img'));
  assert.ok(!html.includes('<img'));
  assert.ok(!html.includes(hostile));
});
test('cycle and downstream nodes use finite visible fallback', () => {
  const model = graph.buildModel(projection([git('A'), git('B'), git('C'), git('D')]), {edges: [edge('A', 'B'), edge('B', 'A'), edge('B', 'C')]});
  const result = graph.layout(model);
  assert.equal(result.cycleAffected.length, 3);
  assert.equal(result.columns[7].nodes.length, 3);
  assert.match(graph.renderHTML(model), /CYCLE_OR_DOWNSTREAM_CONFLICT/);
  assert.equal(graph.layout(graph.buildModel(projection([git('A')]), {edges: [edge('A', 'A')]})).cycleAffected.length, 1);
});
test('layout is deterministic across row order; pure operations preserve inputs', () => {
  const input = projection([git('B', {state: 'REVIEW'}), git('A')]);
  const before = JSON.stringify(input);
  const first = graph.buildModel(input), second = graph.buildModel(projection([...input.work].reverse()));
  assert.deepEqual(first, second);
  assert.deepEqual(graph.layout(first), graph.layout(second));
  const inspected = graph.inspect(first, first.nodes[0].key);
  inspected.node.title = 'changed';
  assert.equal(first.nodes[0].title, 'UNKNOWN');
  assert.equal(JSON.stringify(input), before);
});
test('steering/task/review include scope warnings and no generated execution actions', () => {
  const model = graph.buildModel(projection([git('A', {objective: 'Inspect foundation', ref: 'abc', constraints: ['Only four new files']})]));
  for (const mode of ['STEERING', 'TASK', 'REVIEW']) {
    const context = graph.steeringContext(model, model.nodes[0].key, mode);
    for (const expected of ['COPY ' + mode + ' CONTEXT', 'Preserve scope', 'Current Git canonical wins', 'No deploy/runtime mutation unless separately authorized', '"id": "A"', '"state": "READY"', '"ref": "abc"', '"objective": "Inspect foundation"', 'GIT_CANONICAL', 'Only four new files']) assert.ok(context.includes(expected));
    assert.doesNotMatch(context, /powershell|taskkill|kill-process|codex exec|gemini launch|registry edit|taskboard edit/i);
  }
  assert.match(graph.steeringContext(model, 'missing'), /"target": "UNKNOWN"/);
});
test('browser export and explicit DOM mount work without third-party modules', () => {
  const source = fs.readFileSync(path.join(__dirname, '../../../mobile_report_hub/agent_graph.js'), 'utf8');
  assert.doesNotMatch(source, /GraphCode|\brequire\s*\(|\bimport\s|\bfetch\s*\(|XMLHttpRequest|WebSocket|eval\s*\(/i);
  const sandbox = {};
  vm.runInNewContext(source, sandbox);
  const target = {innerHTML: ''};
  sandbox.EALabAgentGraph.render(target, sandbox.EALabAgentGraph.buildModel());
  assert.match(target.innerHTML, /Empty graph/);
  assert.doesNotMatch(target.innerHTML, /<button|<input|<script/i);
  const css = fs.readFileSync(path.join(__dirname, '../../../mobile_report_hub/agent_graph.css'), 'utf8');
  assert.match(css, /max-width: 100%/);
  assert.match(css, /overflow: auto/);
  assert.doesNotMatch(css, /@import|url\(/);
});
console.log(`${passed} deterministic test groups passed`);
