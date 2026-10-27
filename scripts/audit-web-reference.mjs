import {readFile,readdir,writeFile,mkdir} from 'node:fs/promises';
import {resolve,relative} from 'node:path';
import {createHash} from 'node:crypto';
const project=resolve('.'),web=resolve('../growtopia-local');
const selected=['game/engine/native-engine.mjs','game/engine/native-hook.mjs','game/engine/motion.mjs','game/screens/play.mjs','game/tool-layout.mjs','game/tool-sidebar.mjs','game/tool-chrome.mjs','game/ui.css','game/sky-theme.css','deploy/set/app.js','deploy/set/index.html','deploy/set/gs_ui.css','deploy/set/gs_ui2.css'];
const manifest=[];
for(const name of selected){const bytes=await readFile(resolve(web,name));manifest.push({source:'../growtopia-local/'+name,sha256:createHash('sha256').update(bytes).digest('hex'),bytes:bytes.length,read_only:true});}
async function inventory(folder){let count=0,bytes=0;for(const item of await readdir(folder,{withFileTypes:true})){const name=resolve(folder,item.name);if(item.isDirectory()){const sub=await inventory(name);count+=sub.count;bytes+=sub.bytes;}else{const data=await readFile(name);count++;bytes+=data.length;}}return {count,bytes};}
const assets=await inventory(resolve(web,'deploy/set'));
await mkdir('evidence/web-reference',{recursive:true});
await writeFile('evidence/web-reference/source-baseline.json',JSON.stringify({reference:'Existing Ambatopia web implementation, not a claim of complete official-game parity',files:manifest,set_asset_inventory:assets,unchanged_web:true},null,2));
console.log(JSON.stringify({reviewed_source_files:manifest.length,set_files:assets.count,set_megabytes:Math.round(assets.bytes/1048576),source_web_modified:false}));
