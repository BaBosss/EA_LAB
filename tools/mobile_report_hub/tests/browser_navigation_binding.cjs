// Real Report UI + deterministic asynchronous boundaries. No fake DOM, MT5 run,
// production writes, or synthetic evidence promoted to a research record.
// Usage: node browser_navigation_binding.cjs <native-preview-dir> <evidence-dir>
// The preview is exported by test_native_graphs.py --export-browser-fixture and
// contains the normal build_index output. Playwright must be on NODE_PATH.
'use strict';
const {chromium} = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const preview = path.resolve(process.argv[2]);
const evidence = path.resolve(process.argv[3]);
fs.mkdirSync(evidence, {recursive:true});
const base = JSON.parse(fs.readFileSync(path.join(preview, 'report_index.json')));
const fixture = JSON.parse(fs.readFileSync(path.join(preview, 'native-fixture.json')));
const nativePng = fs.readFileSync(path.join(preview, fixture.item.native_graphs.main.href));
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const assets = new Map();
const records = ['a', 'b', 'c'].map(id => {
  const record = structuredClone(fixture.item);
  record.id = id;
  record.display_name = `Navigation fixture ${id.toUpperCase()}`;
  for (const role of ['main', 'bwd']) {
    const graph = record.native_graphs[role];
    // Distinct bytes prove which record AND role supplied the displayed image.
    const bytes = Buffer.concat([nativePng, Buffer.from(`navigation:${id}:${role}`)]);
    graph.ea_id = id;
    graph.package_id = `navigation-${id}`;
    graph.package_sha256 = sha256(graph.package_id);
    graph.asset_sha256 = sha256(bytes);
    const namespace = sha256(graph.package_id + graph.package_sha256 + id).slice(0,32);
    graph.href = `artifacts/native/${fixture.sha}/${namespace}/${role}/${graph.asset_sha256}.png`;
    assets.set('/' + graph.href, bytes);
  }
  return record;
});
const h08 = structuredClone(base.eas.find(item => item.id === 'b16-h08-usdjpy-h1'));
assert.ok(h08, 'Actual source-bound H08 record required');
assert.deepEqual(['main','bwd'].map(role => h08.native_graphs[role].state), ['MISSING','MISSING']);
const refused = structuredClone(h08);
refused.id = 'refused';
for (const role of ['main', 'bwd']) refused.native_graphs[role].state = 'REFUSED';
const payload = {...base, fixture_only:true, project:{...base.project,
  canonical_sha:fixture.sha, canonical_short_sha:fixture.sha.slice(0,12)},
  eas:[...records, h08, refused]};
const server = http.createServer((req,res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (pathname.endsWith('/report_index.json')) {
    res.setHeader('Content-Type','application/json'); return res.end(JSON.stringify(payload));
  }
  if (assets.has(pathname)) {
    res.setHeader('Content-Type','image/png'); return res.end(assets.get(pathname));
  }
  const directory = path.join(root, 'mobile_report_hub');
  const file = path.resolve(directory, pathname === '/' ? 'index.html' : pathname.slice(1));
  if (!file.startsWith(directory + path.sep) || !fs.existsSync(file)) {
    res.writeHead(404); return res.end();
  }
  res.setHeader('Content-Type', {'.html':'text/html','.js':'text/javascript','.css':'text/css',
    '.svg':'image/svg+xml','.webmanifest':'application/manifest+json'}[path.extname(file)] || 'text/plain');
  res.end(fs.readFileSync(file));
});

// Gates are armed before navigation. Fetch gates wait after the real HTTP response;
// decode gates wait after the real browser image decode. Release order is explicit.
function installGates() {
  const control = window.navigationTest = {gates:[], pending:0, urls:[], revoked:[]};
  const tracked = async operation => {
    control.pending++;
    try {return await operation();} finally {control.pending--;}
  };
  const pause = async (stage, key) => {
    const gate = control.gates.find(g => !g.entered && g.stage === stage && key.includes(g.key));
    if (!gate) return;
    gate.entered = true;
    if (!gate.released) await new Promise(resolve => {gate.resolve = resolve;});
    if (gate.fail) throw new Error('deterministic prior-load failure');
  };
  const fetchOriginal = window.fetch.bind(window);
  window.fetch = (...args) => tracked(async () => {
    const result = await fetchOriginal(...args);
    await pause('fetch', String(args[0]));
    return result;
  });
  const digestOriginal = crypto.subtle.digest.bind(crypto.subtle);
  crypto.subtle.digest = (...args) => tracked(() => digestOriginal(...args));
  const bufferOriginal = Response.prototype.arrayBuffer;
  Response.prototype.arrayBuffer = function(...args) {return tracked(() => bufferOriginal.apply(this,args));};
  const decodeOriginal = HTMLImageElement.prototype.decode;
  HTMLImageElement.prototype.decode = function(...args) {
    return tracked(async () => {await decodeOriginal.apply(this,args); await pause('decode', this.alt);});
  };
  const createOriginal = URL.createObjectURL.bind(URL);
  URL.createObjectURL = blob => {const url=createOriginal(blob); control.urls.push(url); return url;};
  const revokeOriginal = URL.revokeObjectURL.bind(URL);
  URL.revokeObjectURL = url => {control.revoked.push(url); return revokeOriginal(url);};
}

