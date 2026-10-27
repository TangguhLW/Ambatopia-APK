import fs from 'node:fs';
const index=JSON.parse(fs.readFileSync('data/catalog-index.json'));
const items=[];
for(const file of fs.readdirSync(index.details).filter(f=>/^\d+\.json$/.test(f))){
 for(const row of JSON.parse(fs.readFileSync(index.details+'/'+file))){
  const r=row.raw_metadata;
  if((r.actionType===3&&row.status.preview)||r.actionType===17&&row.status.preview&&r.collisionType===1&&!r.renderer&&!r.visualEffect&&!r.animationFlagsRaw&&!row.name.startsWith('UPDATE_'))
   items.push({id:row.original_id,world_id:100000+row.original_id,name:row.name,break_hits:r.breakHits,lock:r.actionType===3,area:({202:10,204:48,206:200,4994:200})[row.original_id]||0,source:'items.dat v27: actionType=17, collisionType=1; static rendering only'});
 }
}
if(fs.existsSync('data/simulator/items.json')){
 const simulator=JSON.parse(fs.readFileSync('data/simulator/items.json'));
 for(const [key,row] of Object.entries(simulator))if(row[7]===3&&!items.some(x=>x.id===Number(key)))items.push({id:Number(key),world_id:100000+Number(key),name:row[0],lock:true,area:({202:10,204:48,206:200,4994:200})[key]||0,source:'growtopiasimulator.com/edit data/world/items.json action type 3'});
}
fs.writeFileSync('data/placeable-blocks.json',JSON.stringify({generation:index.generation,items},null,2));
console.log(JSON.stringify({static_solid_blocks:items.length}));
