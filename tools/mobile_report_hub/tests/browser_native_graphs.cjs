// Isolated loopback browser acceptance. Fixture image is an existing native MT5
// B15 PNG; both test roles are explicitly bound, never production B16 evidence.
const {chromium} = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
const http = require('node:http');
const crypto = require('node:crypto');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../../..');
const evidence = process.argv[2];
const preview = path.join(evidence, 'preview');
const base = JSON.parse(fs.readFileSync(path.join(preview, 'report_index.json')));
const fixture = JSON.parse(fs.readFileSync(path.join(preview, 'native-fixture.json')));
let payload = structuredClone(base);
let corrupt = false;
let missing = false;
let graphRequests = 0;
const results = [];
const server = http.createServer((req,res) => {
  const pathname = new URL(req.url, 'http://localhost').pathname;
  if (pathname.endsWith('/report_index.json')) {
    res.setHeader('Content-Type', 'application/json');
    return res.end(JSON.stringify(payload));
  }
  const native = pathname.startsWith('/artifacts/native/');
  if (native) {
    graphRequests++;
    if (missing) {res.writeHead(404); return res.end();}
    if (corrupt) {res.setHeader('Content-Type', 'image/png'); return res.end('wrong package cached bytes');}
  }
  const dir = native ? preview : path.join(root, 'mobile_report_hub');
  const file = path.resolve(dir, pathname === '/' ? 'index.html' : pathname.slice(1));
  if (!file.startsWith(path.resolve(dir) + path.sep) || !fs.existsSync(file)) {res.writeHead(404); return res.end();}
  res.setHeader('Content-Type', {'.html':'text/html', '.js':'text/javascript', '.css':'text/css', '.png':'image/png', '.svg':'image/svg+xml', '.webmanifest':'application/manifest+json'}[path.extname(file)] || 'text/plain');
  res.end(fs.readFileSync(file));
});

