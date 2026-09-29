'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const Module = require('node:module');

const IDENTITY_PATH = '/__ea_lab_loaded_source_identity_v1';

function sha256(buffer) {
  return crypto.createHash('sha256').update(buffer).digest('hex');
}

function isLoopback(address) {
  return address === '127.0.0.1' || address === '::1' || address === '::ffff:127.0.0.1';
}

function fail(message) {
  throw new Error('source-bound gateway loader: ' + message);
}

if (process.argv.length !== 4) fail('expected target path and SHA256');
const targetPath = path.resolve(process.argv[2]);
const expectedSha256 = String(process.argv[3]).toLowerCase();
if (!/^[0-9a-f]{64}$/.test(expectedSha256)) fail('expected SHA256 is malformed');

const sourceBuffer = fs.readFileSync(targetPath);
const loadedSha256 = sha256(sourceBuffer);
if (loadedSha256 !== expectedSha256) {
  fail(`target SHA256 mismatch expected=${expectedSha256} actual=${loadedSha256}`);
}

const loadedIdentity = Object.freeze({
  schema: 'ea_lab_loaded_source_identity_v1',
  source_path: targetPath,
  source_sha256: loadedSha256,
  source_bytes: sourceBuffer.length
});

const originalCreateServer = http.createServer;
http.createServer = function sourceBoundCreateServer(...args) {
  const suppliedListener = args.length > 0 && typeof args[args.length - 1] === 'function' ? args.pop() : null;
  const server = originalCreateServer.call(http, ...args);
  if (suppliedListener) {
    server.on('request', function sourceBoundRequest(req, res) {
      if (req.method === 'GET' && req.url === IDENTITY_PATH) {
        if (!isLoopback(req.socket.remoteAddress)) {
          res.writeHead(403, {'content-type':'text/plain','cache-control':'no-store'}).end('loopback only');
          return;
        }
        const body = Buffer.from(JSON.stringify(loadedIdentity), 'utf8');
        res.writeHead(200, {
          'content-type':'application/json',
          'content-length':String(body.length),
          'cache-control':'no-store'
        }).end(body);
        return;
      }
      suppliedListener(req, res);
    });
  }
  return server;
};

globalThis.__EA_LAB_LOADED_SOURCE_IDENTITY_V1 = loadedIdentity;
module.filename = targetPath;
module.paths = Module._nodeModulePaths(path.dirname(targetPath));
module._compile(sourceBuffer.toString('utf8'), targetPath);
