'use strict';
const assert=require('node:assert/strict'),b=require('./builder_workflow.js');
let checks=0;const check=(fn)=>{fn();checks++;};
const d=b.newDraft();
check(()=>assert.deepEqual(b.parse(b.encode(d)),d));
check(()=>assert.equal(b.CATALOG.population,null));
check(()=>assert.equal(b.validate(d).can_execute,false));
for(const intent of b.INTENTS)check(()=>{const x={...d,intent};assert.equal(b.parse(b.encode(x)).intent,intent);});
const p=b.newPlan();p.name='OFF <img src=x onerror=alert(1)>';d.plans.push(p);
check(()=>assert.equal(b.validate(d).draft_valid,true));
check(()=>assert.deepEqual(b.parse(b.encode(d)),d));
check(()=>{const copy=b.duplicate(p);assert.notEqual(copy.id,p.id);assert.notEqual(copy.revision,p.revision);assert.equal(copy.enabled,false);assert.equal(copy.authority,'OFF_DRAFT_UNVERIFIED');assert.equal(copy.name,p.name);});
for(const key of Object.keys(d.bindings))check(()=>{d.bindings[key]={id:key,revision:'r1'};assert.deepEqual(b.parse(b.encode(d)).bindings[key],d.bindings[key]);});
const bad=[raw=>raw.replace('"schema":','"schema":"duplicate","schema":'),raw=>raw.replace('"title":','"__proto__":{},"title":'),raw=>raw.replace('"enabled": false','"enabled": true'),raw=>raw.replace('LOCAL_DRAFT_UNVERIFIED','APPROVED'),raw=>raw.replace('"pass_budget": ""','"pass_budget": 1e999'),raw=>raw.replace('"plans": [','"approved":true,"plans": [')];
for(const mutate of bad)check(()=>assert.throws(()=>b.parse(mutate(b.encode(d)))));
check(()=>{const copy=structuredClone(d);copy.plans.push({...p});assert.throws(()=>b.encode(copy));});
check(()=>assert.throws(()=>b.parse(' '.repeat(b.MAX+1))));
check(()=>assert.throws(()=>b.parse('['.repeat(40)+'0'+']'.repeat(40))));
check(()=>assert.throws(()=>b.parse(b.encode(d)+'garbage')));
check(()=>assert.equal(b.validate(d).compatibility,'UNKNOWN'));
check(()=>assert.deepEqual(b.CATALOG.fields,[]));
check(()=>assert.ok(b.MT5UX_SIMPLE_NAMES.length>=15&&b.MT5UX_SIMPLE_NAMES.length<=25));
check(()=>assert.equal(new Set(b.MT5UX_SIMPLE_NAMES).size,b.MT5UX_SIMPLE_NAMES.length));
for(const name of ['_41_FixedLot','_42_RiskPct','_9_MaxLevels','_22_DisplacementBodyFraction','_22_WickBodyRatio'])check(()=>assert.ok(b.MT5UX_SIMPLE_NAMES.includes(name)));
const refused={schema:b.CATALOG.schema,status:'UNRESOLVED',profile_approval:'UNRESOLVED',compatibility:'UNKNOWN',can_submit:false,can_execute:false,population:null,wrappers:[],blockers:['CATALOG_ENUM_UNKNOWN_SYMBOL']};
check(()=>{const c=b.catalogView(refused);assert.deepEqual(c.blockers,refused.blockers);assert.equal(c.status,'UNRESOLVED');assert.equal(c.can_submit,false);assert.equal(c.can_execute,false);assert.equal(c.compatibility,'UNKNOWN');assert.equal(c.population,null);assert.ok(Object.isFrozen(c.blockers));});
for(const mutate of [x=>x.can_submit=true,x=>x.population=0,x=>x.blockers=['<img onerror=alert(1)>'],x=>x.blockers=[]])check(()=>{const x=structuredClone(refused);mutate(x);assert.equal(b.catalogView(x),b.CATALOG);});
if(process.env.BUILDER_CATALOG_PROJECTION){const fs=require('node:fs');const c=JSON.parse(fs.readFileSync(process.env.BUILDER_CATALOG_PROJECTION,'utf8'));
 check(()=>assert.equal(b.catalogView(c).status,'AUDIT_METADATA_VERIFIED'));
 check(()=>assert.deepEqual(c.wrappers.map(w=>[w.build,w.population]),[['B17',159],['B22',153]]));
 for(const mutate of [x=>x.can_submit=true,x=>x.profile_approval='APPROVED',x=>x.wrappers[0].fields[0].editable=true,x=>x.wrappers[0].fields.push(x.wrappers[0].fields[0]),x=>x.wrappers[0].population=0])check(()=>{const x=structuredClone(c);mutate(x);assert.equal(b.catalogView(x).status,'UNRESOLVED');});
 check(()=>{const x=structuredClone(d);x.catalog=c;assert.throws(()=>b.encode(x));});
}
if(process.env.BUILDER_PROFILE_PROJECTION){
 const fs=require('node:fs'),v=JSON.parse(fs.readFileSync(process.env.BUILDER_PROFILE_PROJECTION,'utf8')),c=JSON.parse(fs.readFileSync(process.env.BUILDER_CATALOG_PROJECTION,'utf8'));
 check(()=>assert.equal(b.decisionView(v,b.catalogView(c)).status,'PINNED_PROPOSAL_METADATA'));
 const q=b.newProfile(v),row=n=>v.rows.find(r=>r.name===n),slot=(p,n)=>[...p.shared_values,...p.entry_values,...p.instance_values].find(r=>r.name===n),set=(p,n,value)=>{const s=slot(p,n);s.value=value;s.response=value===null?'UNANSWERED':'VALUE_PROPOSED';};
 check(()=>assert.equal(q.shared_values.length,150));check(()=>assert.equal(q.entry_values.length,2));check(()=>assert.equal(q.instance_values.length,1));check(()=>assert.ok(q.shared_values.every(s=>s.value===null)));check(()=>assert.equal(b.validateProfile(q,v).type_valid,true));check(()=>assert.equal(b.validateProfile(q,v).decision_complete,false));
 check(()=>assert.deepEqual(b.parseProfile(b.encodeProfile(q,v),v),q));
 check(()=>assert.throws(()=>b.parseProfile(' '.repeat(b.MAX)+b.encodeProfile(q,v),v)));
 for(const mutate of [x=>x.scope='GLOBAL_DEFAULT',x=>x.authority='OWNER_APPROVED',x=>x.pins.decision_sha256='0'.repeat(64),x=>x.shared_values.push(x.shared_values[0]),x=>x.shared_values[0].name='UnknownField',x=>x.can_execute=true])check(()=>{const x=structuredClone(q);mutate(x);assert.throws(()=>b.validateProfile(x,v));});
 const en=row('FirstLotMode');check(()=>assert.throws(()=>b.valueCheck(en,'PROG_PLUS')));check(()=>assert.throws(()=>b.valueCheck(en,'41')));check(()=>assert.equal(b.valueCheck(en,'FIRSTLOT_FIXED').representation,'FIRSTLOT_FIXED'));
 const bool=v.rows.find(r=>r.type==='bool');for(const value of ['true','false'])check(()=>assert.equal(b.valueCheck(bool,value).representation,value));for(const value of [false,0,'0'])check(()=>assert.throws(()=>b.valueCheck(bool,value)));
 const integer=v.rows.find(r=>r.type==='int'),long=v.rows.find(r=>r.type==='long');for(const value of ['0','-0','2147483647'])check(()=>assert.doesNotThrow(()=>b.valueCheck(integer,value)));for(const value of ['1.5','1e3','2147483648','NaN'])check(()=>assert.throws(()=>b.valueCheck(integer,value)));
 check(()=>assert.equal(b.valueCheck(long,'9007199254740993').representation,'9007199254740993'));check(()=>assert.throws(()=>b.valueCheck(long,'9223372036854775808')));
 const double=v.rows.find(r=>r.type==='double'&&r.scope==='SHARED');for(const value of ['0','0.01','1e-2'])check(()=>assert.doesNotThrow(()=>b.valueCheck(double,value)));for(const value of ['NaN','Infinity','1e999','true',''])check(()=>assert.throws(()=>b.valueCheck(double,value)));
 check(()=>assert.throws(()=>b.valueCheck(row('_22_DisplacementBodyFraction'),'0')));check(()=>assert.throws(()=>b.valueCheck(row('_22_DisplacementBodyFraction'),'1.01')));check(()=>assert.doesNotThrow(()=>b.valueCheck(row('_22_DisplacementBodyFraction'),'0.65')));
 set(q,'FirstLotMode','FIRSTLOT_FIXED');set(q,'LotProg','PROG_PLUS');set(q,'_53_PlusLot','0.01');set(q,'_41_FixedLot','0.01');set(q,'_9_MaxLevels','20');set(q,bool.name,'false');set(q,integer.name,'0');
 check(()=>assert.equal(b.requiredness(row('_42_RiskPct'),q,v),'EXCLUDED_BY_PROPOSED_BRANCH'));check(()=>assert.equal(b.requiredness(row('_53_PlusLot'),q,v),'REQUIRED_BY_PROPOSED_BRANCH'));
 set(q,'FirstLotMode','FIRSTLOT_RISK');check(()=>assert.equal(b.requiredness(row('_42_RiskPct'),q,v),'REQUIRED_BY_PROPOSED_BRANCH'));set(q,'FirstLotMode','FIRSTLOT_FIXED');
 check(()=>assert.deepEqual(b.parseProfile(b.encodeProfile(q,v),v),q));check(()=>assert.equal(slot(q,bool.name).value,'false'));check(()=>assert.equal(slot(q,integer.name).value,'0'));
 check(()=>assert.ok(b.validateProfile(b.newProfile(v),v).missing.some(x=>x.includes('RC_MaxLot'))));check(()=>assert.ok(b.validateProfile(b.newProfile(v),v).missing.some(x=>x.includes('RC_MaxLevelsOverride'))));
 const hist=b.revisionStore([],q,v);check(()=>assert.equal(hist.length,1));check(()=>assert.equal(b.revisionStore(hist,q,v).length,1));check(()=>{const x=structuredClone(q);x.notes='collision';assert.throws(()=>b.revisionStore(hist,x,v));});check(()=>assert.deepEqual(hist[0],q));
 for(const raw of [b.encodeProfile(q,v).replace('"title":','"title":"duplicate","title":'),b.encodeProfile(q,v).replace('"title":','"__proto__":{},"title":'),'['.repeat(40)+'0'+']'.repeat(40),' '.repeat(1048577)])check(()=>assert.throws(()=>b.parseProfile(raw,v)));
 const bd=b.newDraft();bd.plans.push(b.newPlan());check(()=>assert.throws(()=>b.makeRequest(q,bd,v,false,true)));check(()=>assert.throws(()=>b.makeRequest(q,bd,v,true,false)));const request=b.makeRequest(q,bd,v,true,true);
 check(()=>assert.equal(request.status,'NOT_SUBMITTED'));check(()=>assert.equal(request.intent,'PENDING_DECISIONS'));check(()=>assert.equal(request.owner_attestation,false));check(()=>assert.equal(request.can_execute,false));check(()=>assert.equal(request.builder_draft.plans[0].enabled,false));check(()=>assert.deepEqual(b.parseProfile(JSON.stringify(request),v).profile,q));
 check(()=>{const x=structuredClone(request);x.validation={profile_approval:'APPROVED'};const imported=b.parseProfile(JSON.stringify(x),v);assert.equal(b.validateProfile(imported.profile,v).profile_approval,'UNRESOLVED');});
 check(()=>{const x=structuredClone(request);x.can_submit=true;assert.throws(()=>b.parseProfile(JSON.stringify(x),v));});check(()=>{const x=structuredClone(v);x.rows[0].type='UNKNOWN';assert.equal(b.decisionView(x,c),null);});

 const fixed=row('_41_FixedLot');
 for(const value of ['0','-0','0.00','-0.000e99','0e9999','0.01','0.0100','1e-2','10e-3','1E+0003','9007199254740992','5e-324','1e-323','1.7976931348623157e308'])check(()=>assert.doesNotThrow(()=>b.valueCheck(fixed,value)));
 check(()=>assert.equal(b.valueCheck(fixed,'-0.00e99').representation,'-0'));
 for(const value of ['1e-400','-1e-400','2e-324','0.'+'0'.repeat(399)+'1','9007199254740993','0.10000000000000001','1.0000000000000001','1e999','-1e999','1.7976931348623159e308'])check(()=>assert.throws(()=>b.valueCheck(fixed,value),/underflows|loses precision|finite double/));
 for(const value of [false,0,undefined,'+1','00','0x10','1.',' .1','NaN'])check(()=>assert.throws(()=>b.valueCheck(fixed,value)));
 check(()=>assert.deepEqual(b.valueCheck(fixed,null),{status:'UNRESOLVED',representation:null}));
 for(const value of ['0','-0','1e-400','1.01'])check(()=>assert.throws(()=>b.valueCheck(row('_22_DisplacementBodyFraction'),value)));
 for(const value of ['1e-400','9007199254740993','0.10000000000000001'])check(()=>{const x=structuredClone(q);set(x,'_41_FixedLot',value);assert.equal(b.validateProfile(x,v).type_valid,false);assert.throws(()=>b.encodeProfile(x,v));assert.throws(()=>b.makeRequest(x,b.newDraft(),v,true,true));assert.throws(()=>b.parseProfile(JSON.stringify(x),v));});
 const saved=b.revisionStore([],q,v),collision=structuredClone(q);collision.notes='conflicting saved bytes';
 check(()=>assert.deepEqual(b.restoreProfileCache(JSON.stringify({working:q,history:saved}),v),{working:q,history:saved,readOnly:true}));
 check(()=>assert.throws(()=>b.restoreProfileCache(JSON.stringify({working:collision,history:saved}),v),/content conflict/));
 check(()=>{try{b.restoreProfileCache(JSON.stringify({working:collision,history:saved}),v);assert.fail('collision not refused');}catch(e){assert.deepEqual(e.saved_history,saved);}});
 check(()=>assert.throws(()=>b.restoreProfileCache(JSON.stringify({working:q,history:[q,q]}),v),/Duplicate saved/));
 check(()=>assert.throws(()=>b.restoreProfileCache(JSON.stringify({working:q,history:[q,collision]}),v),/content conflict/));
 for(const fn of [()=>b.encodeProfile(collision,v,saved),()=>b.reviewSummary(collision,v,saved),()=>b.makeRequest(collision,b.newDraft(),v,true,true,saved),()=>b.parseProfile(JSON.stringify(collision),v,saved),()=>b.parseProfile(JSON.stringify({...b.makeRequest(q,b.newDraft(),v,true,true),profile:collision}),v,saved)])check(()=>assert.throws(fn,/content conflict/));
 check(()=>assert.deepEqual(b.parseProfile(b.encodeProfile(q,v),v,saved),q));
 check(()=>assert.deepEqual(saved,[q]));
 const fork=structuredClone(collision);fork.parent_revision=fork.revision;fork.revision+='-fork';check(()=>assert.equal(b.revisionStore(saved,fork,v).length,2));
 const unsaved=structuredClone(collision);unsaved.profile_id+='-new';check(()=>assert.equal(b.restoreProfileCache(JSON.stringify({working:unsaved,history:saved}),v).readOnly,false));


 check(()=>assert.deepEqual(b.mobileSteps(v).slice(2,12).map(s=>s.id),v.groups.map(g=>g.id)));
 check(()=>{const original=b.newDraft();original.bindings.default_profile={id:q.profile_id,revision:q.revision};const before=JSON.stringify({q,original,saved});const next=b.reviseMobile(q,original,v,saved);assert.equal(JSON.stringify({q,original,saved}),before);assert.equal(next.profile.parent_revision,q.revision);assert.notEqual(next.profile.revision,q.revision);assert.equal(next.builder.parent_revision,original.revision);assert.notEqual(next.builder.revision,original.revision);assert.deepEqual(next.builder.bindings.default_profile,{id:'',revision:''});assert.deepEqual(next.history,saved);assert.equal(b.makeRequest(next.profile,next.builder,v,true,true,next.history).status,'NOT_SUBMITTED');});
 check(()=>assert.throws(()=>b.reviseMobile(collision,b.newDraft(),v,saved),/content conflict/));
 check(()=>{const x=structuredClone(q);set(x,'_41_FixedLot','1e-400');assert.throws(()=>b.reviseMobile(x,b.newDraft(),v,[]));});

 // Repair4: imported originals are captured before a child is editable.
 for(const doc of [q,b.makeRequest(q,b.newDraft(),v,true,true,[])]){
  check(()=>{const raw=JSON.stringify(doc,null,2),copy=b.prepareMobileImport(raw,v,[]),p=doc.profile||doc,original=JSON.stringify(p);assert.equal(copy.raw,raw);assert.deepEqual(copy.history,[p]);copy.profile.notes='attempted working edit';assert.equal(JSON.stringify(copy.history[0]),original);assert.equal(JSON.stringify(copy.original.profile||copy.original),original);const child=b.reviseMobile(copy.history[0],copy.builder||b.newDraft(),v,copy.history);assert.equal(child.profile.parent_revision,p.revision);assert.notEqual(child.profile.revision,p.revision);assert.deepEqual(b.parseProfile(raw,v,child.history),doc);});
 }
 check(()=>{const bd=b.newDraft();bd.title='review EA';bd.bindings.entry_contract={id:'entry-marker',revision:'entry-r1'};const m=b.mobileReviewModel(q,bd,v,saved);assert.equal(m.ea,bd.title);assert.equal(m.builder_bindings.entry_contract.id,'entry-marker');assert.deepEqual(m.summary,b.reviewSummary(q,v,saved));assert.ok(m.issues.length>0);assert.equal(m.summary.revision,q.revision);});
 check(()=>{const row=v.rows.find(r=>r.scope==='SHARED');assert.equal(b.reviewTarget(row.name+': missing',q,v).step,row.group);assert.equal(b.reviewTarget('Group '+v.groups[0].id+': no response',q,v).step,v.groups[0].id);assert.equal(b.reviewTarget('unmapped global: refused',q,v),null);});
 check(()=>assert.throws(()=>b.prepareMobileImport('{"schema":1,"schema":2}',v,[]),/Duplicate|duplicate/));
 check(()=>{const bad=structuredClone(q);bad.pins.decision_sha256='0'.repeat(64);assert.throws(()=>b.prepareMobileImport(JSON.stringify(bad),v,[]),/pins/);});
 console.log(JSON.stringify({profile_checks:checks,known_valid_proposal:true,request_status:request.status}));
}

console.log(JSON.stringify({result:'PASS',checks}));
