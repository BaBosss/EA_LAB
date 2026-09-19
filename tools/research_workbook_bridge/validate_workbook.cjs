"use strict";
const fs=require("node:fs");
const path=require("node:path");
const crypto=require("node:crypto");
const cp=require("node:child_process");
const {Module}=require("node:module");

const repo=path.resolve(process.argv[2]||"");
const ref=String(process.argv[3]||"");
const sha256=raw=>crypto.createHash("sha256").update(raw).digest("hex");

try{
  if(!/^[0-9a-f]{40}$/.test(ref)) throw new Error("ref must be lowercase 40-hex");
  const payload=fs.readFileSync(0);
  const validatorBytes=cp.execFileSync("git",["-C",repo,"show",ref+":mobile_report_hub/research_workbook.js"],{maxBuffer:8*1024*1024});
  const mod=new Module("canonical-workbook-validator",module);
  mod.filename="canonical-workbook-validator.cjs";
  mod.paths=Module._nodeModulePaths(repo);
  mod._compile(validatorBytes.toString("utf8"),mod.filename);
  const rw=mod.exports;
  if(!rw || typeof rw.parseImport!=="function") throw new Error("canonical validator export missing parseImport");
  const book=rw.parseImport(payload.toString("utf8"));
  process.stdout.write(JSON.stringify({
    status:"PASS",
    schema_version:book.schema_version,
    revision_id:book.document?.revision_id||null,
    workbook_sha256:sha256(payload),
    validator_sha256:sha256(validatorBytes),
    validator_ref:ref,
    validator:"git:"+ref+":mobile_report_hub/research_workbook.js",
    authority:"STRUCTURAL_VALIDATION_ONLY_NO_EXECUTION_AUTHORITY"
  })+"\n");
}catch(e){
  process.stdout.write(JSON.stringify({status:"BLOCKED",reason:String(e.message||e)})+"\n");
  process.exitCode=2;
}
