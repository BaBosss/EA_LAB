"use strict";
const assert=require('node:assert/strict'),fs=require('node:fs'),vm=require('node:vm'),crypto=require('node:crypto');
const window={crypto:crypto.webcrypto}; vm.runInNewContext(fs.readFileSync('mobile_report_hub/knowledge_reader.js','utf8'),{window,URL,console,navigator:{},TextEncoder,Uint8Array},{filename:'knowledge_reader.js'});
const r=window.EALabKnowledgeReader,authority='READ_ONLY_RESEARCH_NAVIGATION_NO_RUNTIME_OR_STRATEGY_AUTHORITY';
function stable(v){if(Array.isArray(v))return '['+v.map(stable).join(',')+']';if(v&&typeof v==='object')return '{'+Object.keys(v).sort().map(k=>JSON.stringify(k)+':'+stable(v[k])).join(',')+'}';return JSON.stringify(v);}
const base={id:'RC-1',portable_id:'git::RC-1',title:'EA risk ความเสี่ยง',body:'Order Flow not Seafood',topics:['Risk'],source_ids:['SRC-ONE'],line_refs:[],authority_class:'REGISTERED_RESEARCH',document_type:'RESEARCH_CARD',sha256:'a'.repeat(64),path:'knowledge/02_research_cards/RC-1.md'};
const data={schema_version:'ea-lab-second-brain-reader/1',authority,canonical:{sha:'b'.repeat(40),ref:'b'.repeat(40)},registry:[],health:{problems:[],canonical_documents:2,draft_documents:0,source_notes:0,research_cards:1,registry_records:0,missing_or_unsafe_link_count:0,registry_binding_problem_count:0},documents:[base,{...base,id:'NEG',portable_id:'git::NEG',title:'EA risk negative',body:'EA risk failed',document_type:'NEGATIVE_KNOWLEDGE',path:'knowledge/90_negative_knowledge/risk.md'}]};
const binding={schema_version:'ea-lab-knowledge-binding/1',canonical_sha:'b'.repeat(40),data_sha256:crypto.createHash('sha256').update(stable(data)).digest('hex')};
(async()=>{
assert.equal(r.matches(base,'EA','','ALL'),true);assert.equal(r.matches({...base,title:'Seafood',body:'Seafood',topics:[],source_ids:[]},'EA','','ALL'),false);
assert.equal(r.matches(base,'ความเสี่ยง','','ALL'),true);assert.equal(r.matches(base,'ไม่พบ','','ALL'),false);
for(const u of ['javascript:alert(1)','file:///secret','\\\\server\\share','data:text/html,secret'])assert.equal(r.safeHttp(u),null);
assert.throws(()=>r.validate(data),/binding missing/);assert.throws(()=>r.packet(data,'EA',data.documents,{}),/Unverified/);
await r.verifyIndex(data,binding);const pkt=r.packet(data,'EA risk',data.documents,{});
assert.equal(pkt.negative_memory.status,'MATCH');assert.equal(pkt.problem_intake.symbol,null);assert.equal(pkt.test_verdict,null);assert.ok(pkt.matches.every(x=>Array.isArray(x.line_refs)));
assert.throws(()=>r.packet(data,' ',data.documents,{}),/คำถาม/);
assert.throws(()=>r.packet(data,'EA',[{...base}],{}),/verified index/);
assert.throws(()=>r.validate({...data,authority:'FORGED'},binding),/authority/);
assert.throws(()=>r.validate({...data,documents:[{...base,path:'C:/browser/profile/token.txt'},data.documents[1]]},binding),/Unsafe/);
const forged=JSON.parse(JSON.stringify(data));forged.documents[0].body='RAW_PRIVATE_COMMENT';await assert.rejects(r.verifyIndex(forged,binding),/hash mismatch/);
assert.throws(()=>r.validate({...data,canonical:{sha:'c'.repeat(40),ref:'c'.repeat(40)}},binding),/pin mismatch/);
assert.throws(()=>r.validate({...data,health:{...data.health,draft_documents:4}},binding),/mismatch/);
assert.throws(()=>r.validate({...data,documents:[base,base]},binding),/Duplicate/);
data.documents[0].body='mutation';assert.throws(()=>r.packet(data,'EA',data.documents,{}),/modified/);
process.stdout.write('Knowledge reader focused assertions including SBR001 and SBR005 PASS\n');
})().catch(e=>{console.error(e);process.exitCode=1});
