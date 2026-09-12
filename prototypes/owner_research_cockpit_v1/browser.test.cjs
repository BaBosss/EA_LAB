const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
const path=require('node:path');
const {createServer}=require('./serve.cjs');
const output=path.resolve(process.argv[2]||path.join(__dirname,'artifacts'));
fs.mkdirSync(output,{recursive:true});
const pack=JSON.parse(fs.readFileSync(path.join(__dirname,'fixtures.json')));
let mode='normal';
const server=createServer((name,req,res)=>{
 if(name==='fixtures.json'&&mode==='malformed'){res.setHeader('Content-Type','application/json');res.end('{');return true;}
 if(name==='fixtures.json'&&mode==='authority'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({...pack,authority:'CANONICAL'}));return true;}
 if(name==='assets/b15-native-main.png'&&mode==='poison'){const bytes=Buffer.from(fs.readFileSync(path.join(__dirname,name)));bytes[bytes.length-1]^=1;res.setHeader('Content-Type','image/png');res.end(bytes);return true;}
});
const results=[],errors=[],external=[],mutations=[];
async function check(name,fn){await fn();results.push({name,status:'PASS'});console.log(`PASS ${name}`);}
(async()=>{
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const url=`http://127.0.0.1:${server.address().port}`;
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 try{
  const context=await browser.newContext({viewport:{width:390,height:844},serviceWorkers:'block'});
  const page=await context.newPage();await page.clock.install({time:new Date('2026-09-12T07:05:00Z')});
  page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  page.on('request',r=>{if(!r.url().startsWith(url)&&!r.url().startsWith('blob:')&&!r.url().startsWith('data:'))external.push(r.url());if(!['GET','HEAD'].includes(r.method()))mutations.push(r.method());});
  await page.goto(url);await page.locator('.metrics').waitFor();
  await check('Seven screens at 390x844 and 1280x900; no page overflow',async()=>{
   for(const [label,width,height]of [['mobile',390,844],['desktop',1280,900]]){
    await page.setViewportSize({width,height});
    for(const screen of ['overview','research','templates','optimization','evidence','blockers','owner']){
     await page.evaluate(s=>location.hash=s,screen);await page.waitForTimeout(100);
     if(screen==='evidence')await page.locator('#native-panel .badge').filter({hasText:'EXACT'}).waitFor();
     assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true,`${label}/${screen} overflow`);
     assert.equal(await page.locator('h1').count(),1);
     await page.screenshot({path:path.join(output,`${label}-${screen}.png`),fullPage:true});
     if(screen==='overview')await page.screenshot({path:path.join(output,`${label}-viewport.png`)});
    }
   }
  });
  await check('Research search and status filter intersect; empty state',async()=>{
   await page.goto(url+'/#research');await page.locator('[data-research-card]').first().waitFor();
   await page.locator('#research-search').fill('Kangaroo');assert.equal(await page.locator('[data-research-card]').count(),1);
   await page.getByRole('button',{name:'READY',exact:true}).click();assert.equal(await page.locator('[data-research-card]').count(),0);
   await page.locator('#research-search').fill('');assert.equal(await page.locator('[data-research-card]').count(),1);
   await page.getByRole('button',{name:'UNKNOWN',exact:true}).click();assert.equal(await page.locator('[data-research-card]').count(),2);
   assert.equal(await page.locator('[data-research-card] .badge.ready').count(),0);
  });
  await check('Evidence drawer provenance and keyboard dismissal',async()=>{
   await page.locator('[data-inspect="FX-14"]').click();await page.locator('dialog[open]').waitFor();
   assert.match(await page.locator('#drawer-body').innerText(),/UNKNOWN \/ PENDING/);
   assert.match(await page.locator('#drawer-body').innerText(),/fixtures.json#\/research\/4/);
   await page.keyboard.press('Escape');assert.equal(await page.locator('dialog[open]').count(),0);
  });
  await check('EXACT native graph, MISSING / REFUSED placeholders, parameter search',async()=>{
   await page.goto(url+'/#evidence');await page.locator('#native-panel .badge.exact').waitFor();
   assert.equal(await page.locator('.graph-panel .badge.missing').count(),1);assert.equal(await page.locator('.graph-panel .badge.refused').count(),1);
   await page.locator('summary').click();await page.locator('#parameter-search').fill('CountBars');assert.equal(await page.locator('#parameter-results .gate').count(),1);
   await page.getByRole('button',{name:'Inspect original larger'}).click();assert.equal(await page.locator('dialog img').count(),1);await page.keyboard.press('Escape');
  });
  await check('NEED BOSS suppresses stale, offline, unbound and hidden requests',async()=>{
   await page.goto(url+'/#owner');await page.locator('[data-owner-action]').waitFor();assert.equal(await page.locator('[data-owner-action]').count(),1);
   assert.doesNotMatch(await page.locator('#main').innerText(),/MUST_NOT_APPEAR/);
   for(const condition of ['stale','unbound','offline']){
    await page.locator('#scenario').selectOption(condition);assert.equal(await page.locator('[data-owner-action]').count(),0);assert.match(await page.locator('#main').innerText(),/No owner action currently derived/);
    await page.screenshot({path:path.join(output,`owner-${condition}.png`),fullPage:true});
   }
   await page.locator('#scenario').selectOption('normal');assert.equal(await page.locator('[data-owner-action]').count(),1);
   await context.setOffline(true);assert.equal(await page.locator('[data-owner-action]').count(),0);await context.setOffline(false);
  });
  await check('Time passing expires owner action and closes open drawer',async()=>{
   await page.locator('[data-inspect="FX-A01"]').click();await page.clock.fastForward(86400000);assert.equal(await page.locator('[data-owner-action]').count(),0);assert.equal(await page.locator('dialog[open]').count(),0);
   await page.evaluate(()=>location.hash='overview');assert.match(await page.locator('.metrics').innerText(),/UNKNOWN/);assert.equal(await page.locator('.metric .ready-text').count(),0);
  });
  await page.clock.setFixedTime(new Date('2026-09-12T07:05:00Z'));
  await check('Real asset hash mismatch refuses original image',async()=>{mode='poison';await page.goto(url+'/?case=poison#evidence');await page.locator('#native-panel .badge.refused').waitFor();assert.equal(await page.locator('#native-panel img').count(),0);mode='normal';});
  await check('Malformed fixture and authority escalation fail closed',async()=>{for(const condition of ['malformed','authority']){mode=condition;await page.goto(url+'/?case='+condition);await page.getByRole('heading',{name:'UNKNOWN / PENDING'}).waitFor();assert.equal(await page.locator('[data-owner-action],.metrics').count(),0);}mode='normal';});
  await check('No console errors, external connections, or mutation requests',async()=>{assert.deepEqual(errors,[]);assert.deepEqual(external,[]);assert.deepEqual(mutations,[]);});
  const oldFailure=path.join(output,'browser-failure.txt');if(fs.existsSync(oldFailure))fs.unlinkSync(oldFailure);
  fs.writeFileSync(path.join(output,'browser-results.json'),JSON.stringify({status:'PASS',browser:'Microsoft Edge / Playwright',viewports:['390x844','1280x900'],fixtureClock:'2026-09-12T07:05:00Z',baseSha:pack.baseSha,authority:'TEST_EVIDENCE_ONLY',results,errors,external,mutations},null,2));
 }finally{await browser.close();await new Promise(resolve=>server.close(resolve));}
})().catch(e=>{fs.writeFileSync(path.join(output,'browser-failure.txt'),e.stack);console.error(e);server.close();process.exitCode=1;});
