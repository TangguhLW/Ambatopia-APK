import {readFile,writeFile,mkdir,copyFile,readdir,cp,rename} from 'node:fs/promises';
import {resolve,dirname,sep} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createHash} from 'node:crypto';
import {adaptHtml} from '../../growtopia-local/mirror.mjs';
import {stripDiscordHtml} from '../../growtopia-local/game/remove-discord.mjs';
const web=resolve('../growtopia-local'),out=resolve('web-client/dist'),hash=x=>createHash('sha256').update(x).digest('hex');
await mkdir(out,{recursive:true});const html={},manifest=[];
for(const name of await readdir(web+'/.cache')){
 if(!/^[a-f0-9]{64}\.json$/.test(name))continue;const m=JSON.parse(await readFile(web+'/.cache/'+name,'utf8'));const u=new URL(m.sourceUrl);if(u.origin!=='https://growtopiasimulator.com')continue;
 const path=decodeURIComponent(u.pathname);if(!/^\/(set|world|edit)\//.test(path)||path.includes('..')||path.includes('\\'))continue;
 const bytes=await readFile(web+'/public/'+name.slice(0,-5));if(hash(bytes)!==m.sha256)throw Error('Reference cache changed');
 if(m.contentType.includes('text/html')){html[path]=bytes.toString();continue;}
 const source=web+'/deploy'+path,destination=out+path;if(!destination.startsWith(out+sep)&&!destination.startsWith(out+'/'))throw Error('Invalid destination');
 await mkdir(dirname(destination),{recursive:true});let body;try{body=await readFile(source);}catch{body=bytes;}await writeFile(destination,body);manifest.push({path,sha256:hash(body),reference_sha256:m.sha256});
}
for(const dir of ['audio','brand','fonts'])await cp(web+'/deploy/'+dir,out+'/'+dir,{recursive:true});
for(const page of ['set','world','edit']){
 let body=html['/'+page+'/'];if(!body)throw Error('Missing verified tool HTML '+page);
 body=stripDiscordHtml(adaptHtml(body)).replace(/<script src="((?:wp\.)?app\.js[^"<>]*)"><\/script>/,(_m,url)=>`<script type="application/json" data-game-src="${url}"></script>`).replace('</body>','<script type="module" src="/tool.js"></script></body>');
 if(!body.includes('data-game-src'))throw Error('Tool bootstrap boundary changed');
 await writeFile(out+'/'+page+'/index.html',body);
}
const vendor=JSON.parse(await readFile('web-client/vendor-assets/manifest.json'));
if(vendor.failures.length)throw Error('Incomplete wardrobe resource cache');
for(const file of vendor.files){if(!/^\/set\/atlas\/(?:b\/[a-f0-9]{12}\.json|[a-z0-9_]+\.png|sfx\/[a-z_]+\.wav)$/.test(file.path))throw Error('Unsafe wardrobe cache entry');const bytes=await readFile('web-client/vendor-assets'+file.path);if(hash(bytes)!==file.sha256)throw Error('Wardrobe asset changed');const destination=out+file.path;await mkdir(dirname(destination),{recursive:true});await writeFile(destination,bytes);manifest.push(file);}
const weather=JSON.parse(await readFile('research/simulator-current/weather-assets.json'));
for(const file of weather){if(!/^[-a-zA-Z0-9_.~]+$/.test(file.key))throw Error('Unsafe weather key');for(const page of ['set','world','edit']){const dest=out+'/'+page+'/atlas/wxg/'+file.key+'.png';try{await readFile(dest);continue;}catch{}const bytes=await readFile('assets/simulator/wxg/'+file.file);await mkdir(dirname(dest),{recursive:true});await writeFile(dest,bytes);}}
for(const page of ['set','world','edit']){const files=await readdir('assets/simulator/weather');for(const file of files){const dest=out+'/'+page+'/atlas/wx/'+file;try{await readFile(dest);continue;}catch{}await mkdir(dirname(dest),{recursive:true});await copyFile('assets/simulator/weather/'+file,dest);}}
let index=await readFile(web+'/game/index.html','utf8');await writeFile(out+'/index.html',index);
await copyFile(web+'/game/ui.css',out+'/game.css');await copyFile(web+'/game/sky-theme.css',out+'/theme.css');
const {build}=await import(pathToFileURL(web+'/node_modules/esbuild/lib/main.js'));
for(const [entry,dest] of [['app','game'],['tool','tool']])await build({entryPoints:['web-client/src/'+entry+'.mjs'],outfile:out+'/'+dest+'.js',bundle:true,minify:true,format:entry==='tool'?'esm':'iife',platform:'browser',target:'es2022',nodePaths:[web+'/node_modules'],sourcemap:true});
const rendererPath=out+'/set/app.js';let renderer=await readFile(rendererPath,'utf8');const marker='window.AmbatopiaNative={';if(!renderer.includes(marker))throw Error('Native renderer hook moved');renderer=renderer.replace(marker,marker+'catalog:function(){return Array.from(_0x4036e1.values());},');await writeFile(rendererPath,renderer);
await mkdir(out+'/cdn-cgi',{recursive:true});await writeFile(out+'/cdn-cgi/trace','loc=ID\n');
await writeFile(out+'/build.json',JSON.stringify({version:'0.15.0-web-engine',project:'ambatopia-godot',renderer:'Existing Ambatopia web Set renderer',built_at:new Date().toISOString(),assets:manifest}));
const body=await readFile(out+'/game.js','utf8');if(body.includes('pfxgouprvgvtfcnqmqsh'))throw Error('Old web database leaked into new client');
console.log('Packaged',manifest.length,'verified cached simulator resources. Old web unchanged.');
