import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {decodeTexture,upright,png} from './import-assets.mjs';
const read=async p=>JSON.parse(await readFile(p));
const wardrobe=await read('research/web-wardrobe/archive/l.json'),punch=await read('research/web-wardrobe/archive/punch.json'),pets=await read('research/web-wardrobe/archive/pet_tracks.json');
const names=new Set(['particles','particles2','particles4','fisticuffs','blogox',...pets.sheets]);
const death=await read('research/web-wardrobe/archive/respawn.json');
for(const name of death.sheets)names.add(name);
for(const entry of Object.values(punch.punches))for(const p of entry.P||[])if(p.sheet)names.add(p.sheet);
for(const item of wardrobe.items){
 const ef=item.ef;if(!ef)continue;
 if(ef.lt)names.add(ef.lt);
 for(const v of Object.values(ef.lts||{}))names.add(v);
 for(const type of Object.values(ef.types||{}))for(const v of [type,...type.vars||[]])if(v.t)names.add(v.t);
}
const hash=b=>createHash('sha256').update(b).digest('hex'),index={},chunks=[];let offset=0;
for(const name of [...names].sort()){
 if(!/^[a-zA-Z0-9_/-]+$/.test(name)||name.includes('..'))throw Error('Unsafe sheet '+name);
 const source='game/'+name+'.rttex';
 try{
  const raw=await readFile('C:/Users/user/AppData/Local/Growtopia/'+source),image=upright(decodeTexture(raw)),output=png(image);
  index[name]={offset,bytes:output.length,width:image.width,height:image.height,source,sha256:hash(raw),output_sha256:hash(output)};chunks.push(output);offset+=output.length;
 }catch(error){index[name]={missing:true,source,error:String(error.message)};}
}
await writeFile('assets/web-wardrobe/additional-effects.bin',Buffer.concat(chunks));
await writeFile('data/additional-effects-index.json',JSON.stringify(index));
await writeFile('data/punch-tracks.json',JSON.stringify(punch));
await writeFile('data/pet-tracks.json',JSON.stringify(pets));
console.log(JSON.stringify({sheets:names.size,missing:Object.entries(index).filter(([,v])=>v.missing).map(([k])=>k),bytes:offset}));
