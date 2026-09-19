"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const http = require("node:http");
const path = require("node:path");
const { chromium } = require("playwright-core");

const evidence = path.resolve(process.argv[2] || ".");
const preview = path.join(evidence, "preview");
const screenshots = path.join(evidence, "screenshots");
fs.mkdirSync(screenshots, {recursive:true});

const mime = {".html":"text/html",".js":"text/javascript",".css":"text/css",".json":"application/json",".svg":"image/svg+xml",".png":"image/png"};
const server = http.createServer((req,res) => {
  const url = new URL(req.url,"http://127.0.0.1");
  const missing = url.pathname.startsWith("/missing/");
  let relative = url.pathname.replace(/^\/(missing\/)?/,"") || "index.html";
  if (relative === "report_index.json" && missing) { res.writeHead(404,{"Content-Type":"application/json"}); return res.end("{}"); }
  const file = path.resolve(preview, relative);
  if (!file.startsWith(path.resolve(preview) + path.sep) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404); return res.end("missing"); }
  res.writeHead(200,{"Content-Type":mime[path.extname(file)]||"application/octet-stream","Cache-Control":"no-store"});
  fs.createReadStream(file).pipe(res);
});

function edgePath() {
  const candidates = [process.env.EDGE_PATH,"C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe","C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe"].filter(Boolean);
  return candidates.find(fs.existsSync);
}

