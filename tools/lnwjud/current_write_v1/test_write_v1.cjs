const fs = require('node:fs');
const path = require('node:path');
const url = process.env.EA_LAB_WRITE_V1_URL || 'http://127.0.0.1:18768/mcp';

async function rpc(payload) {
  const r = await fetch(url, {
    method: 'POST',
    headers: {'content-type':'application/json','accept':'application/json, text/event-stream'},
    body: JSON.stringify(payload)
  });
  const text = await r.text();
  const line = text.split(/\r?\n/).find((x) => x.startsWith('data:'));
  return JSON.parse(line ? line.slice(5).trim() : text);
}
let id = 0;
async function tool(name, args) {
  const x = await rpc({jsonrpc:'2.0', id:++id, method:'tools/call', params:{name, arguments:args}});
  if (x.error) throw new Error(name + ': ' + JSON.stringify(x.error));
  return x.result;
}
function body(r) { return r.content?.[0]?.text || ''; }
function assert(cond, msg) { if (!cond) throw new Error(msg); }

(async () => {
  await rpc({jsonrpc:'2.0',id:++id,method:'initialize',params:{
    protocolVersion:'2025-11-25',capabilities:{},clientInfo:{name:'write-v1-test',version:'1'}
  }});
  const listed = await rpc({jsonrpc:'2.0',id:++id,method:'tools/list',params:{}});
  const names = listed.result.tools.map((x) => x.name);
  const required = ['ea_lab_current_status','read_canonical_file','list_lanes','get_lane',
    'list_jobs','get_job','list_evidence','read_evidence','monitor_summary',
    'ea_lab_write_status','refresh_write_workspace','read_workspace_file',
    'edit_workspace_file','workspace_diff'];
  for (const name of required) assert(names.includes(name), 'missing tool: ' + name);

  const ws = await tool('ea_lab_write_status',{});
  assert(ws.structuredContent.clean === true, 'workspace must start clean');
  const root = ws.structuredContent.workspace_root;
  const initial = await tool('read_workspace_file',{path:'START_HERE.md',startLine:1,endLine:3});
  const sha0 = initial.structuredContent.file_sha256;
  const oldText = '# EA_LAB START HERE';
  const probeText = '# EA_LAB START HERE [WRITE-V1-ACCEPTANCE-PROBE]';

  const edit = await tool('edit_workspace_file',{
    operation:'replace_exact',path:'START_HERE.md',expectedSha256:sha0,oldText,newText:probeText
  });
  assert(!edit.isError, 'replace_exact positive failed');
  const sha1 = edit.structuredContent.file_sha256;
  const stale = await tool('edit_workspace_file',{
    operation:'replace_exact',path:'START_HERE.md',expectedSha256:sha0,oldText:probeText,newText:oldText
  });
  assert(stale.isError && body(stale).includes('stale file SHA256'), 'stale SHA did not fail closed');
  const reverse = await tool('edit_workspace_file',{
    operation:'replace_exact',path:'START_HERE.md',expectedSha256:sha1,oldText:probeText,newText:oldText
  });
  assert(!reverse.isError && reverse.structuredContent.file_sha256 === sha0, 'reverse did not restore exact bytes');

  const forbidden = await tool('edit_workspace_file',{
    operation:'replace_exact',path:'portfolio/ACCOUNTS.csv',expectedSha256:'0'.repeat(64),oldText:'x',newText:'y'
  });
  assert(forbidden.isError, 'sensitive path was not denied');

  const relProbe='docs/handoffs/LNWJUD_WRITE_V1_ACCEPTANCE_TEMP.md';
  const absProbe=path.join(root,...relProbe.split('/'));
  try {
    const create = await tool('edit_workspace_file',{operation:'create_new',path:relProbe,newText:'# temporary acceptance probe\n'});
    assert(!create.isError && fs.existsSync(absProbe), 'create_new positive failed');
    const dirtyRefresh = await tool('refresh_write_workspace',{});
    assert(dirtyRefresh.isError, 'refresh must refuse dirty workspace');
  } finally {
    if (fs.existsSync(absProbe)) fs.unlinkSync(absProbe);
  }

  const after = await tool('ea_lab_write_status',{});
  assert(after.structuredContent.clean === true, 'workspace not clean after acceptance cleanup');
  console.log(JSON.stringify({result:'PASS',tool_count:names.length,workspace_head:after.structuredContent.head},null,2));
})().catch((e) => { console.error(e); process.exit(1); });
