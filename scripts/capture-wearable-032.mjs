import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const out='research/wearable-032';await mkdir(out,{recursive:true});
const hash=b=>createHash('sha256').update(b).digest('hex');
const items=JSON.parse(await readFile('data/simulator/items.json'));
const normalize=s=>s.normalize('NFKC').replace(/[’‘]/g,"'").replace(/\s+/g,' ').trim().toLowerCase();
const names=new Map(Object.entries(items).filter(([id,row])=>Number(id)%2===0).map(([id,row])=>[normalize(row[0]),Number(id)]));
const speedy=new Set([1740,4988,5264]),sources=[],unmatched=[];
for(const slot of ['Hat','Hair','Face','Shirt','Pants','Feet','Hand','Back','Chest','Artifact']){
 const url='https://growtopiawiki.com/w/Mods/Speedy/'+slot;
 const res=await fetch(url,{signal:AbortSignal.timeout(20000)});if(!res.ok){sources.push({url,status:res.status});continue;}
 const html=await res.text();await writeFile(`${out}/Speedy-${slot}.html`,html);
 const mapped=[];
 for(const tr of html.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/g)){
  const cell=tr[1].match(/<td\b[^>]*>([\s\S]*?)<\/td>/)?.[1];if(!cell)continue;
  for(const a of cell.matchAll(/<a\b[^>]*href="\/w\/([^"#]+)"[^>]*>([\s\S]*?)<\/a>/g)){
   const text=decodeURIComponent(a[1]).replaceAll('_',' ').replaceAll('&amp;','&');
   if(text.startsWith('File:')||!a[2].replace(/<[^>]*>/g,'').trim())continue;
   const id=names.get(normalize(text));if(id){speedy.add(id);mapped.push(id);}else unmatched.push({slot,name:text});
  }
 }
 sources.push({url,status:res.status,sha256:hash(html),mapped:[...new Set(mapped)]});
}
if(!speedy.has(1740)||sources.filter(s=>s.mapped?.length).length<5)throw Error('Insufficient mod tables; previous validated registry retained');
await writeFile('data/clothing-mods-032.json',JSON.stringify({speedy:[...speedy].sort((a,b)=>a-b),qualification:'Known Speedy item identities from captured wiki tables and four inspected items; existing creative movement magnitude retained. Not an official server buff table.'}));
const wardrobe=JSON.parse(await readFile('research/web-wardrobe/archive/l.json'));
const pending=[];
for(const item of wardrobe.items){
 const rows=item.ef?.rows||[];
 const typed=rows.filter(r=>r.ty!=null&&!r.anc&&!(item.id===5264&&r.ty===39));
 if(typed.length)pending.push({id:item.id,name:item.name,typed_emitters:[...new Set(typed.map(r=>r.ty))]});
}
const source=await readFile('research/effects-024/app.readable.js','utf8');const lines=source.split('\n');
await writeFile(out+'/source-snippets.txt',[[40475,40477],[42326,42333],[42809,42831],[39231,39235]].map(([a,b])=>`${a+1}-${b}\n${lines.slice(a,b).join('\n')}`).join('\n\n'));
await writeFile(out+'/sources.json',JSON.stringify({checked_at:new Date().toISOString(),simulator_source:{path:'research/effects-024/app.readable.js',sha256:hash(source)},speedy_items:speedy.size,sources,unmatched,pending_typed_items:pending,qualification:'Pending entries require per-emitter verification; absence from this typed-emitter handler does not prove absence of native XML/other effect paths.'},null,2));
console.log(JSON.stringify({speedy_items:speedy.size,mapped_pages:sources.filter(s=>s.mapped?.length).length,pending_typed_items:pending.length}));
