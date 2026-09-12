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
    payload = structuredClone(base);
    payload.monitoring = {...payload.monitoring, status:'DEGRADED', repo_head:'a'.repeat(40),
      binding_state:'DIFFERENT_REPO_HEAD', snapshot_revision:{git_head:'b'.repeat(40),binding_state:'DIFFERENT_SNAPSHOT_HEAD'}};
    await page.reload();
    await page.locator('.bottom-nav').getByText('Runtime',{exact:true}).click();
    await page.getByText('Monitoring revision provenance',{exact:true}).click();
    await page.getByText('Runtime Git SHA: '+'a'.repeat(40),{exact:true}).waitFor();
    await page.getByText('Snapshot Git SHA: '+'b'.repeat(40),{exact:true}).waitFor();
    await page.getByText('DIFFERENT_SNAPSHOT_HEAD',{exact:true}).waitFor();
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth),390,'Revision provenance overflow');
    results.push('Runtime/snapshot revision mismatch explicit; expanded provenance fits 390px');
    payload = structuredClone(base);
    await page.reload();
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
    const ownerRow = id => ({...lane(id,'BLOCKED'), declared_state:'BLOCKED',
      owner_required:true, blocker_class:'E', blocker_type:'OWNER_EXTERNAL',
      reason:'Explicit Lane Registry E / OWNER_EXTERNAL blocker', owner_action:'UNKNOWN'});
    const ownerFixture = () => {
      const p=structuredClone(base);
      p.control_tower.work=[];
      p.control_tower.registry={status:'AVAILABLE',freshness:'CURRENT',observed_at:stamp,
        source_kind:'LANE_REGISTRY_NONCANONICAL',reason:'AUDIT_OBSERVATION',rows:[ownerRow('OWNER-TEST')]};
      p.control_tower.need_boss=structuredClone(p.control_tower.registry.rows);
      return p;
    };
    for (const width of [390,1280]) {
      await page.setViewportSize({width,height:width===390?844:900});
      for (const condition of ['fresh','stale-row','stale-envelope','missing-time','future-time',
        'cached','offline','historical-explicit','mixed','stale-project','missing-row','unqualified','duplicate','hostile-long']) {
        payload=ownerFixture(); mode=condition==='cached'?'cached':'normal';
        const registry=payload.control_tower.registry, row=registry.rows[0];
        if(condition==='stale-envelope') registry.observed_at=staleStamp;
        if(['stale-row','historical-explicit'].includes(condition)) row.observed_at=staleStamp;
        if(condition==='historical-explicit') {
          row.freshness='STALE'; row.state='UNKNOWN'; row.owner_required=false;
          payload.control_tower.need_boss=[];
        }
        if(condition==='missing-time') delete row.observed_at;
        if(condition==='future-time') row.observed_at=new Date(now.getTime()+6*60000).toISOString();
        if(condition==='stale-project') payload.project.generated_at=staleStamp;
        if(condition==='missing-row') registry.rows=[];
        if(condition==='unqualified') {row.owner_required=false;row.blocker_class='D';row.blocker_type='EXECUTION';}
        if(condition==='duplicate') registry.rows.push(structuredClone(row));
        if(condition==='hostile-long') {
          row.id='<img src=x onerror="window.pwned=1">'+'Owner'.repeat(50);
          row.reason='<script>window.pwned=1</script>'+'Reason'.repeat(80);
          payload.control_tower.need_boss=[structuredClone(row)];
        }
        if(condition==='mixed') {
          const old={...ownerRow('OLD-OWNER'),observed_at:staleStamp};
          registry.rows.push(old);payload.control_tower.need_boss.push(structuredClone(old));
        }
        const expected=['fresh','mixed','hostile-long'].includes(condition)?[row.id]:[];
        await page.goto(url+'#home');await page.reload();
        if(condition==='offline') await context.setOffline(true);
        for (const label of ['Overview','Alerts']) {
          await page.locator('.bottom-nav').getByText(label,{exact:true}).click();
          await page.getByRole('heading',{name:label,exact:true}).first().waitFor();
          const current=page.locator('.need-boss li').filter({hasText:'Next owner action:'});
          assert.deepEqual(await current.locator('strong').allTextContents(),expected,`${condition} ${label} ${width}`);
          if(!['fresh','hostile-long'].includes(condition)) {
            const historical=page.locator('.need-boss [data-owner-history]');
            assert.ok(await historical.count()>0,`${condition}: historical evidence must remain visible`);
            assert.match(await historical.first().innerText(),/No current owner action/);
            if(['stale-row','stale-envelope','historical-explicit','mixed'].includes(condition))
              assert.match(await historical.first().innerText(),/STALE/);
            if(condition==='missing-time') assert.match(await historical.first().innerText(),/UNKNOWN/);
            if(condition==='future-time') assert.match(await historical.first().innerText(),/FUTURE/);
            if(condition==='cached') assert.match(await historical.first().innerText(),/CACHED/);
            if(condition==='offline') assert.match(await historical.first().innerText(),/OFFLINE/);
          }
          assert.equal(await page.locator('.need-boss img, .need-boss script').count(),0);
          assert.equal(await page.evaluate(()=>window.pwned),undefined);
          assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),width);
          if(['fresh','stale-row','historical-explicit'].includes(condition))
            await page.screenshot({path:path.join(evidence,`owner-${condition}-${label}-${width}.png`),fullPage:false});
        }
        await page.locator('.bottom-nav').getByText('Work',{exact:true}).click();
        await page.getByRole('heading',{name:'Agent Graph',exact:true}).waitFor();
        assert.deepEqual(await page.locator('.agent-graph-owner button strong').allTextContents(),expected,`${condition} Work ${width}`);
        assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),width);
        if(condition==='offline') await context.setOffline(false);
        results.push(`NEED BOSS ${width} ${condition}: Overview / Alerts / Work eligibility agrees; suppression explained PASS`);
      }
      // A row can expire while project and Audit envelope remain fresh, without a reload.
      for (const label of ['Overview','Alerts']) {
        await page.clock.setSystemTime(now);
        payload=ownerFixture();mode='normal';
        payload.control_tower.registry.rows[0].observed_at=new Date(now.getTime()-24*3600000+30000).toISOString();
        payload.control_tower.need_boss=structuredClone(payload.control_tower.registry.rows);
        await page.goto(url+(label==='Overview'?'#home':'#alerts'));await page.reload();
        await page.getByRole('heading',{name:label,exact:true}).first().waitFor();
        assert.equal(await page.locator('.need-boss li').filter({hasText:'Next owner action:'}).count(),1);
        await page.clock.fastForward(60000);
        assert.equal(await page.locator('.need-boss li').filter({hasText:'Next owner action:'}).count(),0);
        assert.match(await page.locator('[data-owner-history]').innerText(),/STALE/);
        assert.equal(await page.evaluate(()=>observationCurrent() && workProjection().registry.freshness==='CURRENT'),true);
        await page.locator('.bottom-nav').getByText('Work',{exact:true}).click();
        await page.getByRole('heading',{name:'Agent Graph',exact:true}).waitFor();
        assert.equal(await page.locator('.agent-graph-owner').count(),0);
        results.push(`NEED BOSS ${width} ${label}: timer expires row without reload; fresh envelope retained PASS`);
      }
      await page.clock.setSystemTime(now);
    }
    await page.setViewportSize({width:390,height:844});mode='normal';
    payload = ownerFixture();
    await page.goto(url+'#home');
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
    // V3.1 integration fixtures: real DOM, viewport, input and clipboard paths.
    const sw = fs.readFileSync(path.join(hub, 'sw.js'), 'utf8');
    const html = fs.readFileSync(path.join(hub, 'index.html'), 'utf8');
    for (const asset of ['agent_graph.js', 'agent_graph.css']) {
      assert.ok(sw.includes('"./'+asset+'"') && html.includes('"'+asset+'"'));
      assert.ok(fs.existsSync(path.join(hub, asset)));
    }
    assert.match(sw, /ea-lab-report-hub-v3\.2-native/);
    results.push('V3.1 local shell JS/CSS references and cache generation PASS');
    const badSha=structuredClone(base.control_tower);badSha.work[0].head_sha='short';
    assert.equal(validate(badSha),false,'Schema rejects malformed full SHA');
    const graphRows = [
      {...lane('owner','BLOCKED'), owner_required:true, blocker_class:'E', head_sha:'a'.repeat(40), role:'WRITER',
        worker:'Codex-Primary', ref:'ct/monitor-v31-final-r2-20260911', worktree:'monitor-v31-final-r2-20260911',
        reviewer:'ChatGPT-Control-Tower', reviewed_head:'a'.repeat(40), review_state:'REVIEWED_EXACT_HEAD', registry_classification:'ACTIVE_CURRENT'},
      {...lane('dependent','WAITING'), direct_dependencies:['owner','absent']},
      lane('duplicate','RUNNING'), lane('duplicate','READY'),
      {...lane('historical','UNKNOWN','STALE',staleStamp),declared_state:'RUNNING', registry_classification:'HISTORICAL_UNRESOLVED'},
      lane('same-id','CONFLICT'),
      {...lane('long-'+'x'.repeat(220),'READY'), title:'<img src=x onerror="window.pwned=1">'+'LongTitle'.repeat(80)}
    ];
    const graphFixture = () => {
      const p=structuredClone(base);
      p.control_tower.work=[{id:'same-id',state:'CONFLICT',source_kind:'GIT_CANONICAL',title:'Git declaration',provenance:base.control_tower.work[0].provenance}];
      p.control_tower.registry={status:'AVAILABLE', freshness:'CURRENT', observed_at:stamp, source_kind:'LANE_REGISTRY_NONCANONICAL', reason:'AUDIT_OBSERVATION', rows:structuredClone(graphRows)};
      return p;
    };
    const openGraph = async () => {
      await page.goto(url+'#work'); await page.reload();
      await page.getByRole('heading',{name:'Agent Graph',exact:true}).waitFor();
    };
    const inspectNode = async id => {
      await page.getByRole('button',{name:'Inspect LANE_REGISTRY_NONCANONICAL / '+id, exact:true}).click();
      await page.locator('#agent-inspect h3').waitFor();
    };
    const fact = label => page.locator('#agent-inspect dt').filter({hasText:new RegExp('^'+label+'$')}).locator('xpath=following-sibling::dd[1]').innerText();
    for (const width of [390,1280]) {
      await page.setViewportSize({width,height:width===390?844:900});
      payload=graphFixture(); assert.ok(validate(payload.control_tower),JSON.stringify(validate.errors));
      await openGraph();
      assert.equal(await page.locator('[data-graph-source]').count(),2);
      assert.equal(await page.locator('[data-graph-source="GIT_CANONICAL"] .agent-graph-node').count(),1);
      assert.equal(await page.locator('[data-graph-source="LANE_REGISTRY_NONCANONICAL"] .agent-graph-node').count(),graphRows.length);
      assert.match(await page.locator('#work-agent-graph').innerText(),/OBSERVATION_CORRELATION/);
      assert.match(await page.locator('#work-agent-graph').innerText(),/DEPENDENCY/);
      assert.match(await page.locator('#work-agent-graph').innerText(),/UNRESOLVED_OR_INVALID_EDGE/);
      assert.match(await page.locator('#work-agent-graph').innerText(),/AMBIGUOUS_ID/);
      assert.equal(await page.locator('#work-agent-graph img').count(),0);
      assert.equal(await page.evaluate(()=>window.pwned),undefined);
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),width);
      assert.ok(await page.locator('.agent-graph-pan').first().evaluate(el=>el.scrollWidth>el.clientWidth));
      await page.getByRole('heading',{name:'Agent Graph',exact:true}).scrollIntoViewIfNeeded();
      await page.screenshot({path:path.join(evidence,`graph-${width}.png`),fullPage:false});
      await inspectNode('owner');
      assert.equal(await fact('Full head SHA'),'a'.repeat(40));
      assert.equal(await fact('Role'),'WRITER');
      assert.equal(await fact('Worker'),'Codex-Primary');
      assert.equal(await fact('Ref'),'ct/monitor-v31-final-r2-20260911');
      assert.equal(await fact('Worktree basename'),'monitor-v31-final-r2-20260911');
      assert.equal(await fact('Reviewer'),'ChatGPT-Control-Tower');
      assert.equal(await fact('Reviewed head'),'a'.repeat(40));
      assert.equal(await fact('Review state'),'REVIEWED_EXACT_HEAD');
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),width);
      assert.equal(await fact('NEED BOSS'),'Qualified current owner blocker');
      // Isolated browser clipboard stub captures generated text only.
      await page.evaluate(()=>{window.copied=[];Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async text=>window.copied.push(text)}});});
      for(const mode of ['STEERING','TASK','REVIEW']) {
        await page.getByRole('button',{name:'COPY '+mode+' CONTEXT',exact:true}).click();
        assert.match(await page.getByLabel('Generated context').inputValue(),new RegExp('COPY '+mode+' CONTEXT'));
      }
      assert.equal(await page.evaluate(()=>window.copied.length),3);
      await page.clock.setSystemTime(new Date(now.getTime()+25*3600000));
      await page.getByRole('button',{name:'COPY TASK CONTEXT',exact:true}).click();
      assert.match(await page.getByLabel('Generated context').inputValue(),/"owner_required": false/);
      await page.clock.setSystemTime(now);
      await page.evaluate(()=>Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async()=>{throw Error('denied');}}}));
      await page.getByRole('button',{name:'COPY TASK CONTEXT',exact:true}).click();
      await page.getByText('Clipboard unavailable. Select the generated text to copy.',{exact:true}).waitFor();
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),width);
      await page.screenshot({path:path.join(evidence,`graph-inspect-${width}.png`),fullPage:false});
      await inspectNode('dependent'); assert.match(await fact('Dependencies'),/absent/);
      await inspectNode('historical'); assert.equal(await fact('State'),'UNKNOWN');
      await inspectNode('long-'+'x'.repeat(220));
      assert.match(await fact('Title'),/<img src=x/);
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),width);
      const controls=await page.locator('#app button').allTextContents();
      assert.ok(controls.every(t=>! /^(Run|Kill|Launch|Resume|Send-to-Codex)$/i.test(t.trim())));
      results.push(`Graph ${width}: sources separated, duplicate/conflict, explicit/unresolved relations, hostile/long text, Inspect, copy/fallback, internal pan only PASS`);
    }
    await page.setViewportSize({width:390,height:844});
    for (const condition of ['stale-envelope','aged-envelope','aged-row','stale-project','cached','offline']) {
      payload=graphFixture();mode='normal';
      if(condition==='stale-envelope') payload.control_tower.registry.freshness='STALE';
      if(condition==='aged-envelope') payload.control_tower.registry.observed_at=staleStamp;
      if(condition==='aged-row') payload.control_tower.registry.rows[0].observed_at=staleStamp;
      if(condition==='stale-project') payload.project.generated_at=staleStamp;
      if(condition==='cached') mode='cached';
      await openGraph();
      if(condition==='offline') await context.setOffline(true);
      await inspectNode('owner');
      assert.equal(await fact('State'),'UNKNOWN',condition);
      assert.equal(await fact('Review state'),'UNKNOWN',condition);
      assert.equal(await fact('NEED BOSS'),'No current owner action derived',condition);
      assert.equal(await page.locator('.agent-graph-owner').count(),0);
      if(condition==='offline') await context.setOffline(false);
      results.push('Graph '+condition+': current observation and owner action suppressed');
    }
    mode='normal';payload=graphFixture();payload.control_tower.work=[];payload.control_tower.registry.rows=[];
    await openGraph();assert.match(await page.locator('#work-agent-graph').innerText(),/Empty graph/);
    payload.control_tower.registry.rows=[{...lane('unknown','UNKNOWN'),direct_dependencies:'UNKNOWN'}];
    await openGraph();await inspectNode('unknown');assert.equal(await fact('Dependency evidence'),'UNKNOWN');
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),390);
    results.push('Empty and unknown graph PASS');
    await page.goto(url+'#home');
    payload=structuredClone(base); await page.reload();
    await page.getByRole('heading',{name:'Overview',exact:true}).waitFor();
    await context.setOffline(true);
    await page.getByText('Owner attention UNKNOWN — refresh current evidence.',{exact:true}).waitFor();
    results.push('Offline event invalidates current view');
    await context.setOffline(false);
    await page.setViewportSize({width:1280,height:900});
    assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth)<=1280);
    for (const label of ['Overview','Work','Runtime','EA Lab','Alerts']) {
      await page.locator('.bottom-nav').getByText(label,{exact:true}).click();
      await page.getByRole('heading',{name:label,exact:true}).first().waitFor();
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),1280,label+' desktop overflow');
    }
    assert.deepEqual(errors,[]);
    results.push('Desktop overflow check PASS; no uncaught browser errors');
    fs.writeFileSync(path.join(evidence,'browser-results.json'),JSON.stringify({status:'PASS',viewport:'390x844',results},null,2));
    console.log(JSON.stringify(results,null,2));
  } finally { await browser.close(); server.close(); }
})().catch(error => {console.error(error); server.close(); process.exitCode=1;});
