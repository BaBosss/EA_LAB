"""On-demand loopback viewer; no write endpoints, scheduler, collectors or commands."""
from __future__ import annotations
import argparse, hashlib, http.server, json, pathlib, socket, sys, threading, time, urllib.parse, urllib.request, webbrowser
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from model import Model, Refused, safe_bytes, digest
APP_ID='EA_LAB_OWNER_WEBAPP_20260921'
def render(config,data):
    root=pathlib.Path(config['assets']); html=safe_bytes(root/'owner_webapp.html',root).decode('utf-8')
    css=safe_bytes(root/'owner_webapp.css',root).decode('utf-8'); js=safe_bytes(root/'owner_webapp.js',root).decode('utf-8')
    payload=json.dumps(data,ensure_ascii=False,allow_nan=False).replace('<','\\u003c').replace('\u2028','\\u2028').replace('\u2029','\\u2029')
    return html.replace('/* APP_CSS */',css).replace('/* APP_JS */',js).replace('null/* APP_DATA */',payload).encode('utf-8')
class Application:
    def __init__(self,config): self.config=config; self.lock=threading.Lock(); self.cache=None; self.cached_at=0
    def snapshot(self, force=False):
        with self.lock:
            if force or self.cache is None or time.monotonic()-self.cached_at>=30:
                fresh=Model(self.config).snapshot(); self.cache=fresh; self.cached_at=time.monotonic()
            return self.cache
    def asset(self,key):
        if len(key)!=64 or any(c not in '0123456789abcdef' for c in key): raise Refused('ASSET_ID')
        for ea in self.snapshot()['research']:
            for item in ea.get('native_graphs',{}).values():
                if not isinstance(item,dict) or item.get('state')!='AVAILABLE' or item.get('asset_sha256')!=key: continue
                href=item.get('href',''); rel=pathlib.PurePosixPath(href)
                if not href.startswith('artifacts/native/') or '..' in rel.parts or ':' in href or '\\' in href: raise Refused('ASSET_PATH')
                root=pathlib.Path(self.config['monitor']); raw=safe_bytes(root.joinpath(*rel.parts),root)
                if digest(raw)!=key: raise Refused('ASSET_HASH')
                ext=rel.suffix.lower(); mime={'.png':'image/png','.jpg':'image/jpeg','.jpeg':'image/jpeg','.gif':'image/gif','.webp':'image/webp'}.get(ext)
                if not mime: raise Refused('ASSET_TYPE')
                return raw,mime
        raise Refused('ASSET_UNAVAILABLE')
class Handler(http.server.BaseHTTPRequestHandler):
    app=None
    def _headers(self,code,mime,length):
        self.send_response(code); self.send_header('Content-Type',mime); self.send_header('Content-Length',str(length))
        self.send_header('Cache-Control','no-store'); self.send_header('X-Content-Type-Options','nosniff')
        self.send_header('Content-Security-Policy',"default-src 'self'; img-src 'self' data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'")
        self.end_headers()
    def _send(self,data,mime='application/json; charset=utf-8',code=200,body=True):
        self._headers(code,mime,len(data))
        if body: self.wfile.write(data)
    def do_GET(self):
        path=urllib.parse.urlsplit(self.path).path
        try:
            if path in ('/','/index.html'):
                data=render(self.app.config,self.app.snapshot())
                return self._send(data,'text/html; charset=utf-8')
            if path=='/api/snapshot':
                query=urllib.parse.parse_qs(urllib.parse.urlsplit(self.path).query)
                data=json.dumps(self.app.snapshot(force=query.get('refresh')==['1']),ensure_ascii=False,allow_nan=False).encode('utf-8')
                return self._send(data)
            if path=='/health':
                data=json.dumps({'app':APP_ID,'read_only':True,'status':'OK'}).encode()
                return self._send(data)
            if path=='/favicon.ico':
                return self._send(b'', 'image/x-icon', 204)
            if path.startswith('/asset/'):
                raw,mime=self.app.asset(path.removeprefix('/asset/')); return self._send(raw,mime)
            return self._send(b'not found','text/plain; charset=utf-8',404)
        except (Refused,OSError,ValueError,KeyError,json.JSONDecodeError) as e:
            data=json.dumps({'error':'READ_ONLY_SOURCE_UNAVAILABLE','reason':str(e)[:160]}).encode()
            return self._send(data,code=503)
    def do_HEAD(self): self.do_GET()
    def _reject(self):
        self._send(b'read only','text/plain; charset=utf-8',405)
    do_POST=_reject; do_PUT=_reject; do_DELETE=_reject; do_PATCH=_reject
    def log_message(self,fmt,*args): pass
class Server(http.server.ThreadingHTTPServer):
    daemon_threads=True
    allow_reuse_address=False
def config_from_args(args):
    return {'repo':args.repo,'assets':args.assets,'monitor':args.monitor,'registry':args.registry,
            'jobs':args.jobs,'leases':args.leases,'runtime':args.runtime,'snapshots':args.snapshots,
            'knowledge':args.knowledge}
