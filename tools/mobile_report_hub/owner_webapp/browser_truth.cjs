'use strict';
// Bounded fixture browser only. No production source, server or runtime is opened.
const assert=require('node:assert/strict');
const path=require('node:path');
const fs=require('node:fs');
const os=require('node:os');
const {pathToFileURL}=require('node:url');
const {execFileSync}=require('node:child_process');
const {chromium}=require('playwright-core');
const python=process.env.EA_LAB_TEST_PYTHON||path.resolve(__dirname,'../../python312/python.exe');
const fixtures=JSON.parse(execFileSync(python,[path.join(__dirname,'test_owner_webapp.py'),'--browser-fixtures'],{encoding:'utf8',maxBuffer:8*1024*1024}));
(async()=>{
 const browser=await chromium.launch({headless:true,channel:'msedge'});
 let passed=0;
 try{
  for(const [name,f] of Object.entries(fixtures)){
   if(process.env.OWNER_DOM_CASES&&!process.env.OWNER_DOM_CASES.split(',').includes(name))continue;
   const context=await browser.newContext({viewport:{width:1280,height:900},serviceWorkers:'block'});
   let offlineFile;
   try{
    const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(String(e)));
    await page.clock.install({time:new Date('2026-09-24T00:01:00Z')});
    let mode='cached';
    await page.route('http://owner.fixture/**',route=>{
      const url=new URL(route.request().url());
      if(url.pathname==='/api/snapshot'){
       if(mode==='failed')return route.fulfill({status:503,body:'unavailable'});
       const data=structuredClone(f.snapshot);
       if(mode==='mismatch')data.server_identity.build_sha256='0'.repeat(64);
       return route.fulfill({contentType:'application/json',body:JSON.stringify(data)});
      }
      return route.fulfill({contentType:'text/html',body:f.html});
    });
    if(name==='aging_offline'){
      offlineFile=path.join(os.tmpdir(),`owner-aging-${process.pid}.html`);
      fs.writeFileSync(offlineFile,f.html,{flag:'wx'});
      await page.goto(pathToFileURL(offlineFile).href);
    }else await page.goto('http://owner.fixture/');
    await page.getByRole('heading',{name:'EA_LAB Monitor',exact:true}).waitFor();
    assert.equal(await page.title(),'EA_LAB Monitor');
    assert.ok((await page.locator('#main').innerText()).length>100);
    const kpi=label=>page.locator('.kpi').filter({has:page.locator('label',{hasText:label})}).locator('strong');
    const qualified=['available','empty','malformed_account','gaps','conflict','work_missing','work_invalid','aging','aging_offline'].includes(name);
    assert.equal(await kpi('Open monitor findings').innerText(),qualified?(name==='empty'?'0':'1'):'UNKNOWN',name);
    if(['missing','invalid','malformed_account','gaps','conflict'].includes(name))assert.equal(await kpi('Observed accounts').innerText(),'UNKNOWN',name);
    if(name.startsWith('work_')||name==='empty'){
      await page.evaluate(()=>{location.hash='work'});
      await page.getByRole('heading',{name:'Work',exact:true}).waitFor();
      const source=name==='empty'?'AVAILABLE':name==='work_missing'?'MISSING':'INVALID';
      assert.equal(f.snapshot.work.status,source);
      const text=await page.locator('#main').innerText();
      assert.match(text,new RegExp('Current unfinished qualified observations: '+(source==='AVAILABLE'?'0':'UNKNOWN')));
      assert.match(text,new RegExp('Work source: '+source));
      if(source!=='AVAILABLE')assert.doesNotMatch(text,/qualified observations: 0/);
    }
    if(name.startsWith('aging')){
      await page.setViewportSize({width:name==='aging'?390:1280,height:name==='aging'?600:400});
      await page.locator('details').first().evaluate(e=>{e.open=true});
      await page.locator('[data-open-work="ct-aging"]').first().click();
      await page.locator('.drawer .close').focus();
      await page.evaluate(()=>{
        document.getElementById('topnav').classList.add('open');
        document.getElementById('navToggle').setAttribute('aria-expanded','true');
        window.scrollTo(0,250);
        const d=document.querySelector('.drawer');d.scrollTop=80;
        window.reading={focus:document.activeElement,detail:document.querySelector('details'),drawer:d,
          y:scrollY,drawerY:d.scrollTop,nav:document.querySelector('[data-route="overview"]')};
      });
      assert.ok(await page.evaluate(()=>reading.y>0&&reading.drawerY>0),'exercise real scroll');
      await page.clock.setSystemTime(new Date('2026-09-25T03:00:00Z'));
      await page.clock.runFor(10000);
      assert.deepEqual(await page.evaluate(()=>({
        drawer:reading.drawer===document.querySelector('.drawer'),
        detail:reading.detail===document.querySelector('details')&&reading.detail.open,
        focus:reading.focus===document.activeElement,
        scroll:reading.y===scrollY&&reading.drawerY===reading.drawer.scrollTop,
        nav:reading.nav===document.querySelector('[data-route="overview"]')&&reading.nav.classList.contains('active')&&
          document.getElementById('topnav').classList.contains('open')&&document.getElementById('navToggle').getAttribute('aria-expanded')==='true'
      })),{drawer:true,detail:true,focus:true,scroll:true,nav:true});
      assert.match(await page.locator('.drawer .kv').innerText(),/Freshness\s+STALE/);
      assert.equal(await kpi('Open monitor findings').innerText(),'UNKNOWN');
      assert.match(await kpi('Data observation age').innerText(),/27.0 h.*STALE/);
      assert.match(await page.locator('.timestamp').innerText(),/STALE/);
      assert.equal(await kpi('Active lanes').innerText(),'0');
      assert.equal(await page.locator('[data-open-work="ct-aging"]').count(),0,'expired current work removed');
      if(process.env.OWNER_DOM_EVIDENCE)await page.screenshot({path:path.join(process.env.OWNER_DOM_EVIDENCE,name+'.png')});
      await page.locator('.drawer .close').click();
      assert.equal(await page.locator('.drawer').count(),0);
      await page.evaluate(()=>{location.hash='knowledge'});
      await page.getByRole('heading',{name:'Second Brain',exact:true}).waitFor();
      await page.locator('[data-knowledge-search]').fill('test query');
      await page.clock.runFor(200);
      await page.locator('[data-knowledge-search]').evaluate(e=>{e.focus();e.setSelectionRange(2,6);window.searchInput=e});
      await page.clock.runFor(10000);
      assert.deepEqual(await page.evaluate(()=>({same:searchInput===document.activeElement,value:searchInput.value,
        start:searchInput.selectionStart,end:searchInput.selectionEnd})),{same:true,value:'test query',start:2,end:6});
      assert.deepEqual(errors,[]);passed++;console.log('PASS production DOM '+name);continue;
    }
    await page.evaluate(()=>{location.hash='performance'});
    await page.getByRole('heading',{name:'EA Performance / Live Tracking',exact:true}).waitFor();
    if(['missing','malformed_account'].includes(name)){
      assert.equal(await page.locator('.chart-svg').count(),0);
      assert.match(await page.locator('#main').innerText(),/Balance\s+UNKNOWN/);
    }
    if(['gaps','conflict','available'].includes(name)){
      const paths=await page.locator('.chart-line-balance').evaluateAll(xs=>xs.map(x=>x.getAttribute('d')));
      assert.ok(paths.length);for(const d of paths)assert.doesNotMatch(d,/[Ll]/,'no chart bridging');
      if(name!=='available')assert.match(await page.locator('.metric-strip').innerText(),/Balance\s+UNKNOWN/);
    }
    for(const hash of ['work','runtime','news','knowledge','templates','overview']){
      await page.evaluate(h=>{location.hash=h},hash);await page.waitForFunction(h=>location.hash==='#'+h,hash);
      await page.locator('h1').waitFor();
    }
    await page.getByRole('heading',{name:'EA_LAB Monitor',exact:true}).waitFor();
    if(name==='available'){
      await page.clock.setSystemTime(new Date('2026-09-25T03:00:00Z'));
      await page.clock.runFor(10000);
      assert.equal(await kpi('Open monitor findings').innerText(),'UNKNOWN');
      assert.match(await kpi('Data observation age').innerText(),/27.0 h.*STALE/);
      mode='failed';await page.locator('[data-refresh]').click();await page.waitForFunction(()=>document.querySelector('.timestamp').textContent.includes('Fetch UNAVAILABLE'));
      assert.match(await kpi('Data observation age').innerText(),/STALE/);
      mode='mismatch';await page.locator('[data-refresh]').click();await page.waitForFunction(()=>document.querySelector('.timestamp').textContent.includes('VERSION_MISMATCH'));
      assert.match(await kpi('Data observation age').innerText(),/STALE/);
    }
    if(name==='stale'){
      await page.locator('[data-refresh]').click();await page.waitForFunction(()=>document.querySelector('.timestamp').textContent.includes('Fetch SUCCESS'));
      assert.match(await kpi('Data observation age').innerText(),/STALE/);
      assert.match(await page.locator('.timestamp').innerText(),/cache HIT/);
    }
    assert.deepEqual(errors,[]);passed++;console.log('PASS production DOM '+name);
   }finally{await context.close();if(offlineFile)fs.unlinkSync(offlineFile);}
  }
 }finally{await browser.close();}
 console.log(`${passed} real Model.snapshot -> serialization -> truth -> owner DOM scenarios passed`);
})().catch(e=>{console.error(e);process.exitCode=1});
