import path from 'node:path';
import { pathToFileURL } from 'node:url';
import fs from 'node:fs';

const root = path.resolve(process.argv[2] ?? '');
if (!root || !fs.existsSync(root)) throw new Error(`candidate root not found: ${root}`);

const required = [
  ['packages/mcp-server/dist/tool-registry.js', ['ToolRegistry']],
  ['apps/cli/dist/runtime/stdio-mcp-runtime.js', ['createStdioMcpRuntime']],
  ['packages/storage/dist/index.js', ['SqliteDatabase', 'SqliteWorkspaceRepository']],
  ['packages/workspace/dist/index.js', ['WorkspaceService']],
  ['packages/permissions/dist/index.js', ['permissionProfiles']],
];

const checked = [];
for (const [rel, names] of required) {
  const full = path.join(root, ...rel.split('/'));
  if (!fs.existsSync(full)) throw new Error(`required built module missing: ${rel}`);
  const mod = await import(pathToFileURL(full).href);
  for (const name of names) {
    if (!(name in mod)) throw new Error(`required export missing: ${rel} :: ${name}`);
  }
  checked.push({ file: rel, exports: names });
}
const permissions = await import(pathToFileURL(path.join(root, 'packages', 'permissions', 'dist', 'index.js')).href);
if (!permissions.permissionProfiles?.full) throw new Error('permissionProfiles.full missing');

process.stdout.write(JSON.stringify({
  ok: true,
  required_modules: required.length,
  checked,
  full_profile_present: true,
}));