async function main() {
  await new Promise(resolve => server.listen(0,"127.0.0.1",resolve));
  const port = server.address().port;
  const browser = await chromium.launch({headless:true,executablePath:edgePath()});
  const consoleErrors=[];
  const captureErrors = page => { page.on("console",msg => { if(msg.type()==="error" && !/Failed to load resource.*404/i.test(msg.text())) consoleErrors.push(msg.text()); }); page.on("pageerror",error => consoleErrors.push(error.message)); };
  try {
    const context = await browser.newContext({viewport:{width:390,height:844},acceptDownloads:true,serviceWorkers:"block"});
    const page = await context.newPage();
    captureErrors(page);
    await page.goto(`http://127.0.0.1:${port}/index.html#research`);
    await page.waitForSelector(".research-workbook");
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth),true,"blank mobile workbook must not overflow document");
    assert.equal(await page.locator(".rw-state strong").textContent(),"OWNER_DRAFT");
    assert.match(await page.locator(".rw-state").textContent(),/Monitor truth:/);
    assert.equal(await page.locator("#rw-results .rw-empty").isVisible(),true);
    await page.locator('[data-path="document.campaign_id"]').fill("BOSS-TH-01");
    const longLogic = "LONG-LOGIC-PRINT-" + "closed-bar BUY and SELL condition with equality, warmup, shift and finality; ".repeat(45);
    await page.locator('[data-path="identity.hypothesis"]').fill("SYNTHETIC-HYPOTHESIS-UNVERIFIED");
    await page.locator('[data-path="strategy.buy_conditions"]').fill(longLogic);
    await page.locator('[data-add-row="parameters"]').click();
    await page.locator('[data-table="parameters"][data-row="0"][data-key="name"]').fill("EntryPeriod");
    await page.locator('[data-table="parameters"][data-row="0"][data-key="source_default"]').fill("20");
    await page.locator('[data-table="parameters"][data-row="0"][data-key="range_min"]').fill("1");
    await page.locator('[data-table="parameters"][data-row="0"][data-key="range_step"]').fill("1");
    await page.locator('[data-table="parameters"][data-row="0"][data-key="range_max"]').fill("3");
    await page.locator('[data-add-row="optimizer_sets"]').click();
    await page.locator('[data-table="optimizer_sets"][data-row="0"][data-key="name"]').fill("coarse-a");
    await page.locator('[data-table="optimizer_sets"][data-row="0"][data-key="stage"]').fill("WIDE_COARSE");
    await page.locator('[data-table="optimizer_sets"][data-row="0"][data-key="parameters"]').fill("EntryPeriod");
    await page.locator('[data-table="optimizer_sets"][data-row="0"][data-key="method"]').fill("GENETIC");
    await page.locator('[data-add-row="filters_modules"]').click();
    await page.locator('[data-table="filters_modules"][data-row="0"][data-key="name"]').fill("SYNTH-A+B");
    await page.locator('[data-table="filters_modules"][data-row="0"][data-key="study_type"]').fill("INTERACTION");
    await page.locator('[data-table="filters_modules"][data-row="0"][data-key="interaction_components"]').fill("SYNTH-A,SYNTH-B");
    await page.locator('[data-table="filters_modules"][data-row="0"][data-key="comparison_baseline"]').fill("SYNTH-BASE");
    await page.locator('[data-table="filters_modules"][data-row="0"][data-key="readiness"]').fill("UNKNOWN");
    await page.locator('[data-add-row="results"]').click();
    const result = {run_id:"synthetic-run-001",installation_lineage:"SYNTHETIC-LANE",data_identity:"SYNTHETIC-DATA",symbol:"SYNTH",timeframe:"H1",model:"M1_M1_OHLC_RESEARCH",window_role:"MAIN",window_from:"2026-01-01",window_to:"2026-01-31",currency:"USD",source_ref:"fixtures/synthetic.mq5",source_sha256:"a".repeat(64),build_ref:"fixtures/synthetic.ex5",build_sha256:"b".repeat(64),year:"2026",month:"01",net_profit:"60"};
    for (const [key,value] of Object.entries(result)) await page.locator(`[data-table="results"][data-row="0"][data-key="${key}"]`).fill(value);
    await page.locator('[data-table="results"][data-row="0"][data-key="gross_profit"]').fill("120");
    await page.locator('[data-table="results"][data-row="0"][data-key="gross_loss"]').fill("-60");
    await page.locator('[data-table="results"][data-row="0"][data-key="profit_factor"]').fill("2");
    await page.locator('[data-table="results"][data-row="0"][data-key="equity_dd_native"]').fill("8");
    await page.locator("#rw-standard-stages").click();
    assert.equal(await page.locator('[data-table="stage_plan"][data-key="stage"]').count(),14);
    await page.locator('[data-add-row="timeseries"]').click();
    await page.locator('[data-table="timeseries"][data-row="0"][data-key="series_id"]').fill("curve-1");
    await page.locator('[data-table="timeseries"][data-row="0"][data-key="run_id"]').fill("synthetic-run-001");
    await page.locator('[data-table="timeseries"][data-row="0"][data-key="kind"]').fill("equity_native");
    await page.locator('[data-table="timeseries"][data-row="0"][data-key="source_ref"]').fill("fixtures/synthetic-series.json");
    await page.locator('[data-table="timeseries"][data-row="0"][data-key="source_sha256"]').fill("c".repeat(64));
    await page.locator('[data-table="timeseries"][data-row="0"][data-key="timestamp"]').fill("2026-01-01T00:00:00Z");
    await page.locator('[data-table="timeseries"][data-row="0"][data-key="value"]').fill("10000");
    await page.locator('[data-table="timeseries"][data-row="0"][data-key="unit"]').fill("USD");
    await page.locator('[data-add-row="timeseries"]').click();
    for (const [key,value] of Object.entries({series_id:"curve-1",run_id:"synthetic-run-001",kind:"equity_native",source_ref:"fixtures/synthetic-series.json",source_sha256:"c".repeat(64),timestamp:"2026-01-03T00:00:00Z",value:"10050",unit:"USD"})) await page.locator(`[data-table="timeseries"][data-row="1"][data-key="${key}"]`).fill(value);
    await page.locator('[data-add-row="timeseries"]').click();
    for (const [key,value] of Object.entries({series_id:"curve-1",run_id:"synthetic-run-001",kind:"equity_native",source_ref:"fixtures/synthetic-series.json",source_sha256:"c".repeat(64),timestamp:"2026-01-04T00:00:00Z",value:"10020",unit:"USD"})) await page.locator(`[data-table="timeseries"][data-row="2"][data-key="${key}"]`).fill(value);
    await page.locator('[data-add-row="timeseries"]').click();
    for (const [key,value] of Object.entries({series_id:"curve-1",run_id:"synthetic-run-001",kind:"dd_native",source_ref:"fixtures/synthetic-series.json",source_sha256:"c".repeat(64),timestamp:"2026-01-02T00:00:00Z",value:"2",unit:"percent"})) await page.locator(`[data-table="timeseries"][data-row="3"][data-key="${key}"]`).fill(value);
    await page.locator('[data-add-row="published_evidence"]').click();
    await page.locator('[data-table="published_evidence"][data-row="0"][data-key="label"]').fill("LAST-ROW-PRINT-SENTINEL");
    await page.locator('[data-table="published_evidence"][data-row="0"][data-key="report_href"]').fill("fixtures/synthetic-report.html");
    await page.locator('[data-table="published_evidence"][data-row="0"][data-key="evidence_sha256"]').fill("d".repeat(64));
    await page.waitForTimeout(1200);
    assert.equal(await page.evaluate(() => localStorage.getItem("ea_lab.research_workbook.v1.current") !== null),true);
    await page.reload();
    await page.waitForSelector(".research-workbook");
    assert.equal(await page.locator('[data-path="document.campaign_id"]').inputValue(),"BOSS-TH-01");
    await page.locator('[data-table="parameters"][data-row="0"][data-key="range_step"]').fill("");
    await page.waitForTimeout(1000);
    await page.reload();
    await page.waitForSelector(".research-workbook");
    assert.equal(await page.locator('[data-table="parameters"][data-row="0"][data-key="range_step"]').inputValue(),"","in-progress partial range must survive autosave reload");
    await page.locator('[data-table="parameters"][data-row="0"][data-key="range_step"]').fill("1");
    await page.waitForTimeout(800);
    assert.match(await page.locator("#rw-optimizer-estimates").textContent(),/3 prospective Cartesian combinations/);
    assert.equal(await page.locator("#rw-result-group option").count() >= 2,true);
    assert.equal(await page.locator("#rw-series-group option").count() >= 3,true);
    await page.locator("#rw-result-filter").fill("no-such-run");
    assert.equal(await page.locator('[data-workbook-row="results"][hidden]').count(),1);
    await page.locator("#rw-result-filter").fill("synthetic-run-001");
    assert.equal(await page.locator('[data-workbook-row="results"]:not([hidden])').count(),1);
    assert.equal(await page.locator('#rw-graphs svg[aria-label*="proportional UTC time"]').first().isVisible(),true);
    const timePoints = (await page.locator('#rw-graphs svg[aria-label*="proportional UTC time"] polyline').first().getAttribute("points")).split(" ").map(point => Number(point.split(",")[0]));
    assert.equal(Math.round((timePoints[1]-timePoints[0])/(timePoints[2]-timePoints[1])),2,"time axis must use proportional UTC spacing, not row index spacing");
    const focus = page.locator('[data-path="identity.hypothesis"]');
    await focus.focus();
    await context.setOffline(true);
    await context.setOffline(false);
    assert.equal(await focus.inputValue(),"SYNTHETIC-HYPOTHESIS-UNVERIFIED");
    assert.equal(await focus.evaluate(node => document.activeElement === node),true);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth),true);
    const importHitArea = await page.evaluate(() => {
      const input = document.querySelector("#rw-import").getBoundingClientRect();
      const label = document.querySelector("#rw-import").closest(".rw-file").getBoundingClientRect();
      const validate = document.querySelector("#rw-validate").getBoundingClientRect();
      const overlapsValidate = !(input.right <= validate.left || input.left >= validate.right || input.bottom <= validate.top || input.top >= validate.bottom);
      const validateHit = document.elementFromPoint(validate.left + validate.width / 2, validate.top + validate.height / 2);
      const belowLabelHit = document.elementFromPoint(label.left + label.width / 2, label.bottom + 0.5);
      const rect = value => ({left:value.left,top:value.top,right:value.right,bottom:value.bottom,width:value.width,height:value.height});
      return {
        overlapsValidate,
        validateReceivesPointer:Boolean(validateHit?.closest?.("#rw-validate")),
        clippedOutsideLabel:belowLabelHit?.id !== "rw-import",
        input:rect(input),label:rect(label),validate:rect(validate)
      };
    });
    assert.equal(importHitArea.overlapsValidate,false,"file import hit area must never cover Validate");
    assert.equal(importHitArea.validateReceivesPointer,true,JSON.stringify(importHitArea));
    assert.equal(importHitArea.clippedOutsideLabel,true,JSON.stringify(importHitArea));
    await page.locator("#rw-validate").click();
    assert.match(await page.locator("#rw-status").textContent(),/Validation PASS for workbook structure only/);
    await page.locator("#rw-save").click();
    assert.match(await page.locator("#rw-status").textContent(),/Saved/);
    await page.screenshot({path:path.join(screenshots,"research-workbook-mobile-390x844.png"),fullPage:true});

    const downloadPromise = page.waitForEvent("download");
    await page.locator("#rw-download").click();
    const download = await downloadPromise;
    const saved = path.join(evidence,"downloaded-owner-workbook.json");
    await download.saveAs(saved);
    const exported = JSON.parse(fs.readFileSync(saved,"utf8"));
    assert.equal(exported.document.campaign_id,"BOSS-TH-01");
    assert.equal(typeof exported.document.campaign_id,"string");
    assert.equal(typeof exported.results[0].gross_profit,"number");
    assert.equal(exported.parameters[0].range_step,1);
    assert.equal(exported.results[0].verification_state,"OWNER_ENTERED_UNVERIFIED");

    const invalidImport = path.join(evidence,"invalid-duplicate-import.json");
    fs.writeFileSync(invalidImport,'{"schema_version":"EA_LAB_RESEARCH_WORKBOOK_V1","schema_version":"FORGED"}',"utf8");
    await page.locator("#rw-import").setInputFiles(invalidImport);
    assert.match(await page.locator("#rw-status").textContent(),/current draft preserved/);
    assert.equal(await page.locator('[data-path="document.campaign_id"]').inputValue(),"BOSS-TH-01");

    await page.locator("#rw-revision").click();
    assert.match(await page.locator("#rw-status").textContent(),/previous draft preserved locally/);
    assert.equal(await page.evaluate(() => Object.keys(localStorage).some(key => key.startsWith("ea_lab.research_workbook.v1.history."))),true);

    const printText = await page.locator(".rw-print-projection").textContent();
    assert.match(printText,/LONG-LOGIC-PRINT/);
    assert.match(printText,/LAST-ROW-PRINT-SENTINEL/);
    assert.match(printText,/Optimizer-set plans/);
    assert.match(printText,/Typed time series/);
    assert.match(printText,/Observations, interpretations, decisions and limits/);
    await page.emulateMedia({media:"print"});
    assert.equal(await page.locator(".rw-print-projection").isVisible(),true);
    assert.equal(await page.evaluate(() => { const p=document.querySelector(".rw-print-projection"); return p.scrollWidth <= p.clientWidth && getComputedStyle(p).display !== "none"; }),true);
    assert.equal(await page.locator('[data-print-end="true"]').isVisible(),true);
    await page.emulateMedia({media:"screen"});
    await page.evaluate(() => { window.__printed=false; window.print=()=>{window.__printed=true;}; });
    await page.locator("#rw-print").click();
    assert.equal(await page.evaluate(() => window.__printed),true);
    await context.close();

    const desktop = await browser.newContext({viewport:{width:1280,height:900},serviceWorkers:"block"});
    const desktopPage = await desktop.newPage();
    captureErrors(desktopPage);
    await desktopPage.goto(`http://127.0.0.1:${port}/index.html#research`);
    await desktopPage.waitForSelector(".research-workbook");
    await desktopPage.locator("#rw-import").setInputFiles(saved);
    await desktopPage.waitForSelector('[data-table="results"][data-row="0"]');
    assert.equal(await desktopPage.evaluate(() => document.documentElement.scrollWidth <= document.documentElement.clientWidth),true);
    await desktopPage.screenshot({path:path.join(screenshots,"research-workbook-desktop-1280x900.png"),fullPage:true});
    await desktop.close();

    const missing = await browser.newContext({viewport:{width:390,height:844},serviceWorkers:"block"});
    const missingPage = await missing.newPage();
    captureErrors(missingPage);
    await missingPage.goto(`http://127.0.0.1:${port}/missing/index.html`);
    await missingPage.waitForSelector('a[href="#research"]');
    await missingPage.click('a[href="#research"]');
    await missingPage.waitForSelector(".research-workbook");
    assert.match(await missingPage.locator(".rw-state").textContent(),/Monitor truth: UNKNOWN/);
    await missingPage.screenshot({path:path.join(screenshots,"research-workbook-missing-index.png"),fullPage:true});
    await missing.close();

    const race = await browser.newContext({viewport:{width:390,height:844},serviceWorkers:"block"});
    const racePage = await race.newPage();
    captureErrors(racePage);
    await racePage.route("**/research_workbook.template.json", async route => { await new Promise(resolve => setTimeout(resolve,500)); await route.continue(); });
    await racePage.goto(`http://127.0.0.1:${port}/index.html#research`);
    await racePage.waitForSelector("text=Loading local owner workbook");
    await racePage.evaluate(() => { location.hash="home"; });
    await racePage.waitForTimeout(800);
    assert.equal(await racePage.locator(".research-workbook").count(),0,"late template load must not overwrite a newer route");
    assert.equal(await racePage.locator("h2",{hasText:"Overview"}).count() + await racePage.locator("text=Monitoring unavailable").count() > 0,true);
    await race.close();

    const corrupt = await browser.newContext({viewport:{width:390,height:844},serviceWorkers:"block"});
    await corrupt.addInitScript(() => localStorage.setItem("ea_lab.research_workbook.v1.current",'{"schema_version":'));
    const corruptPage = await corrupt.newPage();
    captureErrors(corruptPage);
    await corruptPage.goto(`http://127.0.0.1:${port}/index.html#research`);
    await corruptPage.waitForSelector(".research-workbook");
    await corruptPage.locator('[data-path="document.campaign_id"]').fill("MEMORY-WITH-CORRUPT-STORAGE");
    await corruptPage.waitForTimeout(1000);
    assert.match(await corruptPage.locator("#rw-status").textContent(),/CORRUPT_PRESERVED/);
    assert.equal(await corruptPage.evaluate(() => localStorage.getItem("ea_lab.research_workbook.v1.current")),'{"schema_version":');
    assert.equal(await corruptPage.locator('[data-path="document.campaign_id"]').inputValue(),"MEMORY-WITH-CORRUPT-STORAGE");
    await corrupt.close();

    const denied = await browser.newContext({viewport:{width:390,height:844},serviceWorkers:"block"});
    await denied.addInitScript(() => { const original=Storage.prototype.setItem; Storage.prototype.setItem=function(){ throw new DOMException("denied","SecurityError"); }; window.__originalStorageSet=original; });
    const deniedPage = await denied.newPage();
    captureErrors(deniedPage);
    await deniedPage.goto(`http://127.0.0.1:${port}/index.html#research`);
    await deniedPage.waitForSelector(".research-workbook");
    await deniedPage.locator('[data-path="document.campaign_id"]').fill("IN-MEMORY");
    await deniedPage.waitForTimeout(1000);
    assert.match(await deniedPage.locator("#rw-status").textContent(),/denied/i);
    assert.equal(await deniedPage.locator('[data-path="document.campaign_id"]').inputValue(),"IN-MEMORY");
    await denied.close();

    assert.deepEqual(consoleErrors,[]);
    process.stdout.write(JSON.stringify({status:"PASS",screenshots:fs.readdirSync(screenshots).sort()},null,2)+"\n");
  } finally { await browser.close(); server.close(); }
}

main().catch(error => { console.error(error); server.close(); process.exitCode=1; });
