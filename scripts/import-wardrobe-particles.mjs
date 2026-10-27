import {readFile,writeFile} from 'node:fs/promises';
import {decodeTexture,upright,png} from './import-assets.mjs';
import {createHash} from 'node:crypto';
const data=JSON.parse(await readFile('research/web-wardrobe/archive/l.json'));
const names=[...new Set(data.items.flatMap(r=>(r.xs||[]).map(x=>x.t)).filter(Boolean))];
const index={},chunks=[];let offset=0;
for(const name of names){
 if(!/^[a-z0-9_]+$/.test(name))throw Error('Unexpected particle sheet');
 const source='game/'+name+'.rttex';
 try{
 const raw=await readFile('C:/Users/user/AppData/Local/Growtopia/'+source),image=upright(decodeTexture(raw)),output=png(image);
 index[name]={offset,bytes:output.length,width:image.width,height:image.height,source,sha256:createHash('sha256').update(raw).digest('hex'),output_sha256:createHash('sha256').update(output).digest('hex')};
 chunks.push(output);offset+=output.length;
 }catch(error){index[name]={missing:true,source,error:String(error.message)};}
}
await writeFile('assets/web-wardrobe/particles.bin',Buffer.concat(chunks));
await writeFile('data/wardrobe-particles.json',JSON.stringify(index));
console.log(JSON.stringify({sheets:names.length,missing:Object.values(index).filter(x=>x.missing).length,png_bytes:offset}));
