import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const json=async p=>JSON.parse(await readFile(p,'utf8'));
const native=await json('data/catalog-index.json');
const simulator=await json('data/simulator/items.json');
const inventory=await json('evidence/local-resource-update/resource-manifest.json');
const sources=new Map(inventory.assets.map(x=>[x.path,x.sha256]));
const pages=new Map(),outputs=new Map(),mapping={},unmatched=[];
const digest=b=>createHash('sha256').update(b).digest('hex');
for(const item of native.entries){
 const row=simulator[String(item.id)];
 if(!row||!item.preview||!item.asset)continue;
 if(!pages.has(item.page))pages.set(item.page,await json(native.details+'/'+item.page+'.json'));
 const record=pages.get(item.page).find(x=>x.original_id===item.id);
 const raw=record.raw_metadata,asset=record.asset;
 const matches=item.name===row[0]&&asset.source==='game/'+row[1]+'.rttex'&&raw.textureX===row[2]&&raw.textureY===row[3]&&raw.renderType===row[4]&&raw.actionType===row[7];
 if(!matches){unmatched.push({id:item.id,name:item.name,reason:'ID exists, but name/sheet/frame/render type/action type do not all agree'});continue;}
 if(sources.get(asset.source)!==asset.sha256){unmatched.push({id:item.id,reason:'Local source changed since catalog generation'});continue;}
 if(!outputs.has(item.asset)){
  const bytes=await readFile(item.asset);
  const sha=digest(bytes);
  if(!item.asset.includes(sha.slice(0,24)))throw Error('Catalog image content address differs: '+item.asset);
  outputs.set(item.asset,{path:item.asset,sha256:sha,source:asset.source,source_sha256:asset.sha256,dimensions:asset.dimensions,transform:'Verified RGBA8 RTTEX, vertical row reversal, lossless PNG'});
 }
 mapping[item.id]=[item.asset,item.frame];
}
await mkdir('evidence/local-resource-update',{recursive:true});
await writeFile('data/local-sprite-overrides.json',JSON.stringify({generation:native.generation,items:mapping}));
await writeFile('evidence/local-resource-update/sprite-provenance.json',JSON.stringify({native_version:native.resource_version,native_generation:native.generation,mapped_items:Object.keys(mapping).length,assets:[...outputs.values()],unmatched,notes:'Only exact ID/name/sheet/frame/render/action matches use local images. Worn animation timing is a separate claim.'},null,2));
console.log(JSON.stringify({local_items:Object.keys(mapping).length,local_sheets:outputs.size,unmatched:unmatched.length}));
