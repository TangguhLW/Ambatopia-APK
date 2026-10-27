import {readFile,writeFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {decodeTexture,upright,png} from './import-assets.mjs';
const source='C:/Users/user/AppData/Local/Growtopia/game/seed.rttex';
const bytes=await readFile(source),seed=upright(decodeTexture(bytes));
await writeFile('assets/ambatopia/seed.png',png(seed));
const items=JSON.parse(await readFile('data/simulator/items.json','utf8'));
const rows=Object.entries(items).filter(([id,row])=>Number(row[7])===19&&Array.isArray(row[15]));
const width=2048,height=Math.ceil(rows.length/128)*16,pixels=Buffer.alloc(width*height*4),map={};
for(let i=0;i<rows.length;i++){
 const [id,row]=rows[i],t=row[15],x0=i%128*16,y0=Math.floor(i/128)*16;map[id]=[x0,y0];
 for(let layer=0;layer<2;layer++){
  const frame=Number(t[layer])%16,color=Number(t[4+layer])>>>0,rgba=[(color>>>8)&255,(color>>>16)&255,color>>>24,color&255];
  for(let y=0;y<16;y++)for(let x=0;x<16;x++){
   const s=((layer*16+y)*seed.width+frame*16+x)*4,d=((y0+y)*width+x0+x)*4,a=seed.pixels[s+3]/255*rgba[3]/255*(layer?0.6:1),old=pixels[d+3]/255,out=a+old*(1-a);
   if(!out)continue;
   for(let c=0;c<3;c++)pixels[d+c]=Math.round((seed.pixels[s+c]*rgba[c]/255*a+pixels[d+c]*old*(1-a))/out);
   pixels[d+3]=Math.round(out*255);
  }
 }
}
await writeFile('assets/ambatopia/seed-icons.png',png({width,height,pixels}));
await writeFile('data/simulator/seed-icons.json',JSON.stringify(map));
const index=JSON.parse(await readFile('data/catalog-index.json','utf8')),descriptions={};
for(const file of await readdir(index.details)){
 if(!/^\d+\.json$/.test(file))continue;
 for(const item of JSON.parse(await readFile(index.details+'/'+file,'utf8')))if(item.category==='clothing'&&item.description)descriptions[item.original_id]={name:item.name,description:item.description};
}
await writeFile('data/simulator/clothing-descriptions.json',JSON.stringify(descriptions));
await writeFile('data/simulator/item-assets-provenance.json',JSON.stringify({source,sha256:createHash('sha256').update(bytes).digest('hex'),seed_icons:rows.length,descriptions:Object.keys(descriptions).length,composition:'16px seed base + 60% overlay, recovered RGBA source colors; resized by Godot'},null,2));
console.log(JSON.stringify({seed_icons:rows.length,descriptions:Object.keys(descriptions).length,width,height}));