def parser():
    here=pathlib.Path(__file__).resolve().parent
    p=argparse.ArgumentParser(description='EA_LAB read-only owner Monitor web app')
    p.add_argument('--repo',default='D:/EA_LAB'); p.add_argument('--assets',default=str(here))
    p.add_argument('--monitor',default='D:/EA_LAB_CONTROL/mobile_report_hub_current')
    p.add_argument('--registry',default='D:/EA_LAB_CONTROL/lanes/registry-v1')
    p.add_argument('--jobs',default='D:/EA_LAB_CONTROL/jobs')
    p.add_argument('--leases',default='D:/EA_LAB_CONTROL/runtime/chat-stall/leases')
    p.add_argument('--runtime',default='D:/EA_LAB_WORKSPACE/runtime/daily-monitor-aec3dd24-20260914')
    p.add_argument('--snapshots',default='D:/EA_LAB_WORKSPACE/runtime/daily-monitor-aec3dd24-20260914/portfolio/live_deals')
    p.add_argument('--knowledge',default='D:/EA_LAB_CONTROL/readers/second-brain/versions/8298da26f570ba30654fd31bb9bf66e53dd4051f')
    p.add_argument('--port',type=int,default=8768); p.add_argument('--no-open',action='store_true')
    p.add_argument('--offline-out'); p.add_argument('--self-test',action='store_true')
    return p
def self_test(config):
    app=Application(config); snap=app.snapshot()
    assert snap['schema']=='ea-lab-owner-view/1' and snap['app']['read_only'] is True
    assert all(a['id'].startswith('acct-') and a['label'].startswith('***') for a in snap['accounts']['rows'])
    assert all('login' not in json.dumps(a).lower() for a in snap['accounts']['rows'])
    assert snap['knowledge']['binding'] in ('HASH_VERIFIED_PINNED_READER_NOT_CURRENT_PROJECT_STATUS','UNAVAILABLE')
    assert snap['news_policy']['pre_news_min']==30.0 and snap['news_policy']['post_news_min']==15.0
    assert snap['news_policy']['effective_runtime']=='UNKNOWN'
    assert len(snap['control_room']['rows'])>0 and snap['control_room']['binding'] in ('MATCH','DIFFERENT_REPO_HEAD')
    assert len(snap['live_performance']['accounts'])>0 and snap['live_performance']['source_fresh'] is True
    assert all(a['account_id'].startswith('acct-') and a['account_label'].startswith('***') for a in snap['live_performance']['accounts'])
    assert snap['live_performance']['binding'] in ('MATCH','DIFFERENT_REPO_HEAD')
    assert sum(len(a['rows']) for a in snap['live_performance']['accounts'])>0
    html=render(config,snap); assert b'EA_LAB Monitor' in html and b'11,432' not in html
    raw_accounts=Model(config).git('show',snap['canonical_sha']+':portfolio/ACCOUNTS.csv').decode('utf-8-sig').splitlines()[1:]
    raw_ids=[line.split(',',1)[0].strip('"') for line in raw_accounts if line.strip()]
    assert all(not ident or ident.encode() not in html for ident in raw_ids)
    print(json.dumps({'result':'PASS','accounts':len(snap['accounts']['rows']),'work':len(snap['work']['rows']),
      'templates':len(snap['templates']),'knowledge':len(snap['knowledge']['documents']),'news':len(snap['news']['events']),
      'errors':snap['errors']},ensure_ascii=False))
def main():
    args=parser().parse_args(); config=config_from_args(args)
    if args.self_test: return self_test(config)
    app=Application(config)
    if args.offline_out:
        out=pathlib.Path(args.offline_out); out.parent.mkdir(parents=True,exist_ok=True)
        raw=render(config,app.snapshot()).replace(b'</head>',b'<meta name="ea-lab-mode" content="OFFLINE_SNAPSHOT"></head>')
        out.write_bytes(raw); print(str(out)); return
    with socket.socket() as probe:
        probe.settimeout(.4)
        if probe.connect_ex(('127.0.0.1',args.port))==0:
            try:
                with urllib.request.urlopen(f'http://127.0.0.1:{args.port}/health',timeout=2) as r:
                    if json.load(r).get('app')==APP_ID:
                        if not args.no_open: webbrowser.open(f'http://127.0.0.1:{args.port}/')
                        print('REUSED '+APP_ID); return
            except Exception: pass
            raise SystemExit('REFUSED: requested port is already owned by another process')
    Handler.app=app
    with Server(('127.0.0.1',args.port),Handler) as server:
        print(f'{APP_ID} read-only at http://127.0.0.1:{args.port}/')
        if not args.no_open: webbrowser.open(f'http://127.0.0.1:{args.port}/')
        try: server.serve_forever()
        except KeyboardInterrupt: pass
if __name__=='__main__': main()
