import {readFile,writeFile,mkdir,stat,copyFile} from 'node:fs/promises';
import {dirname} from 'node:path';import {createHash} from 'node:crypto';
const inventory=JSON.parse(await readFile('evidence/web-client/reference-assets.json'));
const paths=inventory.sheets.map(s=>'/set/atlas/'+s+'.json');
for(const p of ['/set/atlas/tiles_page3.png','/set/atlas/sfx/tile_removed.wav','/set/atlas/sfx/tile_created.wav','/set/atlas/sfx/punch.wav'])paths.push(p);
const queue=[...new Set(paths)],done=[],failures=[];let cursor=0;
const digest=b=>createHash('sha256').update(b).digest('hex');
async function worker(){while(cursor<queue.length&&failures.length<20){const path=queue[cursor++];if(!/^\/set\/atlas\/(?:b\/[a-f0-9]{12}\.json|[a-z0-9_]+\.png|sfx\/[a-z_]+\.wav)$/.test(path))throw Error('Unsafe asset path');const output='web-client/vendor-assets'+path;await mkdir(dirname(output),{recursive:true});let bytes;
 try{bytes=await readFile(output);}catch{try{bytes=await readFile('web-client/dist'+path);}catch{}}
 if(!bytes){try{const response=await fetch('https://growtopiasimulator.com'+path,{redirect:'error',signal:AbortSignal.timeout(20000)});if(!response.ok||response.headers.get('content-type')?.includes('text/html'))throw Error('HTTP '+response.status);bytes=Buffer.from(await response.arrayBuffer());if(bytes.length>16000000)throw Error('Asset too large');}catch(e){failures.push({path,error:e.message});continue;}}
 await writeFile(output,bytes);done.push({path,source:'https://growtopiasimulator.com'+path,sha256:digest(bytes),bytes:bytes.length});if(done.length%200===0){await writeFile('evidence/web-client/asset-download-progress.json',JSON.stringify({done:done.length,total:queue.length,failures}));console.log('Cached wardrobe resources',done.length,'/',queue.length);}
 }}
await Promise.all(Array.from({length:6},worker));
await writeFile('web-client/vendor-assets/manifest.json',JSON.stringify({source:'Verified renderer catalogue bk fields',files:done,failures},null,2));
console.log('Wardrobe resources cached:',done.length,'failures:',failures.length);if(failures.length||done.length!==queue.length)process.exitCode=1;
