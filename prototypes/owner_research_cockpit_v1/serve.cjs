const http=require('node:http');
const fs=require('node:fs');
const path=require('node:path');
const allowed=new Set(['index.html','app.js','model.mjs','styles.css','theme.css','fixtures.json','README.md','assets/b15-native-main.png']);
function createServer(override){return http.createServer((req,res)=>{
  if(!['GET','HEAD'].includes(req.method)){res.writeHead(405);return res.end();}
  let name;try{name=decodeURIComponent(new URL(req.url,'http://localhost').pathname).replace(/^\//,'')||'index.html';}catch{res.writeHead(400);return res.end();}
  if(name==='favicon.ico'){res.writeHead(204);return res.end();}
  if(!allowed.has(name)){res.writeHead(404);return res.end('Not found');}
  if(override?.(name,req,res))return;
  const file=path.join(__dirname,name);
  res.setHeader('Cache-Control','no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  res.setHeader('Content-Type',({'.html':'text/html; charset=utf-8','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.css':'text/css','.png':'image/png','.md':'text/plain; charset=utf-8'})[path.extname(file)]);
  res.end(req.method==='HEAD'?undefined:fs.readFileSync(file));
});}
module.exports={createServer};
if(require.main===module){const server=createServer();server.listen(Number(process.argv[2]||4174),'127.0.0.1',()=>console.log(`Prototype only: http://127.0.0.1:${server.address().port}`));}
