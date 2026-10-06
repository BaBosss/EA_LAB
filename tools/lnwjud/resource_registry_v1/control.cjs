'use strict';
const R=require('./request_contract.cjs');
const {ACTIVE_WRITER_STATES}=require('./lane_registry_bridge.cjs');
const own=(o,k)=>Object.prototype.hasOwnProperty.call(o,k)?o[k]:undefined;
function createControl({bridge,audit,nowUtc}={}){
 if(!bridge||bridge.kind!=='LANE_REGISTRY_BRIDGE_V1'||!['getLane','listLanes','transition'].every(k=>typeof bridge[k]==='function'))R.refuse('UNQUALIFIED_BRIDGE');
 if(!audit||audit.kind!=='DURABLE_AUDIT_STORE_V1'||!['withLock','get','prepare','finalize'].every(k=>typeof audit[k]==='function'))R.refuse('UNQUALIFIED_AUDIT_STORE');
 if(typeof nowUtc!=='function')R.refuse('MALFORMED_CLOCK');
 const lane=id=>bridge.getLane(R.validateRead('lane',{lane_id:id}).lane_id);
 function lease(resourceId){R.validateRead('resource',{resource_id:resourceId});const owners=bridge.listLanes().filter(x=>x.writer&&ACTIVE_WRITER_STATES.includes(x.state)&&x.runtime_lane===resourceId);
   if(owners.length===0)return Object.freeze({resource_id:resourceId,state:'FREE',owner:null});
   if(owners.length===1)return Object.freeze({resource_id:resourceId,state:'OWNED',owner:Object.freeze({lane_id:owners[0].lane_id,state:owners[0].state,head_sha:owners[0].head_sha})});
   return Object.freeze({resource_id:resourceId,state:'AMBIGUOUS',owners:Object.freeze(owners.map(x=>Object.freeze({lane_id:x.lane_id,state:x.state,head_sha:x.head_sha})))});
 }
 function verifyPre(req,current){if(current.state!==req.expected_state)R.refuse('STALE_STATE');if(current.head_sha!==req.expected_head)R.refuse('STALE_HEAD');
   if(req.operation==='request_resource_lease'){
     if(current.runtime_lane!==req.resource_id)R.refuse('RESOURCE_BINDING_MISMATCH');const l=lease(req.resource_id);if(l.state!=='FREE')R.refuse('RESOURCE_NOT_FREE');
   }else if(req.operation==='release_resource_lease'){
     if(current.runtime_lane!==req.resource_id)R.refuse('RESOURCE_BINDING_MISMATCH');const l=lease(req.resource_id);if(l.state!=='OWNED'||l.owner.lane_id!==req.lane_id)R.refuse('LEASE_OWNERSHIP_UNPROVEN');
   }else if(req.operation==='request_lane_transition'&&req.target_state==='RUNNING'&&current.runtime_lane){const l=lease(current.runtime_lane);if(l.state!=='FREE')R.refuse('RESOURCE_NOT_FREE');}
 }
 function verifyPost(req,current){if(current.state!==req.target_state||current.head_sha!==req.expected_head)R.refuse('TRANSITION_READBACK_MISMATCH');
   const resource=req.resource_id||current.runtime_lane||null;if(resource){const l=lease(resource);
     if(req.target_state==='RUNNING'){if(l.state!=='OWNED'||l.owner.lane_id!==req.lane_id)R.refuse('LEASE_READBACK_MISMATCH');}
     else if(l.state==='OWNED'&&l.owner.lane_id===req.lane_id)R.refuse('LEASE_RELEASE_READBACK_MISMATCH');
     else if(l.state==='AMBIGUOUS')R.refuse('RESOURCE_AMBIGUOUS');
   }
 }
 function receipt(req,requestHash,outcome,current){return Object.freeze({schema:'LNWJUD_RESOURCE_REGISTRY_RECEIPT_V1',request_id:req.request_id,idempotency_key:req.idempotency_key,request_sha256:requestHash,actor:req.actor,contract_sha256:req.contract_sha256,operation:req.operation,lane_id:req.lane_id,resource_id:req.resource_id,from_state:req.expected_state,to_state:req.target_state,head_sha:req.expected_head,outcome,observed_state:current.state,observed_runtime_lane:current.runtime_lane||'',completed_utc:nowUtc()});}
 function mutate(input){return audit.withLock(()=>{
   const req=R.validateMutation(input,nowUtc()),requestHash=R.hash(R.stable(req));let record=audit.get(req.idempotency_key);
   if(record){if(!R.object(record)||record.request_sha256!==requestHash)R.refuse('IDEMPOTENCY_DRIFT');if(record.status==='FINAL')return record.receipt;if(record.status!=='PREPARED')R.refuse('AUDIT_STATE_MALFORMED');
     const current=lane(req.lane_id);if(current.head_sha!==req.expected_head)R.refuse('PREPARED_REQUEST_AMBIGUOUS');
     if(current.state===req.target_state){verifyPost(req,current);const out=receipt(req,requestHash,'RECONCILED_AFTER_LOST_ACK',current);audit.finalize(req.idempotency_key,requestHash,out);const rb=audit.get(req.idempotency_key);if(!rb||rb.status!=='FINAL'||R.stable(rb.receipt)!==R.stable(out))R.refuse('AUDIT_READBACK_MISMATCH');return rb.receipt;}
     if(current.state!==req.expected_state)R.refuse('PREPARED_REQUEST_AMBIGUOUS');verifyPre(req,current);
   }else{
     const current=lane(req.lane_id);verifyPre(req,current);audit.prepare(req.idempotency_key,requestHash,Object.freeze({request:Object.freeze(JSON.parse(JSON.stringify(req))),prepared_utc:nowUtc()}));record=audit.get(req.idempotency_key);if(!record||record.status!=='PREPARED'||record.request_sha256!==requestHash)R.refuse('AUDIT_PREPARE_READBACK_MISMATCH');
   }
   bridge.transition({laneId:req.lane_id,expectedState:req.expected_state,expectedHead:req.expected_head,newState:req.target_state,blockerClass:''});
   const after=lane(req.lane_id);verifyPost(req,after);const out=receipt(req,requestHash,'APPLIED',after);audit.finalize(req.idempotency_key,requestHash,out);const rb=audit.get(req.idempotency_key);if(!rb||rb.status!=='FINAL'||R.stable(rb.receipt)!==R.stable(out))R.refuse('AUDIT_READBACK_MISMATCH');return rb.receipt;
 });}
 return Object.freeze({get_lane_current:({lane_id})=>lane(lane_id),get_resource_lease:({resource_id})=>lease(resource_id),request_resource_lease:mutate,release_resource_lease:mutate,request_lane_transition:mutate});
}
module.exports={createControl};
