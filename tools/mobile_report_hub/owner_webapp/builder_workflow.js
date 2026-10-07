(function(root,factory){'use strict';const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.EALabBuilder=api;})(typeof window==='object'?window:null,function(){
'use strict';
const SCHEMA='EA_LAB_BUILDER_DRAFT_V1',KEY='ea_lab.builder.m1.draft',MAX=524288;
const INTENTS=['BUILD_ONLY','BUILD_AND_BASELINE','BUILD_BASELINE_AND_OPTIMIZE'];
const CATALOG=Object.freeze({schema:'EA_LAB_BUILDER_CATALOG_V1',status:'UNRESOLVED',template_release:null,catalog_revision:null,catalog_sha256:null,wrapper_id:null,population:null,fields:Object.freeze([]),qualified_tools:Object.freeze([]),blockers:Object.freeze(['AUDITED_CATALOG_NOT_BOUND'])});
const id=()=>typeof crypto==='object'&&crypto.randomUUID?crypto.randomUUID():Date.now().toString(36)+'-'+Math.random().toString(36).slice(2);
const binding=()=>({id:'',revision:''});
const newDraft=()=>({schema:SCHEMA,authority:'LOCAL_DRAFT_UNVERIFIED',revision:id(),parent_revision:null,title:'',notes:'',intent:'BUILD_ONLY',entry_mode:'ENTRY_ONLY',bindings:{template_release:binding(),default_profile:binding(),entry_contract:binding(),test_plan:binding()},plans:[]});
const newPlan=()=>({id:id(),revision:id(),name:'',enabled:false,authority:'OFF_DRAFT_UNVERIFIED',method:'',scope:'',validation:'',pass_budget:'',time_budget:'',resource_budget:'',notes:''});
function exact(o,keys){if(!o||typeof o!=='object'||Array.isArray(o)||Object.keys(o).sort().join('|')!==keys.slice().sort().join('|'))throw Error('Unexpected or missing fields');}
function text(v){if(typeof v!=='string'||v.length>20000)throw Error('Invalid text field');}
function validate(d){
 exact(d,['schema','authority','revision','parent_revision','title','notes','intent','entry_mode','bindings','plans']);
 if(d.schema!==SCHEMA||d.authority!=='LOCAL_DRAFT_UNVERIFIED'||d.entry_mode!=='ENTRY_ONLY'||!INTENTS.includes(d.intent))throw Error('Unsupported schema, intent or authority');
 for(const k of ['revision','title','notes'])text(d[k]);if(!d.revision)throw Error('Missing revision');if(d.parent_revision!==null)text(d.parent_revision);
 exact(d.bindings,['template_release','default_profile','entry_contract','test_plan']);
 for(const b of Object.values(d.bindings)){exact(b,['id','revision']);text(b.id);text(b.revision);}
 if(!Array.isArray(d.plans)||d.plans.length>100)throw Error('Invalid plans');const seen=new Set();
 for(const p of d.plans){exact(p,['id','revision','name','enabled','authority','method','scope','validation','pass_budget','time_budget','resource_budget','notes']);if(p.enabled!==false||p.authority!=='OFF_DRAFT_UNVERIFIED')throw Error('M1 accepts OFF drafts only');for(const [k,v]of Object.entries(p))if(!['enabled'].includes(k))text(v);if(!p.id||!p.revision||seen.has(p.id))throw Error('Duplicate or missing plan identity');seen.add(p.id);}
 if(new TextEncoder().encode(JSON.stringify(d,null,2)).length>MAX)throw Error('Draft exceeds roundtrip size limit');
 return {draft_valid:true,catalog_status:'UNRESOLVED',input_population:'UNKNOWN',compatibility:'UNKNOWN',can_submit:false,can_execute:false,blockers:['AUDITED_CATALOG_NOT_BOUND','PROFILE_APPROVAL_NOT_BOUND','M1_DRAFT_ONLY']};
}
// Parse JSON structurally before JSON.parse so duplicate object keys cannot disappear.
function parseDocument(raw,validator=validate,limit=MAX){if(typeof raw!=='string'||new TextEncoder().encode(raw).length>limit)throw Error('Import too large');let i=0;
 const ws=()=>{while(/\s/.test(raw[i]||'')&&i<raw.length)i++;};
 function string(){const start=i++;while(i<raw.length){const c=raw[i++];if(c==='\\'){i++;continue;}if(c==='"')return JSON.parse(raw.slice(start,i));}throw Error('Unterminated string');}
 function value(depth){if(depth>32)throw Error('Import nesting too deep');ws();const c=raw[i];if(c==='"'){string();return;}if(c==='{'||c==='['){i++;ws();const end=c==='{'?'}':']',keys=new Set();if(raw[i]===end){i++;return;}while(true){if(c==='{'){ws();if(raw[i]!=='"')throw Error('Invalid object key');const k=string();if(keys.has(k)||['__proto__','prototype','constructor'].includes(k))throw Error('Duplicate or unsafe key');keys.add(k);ws();if(raw[i++]!==':')throw Error('Missing colon');}value(depth+1);ws();if(raw[i]===end){i++;return;}if(raw[i++]!==',')throw Error('Invalid separator');}}const m=/^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/.exec(raw.slice(i));if(!m)throw Error('Invalid JSON value');i+=m[0].length;}
 value(0);ws();if(i!==raw.length)throw Error('Trailing JSON');const d=JSON.parse(raw);validator(d);return d;
}
function parse(raw){return parseDocument(raw);}
function duplicate(p){const copy={...p,id:id(),revision:id(),enabled:false,authority:'OFF_DRAFT_UNVERIFIED'};return copy;}
function encode(d){validate(d);return JSON.stringify(d,null,2);}
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let draft=null,error='',storageState='',catalogState=CATALOG,selectedBuild='';
function catalogView(value){
 if(value?.schema===CATALOG.schema&&value.status==='UNRESOLVED'&&value.profile_approval==='UNRESOLVED'&&value.compatibility==='UNKNOWN'&&value.can_submit===false&&value.can_execute===false&&value.population===null&&Array.isArray(value.wrappers)&&!value.wrappers.length&&Array.isArray(value.blockers)&&value.blockers.length>0&&value.blockers.length<=20&&value.blockers.every(x=>typeof x==='string'&&/^[A-Z][A-Z0-9_-]{0,119}$/.test(x)))return Object.freeze({...CATALOG,profile_approval:'UNRESOLVED',compatibility:'UNKNOWN',can_submit:false,can_execute:false,wrappers:Object.freeze([]),blockers:Object.freeze([...value.blockers])});
 if(!value||value.schema!==CATALOG.schema||value.status!=='AUDIT_METADATA_VERIFIED'||value.profile_approval!=='UNRESOLVED'||value.compatibility!=='UNKNOWN'||value.can_submit!==false||value.can_execute!==false||!Array.isArray(value.wrappers)||!value.wrappers.length||!value.source_head?.match(/^[0-9a-f]{40}$/)||!value.handoff_sha256?.match(/^[0-9a-f]{64}$/))return CATALOG;
 const keys=new Set(),builds=new Set();
 for(const w of value.wrappers){if(builds.has(w.build)||!w.build||!Number.isInteger(w.population)||w.population<=0||!Array.isArray(w.fields)||w.fields.length!==w.population)return CATALOG;builds.add(w.build);for(const f of w.fields){const key=JSON.stringify([f.build,f.name]);if(f.build!==w.build||!f.name||keys.has(key)||f.editable!==false||f.default_authority!=='SOURCE_REFERENCE_NOT_OWNER_APPROVED')return CATALOG;keys.add(key);}}
 return value;
}
function catalogDisplay(){
 if(catalogState.status!=='AUDIT_METADATA_VERIFIED')return '<h2>Input catalog</h2><p>Catalog UNRESOLVED · Input population UNKNOWN. Missing, stale or refused metadata does not mean zero inputs.</p><p>Reason: '+catalogState.blockers.map(esc).join(' · ')+'</p>';
 if(!catalogState.wrappers.some(w=>w.build===selectedBuild))selectedBuild=catalogState.wrappers[0].build;
 const w=catalogState.wrappers.find(w=>w.build===selectedBuild);
 const profiles=catalogState.profile_source_references||{};
 return '<h2>Read-only audited input catalog</h2><p>AUDIT_METADATA_VERIFIED · Profile approval UNRESOLVED · Compatibility UNKNOWN · no effective configuration</p><label class="builder-field">Canonical wrapper<select id="builderWrapper">'+catalogState.wrappers.map(x=>'<option value="'+esc(x.build)+'" '+(x.build===selectedBuild?'selected':'')+'>'+esc(x.build)+'</option>').join('')+'</select></label><p id="builderPopulation">'+esc(w.build)+': '+esc(w.population)+' physical inputs · active/runtime population UNKNOWN</p><p>Wrapper: '+esc(w.wrapper.path)+'<br>Audit source: <code>'+esc(catalogState.source_head)+'</code><br>Handoff SHA256: <code>'+esc(catalogState.handoff_sha256)+'</code><br>Config SHA256: <code>'+esc(catalogState.config_sha256)+'</code></p><details><summary>Source profile references — NOT OWNER APPROVAL</summary><pre>'+esc(JSON.stringify(profiles,null,2))+'</pre></details><div id="catalogFields">'+w.fields.map(f=>'<details class="catalog-field" data-catalog-name="'+esc(f.name)+'"><summary>'+esc(f.label)+' · '+esc(f.name)+' · '+esc(f.audit_status)+'</summary><dl><dt>Type / unit</dt><dd>'+esc(f.type)+' / '+esc(f.unit)+'</dd><dt>Source default — reference only</dt><dd>'+esc(f.source_default)+(f.source_default_code==null?'':' (code '+esc(f.source_default_code)+')')+' · SOURCE_REFERENCE_NOT_OWNER_APPROVED</dd><dt>Applicability predicate — descriptive, not evaluated</dt><dd>'+esc(f.activation_predicate)+'</dd><dt>Effective state</dt><dd>'+esc(f.effective_state)+'</dd><dt>Binding resolver</dt><dd>'+esc(f.binding_state)+' · '+esc(f.binding_reason||'Read-only existing resolver result')+'</dd><dt>Source</dt><dd>'+esc(f.source.path)+':'+esc(f.source.line)+'<br>SHA256 '+esc(f.source.sha256)+'</dd></dl>'+(f.enum_explanations?.length?'<p>Source enum meanings — reference only</p><pre>'+esc(f.enum_explanations.map(e=>e.meaning+' ('+e.symbol+'; code '+e.code+')').join('\n'))+'</pre>':'')+(f.resolver_result?'<pre>'+esc(JSON.stringify(f.resolver_result,null,2))+'</pre>':'')+'</details>').join('')+'</div>';
}
function updateCatalog(main){const box=main.querySelector('#builderCatalog');if(!box)return;box.innerHTML=catalogDisplay();const notice=main.querySelector('#builderForm > .notice');if(notice)notice.textContent=(location.protocol==='file:'?'OFFLINE HTML · ':'')+(catalogState.status==='AUDIT_METADATA_VERIFIED'?'Audit metadata VERIFIED · draft/profile bindings UNRESOLVED · Compatibility UNKNOWN. '+(decisions?'Profile proposals editable; approval and effective configuration UNRESOLVED.':'Approved shared settings remain locked.')+'':'Catalog UNRESOLVED · Input population UNKNOWN · Compatibility UNKNOWN. '+(decisions?'Profile proposals editable; approval and effective configuration UNRESOLVED.':'Approved shared settings remain locked.')+'');const selector=box.querySelector('#builderWrapper');if(selector)selector.onchange=()=>{selectedBuild=selector.value;updateCatalog(main);updateProfile(main);};}
const PROFILE='EA_LAB_DEFAULTPROFILE_DRAFT_V1',REQUEST='EA_LAB_DEFAULTPROFILE_REQUEST_V1',PROFILE_KEY='ea_lab.builder.m1.profiles',REQUEST_MAX=1048576;
let decisions=null,profile=null,profileHistory=[],profileReadOnly=false,advanced=false,profileNotice='',reviewToken=null,profileCacheRaw=null,profileCacheRefused=false;
const clone=x=>JSON.parse(JSON.stringify(x)),same=(a,b)=>JSON.stringify(a)===JSON.stringify(b);
function decisionView(v,c){
 if(!v||c.status!=='AUDIT_METADATA_VERIFIED'||v.schema!=='EA_LAB_PROFILE_DECISIONS_V1'||v.status!=='PINNED_PROPOSAL_METADATA'||v.scope!=='B22_CANONICAL_SHARED_TEMPLATE_A_OWNER_PROPOSAL'||v.source_head!==c.source_head||v.catalog_handoff_sha256!==c.handoff_sha256||v.profile_approval!=='UNRESOLVED'||v.compatibility!=='UNKNOWN'||v.can_submit!==false||v.can_execute!==false||!v.decision_sha256?.match(/^[0-9a-f]{64}$/)||!v.source_refs_sha256?.match(/^[0-9a-f]{64}$/)||!Array.isArray(v.rows)||v.rows.length!==153||!Array.isArray(v.groups)||v.groups.length!==10||new Set(v.groups.map(g=>g.id)).size!==10||!Array.isArray(v.contexts)||v.contexts.length!==3)return null;
 const fields=new Map(c.wrappers.find(w=>w.build==='B22')?.fields.map(f=>[f.name,f])||[]),seen=new Set();
 for(const r of v.rows){const f=fields.get(r.name);if(!f||seen.has(r.name)||r.type!==f.type||r.source_value!==f.source_default||r.source?.sha256!==f.source.sha256||r.source?.line!==f.source.line||!['SHARED','ENTRY','INSTANCE'].includes(r.scope)||!r.constraints||r.constraints.type!==r.type||!same(r.constraints.enum_symbols,f.enum_explanations.map(e=>e.symbol))||!Array.isArray(r.dependencies?.tests))return null;seen.add(r.name);}
 if(v.rows.filter(r=>r.scope==='SHARED').length!==150||v.rows.filter(r=>r.scope==='ENTRY').length!==2||v.rows.filter(r=>r.scope==='INSTANCE').length!==1)return null;
 return clone(v);
}
function profilePin(v){return {source_head:v.source_head,catalog_handoff_sha256:v.catalog_handoff_sha256,decision_sha256:v.decision_sha256,source_refs_sha256:v.source_refs_sha256};}
function newProfile(v){
 if(!v)throw Error('Profile decision metadata UNRESOLVED');
 const slots=scope=>v.rows.filter(r=>r.scope===scope).map(r=>({name:r.name,value:null,response:'UNANSWERED',reason:''}));
 return {schema:PROFILE,authority:'LOCAL_DRAFT_UNVERIFIED',scope:v.scope,profile_id:id(),revision:id(),parent_revision:null,title:'B22 shared Template A owner proposal',notes:'',pins:profilePin(v),bindings:{default_profile:{id:'',revision:''},template_release:{id:'',revision:''},entry_contract:{id:'',revision:''}},group_responses:v.groups.map(g=>({id:g.id,choice:'UNANSWERED',reason:''})),shared_values:slots('SHARED'),entry_values:slots('ENTRY'),instance_values:slots('INSTANCE'),context_responses:v.contexts.map(c=>({id:c.id,value:null,reason:''}))};
}
function allSlots(p){return [...p.shared_values,...p.entry_values,...p.instance_values];}
function valueCheck(row,value){
 if(value===null)return {status:'UNRESOLVED',representation:null};
 if(typeof value!=='string'||value.length>20000)throw Error(row.name+': expected lossless text literal or null');
 const t=row.type,limits=row.constraints;
 if(limits.enum_symbols.length){if(!limits.enum_symbols.includes(value))throw Error(row.name+': unknown or wrong-type enum symbol');return {status:'LOCAL_TYPE_VALID_PROPOSAL',representation:value};}
 if(t==='bool'){if(!['true','false'].includes(value))throw Error(row.name+': choose true or false');return {status:'LOCAL_TYPE_VALID_PROPOSAL',representation:value};}
 if(limits.integer_bounds){if(!/^-?(?:0|[1-9]\d*)$/.test(value))throw Error(row.name+': exact integer literal required (no fraction/exponent)');const n=BigInt(value);if(n<BigInt(limits.integer_bounds[0])||n>BigInt(limits.integer_bounds[1]))throw Error(row.name+': outside declared integer bounds');return {status:'LOCAL_TYPE_VALID_PROPOSAL',representation:n.toString()};}
 if(t==='double'){
  // Reuse the existing decimal grammar; compare its exact coefficient/exponent
  // with the finite double's decimal roundtrip, not rounded Number equality.
  const literal=/^(-?)(0|[1-9]\d*)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$/,input=literal.exec(value),n=Number(value);
  if(!input||!Number.isFinite(n))throw Error(row.name+': finite double decimal required; overflow/nonfinite value refused');
  const decimalIdentity=m=>{const fraction=m[3]||'',digits=(m[2]+fraction).replace(/^0+/,'');if(!digits)return m[1]+'0';const coefficient=digits.replace(/0+$/,'');return m[1]+coefficient+'e'+(BigInt(m[4]||'0')-BigInt(fraction.length)+BigInt(digits.length-coefficient.length)).toString();};
  const representation=Object.is(n,-0)?'-0':String(n);
  if(decimalIdentity(input)!==decimalIdentity(literal.exec(representation)))throw Error(row.name+(n===0?': nonzero decimal underflows double; proposed literal refused':': decimal loses precision in double roundtrip; proposed literal refused'));
  if(limits.positive&&n<=0||limits.maximum!==null&&limits.maximum!==undefined&&n>Number(limits.maximum))throw Error(row.name+': audited entry domain refused');
  return {status:'LOCAL_TYPE_VALID_PROPOSAL',representation};
 }
 if(t==='string')return {status:'LOCAL_TYPE_VALID_PROPOSAL',representation:value};
 return {status:'UNRESOLVED_PLATFORM_OR_TYPE_MEANING',representation:null};
}
function requiredness(row,p,v){
 if(row.scope==='ENTRY'||row.scope==='INSTANCE'||row.tier==='NORMAL_REQUIRED_DECISION'||row.tier==='RESOLVED_OWNER_INTENT_WITH_UNPROVEN_EFFECTIVE_CONFIG'&&!row.dependencies.tests.length)return 'REQUIRED_PROPOSAL';
 const slots=new Map(allSlots(p).map(s=>[s.name,s.value]));let unknown=false;
 for(const t of row.dependencies.tests){const value=slots.get(t.selector);if(value==null){unknown=true;continue;}const yes=t.values.includes(value);if(t.op==='!='?yes:!yes)return 'EXCLUDED_BY_PROPOSED_BRANCH';}
 if(row.dependencies.tests.length&&!unknown)return 'REQUIRED_BY_PROPOSED_BRANCH';
 if(row.tier==='NOT_A_CURRENT_SHARED_PROFILE_QUESTION'&&!row.dependencies.tests.length)return 'DEFERRED_AUDIT_REFERENCE';
 return 'UNRESOLVED_CONDITIONAL_REQUIREMENT';
}
function validateProfile(p,v){
 if(!v)throw Error('Profile decision metadata UNRESOLVED');
 exact(p,['schema','authority','scope','profile_id','revision','parent_revision','title','notes','pins','bindings','group_responses','shared_values','entry_values','instance_values','context_responses']);
 if(p.schema!==PROFILE||p.authority!=='LOCAL_DRAFT_UNVERIFIED'||p.scope!==v.scope)throw Error('Profile schema/authority/scope refused');
 for(const k of ['profile_id','revision','title','notes'])text(p[k]);if(!p.profile_id||!p.revision)throw Error('Profile identity required');if(p.parent_revision!==null)text(p.parent_revision);
 exact(p.pins,Object.keys(profilePin(v)));if(!same(p.pins,profilePin(v)))throw Error('Profile catalog/decision pins mismatch');
 exact(p.bindings,['default_profile','template_release','entry_contract']);for(const r of Object.values(p.bindings)){exact(r,['id','revision']);text(r.id);text(r.revision);}
 const errors=[],missing=[];
 for(const [key,scope]of [['shared_values','SHARED'],['entry_values','ENTRY'],['instance_values','INSTANCE']]){
  const expected=v.rows.filter(r=>r.scope===scope);if(!Array.isArray(p[key])||p[key].length!==expected.length)throw Error('Profile scope/population mismatch');
  for(let i=0;i<expected.length;i++){const row=expected[i],s=p[key][i];exact(s,['name','value','response','reason']);if(s.name!==row.name||!['UNANSWERED','VALUE_PROPOSED','UNRESOLVED'].includes(s.response))throw Error('Profile row identity/response refused');text(s.reason);
   if(s.value!==null&&typeof s.value!=='string')throw Error(row.name+': literal must be text or null');if((s.response==='VALUE_PROPOSED')!==(s.value!==null))throw Error(row.name+': response/value disagreement');if(s.response==='UNRESOLVED'&&!s.reason.trim())throw Error(row.name+': unresolved response requires reason');
   try{const result=valueCheck(row,s.value);if(s.value!==null&&result.representation===null)missing.push(row.name+': '+result.status);}catch(e){errors.push(e.message);}
   const req=requiredness(row,p,v);if(req.startsWith('REQUIRED')&&s.value===null)missing.push(row.name+': '+req);if(req==='UNRESOLVED_CONDITIONAL_REQUIREMENT')missing.push(row.name+': unresolved branch/runtime applicability');
  }
 }
 if(!Array.isArray(p.group_responses)||p.group_responses.length!==v.groups.length)throw Error('Profile group count');p.group_responses.forEach((g,i)=>{exact(g,['id','choice','reason']);if(g.id!==v.groups[i].id||!['UNANSWERED','PROPOSE_VALUES','UNRESOLVED'].includes(g.choice))throw Error('Profile group response');text(g.reason);if(g.choice==='UNANSWERED')missing.push('Group '+g.id+': no response');if(g.choice==='UNRESOLVED'&&!g.reason.trim())missing.push('Group '+g.id+': unresolved reason required');});
 if(!Array.isArray(p.context_responses)||p.context_responses.length!==v.contexts.length)throw Error('Profile context count');p.context_responses.forEach((r,i)=>{exact(r,['id','value','reason']);if(r.id!==v.contexts[i].id)throw Error('Profile context identity');if(r.value!==null)text(r.value);text(r.reason);if(!r.value)missing.push(r.id+': external context unqualified');});
 for(const [k,r]of Object.entries(p.bindings))if(!r.id||!r.revision)missing.push(k+': proposed ID/revision unresolved');
 if(new TextEncoder().encode(JSON.stringify(p,null,2)).length>MAX)throw Error('Profile export too large');
 return {structural_valid:true,type_valid:errors.length===0,decision_complete:errors.length===0&&missing.length===0,errors,missing,profile_approval:'UNRESOLVED',compatibility:'UNKNOWN',effective_state:'UNKNOWN_NO_EFFECTIVE_CONFIG',can_submit:false,can_execute:false};
}
function savedRevision(history,p){const matches=history.filter(r=>r.profile_id===p.profile_id&&r.revision===p.revision);if(matches.length>1)throw Error('Duplicate saved profile/revision identity refused');const saved=matches[0];if(saved&&!same(saved,p))throw Error('Same saved profile/revision content conflict; explicit Fork required');return saved||null;}
function encodeProfile(p,v,history=[]){savedRevision(history,p);const result=validateProfile(p,v);if(!result.type_valid)throw Error(result.errors.join('\n'));return JSON.stringify(p,null,2);}
function revisionStore(history,p,v){encodeProfile(p,v,history);const sameId=savedRevision(history,p);const next=sameId?clone(history):[...clone(history),clone(p)];if(next.length>100||new TextEncoder().encode(JSON.stringify(next)).length>4194304)throw Error('Revision cache limit; export JSON backup');return next;}
function reviewSummary(p,v,history=[]){savedRevision(history,p);const validation=validateProfile(p,v);return {scope:p.scope,profile_id:p.profile_id,revision:p.revision,requested_intent_reference:v.intent,requested_resolved_effective_reference:v.requested_resolved_effective,values:allSlots(p).map(s=>{const row=v.rows.find(r=>r.name===s.name);let resolved;try{resolved=valueCheck(row,s.value);}catch(e){resolved={status:'INVALID',representation:null};}return {name:s.name,scope:row.scope,source_value:row.source_value,owner_proposed_value:s.value,resolved_proposal:resolved,requiredness:requiredness(row,p,v),response:s.response,reason:s.reason,predicate:row.predicate,provenance:row.source,effective:'UNKNOWN'};}),groups:p.group_responses,bindings:p.bindings,contexts:p.context_responses,validation};}
function makeRequest(p,bd,v,pending,confirmed,history=[]){savedRevision(history,p);const validation=validateProfile(p,v);validate(bd);if(!validation.type_valid)throw Error(validation.errors.join('\n'));if(!confirmed)throw Error('Review and confirm the exact current snapshot first');if(!validation.decision_complete&&!pending)throw Error('Required decisions remain; explicitly acknowledge pending-decisions request');const request={schema:REQUEST,status:'NOT_SUBMITTED',authority:'UNVERIFIED_PROPOSAL_ONLY',request_id:id(),intent:validation.decision_complete?'PROFILE_REVIEW':'PENDING_DECISIONS',profile:clone(p),builder_draft:clone(bd),pins:profilePin(v),validation,review_summary:reviewSummary(p,v,history),unresolved_questions:validation.missing,owner_attestation:false,can_submit:false,can_execute:false};if(new TextEncoder().encode(JSON.stringify(request,null,2)).length>REQUEST_MAX)throw Error('Request export too large');return request;}
function parseProfile(raw,v,history=[]){const parsed=parseDocument(raw,x=>{if(x.schema===PROFILE){const val=validateProfile(x,v);if(!val.type_valid)throw Error(val.errors.join('\n'));return;}
 exact(x,['schema','status','authority','request_id','intent','profile','builder_draft','pins','validation','review_summary','unresolved_questions','owner_attestation','can_submit','can_execute']);if(x.schema!==REQUEST||x.status!=='NOT_SUBMITTED'||x.authority!=='UNVERIFIED_PROPOSAL_ONLY'||x.owner_attestation!==false||x.can_submit!==false||x.can_execute!==false||!['PROFILE_REVIEW','PENDING_DECISIONS'].includes(x.intent)||!same(x.pins,profilePin(v)))throw Error('Request schema/authority/pins refused');text(x.request_id);if(!x.request_id)throw Error('Request identity required');validate(x.builder_draft);const val=validateProfile(x.profile,v);if(!val.type_valid)throw Error(val.errors.join('\n'));if(x.intent==='PROFILE_REVIEW'&&!val.decision_complete)throw Error('Incomplete profile review request');},REQUEST_MAX);if(parsed.schema===PROFILE&&new TextEncoder().encode(raw).length>MAX)throw Error('Profile import too large');savedRevision(history,parsed.schema===REQUEST?parsed.profile:parsed);return parsed;}
function resetProfileState(){importedOriginal=null;importedOriginalRaw=null;profile=null;profileHistory=[];profileReadOnly=false;reviewToken=null;profileNotice='';profileCacheRaw=null;profileCacheRefused=false;}
function profileDownload(name,raw){const url=URL.createObjectURL(new Blob([raw],{type:'application/json'})),a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
function restoreProfileCache(raw,v){
 const stored=parseDocument(raw,x=>{exact(x,['working','history']);if(!Array.isArray(x.history)||x.history.length>100)throw Error('Revision cache invalid');validateProfile(x.working,v);let checked=[];for(const p of x.history){const next=revisionStore(checked,p,v);if(next.length===checked.length)throw Error('Duplicate saved profile/revision in cache refused');checked=next;}try{savedRevision(checked,x.working);}catch(e){e.saved_history=clone(checked);throw e;}},4194304);
 return {working:stored.working,history:stored.history,readOnly:!!savedRevision(stored.history,stored.working)};
}
function ensureProfile(){if(profile||!decisions)return;profile=newProfile(decisions);try{const raw=localStorage.getItem(PROFILE_KEY);profileCacheRaw=raw;if(raw){const stored=restoreProfileCache(raw,decisions);profile=stored.working;profileHistory=stored.history;profileReadOnly=stored.readOnly;}}catch(e){if(e.saved_history)profileHistory=e.saved_history;profileCacheRefused=true;profileNotice='Cache unavailable/refused and preserved: '+e.message+'; use JSON backup. No saved-data migration.';}}
function assertProfileBoundary(){savedRevision(profileHistory,profile);if(!profileCacheRefused){let raw;try{raw=localStorage.getItem(PROFILE_KEY);}catch(e){return;}if(raw!==profileCacheRaw)throw Error('Stale revision cache changed in another tab; reload before save/import/export. Stored bytes preserved');}}
function cacheProfile(){try{assertProfileBoundary();if(profileCacheRefused)throw Error('Refused stored cache preserved; use JSON backup');const raw=JSON.stringify({working:profile,history:profileHistory});if(new TextEncoder().encode(raw).length>4194304)throw Error('Cache limit');localStorage.setItem(PROFILE_KEY,raw);profileCacheRaw=raw;}catch(e){profileNotice='Browser cache unavailable: '+e.message+'; export JSON backup';}}
function editProfile(){if(profileReadOnly)throw Error('Saved revision is immutable; Fork first');reviewToken=null;cacheProfile();}
// Imported source is a raw backup, not a new proposal schema or approval receipt.
const IMPORT_KEY='ea_lab.builder.m1.imported_original';
let importedOriginal=null,importedOriginalRaw=null;
function prepareMobileImport(raw,v,history){
 const doc=parseProfile(raw,v,history),p=doc.schema===REQUEST?doc.profile:doc;
 return {raw,original:clone(doc),profile:clone(p),history:revisionStore(history,p,v),builder:doc.schema===REQUEST?clone(doc.builder_draft):null};
}
function importLocked(){const p=importedOriginal?.schema===REQUEST?importedOriginal.profile:importedOriginal;return !!(p&&profile&&p.profile_id===profile.profile_id&&p.revision===profile.revision);}
function restoreMobileOriginal(){
 importedOriginal=null;importedOriginalRaw=null;
 try{const raw=localStorage.getItem(IMPORT_KEY);if(raw){const parsed=parseProfile(raw,decisions,profileHistory);importedOriginal=clone(parsed);importedOriginalRaw=raw;}}
 catch(e){profileCacheRefused=true;profileNotice='Imported original backup refused and preserved: '+e.message;}
}
function storeMobileImport(prepared){
 const values=[[IMPORT_KEY,prepared.raw],[PROFILE_KEY,JSON.stringify({working:prepared.profile,history:prepared.history})]];
 if(prepared.builder)values.push([KEY,encode(prepared.builder)]);
 if(new TextEncoder().encode(values[1][1]).length>4194304)throw Error('Cache limit; original working state retained');
 const before=values.map(([k])=>[k,localStorage.getItem(k)]);let written=0;
 try{for(const [k,v]of values){localStorage.setItem(k,v);written++;}}
 catch(e){let rollback='';for(const [k,v]of before.slice(0,written).reverse()){try{if(v===null)localStorage.removeItem(k);else localStorage.setItem(k,v);}catch(f){rollback+='; backup restore unavailable: '+f.message;}}throw Error('Import cache unavailable; original working state retained: '+e.message+rollback);}
 profile=prepared.profile;profileHistory=prepared.history;profileReadOnly=true;
 importedOriginal=prepared.original;importedOriginalRaw=prepared.raw;profileCacheRaw=values[1][1];
 if(prepared.builder)draft=prepared.builder;
 reviewToken=null;
}
function mobileGlobalError(main,message,focus=true){
 profileNotice=message;profileDiagnostics(main);
 const status=main.querySelector('#mobileStatus')||main.querySelector('#profileDiagnostics');
 if(status){status.textContent=message;status.hidden=false;status.tabIndex=-1;if(focus){status.focus({preventScroll:true});mobileReveal(status,true);}}
}
function mobileImportControls(main){
 const locked=importLocked();
 for(const el of main.querySelectorAll('[data-builder-field],#builderAdd,[data-duplicate],#builderImport'))el.disabled=locked;
}
function reviewTarget(message,p,v){
 const key=message.split(':')[0],row=v.rows.find(r=>r.name===key);
 if(row)return {step:row.scope==='SHARED'?row.group:row.scope==='ENTRY'?'entry':'instance',selector:'[data-profile-value="'+row.name+'"]'};
 const group=v.groups.find(g=>key==='Group '+g.id);if(group)return {step:group.id,selector:'[data-profile-group-choice="'+group.id+'"]'};
 if(p.context_responses.some(r=>r.id===key))return {step:'context',selector:'[data-profile-context="'+key+'"]'};
 if(Object.hasOwn(p.bindings,key))return {step:v.groups[0].id,selector:'[data-profile-binding="'+key+'.id"]'};
 return null;
}
function mobileReviewModel(p,bd,v,history){
 const summary=reviewSummary(p,v,history);validate(bd);
 return {summary,ea:bd.title,builder_revision:bd.revision,builder_bindings:clone(bd.bindings),profile_title:p.title,group_metadata:clone(v.groups),value_targets:Object.fromEntries(summary.values.map(r=>[r.name,reviewTarget(r.name+':',p,v)])),saved:!!savedRevision(history,p),issues:[...summary.validation.errors,...summary.validation.missing].map(message=>({message,target:reviewTarget(message,p,v)}))};
}
function mobileReviewHTML(model){
 const s=model.summary,ref=r=>(r.id||'UNRESOLVED')+' / '+(r.revision||'UNRESOLVED');
 const jump=(label,t)=>t?'<button class="btn" data-review-step="'+esc(t.step)+'" data-review-selector="'+esc(t.selector)+'">'+esc(label)+'</button>':'<span>'+esc(label)+'</span>';
 return '<section id="mobileHumanReview"><h4>ตรวจทาน EA นี้ — ข้อเสนอเท่านั้น</h4><p>ชื่อ EA: '+esc(model.ea)+' · Revision: '+esc(model.builder_revision)+'</p><p>ตั้งค่า EA: '+esc(model.profile_title)+' · Revision: '+esc(s.revision)+' · Scope: '+esc(s.scope)+' · B22</p><p>'+(model.saved?'บันทึกแล้ว / immutable':'กำลังแก้ไข / working')+'</p><p>ความเสี่ยงและค่าเริ่มต้นยังไม่ผ่านการยืนยัน · Approval UNRESOLVED · Compatibility UNKNOWN · Effective UNKNOWN · NOT_SUBMITTED</p><h5>ข้อมูลอ้างอิงที่เสนอ — ยังไม่ยืนยัน</h5>'+Object.entries(model.builder_bindings).map(([k,r])=>'<p data-review-reference="builder.'+esc(k)+'">Builder '+esc(k)+': '+esc(ref(r))+'</p>').join('')+Object.entries(s.bindings).map(([k,r])=>'<p data-review-reference="profile.'+esc(k)+'">Profile '+esc(k)+': '+esc(ref(r))+'</p>').join('')+'<h5>ทางเลือกของแต่ละกลุ่ม</h5>'+s.groups.map(g=>'<p data-review-group="'+esc(g.id)+'">'+esc(g.id)+': '+esc(g.choice)+' · '+esc(g.reason)+'</p>').join('')+'<h5>ค่าที่เสนอและเงื่อนไข</h5>'+s.values.filter(r=>r.owner_proposed_value!==null).map(r=>'<p data-review-value="'+esc(r.name)+'">'+esc(r.name)+': <strong>'+esc(r.owner_proposed_value)+'</strong> · '+esc(r.requiredness)+' · '+esc(r.reason)+' · Effective UNKNOWN '+jump('แก้ไข '+r.name,model.value_targets[r.name])+'</p>').join('')+'<h5>ข้อจำกัดและความหมายที่ต้องพิจารณา</h5>'+model.group_metadata.map(g=>'<p>'+esc(g.label)+': '+esc(g.higher_cap)+'</p>').join('')+'<h5>บริบทที่เสนอ</h5>'+s.contexts.map(r=>'<p>'+esc(r.id)+': '+esc(r.value??'UNRESOLVED')+' · '+esc(r.reason)+'</p>').join('')+'<h5>รายการที่ต้องตรวจ/ตอบ: '+model.issues.length+'</h5><ul>'+model.issues.map(i=>'<li>'+jump(i.message,i.target)+'</li>').join('')+'</ul></section><details id="mobileTechnicalReview"><summary>ข้อมูลทางเทคนิค / JSON</summary><pre>'+esc(JSON.stringify(s,null,2))+'</pre></details>';
}
function mobileReviewJump(main,target){
 const confirmed=main.querySelector('#profileConfirm')?.checked,pending=main.querySelector('#profilePending')?.checked;
 mobileStep=target.step;advanced=true;updateProfile(main);
 const confirm=main.querySelector('#profileConfirm');if(confirm&&reviewToken){confirm.checked=!!confirmed;main.querySelector('#profilePending').checked=!!pending;}
 profileDiagnostics(main);
 const el=main.querySelector(target.selector);if(el){mobileOpenDetails(el);if(!el.matches('input,select,textarea,button,a'))el.tabIndex=-1;el.focus({preventScroll:true});mobileReveal(el,true);}else mobileGlobalError(main,'ไม่พบช่องที่อ้างถึง — ข้อผิดพลาดส่วนกลาง');
}
function openMobileChild(main){
 assertProfileBoundary();if(profileCacheRefused)throw Error('Refused cache preserved');
 const next=reviseMobile(profile,draft,decisions,profileHistory);profile=next.profile;draft=next.builder;profileHistory=next.history;profileReadOnly=false;reviewToken=null;
 localStorage.setItem(KEY,encode(draft));cacheProfile();profileNotice='สร้างสำเนาแก้ไขแล้ว · ต้นฉบับไม่เปลี่ยน · ยังไม่ยืนยัน';main.querySelector('#builderForm').remove();mount(main,catalogState,decisions);
}

function profileDiagnostics(main){const mobileStatus=main.querySelector('#mobileStatus');if(mobileStatus)mobileStatus.textContent=profileNotice||'ร่างเท่านั้น · NOT_SUBMITTED · ผลใช้งานจริง UNKNOWN';const box=main.querySelector('#profileDiagnostics');if(!box)return;try{assertProfileBoundary();const val=validateProfile(profile,decisions);box.textContent=(profileNotice?profileNotice+'\n':'')+(val.type_valid?'Local types checked; owner approval UNRESOLVED.':'Invalid proposed value: '+val.errors.join('; '))+'\nMissing/pending decisions: '+val.missing.length+'. Compatibility UNKNOWN; effective configuration UNKNOWN.';main.querySelector('#profileSend').disabled=!val.type_valid||!reviewToken||!main.querySelector('#profileConfirm').checked;for(const el of main.querySelectorAll('[data-profile-status]')){const slot=allSlots(profile).find(s=>s.name===el.dataset.profileStatus),row=decisions.rows.find(r=>r.name===slot.name);try{const r=valueCheck(row,slot.value);el.textContent=r.status+' / '+(r.representation??'UNRESOLVED')+' / '+requiredness(row,profile,decisions);}catch(e){el.textContent=e.message;}}}catch(e){box.textContent=e.message;main.querySelector('#profileSend').disabled=true;}}
function updateProfile(main){
 const box=main.querySelector('#profileWorkflow');if(!box)return;
 if(!decisions){box.innerHTML='<p class="notice">DefaultProfile decision metadata UNRESOLVED. Working draft preserved; profile Send unavailable.</p>'+(profile?'<button class="btn" id="profileBackup">Export preserved draft backup — UNVERIFIED</button>':'');if(profile)box.querySelector('#profileBackup').onclick=()=>{try{assertProfileBoundary();profileDownload('ea-defaultprofile-preserved-UNVERIFIED.json',JSON.stringify(profile,null,2));}catch(e){box.querySelector('.notice').textContent='Backup refused: '+e.message;}};reviewToken=null;return;}
 ensureProfile();restoreMobileOriginal();if(selectedBuild&&selectedBuild!=='B22'){box.innerHTML='<p class="notice">OUT_OF_SCOPE: this proposed profile is pinned to B22. B17 catalog remains read-only; B22 values are not global defaults.</p>';return;}
 const focus=box.contains(document.activeElement)?document.activeElement?.dataset.profileValue:null,selection=focus?document.activeElement.selectionStart:null;
 const rows=decisions.rows,slots=new Map(allSlots(profile).map(s=>[s.name,s])),disabled=profileReadOnly?'disabled':'';
 const field=r=>{const s=slots.get(r.name),req=requiredness(r,profile,decisions),enums=catalogState.wrappers.find(w=>w.build==='B22').fields.find(f=>f.name===r.name).enum_explanations;let control;
  if(enums.length||r.type==='bool'){const options=enums.length?enums.map(e=>[e.symbol,e.meaning+' — '+e.symbol]):[['true','เปิด / true'],['false','ปิด / false']];control='<select data-profile-value="'+esc(r.name)+'" '+disabled+'><option value="">ยังไม่เลือก / Unanswered</option>'+options.map(([v,l])=>'<option value="'+esc(v)+'" '+(s.value===v?'selected':'')+'>'+esc(l)+'</option>').join('')+'</select>';}
  else control='<input data-profile-value="'+esc(r.name)+'" value="'+esc(s.value)+'" maxlength="20000" '+disabled+' inputmode="'+(r.type==='string'?'text':'decimal')+'" placeholder="'+esc(r.type)+' — owner proposal">';
  return '<article class="profile-row" data-profile-row="'+esc(r.name)+'"><label>'+esc(r.label)+' <code>'+esc(r.name)+'</code> <small>'+esc(r.type)+' / '+esc(r.unit)+' / '+esc(r.audit_status)+'</small>'+control+'</label><p data-profile-status="'+esc(r.name)+'"></p><p>Source reference: <code>'+esc(r.source_value)+'</code> — SOURCE_REFERENCE_NOT_OWNER_APPROVED</p>'+(r.source_proposal_literal!==null?'<button class="btn" data-adopt-source="'+esc(r.name)+'" '+disabled+'>Use this source reference as my unverified proposal</button>':'')+(r.intent!==null?'<p>Existing semantic intent: '+esc(typeof r.intent==='object'?r.intent.symbol:String(r.intent))+'; profile value not approved. <button class="btn" data-adopt-intent="'+esc(r.name)+'" '+disabled+'>Use this intent as my draft proposal</button></p>':'')+'<details><summary>Predicate / provenance / higher constraints</summary><p>'+esc(r.predicate)+'</p><p>'+esc(r.meaning)+'</p><p>'+esc(r.source.path)+':'+esc(r.source.line)+'<br><code>'+esc(r.source.sha256)+'</code><br>Source '+esc(r.source_head)+'</p><p>Requested proposal only. Effective UNKNOWN. See group higher caps; no runtime evaluation.</p></details><label>Unresolved reason<input data-profile-reason="'+esc(r.name)+'" value="'+esc(s.reason)+'" maxlength="20000" '+disabled+'></label></article>';
 };
 const visible=r=>advanced||r.scope!=='SHARED'||r.tier==='NORMAL_REQUIRED_DECISION'||r.tier==='RESOLVED_OWNER_INTENT_WITH_UNPROVEN_EFFECTIVE_CONFIG'||requiredness(r,profile,decisions)==='REQUIRED_BY_PROPOSED_BRANCH';
 box.innerHTML='<h3>DefaultProfile — แบบร่างค่าเสนอของเจ้าของ</h3><p>B22 canonical shared Template A proposal. Source ≠ owner approval. Entry settings and instance Magic stay separate.</p><p>28 core / 86 conditional / 31 deferred / 5 semantic intents. Effective UNKNOWN; no activation.</p><div class="builder-toolbar"><button class="btn" id="profileView">'+(advanced?'Normal view':'Advanced full surface')+'</button><button class="btn" id="profileSave" '+disabled+'>Save Revision</button><button class="btn" id="profileBind">Use saved local profile reference</button><button class="btn" id="profileFork">Fork editable revision</button><button class="btn" id="profileDuplicate">Duplicate as new unverified profile</button><button class="btn" id="profileExport">Export profile JSON</button><label class="btn">Import profile / request JSON<input id="profileImport" type="file" accept=".json,application/json"></label></div><p>Revision '+esc(profile.revision)+(profileReadOnly?' — SAVED / IMMUTABLE':' — editable working copy')+'</p><label>Saved revisions<select id="profileHistory"><option value="">Select immutable snapshot</option>'+profileHistory.map((p,i)=>'<option value="'+i+'">'+esc(p.title)+' / '+esc(p.revision)+'</option>').join('')+'</select></label><label>Profile title<input id="profileTitle" value="'+esc(profile.title)+'" '+disabled+' maxlength="20000"></label><label>Proposed profile ID<input id="profileId" value="'+esc(profile.profile_id)+'" '+disabled+' maxlength="20000"></label><label>Notes<textarea id="profileNotes" '+disabled+' maxlength="20000">'+esc(profile.notes)+'</textarea></label>'+Object.entries(profile.bindings).map(([k,r])=>'<div class="profile-bindings"><strong>'+esc(k)+' proposed reference (unverified)</strong>'+['id','revision'].map(n=>'<label>'+esc(n)+'<input data-profile-binding="'+k+'.'+n+'" value="'+esc(r[n])+'" '+disabled+' maxlength="20000"></label>').join('')+'</div>').join('')+decisions.groups.map(g=>{const answer=profile.group_responses.find(r=>r.id===g.id),groupRows=rows.filter(r=>r.scope==='SHARED'&&r.group===g.id),shown=groupRows.filter(visible);return '<section class="profile-group" data-profile-group="'+esc(g.id)+'"><h4>'+esc(g.label)+' — '+esc(g.id)+'</h4><p>'+esc(g.question)+'</p><details><summary>Higher cap / consequential meaning</summary><p>'+esc(g.higher_cap)+'</p></details><label>Group response<select data-profile-group-choice="'+g.id+'" '+disabled+'>'+['UNANSWERED','PROPOSE_VALUES','UNRESOLVED'].map(x=>'<option '+(answer.choice===x?'selected':'')+'>'+x+'</option>').join('')+'</select></label><label>Group unresolved reason / notes<input data-profile-group-reason="'+g.id+'" value="'+esc(answer.reason)+'" '+disabled+' maxlength="20000"></label><p>'+groupRows.filter(r=>requiredness(r,profile,decisions)==='UNRESOLVED_CONDITIONAL_REQUIREMENT').length+' conditional requirements remain unresolved. '+(advanced?'Full audited surface.':'Other conditional/deferred values remain available in Advanced; missing fields remain in validation.')+'</p>'+shown.map(field).join('')+'</section>';}).join('')+'<section class="profile-group"><h4>B22 Entry Contract — separate values</h4>'+rows.filter(r=>r.scope==='ENTRY').map(field).join('')+'</section><section class="profile-group"><h4>Instance ownership — not shared defaults</h4>'+rows.filter(r=>r.scope==='INSTANCE').map(field).join('')+'</section><section class="profile-group"><h4>External context — unqualified</h4>'+profile.context_responses.map(r=>'<label>'+esc(r.id)+' proposed reference<input data-profile-context="'+esc(r.id)+'" value="'+esc(r.value)+'" '+disabled+' maxlength="20000"></label>').join('')+'</section><details><summary>Requested / resolved meaning / effective UNKNOWN</summary><pre>'+esc(JSON.stringify(decisions.requested_resolved_effective,null,2))+'</pre></details><pre id="profileDiagnostics" role="status"></pre><div class="builder-toolbar"><button class="btn" id="profileValidate">Validate required decisions</button><button class="btn" id="profileReview">Review Summary</button></div><div id="profileReviewSummary"></div><p>ส่ง = Export a request file to attach back. NOT_SUBMITTED; M2 intake blocked. No queued/accepted receipt.</p><label><input type="checkbox" id="profilePending"> Request help with listed pending decisions (acknowledge incomplete profile)</label><label><input type="checkbox" id="profileConfirm" disabled> Confirm this exact reviewed snapshot</label><button class="btn primary" id="profileSend" disabled>ส่ง — Send: Export request file</button>';
 const attempt=(fn,focusError=true)=>{try{fn();if(focusError&&profileNotice.startsWith('Browser cache unavailable:'))mobileGlobalError(main,profileNotice);}catch(e){mobileGlobalError(main,e.message,focusError);}};
 const edit=fn=>attempt(()=>{if(profileReadOnly)throw Error('Fork saved revision before editing');fn();editProfile();main.querySelector('#profileConfirm').checked=false;main.querySelector('#profileConfirm').disabled=true;main.querySelector('#profileReviewSummary').textContent='Edited; review again.';profileDiagnostics(main);},false);
 box.querySelectorAll('[data-profile-value]').forEach(el=>el.addEventListener('input',()=>edit(()=>{const s=slots.get(el.dataset.profileValue);s.value=el.value===''?null:el.value;s.response=s.value===null?'UNANSWERED':'VALUE_PROPOSED';if(el.tagName==='SELECT')updateProfile(main);})));
 box.querySelectorAll('[data-adopt-source]').forEach(el=>el.onclick=()=>edit(()=>{const r=rows.find(r=>r.name===el.dataset.adoptSource),s=slots.get(r.name);s.value=r.source_proposal_literal;s.response='VALUE_PROPOSED';s.reason='Explicit source-reference adoption; no approval';updateProfile(main);}));
 box.querySelectorAll('[data-adopt-intent]').forEach(el=>el.onclick=()=>edit(()=>{const r=rows.find(r=>r.name===el.dataset.adoptIntent),s=slots.get(r.name);s.value=typeof r.intent==='object'?r.intent.symbol:String(r.intent);s.response='VALUE_PROPOSED';updateProfile(main);}));
 box.querySelectorAll('[data-profile-reason]').forEach(el=>el.oninput=()=>edit(()=>{const s=slots.get(el.dataset.profileReason);s.reason=el.value;if(s.value===null)s.response=el.value.trim()?'UNRESOLVED':'UNANSWERED';}));
 box.querySelectorAll('[data-profile-group-choice]').forEach(el=>el.onchange=()=>edit(()=>{profile.group_responses.find(g=>g.id===el.dataset.profileGroupChoice).choice=el.value;}));
 box.querySelectorAll('[data-profile-group-reason]').forEach(el=>el.oninput=()=>edit(()=>{profile.group_responses.find(g=>g.id===el.dataset.profileGroupReason).reason=el.value;}));
 box.querySelectorAll('[data-profile-binding]').forEach(el=>el.oninput=()=>edit(()=>{const [k,n]=el.dataset.profileBinding.split('.');profile.bindings[k][n]=el.value;}));
 box.querySelectorAll('[data-profile-context]').forEach(el=>el.oninput=()=>edit(()=>{profile.context_responses.find(r=>r.id===el.dataset.profileContext).value=el.value||null;}));
 for(const [selector,k]of [['#profileTitle','title'],['#profileId','profile_id'],['#profileNotes','notes']])box.querySelector(selector).oninput=e=>edit(()=>{profile[k]=e.target.value;});
 box.querySelector('#profileView').onclick=()=>{advanced=!advanced;updateProfile(main);};
 box.querySelector('#profileSave').onclick=()=>attempt(()=>{assertProfileBoundary();profileHistory=revisionStore(profileHistory,profile,decisions);profileReadOnly=true;reviewToken=null;profileNotice='Saved immutable local revision; UNVERIFIED, not approved';cacheProfile();updateProfile(main);});
 box.querySelector('#profileBind').onclick=()=>attempt(()=>{assertProfileBoundary();if(importLocked())throw Error('Imported reference unverified; open an editable child before binding');if(!profileReadOnly)throw Error('Save Revision before binding its local reference');draft.bindings.default_profile={id:profile.profile_id,revision:profile.revision};draft.parent_revision=draft.revision;draft.revision=id();reviewToken=null;try{localStorage.setItem(KEY,encode(draft));}catch(e){profileNotice='Builder cache unavailable; export backup';}for(const n of ['id','revision'])main.querySelector('[data-builder-field="bindings.default_profile.'+n+'"]').value=draft.bindings.default_profile[n];profileNotice='Saved local reference selected; not Factory registration or owner approval';profileDiagnostics(main);});
 box.querySelector('#profileFork').onclick=()=>attempt(()=>{if(importLocked()){openMobileChild(main);return;}profile=clone(profile);profile.parent_revision=profile.revision;profile.revision=id();profileReadOnly=false;reviewToken=null;profileNotice='Editable fork; approval remains UNRESOLVED';cacheProfile();updateProfile(main);});
 box.querySelector('#profileDuplicate').onclick=()=>attempt(()=>{profile=clone(profile);profile.profile_id=id();profile.parent_revision=null;profile.revision=id();for(const b of Object.values(profile.bindings)){b.id='';b.revision='';}profileReadOnly=false;reviewToken=null;cacheProfile();updateProfile(main);});
 box.querySelector('#profileHistory').onchange=e=>attempt(()=>{if(e.target.value==='')return;profile=clone(profileHistory[Number(e.target.value)]);profileReadOnly=true;reviewToken=null;cacheProfile();updateProfile(main);});
 box.querySelector('#profileExport').onclick=()=>attempt(()=>{assertProfileBoundary();profileDownload('ea-defaultprofile-draft.json',encodeProfile(profile,decisions,profileHistory));profileNotice='Profile draft file exported; NOT_SUBMITTED';profileDiagnostics(main);});
 box.querySelector('#profileImport').onchange=async e=>{try{const f=e.target.files[0];if(!f)return;if(f.size>REQUEST_MAX)throw Error('Import too large');assertProfileBoundary();if(profileCacheRefused)throw Error('Stored revision cache refused; reload with valid cache before importing. Saved bytes preserved');const raw=await f.text(),prepared=prepareMobileImport(raw,decisions,profileHistory);assertProfileBoundary();storeMobileImport(prepared);profileNotice='Imported unverified '+(prepared.builder?'request':'profile')+'; original immutable; NOT_SUBMITTED';main.querySelector('#builderForm').remove();mount(main,catalogState,decisions);}catch(e){mobileGlobalError(main,'Import refused; current draft preserved: '+e.message);}finally{if(main.querySelector('#profileImport'))main.querySelector('#profileImport').value='';}};
 box.querySelector('#profileValidate').onclick=()=>attempt(()=>{const val=validateProfile(profile,decisions);box.querySelector('#profileReviewSummary').innerHTML='<h4>Required validation</h4><pre>'+esc(JSON.stringify(val,null,2))+'</pre>';profileDiagnostics(main);});
 box.querySelector('#profileReview').onclick=()=>attempt(()=>{assertProfileBoundary();const model=mobileReviewModel(profile,draft,decisions,profileHistory);if(!model.summary.validation.type_valid)mobileFocusError(main,true);box.querySelector('#profileReviewSummary').innerHTML=mobileReviewHTML(model);reviewToken=model.summary.validation.type_valid?JSON.stringify({profile,builder:draft}):null;box.querySelector('#profileConfirm').disabled=!model.summary.validation.type_valid;box.querySelector('#profileConfirm').checked=false;profileDiagnostics(main);});
 box.querySelector('#profileConfirm').onchange=()=>profileDiagnostics(main);
 box.querySelector('#profileSend').onclick=()=>attempt(()=>{assertProfileBoundary();if(reviewToken!==JSON.stringify({profile,builder:draft}))throw Error('Snapshot changed; Review Summary again');const request=makeRequest(profile,draft,decisions,box.querySelector('#profilePending').checked,box.querySelector('#profileConfirm').checked,profileHistory);profileDownload('ea-defaultprofile-request-NOT_SUBMITTED.json',JSON.stringify(request,null,2));profileNotice='เตรียมไฟล์คำขอแล้ว; ตรวจสอบไฟล์ที่เบราว์เซอร์บันทึก — NOT_SUBMITTED. No intake or activation.';profileDiagnostics(main);});
 if(reviewToken===JSON.stringify({profile,builder:draft})){box.querySelector('#profileReviewSummary').innerHTML=mobileReviewHTML(mobileReviewModel(profile,draft,decisions,profileHistory));box.querySelector('#profileConfirm').disabled=false;}
 mt5UxLayout(main);profileDiagnostics(main);mobileImportControls(main);if(focus){const el=box.querySelector('[data-profile-value="'+focus+'"]');if(el){el.focus();if(typeof selection==='number'&&el.tagName==='INPUT')el.setSelectionRange(selection,selection);}}
}

// Presentation state deliberately never enters the accepted draft/request schemas.
let mobileStep='start',mobileGuided=null;
function mobileSteps(v){return [{id:'start',label:'เริ่มต้น'},{id:'idea',label:'ไอเดียของ EA'},...v.groups.map(g=>({id:g.id,label:'ตั้งค่า EA · '+g.label})),{id:'entry',label:'เงื่อนไขเข้า EA'},{id:'instance',label:'เจ้าของ instance'},{id:'context',label:'บริบทของ EA'},{id:'review',label:'ตรวจทาน EA นี้'},{id:'request',label:'ส่งคำขอของ EA นี้'}];}
function reviseMobile(p,bd,v,history){
 const nextHistory=revisionStore(history,p,v),next=clone(p),builder=clone(bd);
 validate(builder);next.parent_revision=p.revision;next.revision=id();
 builder.parent_revision=bd.revision;builder.revision=id();builder.bindings.default_profile=binding();
 return {profile:next,builder,history:nextHistory};
}
function mobileOpenDetails(el){for(let p=el?.parentElement;p;p=p.parentElement)if(p.tagName==='DETAILS')p.open=true;}
let mobileRevealSerial=0;
async function mobileReveal(el,center=false){
 const serial=++mobileRevealSerial,body=document.body;
 // Rectangles and scroll deltas use viewport CSS coordinates, including browser zoom.
 mobileOpenDetails(el);
 const target=el.id==='mobileChrome'?el.querySelector('h2'):el;
 if(!target)return;
 body.dataset.mobileReveal='pending';
 const frame=()=>new Promise(resolve=>requestAnimationFrame(resolve));
 const space=()=>{const v=window.visualViewport,lo=v?.offsetTop||0,hi=lo+(v?.height||innerHeight);
  const h=document.querySelector('.topbar'),bar=document.querySelector('#mobileBar');
  let top=lo,bottom=hi;
  for(const [node,edge]of [[h,'top'],[bar,'bottom']]){if(!node||node.hidden)continue;const r=node.getBoundingClientRect();
   if(!['sticky','fixed'].includes(getComputedStyle(node).position)||r.bottom<=lo||r.top>=hi)continue;
   if(edge==='top')top=Math.max(top,r.bottom);else bottom=Math.min(bottom,r.top);
  }return {top,bottom};};
 body.classList.remove('mobile-chrome-flow');
 const header=document.querySelector('.topbar'),bar=document.querySelector('#mobileBar'),error=target.getAttribute('aria-describedby');
 const context=error?document.getElementById(error)?.getBoundingClientRect().height||0:0;
 const occupied=(header?.getBoundingClientRect().height||0)+(bar&&!bar.hidden&&getComputedStyle(bar).position==='sticky'?bar.getBoundingClientRect().height:0);
 if(occupied+target.getBoundingClientRect().height+context+32>(window.visualViewport?.height||innerHeight))body.classList.add('mobile-chrome-flow');
 target.scrollIntoView({block:center?'center':'start',inline:'nearest',behavior:'instant'});
 for(let i=0;i<2;i++){
  await frame();if(serial!==mobileRevealSerial||!target.isConnected)return;
  const r=target.getBoundingClientRect(),{top,bottom}=space();
  if(r.top>=top+8&&r.bottom<=bottom-8)break;
  const dest=center?top+Math.max(8,(bottom-top-r.height)/2):top+8;
  window.scrollBy({top:r.top-dest,behavior:'instant'});
 }
 await frame();if(serial!==mobileRevealSerial||!target.isConnected)return;
 const r=target.getBoundingClientRect(),limits=space();
 if(r.top<limits.top||r.bottom>limits.bottom){body.classList.add('mobile-chrome-flow');target.scrollIntoView({block:'center',inline:'nearest',behavior:'instant'});await frame();}
 if(serial===mobileRevealSerial)body.dataset.mobileReveal='settled';
}
function mobileFocusError(main,all=false){
 if(!decisions||!profile)return false;
 const candidates=allSlots(profile).filter(s=>all||main.querySelector('[data-profile-row="'+s.name+'"]')?.closest('[data-mobile-section]')?.dataset.mobileSection===mobileStep);
 for(const s of candidates){const row=decisions.rows.find(r=>r.name===s.name);try{valueCheck(row,s.value);}catch(e){
  if(!main.querySelector('[data-profile-value="'+s.name+'"]'))advanced=true;
  mobileStep=row.scope==='SHARED'?row.group:row.scope==='ENTRY'?'entry':'instance';updateProfile(main);
  const el=main.querySelector('[data-profile-value="'+s.name+'"]'),status=main.querySelector('[data-profile-status="'+s.name+'"]');
  if(el){mobileOpenDetails(el);el.setAttribute('aria-invalid','true');if(status){status.id='mobileFieldError';status.textContent=e.message;el.setAttribute('aria-describedby',status.id);}el.focus({preventScroll:true});mobileReveal(el,true);}return true;
 }}return false;
}
function mobileLayout(main){
 const form=main.querySelector('#builderForm'),box=main.querySelector('#profileWorkflow');if(!form||!box||!decisions||!profile||!box.querySelector('#profileTitle'))return;
 if(mobileGuided===null)mobileGuided=true;
 form.dataset.currentWorkspace='one-ea';
 const steps=mobileSteps(decisions);if(!steps.some(s=>s.id===mobileStep))mobileStep='start';
 let chrome=form.querySelector('#mobileChrome');if(!chrome){chrome=document.createElement('section');chrome.id='mobileChrome';form.prepend(chrome);}
 chrome.innerHTML='<h2>EA ที่กำลังตั้งค่า</h2><p id="mobileCurrentName">'+esc(draft.title||'ยังไม่ได้ตั้งชื่อ EA')+'</p><p>ร่างในเบราว์เซอร์ · <strong>NOT_SUBMITTED</strong> · ยังไม่ส่งและไม่เริ่มทำงาน</p><p>ค่าที่เสนอและค่าอ้างอิงยังไม่ผ่านการยืนยัน ความเสี่ยงและค่าเริ่มต้นที่ยังไม่ตัดสินใจต้องตรวจทาน ผลใช้งานจริง UNKNOWN</p><details id="mobileWorkspaceActions" '+(mobileStep==='start'?'open':'')+'><summary>เลือกงาน · สร้างใหม่ / เปิดงานเดิม</summary><button class="btn primary" id="mobileNew">สร้าง EA ใหม่</button><button class="btn" id="mobileResume">เปิดงานเดิม / ทำต่อจากร่าง</button><button class="btn" id="mobileOpen">นำเข้าไฟล์งานเดิม</button><div id="mobileNewPrompt" hidden><p>ดาวน์โหลดสำรองก่อนแทนที่ร่างปัจจุบัน ประวัติที่บันทึกแล้วจะยังอยู่</p><button class="btn" id="mobileBackupBeforeNew">ดาวน์โหลดสำรองร่างปัจจุบัน</button><button class="btn" id="mobileConfirmNew">ยืนยันสร้าง EA ใหม่</button></div></details><div id="mobileStart" '+(mobileGuided&&mobileStep==='start'?'':'hidden')+'><p>ตั้งค่า EA ครั้งละตัว เลือกทำต่อจากร่าง หรือเปิดไฟล์งานเดิมเพื่อสร้างฉบับใหม่</p></div><details id="mobileDetails" '+(!mobileGuided?'open':'')+'><summary>รายละเอียด / ประวัติ</summary><p>เครื่องมือและข้อมูลอ้างอิงของ EA ตัวปัจจุบัน ไม่ใช่ workspace เพิ่มเติม</p><button class="btn" id="mobileMode">'+(mobileGuided?'แสดงทุกช่อง':'เปิดขั้นตอนทีละหน้า')+'</button></details><details id="mobileIndex"><summary>เลือกขั้นตอน</summary><nav aria-label="ขั้นตอนของ EA">'+steps.map(s=>'<button class="btn" data-mobile-go="'+esc(s.id)+'" '+(s.id===mobileStep?'aria-current="step"':'')+'>'+esc(s.label)+'</button>').join('')+'</nav></details><h3 id="mobileStepTitle" tabindex="-1">'+esc(steps.find(s=>s.id===mobileStep).label)+'</h3>';

 const panels=[...form.querySelectorAll('.builder-grid > .panel')],profilePanel=panels[0];
 // Move existing controls, retaining their accepted event handlers and exact values.
 if(!box.querySelector('[data-mobile-section="identity"]')){
  const first=box.querySelector('[data-profile-group]'),identity=document.createElement('section');identity.dataset.mobileSection='identity';box.insertBefore(identity,box.firstChild);
  while(identity.nextSibling&&identity.nextSibling!==first)identity.append(identity.nextSibling);
  for(const g of box.querySelectorAll('[data-profile-group]'))g.dataset.mobileSection=g.dataset.profileGroup;
  const extras=[...box.querySelectorAll(':scope > .profile-group:not([data-profile-group])')];extras.forEach((el,i)=>el.dataset.mobileSection=['entry','instance','context'][i]);
  const review=document.createElement('section');review.dataset.mobileSection='review';const last=extras.at(-1);if(last){box.insertBefore(review,last.nextSibling);while(review.nextSibling)review.append(review.nextSibling);}
  const request=document.createElement('section');request.dataset.mobileSection='request';box.append(request);
  for(const selector of ['#profilePending','#profileConfirm','#profileSend']){const el=box.querySelector(selector);if(el)request.append(el.closest('label')||el);}
  request.insertAdjacentHTML('afterbegin','<h3>ส่งคำขอของ EA นี้</h3><p>ดาวน์โหลด JSON เพื่อแนบกลับในแชท — ยังไม่ได้ส่งเข้าระบบ (NOT_SUBMITTED)</p>');
  request.insertAdjacentHTML('beforeend','<button class="btn" data-review-step="review" data-review-selector="#mobileHumanReview h4">กลับไปดูข้อมูลที่ตรวจทาน</button><p>ส่งจริงยังปิดอยู่: real intake / Factory consumer ยังไม่ผ่าน qualification</p><button class="btn" disabled>ส่งจริง — ยังไม่พร้อม</button>');
 }
 const identity=box.querySelector('[data-mobile-section="identity"]');
 if(!identity.querySelector('#mobileRevise')){const b=document.createElement('button');b.id='mobileRevise';b.className='btn';b.textContent='แก้ไขเป็นฉบับใหม่';identity.prepend(b);}
 // Existing technical controls remain secondary; move nodes without cloning data or handlers.
 let technical=identity.querySelector('#mobileIdentityDetails');
 if(!technical){technical=document.createElement('details');technical.id='mobileIdentityDetails';technical.innerHTML='<summary>รายละเอียดชุดตั้งค่า / ประวัติ</summary>';identity.append(technical);for(const el of [...identity.children])if(el!==technical&&el.id!=='mobileRevise'&&!el.contains(box.querySelector('#profileNotes')))technical.append(el);}
 technical.open=!mobileGuided;
 const ideaBody=panels[1]?.querySelector('.panel-body');
 if(ideaBody){let extra=ideaBody.querySelector('#mobileIdeaDetails');if(!extra){extra=document.createElement('details');extra.id='mobileIdeaDetails';extra.innerHTML='<summary>รายละเอียดอ้างอิงของ EA</summary>';ideaBody.append(extra);for(const el of [...ideaBody.children])if(el!==extra&&!el.querySelector('[data-builder-field="title"],[data-builder-field="notes"]'))extra.append(el);}extra.open=!mobileGuided;}
 const actions={'#profileSave':'บันทึกฉบับนี้','#profileFork':'สร้างฉบับแก้ไข','#profileExport':'ดาวน์โหลดสำรองการตั้งค่า','#profileReview':'ตรวจทาน EA นี้','#profileSend':'ดาวน์โหลดคำขอของ EA นี้'};
 for(const [sel,label]of Object.entries(actions)){const el=box.querySelector(sel);if(el)el.textContent=label;}
 let bar=form.querySelector('#mobileBar');if(!bar){bar=document.createElement('nav');bar.id='mobileBar';bar.setAttribute('aria-label','นำทาง');form.append(bar);}
 bar.innerHTML='<button class="btn" id="mobileBack">ย้อนกลับ</button><button class="btn" id="mobileSave">บันทึกร่าง</button><button class="btn primary" id="mobileNext">ถัดไป</button>';
 const show=()=>{
  form.classList.toggle('mobile-guided',mobileGuided);chrome.querySelector('#mobileIndex').hidden=!mobileGuided;chrome.querySelector('#mobileStepTitle').hidden=!mobileGuided;bar.hidden=!mobileGuided;
  for(const el of box.querySelectorAll('[data-mobile-section]'))el.hidden=mobileGuided&&!(el.dataset.mobileSection===mobileStep||(el.dataset.mobileSection==='identity'&&mobileStep===decisions.groups[0].id));
  panels.forEach((el,i)=>el.hidden=mobileGuided&&(i===0?['start','idea'].includes(mobileStep):i===1?mobileStep!=='idea':true));
  if(profilePanel){for(const el of profilePanel.querySelector('.panel-body').children)if(el!==box)el.hidden=mobileGuided;profilePanel.querySelector('.panel-head').hidden=mobileGuided;}
  for(const el of [...form.children])if(![chrome,bar].includes(el)&&!el.classList.contains('builder-grid'))el.hidden=mobileGuided;
  // Keep status reachable in every step without making navigation a schema edit.
  let status=chrome.querySelector('#mobileStatus');if(!status){status=document.createElement('p');status.id='mobileStatus';status.setAttribute('role','status');status.tabIndex=-1;chrome.append(status);}status.textContent=profileNotice||'ข้อมูลร่างในเครื่องเท่านั้น · การอนุมัติ UNRESOLVED';
  bar.querySelector('#mobileBack').disabled=mobileStep==='start';bar.querySelector('#mobileNext').disabled=mobileStep==='request';
 };
 const go=step=>{mobileStep=step;mobileLayout(main);main.querySelector('#mobileStepTitle').focus({preventScroll:true});mobileReveal(main.querySelector('#mobileChrome'));};
 chrome.querySelector('#mobileMode').onclick=()=>{mobileGuided=!mobileGuided;mobileLayout(main);};
 chrome.querySelectorAll('[data-mobile-go]').forEach(el=>el.onclick=()=>go(el.dataset.mobileGo));
 chrome.querySelector('#mobileResume').onclick=()=>go('idea');
 chrome.querySelector('#mobileOpen').onclick=()=>{go(decisions.groups[0].id);mobileOpenDetails(main.querySelector('#profileImport'));main.querySelector('#profileImport').click();};
 chrome.querySelector('#mobileNew').onclick=()=>{chrome.querySelector('#mobileNewPrompt').hidden=false;};
 chrome.querySelector('#mobileBackupBeforeNew').onclick=()=>{box.querySelector('#profileExport').click();main.querySelector('#builderExport').click();};
 chrome.querySelector('#mobileConfirmNew').onclick=()=>{try{assertProfileBoundary();if(profileCacheRefused)throw Error('Refused cache preserved');draft=newDraft();profile=newProfile(decisions);profileReadOnly=false;reviewToken=null;localStorage.setItem(KEY,encode(draft));cacheProfile();mobileStep='idea';form.remove();mount(main,catalogState,decisions);}catch(e){profileNotice=e.message;mobileLayout(main);}};
 box.querySelector('#mobileRevise').onclick=()=>{try{openMobileChild(main);}catch(e){mobileGlobalError(main,e.message);}};
 bar.querySelector('#mobileBack').onclick=()=>go(steps[Math.max(0,steps.findIndex(s=>s.id===mobileStep)-1)].id);
 bar.querySelector('#mobileNext').onclick=()=>{if(mobileFocusError(main))return;go(steps[Math.min(steps.length-1,steps.findIndex(s=>s.id===mobileStep)+1)].id);};
 bar.querySelector('#mobileSave').onclick=()=>{if(mobileFocusError(main,true))return;box.querySelector('#profileSave').click();};
 show();
}


// MT5-like owner presentation. This state is presentation-only and never enters
// the accepted Builder/Profile request schemas.
const MT5UX_KEY='ea_lab.builder.mt5ux.presentation.v1';
const MT5UX_SIMPLE_NAMES=Object.freeze([
 '_41_FixedLot','_42_RiskPct','FirstLotMode','LotProg','_53_PlusLot',
 '_9_MaxLevels','_9_StepUseATR','_9_StepATRmult','_0_ATR_Period',
 'ExitMode','_21_TP_Pip','_22_TP_ATRmult','SLMode','_33_SL_ATRmult',
 '_0_MaxSpread','_0_Slippage','ProtectLevel','RC_AcctDDLimitPct','RC_MaxLot',
 'HedgeMode','_MG_SelfGate','_22_DisplacementBodyFraction','_22_WickBodyRatio'
]);
let mt5UxState=null;
function mt5UxLoad(){
 if(mt5UxState)return mt5UxState;
 mt5UxState={tab:'inputs',mode:'simple',query:'',symbol:'XAUUSD',timeframe:'M15',preset:'Current draft',optimization:{}};
 try{
  const raw=localStorage.getItem(MT5UX_KEY),parsed=raw?JSON.parse(raw):null;
  if(parsed&&typeof parsed==='object'){
   for(const k of ['tab','mode','query','symbol','timeframe','preset'])if(typeof parsed[k]==='string')mt5UxState[k]=parsed[k];
   if(parsed.optimization&&typeof parsed.optimization==='object'&&!Array.isArray(parsed.optimization))mt5UxState.optimization=parsed.optimization;
  }
 }catch(e){}
 if(!['inputs','optimization','review'].includes(mt5UxState.tab))mt5UxState.tab='inputs';
 if(!['simple','all'].includes(mt5UxState.mode))mt5UxState.mode='simple';
 return mt5UxState;
}
function mt5UxSave(){try{localStorage.setItem(MT5UX_KEY,JSON.stringify(mt5UxState));}catch(e){}}
function mt5UxGroupLabel(id){return decisions?.groups?.find(g=>g.id===id)?.label||({ENTRY_CONTRACT:'Entry',PROFILE_IDENTITY:'Execution'}[id]||id||'Other');}
function mt5UxSlot(name){return profile?allSlots(profile).find(s=>s.name===name):null;}
function mt5UxReference(row){return row.source_proposal_literal!==null&&row.source_proposal_literal!==undefined?row.source_proposal_literal:(row.source_value??'');}
function mt5UxValue(row){const slot=mt5UxSlot(row.name);return slot?.value===null||slot?.value===undefined?String(mt5UxReference(row)):String(slot.value);}
function mt5UxEnumOptions(row){
 const field=catalogState?.wrappers?.find(w=>w.build==='B22')?.fields?.find(f=>f.name===row.name);
 if(row.type==='bool')return [['true','ON'],['false','OFF']];
 return (field?.enum_explanations||[]).map(e=>[e.symbol,e.meaning+' — '+e.symbol]);
}
function mt5UxControl(row){
 const value=mt5UxValue(row),opts=mt5UxEnumOptions(row),slot=mt5UxSlot(row.name),refOnly=slot?.value===null||slot?.value===undefined;
 const title=refOnly?'ค่าอ้างอิงต้นทาง — ยังไม่ใช่ owner-approved/effective value':'ค่าที่เสนอโดยเจ้าของ';
 if(opts.length)return '<select class="mt5-param-input" data-mt5-value="'+esc(row.name)+'" title="'+esc(title)+'">'+opts.map(([v,l])=>'<option value="'+esc(v)+'" '+(v===value?'selected':'')+'>'+esc(l)+'</option>').join('')+'</select>';
 return '<input class="mt5-param-input" data-mt5-value="'+esc(row.name)+'" value="'+esc(value)+'" inputmode="'+(row.type==='double'?'decimal':row.type==='int'?'numeric':'text')+'" title="'+esc(title)+'">';
}
function mt5UxVisibleRows(){
 const s=mt5UxLoad(),q=s.query.trim().toLowerCase(),simple=new Set(MT5UX_SIMPLE_NAMES);
 return (decisions?.rows||[]).filter(r=>(s.mode==='all'||simple.has(r.name))&&(!q||[r.label,r.name,mt5UxGroupLabel(r.group)].join(' ').toLowerCase().includes(q)));
}
function mt5UxEdit(main,row,value){
 try{
  if(profileReadOnly)throw Error('ฉบับที่บันทึกแล้วแก้ไขไม่ได้ — สร้างฉบับแก้ไขก่อน');
  valueCheck(row,value);
  const slot=mt5UxSlot(row.name);if(!slot)throw Error('ไม่พบ parameter '+row.name);
  slot.value=value;slot.response='VALUE_PROPOSED';slot.reason='';
  editProfile();profileNotice='แก้ไข '+row.label+' แล้ว · ยังไม่ส่ง / NOT_SUBMITTED';updateProfile(main);
 }catch(e){mobileGlobalError(main,e.message);}
}
function mt5UxResetRow(main,row){
 try{
  if(profileReadOnly)throw Error('ฉบับที่บันทึกแล้วแก้ไขไม่ได้ — สร้างฉบับแก้ไขก่อน');
  const slot=mt5UxSlot(row.name);if(!slot)throw Error('ไม่พบ parameter '+row.name);
  slot.value=null;slot.response='UNANSWERED';slot.reason='';
  editProfile();profileNotice='กลับไปใช้ค่าอ้างอิงสำหรับ '+row.label+' · ยังไม่อนุมัติ';updateProfile(main);
 }catch(e){mobileGlobalError(main,e.message);}
}
function mt5UxInputHTML(){
 const rows=mt5UxVisibleRows(),by=new Map();
 for(const r of rows){const k=mt5UxGroupLabel(r.group);if(!by.has(k))by.set(k,[]);by.get(k).push(r);}
 if(!rows.length)return '<div class="mt5-empty">ไม่พบ parameter ที่ค้นหา</div>';
 return [...by.entries()].map(([g,rs])=>'<details class="mt5-param-group" open><summary><span>'+esc(g)+'</span><small>'+rs.length+' inputs</small></summary>'+rs.map(r=>{
  const slot=mt5UxSlot(r.name),refOnly=slot?.value===null||slot?.value===undefined;
  return '<div class="mt5-param-row" data-mt5-row="'+esc(r.name)+'"><div class="mt5-param-name"><strong>'+esc(r.label)+'</strong><small>'+(refOnly?'ค่าอ้างอิง · ยังไม่อนุมัติ':'Owner proposal')+'</small></div><div class="mt5-param-control">'+mt5UxControl(r)+'</div><div class="mt5-param-unit">'+esc(r.unit||'')+'</div><button class="mt5-reset-one" data-mt5-reset="'+esc(r.name)+'" title="กลับเป็นค่าอ้างอิง" '+(refOnly?'disabled':'')+'>↺</button></div>';
 }).join('')+'</details>').join('');
}
function mt5UxOptimizationHTML(){
 const s=mt5UxLoad(),simple=new Set(MT5UX_SIMPLE_NAMES),rows=(decisions?.rows||[]).filter(r=>s.mode==='all'||simple.has(r.name)).slice(0,25);
 if(!rows.length)return '<div class="mt5-empty">เลือก Simple หรือค้นหา parameter ก่อน</div>';
 return '<div class="mt5-opt-note">แผน Optimization หน้านี้เป็น UI-local / OFF_DRAFT_UNVERIFIED เท่านั้น ยังไม่ส่งให้ optimizer และไม่เปิด execution</div><div class="mt5-opt-wrap"><table class="mt5-opt-table"><thead><tr><th>Optimize</th><th>Parameter</th><th>Value</th><th>Start</th><th>Step</th><th>Stop</th></tr></thead><tbody>'+rows.map(r=>{
  const o=s.optimization[r.name]||{},checked=!!o.enabled;
  return '<tr><td><input type="checkbox" data-mt5-opt="'+esc(r.name)+'" data-k="enabled" '+(checked?'checked':'')+'></td><td><strong>'+esc(r.label)+'</strong><small>'+esc(r.name)+'</small></td><td>'+esc(mt5UxValue(r))+'</td>'+['start','step','stop'].map(k=>'<td><input data-mt5-opt="'+esc(r.name)+'" data-k="'+k+'" value="'+esc(o[k]||'')+'" placeholder="—"></td>').join('')+'</tr>';
 }).join('')+'</tbody></table></div>';
}
function mt5UxReviewHTML(main){
 let validation;try{validation=validateProfile(profile,decisions);}catch(e){validation={type_valid:false,decision_complete:false,errors:[e.message],missing:[]};}
 const proposed=(decisions?.rows||[]).filter(r=>mt5UxSlot(r.name)?.value!==null),opt=Object.entries(mt5UxLoad().optimization).filter(([,v])=>v?.enabled);
 const proposedHTML=proposed.length?proposed.map(r=>'<div class="mt5-review-line"><span>'+esc(r.label)+'</span><strong>'+esc(mt5UxSlot(r.name).value)+'</strong></div>').join(''):'<p class="mt5-muted">ยังไม่มีค่าที่แก้ไขจาก reference</p>';
 const optHTML=opt.length?opt.map(([name,o])=>{const r=decisions.rows.find(x=>x.name===name);return '<div class="mt5-review-line"><span>'+esc(r?.label||name)+'</span><strong>'+esc(o.start||'—')+' → '+esc(o.stop||'—')+' / step '+esc(o.step||'—')+'</strong></div>';}).join(''):'<p class="mt5-muted">Optimization OFF</p>';
 const confirm=main.querySelector('#profileConfirm'),pending=main.querySelector('#profilePending'),send=main.querySelector('#profileSend');
 return '<div class="mt5-review-hero"><h2>ตรวจทาน EA</h2><strong>B22</strong> · '+esc(mt5UxState.symbol)+' / '+esc(mt5UxState.timeframe)+'<p>สถานะ <b>NOT_SUBMITTED</b> · Real Submit / Factory / MT5 ยังปิด</p></div><div class="mt5-review-grid"><section><h3>Inputs ที่เสนอ</h3>'+proposedHTML+'</section><section><h3>Optimization</h3>'+optHTML+'</section></div><div class="mt5-review-status"><b>ตรวจข้อมูล:</b> '+(validation.type_valid?'ชนิดข้อมูลผ่าน':'มีค่าที่ไม่ถูกต้อง')+' · unresolved '+(validation.missing?.length||0)+' รายการ'+(profileReadOnly?' · Saved immutable revision':' · Working draft')+'</div><div class="mt5-review-actions"><button class="btn" id="mt5ReviewExact">ตรวจทาน snapshot นี้</button><label><input type="checkbox" id="mt5Pending" '+(pending?.checked?'checked':'')+'> ยังมีรายการที่ต้องช่วยตัดสินใจ / ส่งแบบ PENDING_DECISIONS</label><label><input type="checkbox" id="mt5Confirm" '+(confirm?.checked?'checked':'')+' '+(confirm?.disabled?'disabled':'')+'> ยืนยัน snapshot ที่ตรวจทานแล้ว</label><button class="btn primary" id="mt5Download" '+(send?.disabled?'disabled':'')+'>ดาวน์โหลดคำขอ — NOT_SUBMITTED</button></div>';
}
function mt5UxLayout(main){
 const form=main.querySelector('#builderForm'),box=main.querySelector('#profileWorkflow');if(!form||!box||!decisions||!profile)return;
 const s=mt5UxLoad();form.classList.add('mt5-ux-active');form.dataset.currentWorkspace='mt5-like';
 form.querySelector('#mt5UxRoot')?.remove();
 const root=document.createElement('section');root.id='mt5UxRoot';root.className='mt5-ux';
 root.innerHTML='<header class="mt5-ux-head"><div><h1>EA Builder</h1><p>ตั้งค่า EA แบบเดียวกับ MT5 · ข้อมูลเทคนิคซ่อนไว้ด้านหลัง</p></div><div class="mt5-head-actions"><span class="mt5-status">NOT_SUBMITTED</span><button class="btn" id="mt5SaveRevision">บันทึก Revision</button></div></header><section class="mt5-selector"><label>EA / Strategy<select id="mt5Strategy"><option>B22</option></select></label><label>Symbol<select id="mt5Symbol">'+['XAUUSD','EURUSD','GBPUSD','EURGBP','USDJPY','EURJPY','BTCUSD','ETHUSD'].map(v=>'<option '+(v===s.symbol?'selected':'')+'>'+v+'</option>').join('')+'</select></label><label>Timeframe<select id="mt5Timeframe">'+['M5','M15','H1','H4','D1'].map(v=>'<option '+(v===s.timeframe?'selected':'')+'>'+v+'</option>').join('')+'</select></label><label>Preset<select id="mt5Preset">'+['Current draft','Source references'].map(v=>'<option '+(v===s.preset?'selected':'')+'>'+v+'</option>').join('')+'</select></label></section><p class="mt5-context-note">Symbol/Timeframe/Preset ในรุ่นนี้เป็น presentation context เท่านั้น จนกว่าจะมี contract ผูกเข้ากับ request schema; ไม่มี execution เกิดขึ้น</p><div class="mt5-tabs-row"><nav class="mt5-tabs">'+[['inputs','Inputs'],['optimization','Optimization'],['review','Review']].map(([k,l])=>'<button class="mt5-tab '+(s.tab===k?'active':'')+'" data-mt5-tab="'+k+'">'+l+'</button>').join('')+'</nav><div class="mt5-modes"><button class="mt5-mode '+(s.mode==='simple'?'active':'')+'" data-mt5-mode="simple">Simple (แนะนำ)</button><button class="mt5-mode '+(s.mode==='all'?'active':'')+'" data-mt5-mode="all">All Inputs ('+(decisions.rows?.length||'UNKNOWN')+')</button></div></div><section class="mt5-workspace"><div class="mt5-main"><div id="mt5TabInputs" '+(s.tab==='inputs'?'':'hidden')+'><div class="mt5-toolbar"><input id="mt5Search" value="'+esc(s.query)+'" placeholder="ค้นหา parameter... Risk, Grid, TP, ATR"><span>'+(s.mode==='simple'?mt5UxVisibleRows().length:'153')+' แสดงอยู่</span></div><div id="mt5Rows">'+mt5UxInputHTML()+'</div></div><div id="mt5TabOptimization" '+(s.tab==='optimization'?'':'hidden')+'>'+mt5UxOptimizationHTML()+'</div><div id="mt5TabReview" '+(s.tab==='review'?'':'hidden')+'>'+mt5UxReviewHTML(main)+'</div></div><aside class="mt5-side"><section><h3>EA ปัจจุบัน</h3><div><span>EA</span><strong>B22</strong></div><div><span>Symbol</span><strong>'+esc(s.symbol)+'</strong></div><div><span>Timeframe</span><strong>'+esc(s.timeframe)+'</strong></div><div><span>Preset</span><strong>'+esc(s.preset)+'</strong></div></section><section class="mt5-good"><h3>Input Catalog</h3><p>B22 · '+esc(decisions.rows.length)+' inputs ถูกโหลดจาก catalog/decision metadata เดิม</p><p>ค่าที่ไม่ได้แก้ไขยังเป็น source reference ไม่ใช่ owner approval</p></section><section class="mt5-warn"><h3>Real Submit ยังไม่เปิด</h3><p>ไฟล์ยังเป็น NOT_SUBMITTED และไม่เปิด Factory / MT5</p></section><details id="mt5Technical"><summary>รายละเอียดทางเทคนิค / ประวัติ</summary><p>Profile '+esc(profile.profile_id)+' / '+esc(profile.revision)+'</p><p>Builder '+esc(draft.revision)+'</p><button class="btn" id="mt5ToggleLegacy">เปิดเครื่องมือเทคนิคเดิม</button></details></aside></section><div class="mt5-bottom"><button class="btn" id="mt5Fork">'+(profileReadOnly?'สร้างฉบับแก้ไข':'ฉบับนี้กำลังแก้ไข')+'</button><button class="btn primary" id="mt5GoReview">ตรวจทาน EA →</button></div>';
 form.insertBefore(root,form.firstChild);
 const rerender=()=>{mt5UxSave();mt5UxLayout(main);};
 root.querySelectorAll('[data-mt5-tab]').forEach(b=>b.onclick=()=>{s.tab=b.dataset.mt5Tab;rerender();});
 root.querySelectorAll('[data-mt5-mode]').forEach(b=>b.onclick=()=>{s.mode=b.dataset.mt5Mode;rerender();});
 root.querySelector('#mt5Search').oninput=e=>{s.query=e.target.value;mt5UxSave();const rows=root.querySelector('#mt5Rows');if(rows)rows.innerHTML=mt5UxInputHTML();mt5UxBindRows(main,root);};
 root.querySelector('#mt5Symbol').onchange=e=>{s.symbol=e.target.value;rerender();};
 root.querySelector('#mt5Timeframe').onchange=e=>{s.timeframe=e.target.value;rerender();};
 root.querySelector('#mt5Preset').onchange=e=>{s.preset=e.target.value;rerender();};
 root.querySelector('#mt5SaveRevision').onclick=()=>box.querySelector('#profileSave')?.click();
 root.querySelector('#mt5Fork').onclick=()=>{if(profileReadOnly)box.querySelector('#profileFork')?.click();};
 root.querySelector('#mt5GoReview').onclick=()=>{s.tab='review';rerender();};
 root.querySelector('#mt5ToggleLegacy').onclick=()=>{form.classList.toggle('mt5-tech-open');root.querySelector('#mt5ToggleLegacy').textContent=form.classList.contains('mt5-tech-open')?'ซ่อนเครื่องมือเทคนิคเดิม':'เปิดเครื่องมือเทคนิคเดิม';};
 mt5UxBindRows(main,root);mt5UxBindOptimization(root);
 const review=root.querySelector('#mt5ReviewExact');if(review)review.onclick=()=>{box.querySelector('#profileReview')?.click();s.tab='review';rerender();};
 const pending=root.querySelector('#mt5Pending');if(pending)pending.onchange=()=>{const old=box.querySelector('#profilePending');if(old){old.checked=pending.checked;profileDiagnostics(main);}rerender();};
 const confirm=root.querySelector('#mt5Confirm');if(confirm)confirm.onchange=()=>{const old=box.querySelector('#profileConfirm');if(old){old.checked=confirm.checked;profileDiagnostics(main);}rerender();};
 const download=root.querySelector('#mt5Download');if(download)download.onclick=()=>box.querySelector('#profileSend')?.click();
}
function mt5UxBindRows(main,root){
 root.querySelectorAll('[data-mt5-value]').forEach(el=>el.onchange=()=>{const row=decisions.rows.find(r=>r.name===el.dataset.mt5Value);if(row)mt5UxEdit(main,row,el.value);});
 root.querySelectorAll('[data-mt5-reset]').forEach(el=>el.onclick=()=>{const row=decisions.rows.find(r=>r.name===el.dataset.mt5Reset);if(row)mt5UxResetRow(main,row);});
}
function mt5UxBindOptimization(root){
 const s=mt5UxLoad();
 root.querySelectorAll('[data-mt5-opt]').forEach(el=>el.oninput=()=>{const name=el.dataset.mt5Opt,k=el.dataset.k,o=s.optimization[name]||(s.optimization[name]={enabled:false,start:'',step:'',stop:''});o[k]=k==='enabled'?el.checked:el.value;mt5UxSave();});
}

function mount(main,catalog,decision){
 if(!main.__mobileReviewHandlers){main.__mobileReviewHandlers=true;main.addEventListener('click',e=>{const link=e.target.closest('[data-review-step]');if(link){e.preventDefault();mobileReviewJump(main,{step:link.dataset.reviewStep,selector:link.dataset.reviewSelector});}});
  for(const type of ['input','change','click'])main.addEventListener(type,e=>{if(importLocked()&&e.target.closest('[data-builder-field],#builderAdd,[data-duplicate],#builderImport')){e.preventDefault();e.stopImmediatePropagation();mobileGlobalError(main,'ต้นฉบับที่นำเข้ายังแก้ไขไม่ได้ — เปิดสำเนาเพื่อแก้ไขก่อน',type==='click');}},true);
 }
const priorDecision=decisions;catalogState=catalogView(catalog);decisions=decisionView(decision,catalogState);if(decisions&&!selectedBuild)selectedBuild='B22';if(main.querySelector('#builderForm')){updateCatalog(main);if(!same(priorDecision,decisions))updateProfile(main);return;}
 if(!draft){draft=newDraft();try{const raw=localStorage.getItem(KEY);if(raw)draft=parse(raw);storageState='Browser-local draft cache';}catch(e){error='Stored draft unavailable: '+e.message;storageState='Cache unavailable; use JSON export';}}
 function save(){try{localStorage.setItem(KEY,encode(draft));storageState='Saved browser-local; UNVERIFIED';}catch(e){storageState='Cache unavailable; use JSON export';}main.querySelector('#builderStorage').textContent=storageState;const current=main.querySelector('#mobileCurrentName');if(current)current.textContent=draft.title||'ยังไม่ได้ตั้งชื่อ EA';}
 function changed(){reviewToken=null;const confirm=main.querySelector('#profileConfirm');if(confirm){confirm.checked=false;confirm.disabled=true;main.querySelector('#profileSend').disabled=true;}draft.parent_revision=draft.revision;draft.revision=id();save();main.querySelector('#builderRevision').textContent=draft.revision;main.querySelector('#builderDiagnostic').textContent='Edited draft; validate again. Submission and execution disabled.';}
 const field=(label,key,value,type='input')=>'<label class="builder-field">'+esc(label)+(type==='textarea'?'<textarea maxlength="20000" data-builder-field="'+key+'">'+esc(value)+'</textarea>':'<input maxlength="20000" data-builder-field="'+key+'" value="'+esc(value)+'">')+'</label>';
 function draw(){main.innerHTML='<section id="builderForm" class="builder"><div class="shell-head"><div><h1>EA Builder</h1><p>Design and export an owner draft · no submission or execution</p></div></div><div class="notice">'+(location.protocol==='file:'?'OFFLINE HTML · ':'')+'Catalog UNRESOLVED · Input population UNKNOWN · Compatibility UNKNOWN. '+(decisions?'Profile proposals editable; approval and effective configuration UNRESOLVED.':'Approved shared settings remain locked.')+'</div><div class="builder-toolbar"><button class="btn" id="builderValidate">Validate draft</button><button class="btn" id="builderExport">Export draft JSON</button><label class="btn">Import draft JSON<input id="builderImport" type="file" accept=".json,application/json"></label><button class="btn primary" id="builderReview">Export review proposal — NOT_SUBMITTED</button><button class="btn" disabled>Submit disabled</button></div><p id="builderStorage" role="status">'+esc(storageState)+'</p><p id="builderDiagnostic" role="status">'+esc(error||'Draft only; audited catalog not bound.')+'</p><div class="builder-grid"><section class="panel"><header class="panel-head"><h2>Default Profiles</h2></header><div class="panel-body">'+field('Profile reference ID (unverified)','bindings.default_profile.id',draft.bindings.default_profile.id)+field('Profile revision','bindings.default_profile.revision',draft.bindings.default_profile.revision)+'<fieldset disabled><legend>Shared settings — UNRESOLVED / LOCKED</legend><label>MM / grid / exit / SL / risk / modules<input value="Owner or approved inherited profile required"></label></fieldset><p>Source defaults are not supplied or approved here.</p><div id="profileWorkflow"></div></div></section><section class="panel"><header class="panel-head"><h2>Design EA</h2></header><div class="panel-body">'+field('Draft title','title',draft.title)+field('Design notes','notes',draft.notes,'textarea')+'<label class="builder-field">Intent<select data-builder-field="intent">'+INTENTS.map(v=>'<option '+(v===draft.intent?'selected':'')+'>'+v+'</option>').join('')+'</select></label><p>ENTRY_ONLY · shared controls locked. BUILD_AND_BASELINE stops after baseline; M1 runs nothing.</p>'+['template_release','entry_contract','test_plan'].map(k=>field(k+' reference ID (unverified)','bindings.'+k+'.id',draft.bindings[k].id)+field(k+' revision','bindings.'+k+'.revision',draft.bindings[k].revision)).join('')+'<p>Draft revision: <code id="builderRevision">'+esc(draft.revision)+'</code></p></div></section><section class="panel"><header class="panel-head"><h2>Optimize Strategy</h2><button class="btn" id="builderAdd">Add OFF draft</button></header><div class="panel-body"><p>Optimization OFF. No qualified tool or searchable input catalog is bound. Empty ranges and budgets may be saved as OFF drafts.</p><div id="builderPlans">'+draft.plans.map((p,index)=>'<article class="builder-plan" data-plan="'+index+'"><h3>OFF draft '+(index+1)+'</h3>'+['name','method','scope','validation','pass_budget','time_budget','resource_budget','notes'].map(k=>field(k,'plans.'+index+'.'+k,p[k],k==='notes'?'textarea':'input')).join('')+'<p>Method, scope and validation are separate unqualified proposals.</p><button class="btn" data-duplicate="'+index+'">DuplicateAsOFFDraft</button><button class="btn" data-validate-plan="'+index+'">Validate</button><button class="btn" data-results="'+index+'">OpenResults</button><p class="plan-diagnostic" role="status">OFF_DRAFT_UNVERIFIED · no approval or evidence</p></article>').join('')+'</div></div></section><section class="panel"><header class="panel-head"><h2>Requests &amp; Results</h2></header><div class="panel-body"><p>LOCAL_DRAFT_UNVERIFIED / NOT_SUBMITTED</p><p>No intake receipt, accepted run or result binding. Results UNAVAILABLE.</p><p>Export/import/copy never grants approval. Reference IDs remain owner proposals. Changing a revision requires fresh downstream review.</p></div></section></div></section>';
 main.querySelector('#builderForm').insertAdjacentHTML('beforeend','<section id="builderCatalog" class="panel panel-body"></section>');updateCatalog(main);updateProfile(main);
 main.querySelectorAll('[data-builder-field]').forEach(el=>el.addEventListener('input',()=>{const bits=el.dataset.builderField.split('.');let obj=draft;for(const k of bits.slice(0,-1))obj=obj[k];obj[bits.at(-1)]=el.value;if(bits[0]==='plans')draft.plans[Number(bits[1])].revision=id();changed();}));
 main.querySelector('#builderAdd').onclick=()=>{if(draft.plans.length>=100){error='Plan limit reached';return;}draft.plans.push(newPlan());changed();draw();};
 main.querySelectorAll('[data-duplicate]').forEach(el=>el.onclick=()=>{if(draft.plans.length>=100)return;draft.plans.push(duplicate(draft.plans[Number(el.dataset.duplicate)]));changed();draw();});
 main.querySelectorAll('[data-validate-plan]').forEach(el=>el.onclick=()=>{validate(draft);el.parentElement.querySelector('.plan-diagnostic').textContent='Valid OFF draft; incomplete fields allowed. Tool UNQUALIFIED; execution disabled.';});
 main.querySelectorAll('[data-results]').forEach(el=>el.onclick=()=>{el.parentElement.querySelector('.plan-diagnostic').textContent='Results UNAVAILABLE_NO_ACCEPTED_RUN';});
 main.querySelector('#builderValidate').onclick=()=>{try{main.querySelector('#builderDiagnostic').textContent=JSON.stringify(validate(draft));}catch(e){main.querySelector('#builderDiagnostic').textContent=e.message;}};
 const download=(name,raw)=>{const url=URL.createObjectURL(new Blob([raw],{type:'application/json'}));const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);};
 main.querySelector('#builderExport').onclick=()=>download('ea-builder-draft.json',encode(draft));
 main.querySelector('#builderReview').onclick=()=>download('ea-builder-review-NOT_SUBMITTED.json',JSON.stringify({schema:'EA_LAB_BUILDER_REVIEW_PROPOSAL_V1',status:'NOT_SUBMITTED',authority:'UNVERIFIED_PROPOSAL_ONLY',draft:JSON.parse(encode(draft)),validation:validate(draft)},null,2));
 main.querySelector('#builderImport').onchange=async e=>{try{const f=e.target.files[0];if(!f)return;if(f.size>MAX)throw Error('Import too large');const candidate=parse(await f.text());draft=candidate;error='Imported UNVERIFIED draft; NOT_SUBMITTED';save();draw();}catch(err){main.querySelector('#builderDiagnostic').textContent='Import refused; current draft preserved: '+err.message;}};
 mt5UxLayout(main);
 }
 draw();
}
return {SCHEMA,KEY,MAX,INTENTS,CATALOG,PROFILE,REQUEST,PROFILE_KEY,newDraft,newPlan,validate,parse,encode,duplicate,catalogView,mount,decisionView,newProfile,valueCheck,requiredness,validateProfile,encodeProfile,parseProfile,revisionStore,reviewSummary,makeRequest,resetProfileState,savedRevision,restoreProfileCache,mobileSteps,reviseMobile,IMPORT_KEY,prepareMobileImport,reviewTarget,mobileReviewModel,MT5UX_KEY,MT5UX_SIMPLE_NAMES};
});