(async () => {
  await new Promise(resolve => server.listen(0,'127.0.0.1',resolve));
  const browser = await chromium.launch({headless:true,channel:'msedge'});
  try {
    const context = await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});
    const page = await context.newPage();
    page.setDefaultTimeout(10000);
    const errors=[];
    page.on('pageerror', e=>errors.push(String(e)));
    const url=`http://127.0.0.1:${server.address().port}`;
    const testIndex = () => ({...structuredClone(base),fixture_only:true,project:{...base.project,canonical_sha:fixture.sha,canonical_short_sha:fixture.sha.slice(0,12)},eas:[structuredClone(fixture.item)]});
    let serial=0;
    async function openFixture() {
      await page.goto(url+`/index.html?fixture=1&case=${++serial}#detail/graph-fixture`);
      await page.locator('.graph-state').first().waitFor();
      await page.waitForFunction(()=>![...document.querySelectorAll('.graph-state')].some(n=>n.textContent.includes('VERIFYING')));
    }
    for (const viewport of [{width:390,height:844},{width:1280,height:900}]) {
      await page.setViewportSize(viewport);
      payload=testIndex();
      await openFixture();
      assert.equal(await page.locator('.native-graph img').count(),2);
      assert.equal(await page.locator('#graph-evidence-status').innerText(),'AVAILABLE');
      for(const img of await page.locator('.native-graph img').all()) {
        const box=await img.evaluate(n=>({w:n.clientWidth,h:n.clientHeight,nw:n.naturalWidth,nh:n.naturalHeight}));
        assert.ok(Math.abs(box.w/box.h-box.nw/box.nh)<0.05,'Image aspect ratio preserved');
      }
      for(const name of ['Exact tested setup','MAIN','BWD','Evidence status','Changed from parent','Key parameters']) await page.getByRole('heading',{name,exact:true}).waitFor();
      assert.match(await page.locator('[data-role="main"] .metric-card').innerText(),/PF.*1.23.*Net.*45.67.*EqDD.*2.34.*Trades.*56.*Cycles.*34/s);
      const popupPromise=page.waitForEvent('popup');
      await page.getByRole('link',{name:'Open MAIN graph larger'}).click();
      const popup=await popupPromise;
      assert.ok(popup.url().startsWith('blob:'));
      await popup.close();
      await page.getByText('Full parameters',{exact:true}).click();
      await page.getByLabel('Search parameters').fill('Another');
      assert.equal(await page.locator('#full-parameters [data-parameter]:visible').count(),1);
      assert.match(await page.locator('#parameter-count').innerText(),/1 \/ 2/);
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),viewport.width);
      await page.screenshot({path:path.join(evidence,`native-valid-${viewport.width}.png`),fullPage:true});
      results.push(`Native fixture ${viewport.width}x${viewport.height}: setup, MAIN/BWD, metrics, aspect ratio, larger view, search, no overflow PASS`);
      payload=structuredClone(base);
      await page.goto(url+'/index.html#detail/b16-h08-usdjpy-h1');
      await page.getByRole('heading',{name:'Exact tested setup',exact:true}).waitFor();
      assert.deepEqual(await page.locator('.graph-state').allTextContents(),['GRAPH ASSET MISSING','GRAPH ASSET MISSING']);
      assert.equal(await page.locator('#graph-evidence-status').innerText(),'INCOMPLETE');
      assert.equal(await page.locator('.native-graph img').count(),0);
      assert.match(await page.locator('[data-role="main"]').innerText(),/1.68/);
      assert.match(await page.locator('[data-role="bwd"]').innerText(),/0.66/);
      assert.match(await page.locator('.report-status').innerText(),/DO_NOT_ADOPT_CENTER_RETAIN_PARENT_RESEARCH_REFERENCE/);
      await page.getByText('Full parameters',{exact:true}).click();
      await page.getByLabel('Search parameters').fill('_16_RsiLow');
      assert.equal(await page.locator('#full-parameters [data-parameter]:visible').count(),1);
      assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth),viewport.width);
      await page.screenshot({path:path.join(evidence,`b16-h08-${viewport.width}.png`),fullPage:true});
      results.push(`Real H08 ${viewport.width}x${viewport.height}: two MISSING surfaces; metrics, conclusion and parameters retained PASS`);
    }
    for(const unavailable of [['bwd'],['main'],['main','bwd']]) {
      payload=testIndex();
      for(const role of unavailable) payload.eas[0].native_graphs[role]={state:'MISSING'};
      await openFixture();
      assert.equal(await page.locator('.native-graph img').count(),2-unavailable.length);
      assert.equal(await page.locator('#graph-evidence-status').innerText(),'INCOMPLETE');
    }
    payload=testIndex();delete payload.eas[0].native_graphs;await openFixture();
    assert.deepEqual(await page.locator('.graph-state').allTextContents(),['GRAPH ASSET MISSING','GRAPH ASSET MISSING']);
    results.push('Both one-sided, both-missing and legacy no-graph fields PASS');
    for(const mutate of [
      g=>{g.main.href='../../private.png';},
      g=>{g.main.ea_id='different-ea';},
      g=>{g.main.role='BWD';},
      g=>{g.main.canonical_sha='f'.repeat(40);},
      g=>{g.main.package_id='DIFFERENT_PACKAGE';},
      g=>{g.main.href=g.bwd.href;},
      g=>{g.main.href='<img src=x onerror=alert(1)>';},
    ]) {
      payload=testIndex();mutate(payload.eas[0].native_graphs);await openFixture();
      assert.equal(await page.locator('[data-native-role="main"] .graph-state').innerText(),'GRAPH ASSET REFUSED');
      assert.equal(await page.locator('[data-native-role="main"] img').count(),0);
    }
    payload=testIndex();corrupt=true;await openFixture();corrupt=false;
    assert.deepEqual(await page.locator('.graph-state').allTextContents(),['GRAPH ASSET REFUSED','GRAPH ASSET REFUSED']);
    payload=testIndex();missing=true;await openFixture();missing=false;
    assert.deepEqual(await page.locator('.graph-state').allTextContents(),['GRAPH ASSET REFUSED','GRAPH ASSET REFUSED']);
    // Valid PNG signature/hash but undecodable: Phase A does not promise decoding.
    payload=testIndex();
    const broken=Buffer.from('89504e470d0a1a0a','hex');
    const hash=crypto.createHash('sha256').update(broken).digest('hex');
    for(const graph of Object.values(payload.eas[0].native_graphs)) {
      graph.href=graph.href.replace(graph.asset_sha256,hash);graph.asset_sha256=hash;
      const target=path.join(preview,graph.href);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,broken);
    }
    await openFixture();
    assert.deepEqual(await page.locator('.graph-state').allTextContents(),['GRAPH ASSET REFUSED','GRAPH ASSET REFUSED']);
    results.push('Unsafe/hostile/mismatched identity, cross-window, wrong cached bytes, HTTP failure and decode failure REFUSED PASS');
    payload=testIndex();payload.eas[0].evidence.model='MODEL_2';await openFixture();
    assert.equal(await page.locator('.native-window .metric-card').count(),0);
    results.push('Model2 metrics excluded from research performance PASS');
    assert.deepEqual(errors,[]);
    await context.close();
    // Exercise actual SW in an isolated context, including a poisoned old cache.
    payload=testIndex();
    const swContext=await browser.newContext({viewport:{width:390,height:844}});
    const swPage=await swContext.newPage();
    await swPage.goto(url+'/index.html?fixture=1#detail/graph-fixture');
    await swPage.evaluate(()=>navigator.serviceWorker.ready);
    await swPage.reload();
    await swPage.waitForFunction(()=>!!navigator.serviceWorker.controller);
    const graphHref=fixture.item.native_graphs.main.href;
    await swPage.evaluate(async href=>{
      const cache=await caches.open('ea-lab-report-hub-v3.1');
      await cache.put(href,new Response('wrong graph from old cache',{headers:{'Content-Type':'image/png'}}));
    },graphHref);
    graphRequests=0;
    await swPage.reload();
    await swPage.waitForFunction(()=>document.querySelectorAll('.native-graph img').length===2);
    assert.ok(graphRequests>=2,'Native evidence fetched despite poisoned cache');
    const names=await swPage.evaluate(()=>caches.keys());
    assert.ok(names.includes('ea-lab-report-hub-v3.2-native'));
    results.push('Actual service worker new generation + poisoned old native-cache bypass PASS');
    await swContext.close();
    fs.writeFileSync(path.join(evidence,'browser-native-results.json'),JSON.stringify({status:'PASS',results},null,2));
    console.log(JSON.stringify(results,null,2));
  } finally {await browser.close();server.close();}
})().catch(e=>{console.error(e);server.close();process.exitCode=1;});
