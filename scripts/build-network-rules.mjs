import {readFile,writeFile} from 'node:fs/promises';
const read=async p=>JSON.parse(await readFile(p,'utf8'));
const items=await read('data/simulator/items.json'),use=await read('data/simulator/use.json');
const native=await read('data/placeable-blocks.json'),catalog=await read('data/catalog-index.json');
const slots=['hat','shirt','pants','feet','face','hand','back','hair','neck','artifact'];
const records=new Map();
for(const item of catalog.entries)if(item.slot)records.set(item.id,{id:item.id,source_id:item.id,hits:3,category:'clothing',slot:item.slot});
for(const item of native.items)records.set(item.world_id,{id:item.world_id,source_id:item.id,hits:Math.max(1,Math.ceil((item.break_hits??18)/6)),category:item.lock?'lock':'block',lock_area:item.lock?item.area:null});
for(const [id,row] of Object.entries(items)){
 if([0,1,6,7,8,9,18,32].includes(Number(id)))continue;
 if(row[7]===3)continue; // Locks use native ID mappings and measured areas.
 records.set(200000+Number(id),{id:200000+Number(id),source_id:Number(id),hits:Math.max(1,Math.ceil((row[8]??18)/6)),category:use.cloth[id]!==undefined?'clothing':({17:'block',18:'background',19:'seed',8:'consumable'}[row[7]]||'other'),slot:slots[use.cloth[id]]||null,weather:use.weather[id]?.k||null});
}
for(const [id,source,hits,category,area] of [[1,2,3,'block',null],[2,8,999,'protected',null],[3,10,10,'block',null],[4,6,999,'protected',null],[5,242,3,'lock',0],[6,108,3,'block',null],[7,4,3,'block',null]])records.set(id,{id,source_id:source,hits,category,lock_area:area});
const json=JSON.stringify([...records.values()]);
const sql=`-- Generated from the project's verified item mappings. No account data.\ninsert into game_private.item_rules(id,source_id,hits,category,lock_area,slot,weather)\nselect id,source_id,hits,category,lock_area,slot,weather from jsonb_to_recordset($rules$${json}$rules$::jsonb)\nas r(id int,source_id int,hits int,category text,lock_area int,slot text,weather text)\non conflict(id) do update set source_id=excluded.source_id,hits=excluded.hits,category=excluded.category,lock_area=excluded.lock_area,slot=excluded.slot,weather=excluded.weather;\n`;
await writeFile('supabase/network-item-rules.sql',sql);
console.log('Network item rules:',records.size);

