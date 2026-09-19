"use strict";
const fs=require("node:fs");
const crypto=require("node:crypto");
const path=require("node:path");
const repo=path.resolve(__dirname,"..","..");
const rw=require(path.join(repo,"mobile_report_hub","research_workbook.js"));
const p=path.resolve(process.argv[2]||"");
try{
  const raw=fs.readFileSync(p,"utf8");
  const book=rw.parseImport(raw);
  const out={
    status:"PASS",
    schema_version:book.schema_version,
    revision_id:book.document?.revision_id||null,
    workbook_sha256:crypto.createHash("sha256").update(Buffer.from(raw,"utf8")).digest("hex"),
    validator:"mobile_report_hub/research_workbook.js",
    authority:"STRUCTURAL_VALIDATION_ONLY_NO_EXECUTION_AUTHORITY"
  };
  process.stdout.write(JSON.stringify(out)+"\n");
}catch(e){
  process.stdout.write(JSON.stringify({status:"BLOCKED",reason:String(e.message||e)})+"\n");
  process.exitCode=2;
}