(async () => {
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  const browser = await chromium.launch({headless:true,channel:'msedge'});
  const results = [];
  const url = `http://127.0.0.1:${server.address().port}`;
  try {
    for (const viewport of [{width:390,height:844},{width:1280,height:900}]) {
      async function run(name, test) {
        if (process.env.NAVIGATION_CASE_FILTER && !name.includes(process.env.NAVIGATION_CASE_FILTER)) return;
        const context = await browser.newContext({viewport,serviceWorkers:'block'});
        await context.addInitScript(installGates);
        const page = await context.newPage();
        page.setDefaultTimeout(5000);
        const errors=[];
        page.on('pageerror', error => errors.push(String(error)));
        const navigate = async id => {
          await page.evaluate(id => {location.hash=`detail/${id}`;},id);
          await page.waitForFunction(name => document.querySelector('.page-heading h2')?.textContent === name,
            payload.eas.find(record=>record.id===id).display_name);
          // The route itself, not a test rendering function, must have run.
          await page.waitForFunction(id => route().id === id && document.querySelector('.tested-setup') !== null,id);
        };
        const arm = async (stage, role, id='a', fail=false) => {
          const key = stage === 'fetch' ? records.find(r=>r.id===id).native_graphs[role].href : role.toUpperCase();
          return page.evaluate(gate => {navigationTest.gates.push(gate);return navigationTest.gates.length-1;}, {stage,key,fail});
        };
        const entered = index => page.waitForFunction(index=>navigationTest.gates[index].entered,index);
        const release = index => page.evaluate(index => {
          const gate=navigationTest.gates[index]; gate.released=true; gate.resolve?.();
        },index);
        const settled = async () => {
          await page.waitForFunction(()=>navigationTest.pending===0);
          await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
          await page.waitForFunction(()=>navigationTest.pending===0);
        };
        const states = async expected => {
          assert.deepEqual(await page.locator('.graph-state').allTextContents(),expected.map(s=>`GRAPH ASSET ${s}`));
          assert.equal(await page.locator('.native-graph img').count(),expected.filter(s=>s==='AVAILABLE').length);
          assert.equal(await page.locator('#graph-evidence-status').innerText(),expected.every(s=>s==='AVAILABLE')?'AVAILABLE':'INCOMPLETE');
        };
        const images = async id => {
          for (const role of ['main','bwd']) {
            const actual=await page.locator(`[data-native-role="${role}"] img`).evaluate(async img=>{
              const bytes=await (await fetch(img.src)).arrayBuffer();
              return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes)),b=>b.toString(16).padStart(2,'0')).join('');
            });
            assert.equal(actual,records.find(r=>r.id===id).native_graphs[role].asset_sha256,`${id}/${role} image bytes`);
          }
        };
        try {
          await page.goto(url+'/index.html?fixture=1#detail/b16-h08-usdjpy-h1');
          await page.locator('.native-windows').waitFor();
          await test({page,navigate,arm,entered,release,settled,states,images});
          assert.deepEqual(errors,[],'No uncaught browser errors');
          assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),viewport.width,'No horizontal overflow');
          results.push({name,viewport,status:'PASS'});
        } catch(error) {results.push({name,viewport,status:'FAIL',error:String(error)});}
        finally {console.log(`${results.at(-1).status} ${viewport.width} ${name}`);await context.close();}
      }
      for (const stage of ['fetch','decode']) {
        for (const role of ['main','bwd']) {
          await run(`${stage}: delayed A ${role} -> H08`,async t=>{
            const gate=await t.arm(stage,role); await t.navigate('a');await t.entered(gate);
            // Actual visible UI path for the accepted reproduction.
            await t.page.getByRole('link',{name:'← Back',exact:true}).click();
            await t.page.locator('[data-nav="ealab"]').click();
            await t.page.getByText('Research reports',{exact:true}).click();
            await t.page.locator('a[href="#detail/b16-h08-usdjpy-h1"]').first().click();
            await t.page.locator('.native-windows').waitFor();
            await t.states(['MISSING','MISSING']);await t.release(gate);await t.settled();await t.states(['MISSING','MISSING']);
            await t.page.screenshot({path:path.join(evidence,`${stage}-${role}-h08-${viewport.width}.png`),fullPage:true});
          });
        }
        await run(`${stage}: both roles delayed -> H08, reverse release`,async t=>{
          const main=await t.arm(stage,'main'), bwd=await t.arm(stage,'bwd');
          await t.navigate('a');await t.entered(main);await t.entered(bwd);await t.navigate(h08.id);
          await t.release(bwd);await t.release(main);await t.settled();await t.states(['MISSING','MISSING']);
        });
        await run(`${stage}: A -> B -> A rejects first A generation`,async t=>{
          const gate=await t.arm(stage,'main');await t.navigate('a');await t.entered(gate);
          await t.navigate('b');await t.navigate('a');
          await t.page.waitForFunction(()=>document.querySelectorAll('.native-graph img').length===2);
          const urls=await t.page.locator('.native-graph img').evaluateAll(nodes=>nodes.map(n=>n.src));
          await t.release(gate);await t.settled();await t.states(['AVAILABLE','AVAILABLE']);await t.images('a');
          assert.deepEqual(await t.page.locator('.native-graph img').evaluateAll(nodes=>nodes.map(n=>n.src)),urls,'Newest generation nodes unchanged');
        });
        await run(`${stage}: old A completes after valid B`,async t=>{
          const gate=await t.arm(stage,'main');await t.navigate('a');await t.entered(gate);await t.navigate('b');
          await t.page.waitForFunction(()=>document.querySelectorAll('.native-graph img').length===2);
          await t.release(gate);await t.settled();await t.states(['AVAILABLE','AVAILABLE']);await t.images('b');
        });
        for (const role of ['main','bwd']) {
          await run(`${stage}: ${role} callback cannot contaminate opposite slot`,async t=>{
            const gate=await t.arm(stage,role);await t.navigate('a');await t.entered(gate);await t.navigate('c');
            await t.page.waitForFunction(()=>document.querySelectorAll('.native-graph img').length===2);
            await t.release(gate);await t.settled();await t.states(['AVAILABLE','AVAILABLE']);await t.images('c');
          });
        }
        await run(`${stage}: refused destination rejects stale success`,async t=>{
          const gate=await t.arm(stage,'main');await t.navigate('a');await t.entered(gate);await t.navigate('refused');
          await t.release(gate);await t.settled();await t.states(['REFUSED','REFUSED']);
        });
        await run(`${stage}: rapid A B C A H08 B H08 navigation`,async t=>{
          const gate=await t.arm(stage,'main');await t.navigate('a');await t.entered(gate);
          for(const id of ['b','c','a',h08.id,'b',h08.id]) await t.navigate(id);
          await t.release(gate);await t.settled();await t.states(['MISSING','MISSING']);
        });
        await run(`${stage}: stale failure cannot refuse current valid B`,async t=>{
          const gate=await t.arm(stage,'main','a',true);await t.navigate('a');await t.entered(gate);await t.navigate('b');
          await t.release(gate);await t.settled();await t.states(['AVAILABLE','AVAILABLE']);await t.images('b');
        });
        await run(`${stage}: leaving detail discards old callbacks`,async t=>{
          const gate=await t.arm(stage,'main');await t.navigate('a');await t.entered(gate);
          await t.page.getByRole('link',{name:'← Back',exact:true}).click();
          await t.release(gate);await t.settled();assert.equal(await t.page.locator('.native-graph img').count(),0);
          assert.equal(await t.page.evaluate(()=>navigationTest.urls.every(url=>navigationTest.revoked.includes(url))),true,'All obsolete blob URLs revoked');
        });
      }
      for(const id of ['a','b','c']) await run(`positive control ${id}: exact record/package/role bytes`,async t=>{
        await t.navigate(id);await t.settled();await t.states(['AVAILABLE','AVAILABLE']);await t.images(id);
      });
      await run('same-generation delayed positive control',async t=>{
        const gate=await t.arm('decode','main');await t.navigate('a');await t.entered(gate);
        await t.release(gate);await t.settled();await t.states(['AVAILABLE','AVAILABLE']);await t.images('a');
      });
    }
  } finally {await browser.close();server.close();}
  fs.writeFileSync(path.join(evidence,'navigation-results.json'),JSON.stringify({
    source_sha256:sha256(fs.readFileSync(path.join(root,'mobile_report_hub/app.js'))),
    passed:results.filter(r=>r.status==='PASS').length,total:results.length,results},null,2));
  for(const result of results) console.log(`${result.status} ${result.viewport.width} ${result.name}${result.error?' '+result.error:''}`);
  if(results.some(r=>r.status==='FAIL')) process.exitCode=1;
})().catch(error=>{console.error(error);server.close();process.exitCode=1;});
