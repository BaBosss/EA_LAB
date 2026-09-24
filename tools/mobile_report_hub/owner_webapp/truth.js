/* Point-in-time display truth; transport cannot qualify source evidence. */
(function(root){'use strict';
const number=v=>typeof v==='number'&&Number.isFinite(v)?v:null;
function timestamp(v){
 if(typeof v!=='string')return null;
 const m=/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|([+-])(\d{2}):(\d{2}))$/.exec(v);
 if(!m)return null;
 const [yr,mo,day,hr,min,sec]=m.slice(1,7).map(Number);
 if(yr<1||mo<1||mo>12||day<1||hr>23||min>59||sec>59||Number(m[10]||0)>23||Number(m[11]||0)>59)return null;
 const days=new Date(Date.UTC(yr===1?2001:yr,mo,0)).getUTCDate();
 if(day>days)return null;
 const t=Date.parse(v.replace(/(\.\d{3})\d+/, '$1'));
 return Number.isFinite(t)?t:null;
}
function freshness(value,now=Date.now(),hours=26){
 const t=timestamp(value);
 if(t===null||!Number.isFinite(now))return {state:'UNKNOWN',age_hours:null};
 const age=(now-t)/36e5;
 return {state:age<0?'FUTURE':age>hours?'STALE':'CURRENT',age_hours:age<0?null:age};
}
function view(raw,now=Date.now()){
 const d=JSON.parse(JSON.stringify(raw||{}));
 if(d.schema!=='ea-lab-owner-view/1')return {truth_error:'VERSION_MISMATCH',accounts:{status:'INVALID',rows:[]},work:{status:'INVALID',rows:[]},safe_projection:{status:'INVALID'},alerts:[]};
 const s=d.safe_projection||{status:'MISSING'};
 s.freshness=s.status==='AVAILABLE'?freshness(s.generated_at,now).state:'UNKNOWN';
 d.safe_projection=s;
 d.alerts=s.status==='AVAILABLE'&&s.freshness==='CURRENT'&&Array.isArray(s.findings)?s.findings:[];
 d.finding_count=s.status==='AVAILABLE'&&s.freshness==='CURRENT'?d.alerts.filter(x=>x.state==='OPEN').length:null;
 const object=v=>v!==null&&typeof v==='object'&&!Array.isArray(v);
 if(!object(d.monitoring)||!['CURRENT','DEGRADED'].includes(d.monitoring.status)||!Array.isArray(d.monitoring.sources)||d.monitoring.sources.some(s=>!object(s))){
   d.monitoring={status:'UNAVAILABLE',sources:[]};
 }
 d.source_freshness=freshness(d.monitoring.generated_at_utc,now);
 d.capture_freshness=freshness(d.observed_at,now);
 if(d.monitoring){
   d.monitoring.freshness=d.source_freshness.state;
   for(const source of d.monitoring.sources||[]){
     source.freshness=['CURRENT','STALE'].includes(source.state)?freshness(source.observed_at_utc,now,30).state:'UNKNOWN';
   }
 }
 if(d.macro)d.macro.freshness=freshness(d.macro.time,now).state;
 if(d.control_room)d.control_room.freshness=freshness(d.control_room.generated_at,now,30).state;
 if(d.live_performance){
   const age=freshness(d.live_performance.source_mtime,now,30);
   d.live_performance.freshness=age.state;
   d.live_performance.source_age_hours=age.age_hours;
   // Producer's boolean and capture-age are historical observations only.
   d.live_performance.source_fresh=d.live_performance.freshness==='CURRENT';
 }
 for(const row of d.work?.rows||[]){
   row.freshness=freshness(row.updated_at,now,24).state;
   row.process_freshness=freshness(row.process_checked_utc,now,30/3600).state;
   if(row.process_freshness!=='CURRENT'){
     row.process_state='UNKNOWN';row.process_health='UNAVAILABLE';
     row.runner_alive=null;row.child_alive=null;row.postcondition_alive=null;
     if(['ACTIVE_PROCESS','STALLED','RECOVERY_REQUIRED'].includes(row.display_state))row.display_state='LIVENESS_UNAVAILABLE';
   }else if(['ACTIVE_PROCESS','STALLED','RECOVERY_REQUIRED'].includes(row.display_state))row.display_state='OBSERVED_'+row.display_state;
   row.progress='UNKNOWN';
 }
 return d;
}
const api={number,timestamp,freshness,view};
if(typeof module==='object'&&module.exports)module.exports=api;
root.EALabTruth=api;
})(typeof window==='object'?window:globalThis);
