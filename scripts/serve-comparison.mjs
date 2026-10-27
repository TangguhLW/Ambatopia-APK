import {createServer} from 'node:http';
import {readFile,stat} from 'node:fs/promises';
import {resolve,extname,sep} from 'node:path';
const root=resolve('evidence/fidelity-2026-10-22');
createServer(async(req,res)=>{try{const pathname=decodeURIComponent(new URL(req.url,'http://127.0.0.1').pathname);const file=resolve(root,'.'+(pathname==='/'?'/comparison.html':pathname));if(!file.startsWith(root+sep)||pathname.split('/').some(p=>p.startsWith('.'))){res.writeHead(403).end();return;}if(!(await stat(file)).isFile()){res.writeHead(404).end();return;}res.writeHead(200,{'Content-Type':({'.html':'text/html; charset=utf-8','.png':'image/png','.json':'application/json','.md':'text/plain; charset=utf-8'})[extname(file)]||'application/octet-stream','Cache-Control':'no-store'});res.end(await readFile(file));}catch{res.writeHead(404).end();}}).listen(4190,'127.0.0.1',()=>console.log('Comparison evidence: http://127.0.0.1:4190/'));
