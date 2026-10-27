import {readFile,writeFile,mkdir,rename,stat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {parseItemsDat} from './items-dat.mjs';
import {decodeTexture,upright,png} from './import-assets.mjs';
import {publishIndex} from './catalog-schema.mjs';
const source='C:/Users/user/AppData/Local/Growtopia',out='data/catalog';
const hash=b=>createHash('sha256').update(b).digest('hex');
const bytes=await readFile(join(source,'cache/items.dat')),sourceHash=hash(bytes),parsed=parseItemsDat(bytes);
const generation=hash(Buffer.concat([bytes,await readFile(import.meta.filename),await readFile('scripts/items-dat.mjs'),await readFile('research/catalog/sources/wiki-samples.json')])).slice(0,16),target=out+'/'+generation;
await mkdir(target,{recursive:true});await mkdir('assets/catalog',{recursive:true});
const slots=['hat','shirt','pants','feet','face','hand','back','hair','neck'];
const layers={back:0,feet:20,pants:30,shirt:40,neck:45,face:60,hair:65,hat:70,hand:80};
const supportedIds=new Set([34,36,38,40,42,44,46,48,50,66,68,70,72,74,76,78,80,82,84,86,88,90,92,94,96,98,122,124,156,362,1460]);
const mappings=new Map(),failures=[],index=[],items=[],conflicts=[];
for(const texture of [...new Set(parsed.items.map(i=>i.texture).filter(Boolean))]){
 if(!/^(?:[-\w]+\/)*[-\w]+\.rttex$/.test(texture)){failures.push({texture,error:'Unsafe or unsupported resource path'});continue;}
 try{
  const raw=await readFile(join(source,'game',texture)),decoded=upright(decodeTexture(raw));
  const encoded=png(decoded),asset='assets/catalog/'+hash(encoded).slice(0,24)+'.png';
  const cached=await readFile(asset).catch(()=>null);
  if(!cached||hash(cached)!==hash(encoded))await writeFile(asset,encoded);
  mappings.set(texture,{source:'game/'+texture,source_sha256:hash(raw),path:asset,width:decoded.width,height:decoded.height,pixels:decoded.pixels});
 }catch(e){failures.push({texture,error:e.message});}
}
const wiki=JSON.parse(await readFile('research/catalog/sources/wiki-samples.json','utf8'));
const wikiTitles=new Map((wiki.query?.pages||[]).filter(p=>!p.missing).map(p=>[p.title,p]));
for(const raw of parsed.items){
 const m=mappings.get(raw.texture),x=raw.textureX*32,y=raw.textureY*32;
 let preview=Boolean(m&&raw.actionType!==19&&x+32<=m.width&&y+32<=m.height),visible=false;
 if(preview){for(let dy=0;dy<32&&!visible;dy++)for(let dx=0;dx<32;dx++)if(m.pixels[((y+dy)*m.width+x+dx)*4+3]){visible=true;break;}preview=visible;}
 const slot=raw.actionType===20?(slots[raw.clothingType]??null):null;
 const regular=raw.actionType===20&&/^player_(shirt|pants|hairhair|hair|feet|faceitem|handitem|back|chestitem)\d*\.rttex$/.test(raw.texture)&&!raw.renderer&&!raw.hitEffect&&[0,4,7,8,20,22,27,38,39].includes(raw.visualEffect)&&raw.animationFlagsRaw===0&&raw.unknown12.slice(8)==='090909090909090909';
 const equipment=Boolean(slot&&(supportedIds.has(raw.id)||regular)&&preview);
 const category=raw.actionType===17?'block':raw.actionType===19?'seed':raw.actionType===20?'clothing':raw.actionType===18?'background':raw.actionType===8?'consumable':raw.actionType===3?'lock':raw.id===18||raw.id===32?'tool':'other';
 const wikiPage=wikiTitles.get(raw.name),wikiProof=wikiPage?{url:'https://growtopia.fandom.com/wiki/'+encodeURIComponent(raw.name.replaceAll(' ','_')),revision:wikiPage.revisions[0].revid,timestamp:wikiPage.revisions[0].timestamp,match:'exact name corroboration only; no ID present; not merged as identity',license:'CC-BY-SA',author_history:'?action=history'}:null;
 const effects=[];
 if([156,362,1460].includes(raw.id))effects.push({kind:'double_jump',trigger:'jump_pressed_while_airborne',duration:null,cooldown:null,parameters:{extra_jumps:1},implementation:'local_gameplay',native_timing_verified:false,provenance:['items.dat:description',wikiProof?.url]});
 if(raw.id===98)effects.push({kind:'enhanced_digging',trigger:'punch',duration:null,cooldown:null,parameters:null,implementation:'local_gameplay',native_parameters_verified:false,provenance:['items.dat:description',wikiProof?.url]});
 if(raw.renderer||raw.hitEffect||raw.visualEffect)effects.push({kind:'native_effect_reference',trigger:null,duration:null,cooldown:null,parameters:null,implementation:regular&&raw.visualEffect?'local_visual':'not_implemented',references:{renderer:raw.renderer||null,hit:raw.hitEffect||null,visual_type:raw.visualEffect},provenance:['items.dat','H-pun/growtopia-docs@c34f6b4142113cc458a38c49842e1c180ea7b0bb:character-rendering']});
 const record={internal_id:'gt:'+raw.id,original_id:raw.id,name:raw.name,aliases:[],entity_type:'item',category,description:raw.description||null,asset:m?{source:m.source,sha256:m.source_sha256,path:m.path,frame:[x,y,32,32],dimensions:[m.width,m.height],anchor:equipment?[16,slot==='hair'||slot==='hat'||slot==='face'?32:28]:null,layer:equipment?layers[slot]:null,animation:null}:null,equipment:slot?{slot,compatible:equipment,conflicts:[slot],body_replacement:null,facing:'mirror_x',anchor_verification:'reference-derived shared alignment; native animation not measured'}:null,effects,status:{metadata:true,asset_available:Boolean(m),preview,equipment,effect_visual:false,gameplay:[98,156,362,1460].includes(raw.id),reference_verified:[34,36,38,44,48,68,70,76,82,84].includes(raw.id)},provenance:{resource:{sha256:sourceHash,version:parsed.version,record_offset:raw.sourceOffset,record_end:raw.recordEnd},retrieved:'2026-10-22',field_sources:{name:'items.dat',original_id:'items.dat',frame:'items.dat textureX/Y × 32; static inventory frame',slot:'items.dat clothingType for actionType20',category:'adapter actionType classification; remaining types unknown'},wiki:wikiProof,confidence:equipment?'implemented_subset':'metadata_and_bounds',conflicts:[]},raw_metadata:raw};
 items.push(record);index.push({id:raw.id,name:raw.name,aliases:[],category,slot,preview,equip:equipment,asset:preview?m.path:null,frame:preview?[x,y,32,32]:null,page:Math.floor(raw.id/256)});
}
for(let start=0;start<items.length;start+=256)await writeFile(`${target}/${start/256}.json`,JSON.stringify(items.slice(start,start+256)));
const prior=await readFile('data/catalog-index.json','utf8').then(JSON.parse).catch(()=>null);
const priorIds=new Map((prior?.entries||[]).map(x=>[x.id,x]));
const currentIds=new Set(index.map(i=>i.id));
if([...priorIds.keys()].some(id=>!currentIds.has(id)))throw Error('Import would remove existing IDs; explicit resource version review required');
const diff={added:index.filter(i=>!priorIds.has(i.id)).map(i=>i.id),changed:index.filter(i=>priorIds.has(i.id)&&JSON.stringify(priorIds.get(i.id))!==JSON.stringify(i)).map(i=>i.id),removed:[]};
const report={source_version:27,source_sha256:sourceHash,declared:parsed.count,parsed:items.length,bytes_consumed:parsed.consumed,total_bytes:bytes.length,unique:items.length,local_textures:mappings.size,asset_available:items.filter(i=>i.status.asset_available).length,preview:items.filter(i=>i.status.preview).length,equipment:items.filter(i=>i.status.equipment).length,reference_verified:items.filter(i=>i.status.reference_verified).length,effect_reference_entries:items.filter(i=>i.effects.length).length,effect_semantics_documented:2,effect_gameplay_implemented:4,effect_visual_implemented:0,wiki_corroborated:items.filter(i=>i.provenance.wiki).length,unknown_v27_extensions:items.filter(i=>i.raw_metadata.uninterpretedExtension).length,failures,conflicts,diff,limitations:['All records parsed structurally; unknown raw fields retained, not semantically decoded','Seed composites intentionally have no generic block thumbnail','Static preview bounds do not prove native animation, special layers or effects',String(items.filter(i=>i.status.equipment).length)+' supported static wearables; special renderer clothing remains unavailable','No titles/badges invented from ordinary item names','Gameplay abilities are enforced by the shared session server; persistent public accounts are not implemented']};
await writeFile(target+'/coverage.json',JSON.stringify(report,null,2));
await writeFile(target+'/asset-manifest.json',JSON.stringify([...mappings.entries()].map(([name,{pixels,...m}])=>({name,...m})),null,2));
const next={schema_version:1,generation,resource_version:27,details:target,entries:index};
await writeFile('data/wearable-index.json',JSON.stringify({...next,entries:index.filter(i=>i.equip)}));
await publishIndex(next,'data/catalog-index.json');
await writeFile('research/catalog/coverage.json',JSON.stringify(report,null,2));
console.log(JSON.stringify({...report,diff:{added:diff.added.length,changed:diff.changed.length,removed:0}},null,2));
