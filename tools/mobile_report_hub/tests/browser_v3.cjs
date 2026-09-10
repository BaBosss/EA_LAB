// Standalone local rendered acceptance; no production server or runtime changes.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const hub = path.join(root, 'mobile_report_hub');
const evidence = process.argv[2];
if (!evidence) throw new Error('Evidence directory argument required');
const base = JSON.parse(fs.readFileSync(path.join(evidence, 'preview/report_index.json'), 'utf8'));
const Ajv = require('ajv');
const validate = new Ajv({strict:false}).compile(JSON.parse(fs.readFileSync(path.join(__dirname,'../control_tower.schema.json'),'utf8')));
assert.ok(validate(base.control_tower), JSON.stringify(validate.errors));
assert.equal(validate({...base.control_tower,version:2}),false);
let payload = base;
let mode = 'normal';
const results = [];
const server = http.createServer((req, res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (pathname.endsWith('/report_index.json')) {
    res.setHeader('Content-Type', 'application/json');
    if (mode === 'cached') res.setHeader('X-EA-LAB-Cache', 'true');
    if (mode === 'missing') { res.writeHead(404); return res.end('{}'); }
    return res.end(mode === 'malformed' ? '{' : JSON.stringify(payload));
  }
  const file = path.join(hub, pathname === '/' ? 'index.html' : pathname.slice(1));
  if (!file.startsWith(hub + path.sep) || !fs.existsSync(file)) {res.writeHead(404); return res.end();}
  res.setHeader('Content-Type', {'.html':'text/html', '.js':'text/javascript', '.css':'text/css', '.svg':'image/svg+xml', '.webmanifest':'application/manifest+json'}[path.extname(file)] || 'text/plain');
  res.end(fs.readFileSync(file));
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({headless:true, channel:'msedge'});
  try {
    const context = await browser.newContext({viewport:{width:390,height:844}, serviceWorkers:'block'});
    const page = await context.newPage();
    const now = new Date(base.project.generated_at);
    await page.clock.install({time: now});
    const errors = [];
    page.on('pageerror', error => errors.push(String(error)));
    const url = `http://127.0.0.1:${server.address().port}/index.html`;
    await page.goto(url);
    await page.getByRole('heading', {name:'Overview', exact:true}).waitFor();
    assert.equal(await page.locator('#global-state').innerText(),'DEGRADED_MONITORING');
    const navTops = await page.locator('.bottom-nav a').evaluateAll(nodes=>nodes.map(node=>node.getBoundingClientRect().top));
    assert.equal(new Set(navTops).size,1,'All five navigation items must share one row');
    results.push('V3 JSON schema positive/negative PASS; canonical degraded state visible; five-tab single row');
    for (const [label, heading] of [['Overview','Overview'],['Work','Work'],['Runtime','Runtime'],['EA Lab','EA Lab'],['Alerts','Alerts']]) {
      await page.locator('.bottom-nav').getByText(label,{exact:true}).click();
      await page.getByRole('heading',{name:heading,exact:true}).first().waitFor();
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth),390, `${label} overflow`);
      results.push(`${label}: rendered, scrollWidth=390`);
    }
    await page.goto(url+'#home');
    await page.getByRole('heading',{name:'NEED BOSS',exact:true}).waitFor();
    await page.screenshot({path:path.join(evidence,'overview-390x844.png'),fullPage:false});
    payload = structuredClone(base);
    const stamp = now.toISOString();
    const staleStamp = new Date(now.getTime() - 48 * 3600000).toISOString().replace('.000Z','Z');
    const lane = (id, state, freshness = 'CURRENT', observed_at = stamp) => ({
      id, state, freshness, observed_at, source_kind:'LANE_REGISTRY_NONCANONICAL'
    });
    payload.control_tower.registry = {
      status:'AVAILABLE', freshness:'CURRENT', observed_at:stamp,
      source_kind:'LANE_REGISTRY_NONCANONICAL', reason:'AUDIT_OBSERVATION',
      rows:[lane('current-running','RUNNING'), lane('current-blocked','BLOCKED'),
        {...lane('historical','UNKNOWN','STALE',staleStamp), registry_classification:'STALE_NONACTIVE'},
        lane('conflicting','CONFLICT'), lane('aged-running','RUNNING','CURRENT',staleStamp),
        lane('stale-blocked','BLOCKED','STALE')]
    };
    assert.ok(validate(payload.control_tower), JSON.stringify(validate.errors));
    const workCount = state => page.locator('.work-counts article').filter({has:page.locator('span', {hasText:new RegExp(`^${state}$`)})}).locator('strong').innerText();
    await page.reload();
    await page.getByRole('heading',{name:'Overview',exact:true}).waitFor();
    assert.equal(await workCount('RUNNING'),'1');
    assert.equal(await workCount('BLOCKED'),'1');
    assert.equal(await workCount('PARKED'),'UNKNOWN');
    await page.getByText('Unresolved observations: 4. Counts exclude these rows. PARKED: unavailable.',{exact:true}).waitFor();
    results.push('Mixed current/stale/conflicting registry: RUNNING=1, BLOCKED=1, unresolved=4, PARKED=UNKNOWN');
    const mixed = structuredClone(payload);
    for (const change of [
      p => {p.control_tower.registry.status='UNAVAILABLE';},
      p => {p.control_tower.registry.freshness='UNKNOWN';},
      p => {p.control_tower.registry.observed_at=staleStamp;},
      p => {p.project.generated_at=staleStamp;}
    ]) {
      payload=structuredClone(mixed); change(payload); await page.reload();
      await page.getByRole('heading',{name:'Overview',exact:true}).waitFor();
      assert.equal(await workCount('RUNNING'),'UNKNOWN');
      assert.equal(await workCount('BLOCKED'),'UNKNOWN');
    }
    results.push('Unavailable/unknown/stale registry envelope and stale project suppress WORK counts');
    payload = structuredClone(base);
    payload.control_tower.need_boss = [{id:'OWNER-TEST',state:'BLOCKED',reason:'Explicit test owner blocker',source_kind:'LANE_REGISTRY_NONCANONICAL',owner_action:'UNKNOWN'}];
    await page.reload();
    await page.getByText('OWNER-TEST',{exact:true}).waitFor();
    results.push('NEED BOSS explicit owner fixture rendered');
    payload.project.generated_at = '2020-01-01T00:00:00Z';
    await page.reload();
    await page.getByText('Owner attention UNKNOWN — refresh current evidence.',{exact:true}).waitFor();
    assert.match(await page.locator('#data-warning').innerText(), /STALE/);
    results.push('Stale timestamp hides current owner action');
    for (const stamp of ['2999-01-01T00:00:00Z']) {
      payload = structuredClone(base); payload.project.generated_at=stamp;
      await page.reload();
      await page.getByText('Owner attention UNKNOWN — refresh current evidence.',{exact:true}).waitFor();
      results.push('Future timestamp fails visible');
    }
    for (const testMode of ['cached','malformed','missing']) {
      payload=structuredClone(base); mode=testMode; await page.reload();
      if(testMode==='cached') {await page.getByText('Owner attention UNKNOWN — refresh current evidence.',{exact:true}).waitFor();}
      else await page.getByRole('heading',{name:'Monitoring unavailable'}).waitFor();
      results.push(`${testMode}: fail visible`);
    }
    mode='normal'; payload=structuredClone(base); payload.sources[0].canonical_sha='f'.repeat(40);
    await page.reload(); await page.getByText('Canonical source SHA mismatch',{exact:true}).waitFor();
    results.push('Canonical source SHA mismatch rejected');
    payload=structuredClone(base); payload.control_tower.work=null;
    await page.reload(); await page.getByText('Invalid V3 collection',{exact:true}).waitFor();
    results.push('Malformed V3 collection rejected');
    payload=structuredClone(base); await page.reload();
    await page.getByRole('heading',{name:'Overview',exact:true}).waitFor();
    await context.setOffline(true);
    await page.getByText('Owner attention UNKNOWN — refresh current evidence.',{exact:true}).waitFor();
    results.push('Offline event invalidates current view');
    await context.setOffline(false);
    await page.setViewportSize({width:1280,height:900});
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth)<=1280);
    assert.deepEqual(errors,[]);
    results.push('Desktop overflow check PASS; no uncaught browser errors');
    fs.writeFileSync(path.join(evidence,'browser-results.json'),JSON.stringify({status:'PASS',viewport:'390x844',results},null,2));
    console.log(JSON.stringify(results,null,2));
  } finally { await browser.close(); server.close(); }
})().catch(error => {console.error(error); server.close(); process.exitCode=1;});
