'use strict';
const crypto=require('node:crypto');
const fs=require('node:fs');
const path=require('node:path');
const R=require('./request_contract.cjs');
const ACTIVE_WRITER_STATES=Object.freeze(['RUNNING','REVIEW','FROZEN','INTEGRATING']);
function fileSha(p){return crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');}
function parseJson(text){try{return JSON.parse(String(text).trim());}catch{R.refuse('REGISTRY_RESPONSE_MALFORMED');}}
function validateLane(x){if(!R.object(x)||!R.id(x.lane_id)||typeof x.state!=='string'||!R.sha(x.head_sha)||typeof x.writer!=='boolean'||typeof x.runtime_lane!=='string')R.refuse('REGISTRY_RECORD_MALFORMED');return x;}
function createLaneRegistryBridge({powershellPath,scriptPath,scriptSha256,registryRoot,repoRoot,actuator}={}){
 if(typeof powershellPath!=='string'||typeof scriptPath!=='string'||typeof registryRoot!=='string'||typeof repoRoot!=='string'||!R.digest(scriptSha256))R.refuse('MALFORMED_BRIDGE_CONFIG');
 if(!path.win32.isAbsolute(powershellPath)||!path.win32.isAbsolute(scriptPath)||!path.win32.isAbsolute(registryRoot)||!path.win32.isAbsolute(repoRoot))R.refuse('MALFORMED_BRIDGE_CONFIG');
 if(!actuator||actuator.kind!=='FIXED_POWERSHELL_ACTUATOR_V1'||typeof actuator.invoke!=='function')R.refuse('UNQUALIFIED_ACTUATOR');
 if(fileSha(scriptPath)!==scriptSha256)R.refuse('REGISTRY_SCRIPT_HASH_MISMATCH');
 const base=()=>['-NoLogo','-NoProfile','-File',scriptPath];
 function invoke(extra){const result=actuator.invoke(Object.freeze({filePath:powershellPath,args:Object.freeze([...base(),...extra]),cwd:repoRoot}));
   if(!R.object(result)||!Number.isSafeInteger(result.exitCode)||typeof result.stdout!=='string'||typeof result.stderr!=='string')R.refuse('ACTUATOR_RESULT_MALFORMED');
   if(result.exitCode!==0)R.refuse('REGISTRY_REFUSED',result.stderr||result.stdout||'lane registry refused');
   return parseJson(result.stdout);
 }
 function getLane(laneId){if(!R.id(laneId))R.refuse('INVALID_ID');return validateLane(invoke(['-Command','Get','-RegistryRoot',registryRoot,'-RepoRoot',repoRoot,'-LaneId',laneId,'-Json']));}
 function listLanes(){const v=invoke(['-Command','List','-RegistryRoot',registryRoot,'-RepoRoot',repoRoot,'-Json']);if(!Array.isArray(v))R.refuse('REGISTRY_RESPONSE_MALFORMED');return v.map(validateLane);}
 function transition({laneId,expectedState,expectedHead,newState,blockerClass=''}){
   if(!R.id(laneId)||!R.sha(expectedHead))R.refuse('INVALID_IDENTITY');
   const args=['-Command','Transition','-RegistryRoot',registryRoot,'-RepoRoot',repoRoot,'-LaneId',laneId,'-ExpectedState',expectedState,'-ExpectedHead',expectedHead,'-NewState',newState,'-BlockerClass',blockerClass,'-Json'];
   return invoke(args);
 }
 return Object.freeze({kind:'LANE_REGISTRY_BRIDGE_V1',getLane,listLanes,transition,identity:Object.freeze({powershellPath,scriptPath,scriptSha256,registryRoot,repoRoot})});
}
module.exports={ACTIVE_WRITER_STATES,createLaneRegistryBridge,validateLane,fileSha};
