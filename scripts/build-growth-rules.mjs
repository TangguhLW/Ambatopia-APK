import {readFile,writeFile} from 'node:fs/promises';
const use=JSON.parse(await readFile('data/simulator/use.json','utf8'));
const items=JSON.parse(await readFile('data/simulator/items.json','utf8'));
const ids=new Set([...Object.keys(use.seed).filter(id=>items[id]?.[7]===19),...Object.keys(use.provider)]);
const rows=[...ids].map(id=>[Number(id),items[id]?.[7]===19?Math.max(1,Number(use.seed[id][0])):null,items[id]?.[7]===19&&Number(use.seed[id][1])===999, use.provider[id]||null,id==='1008'?[[112,250]]:(use.provider_drop[id]||[])]).sort((a,b)=>a[0]-b[0]);
const rules=`insert into game_private.growth_rules(source_id,seed_seconds,single_fruit,provider_seconds,rewards)
select (v->>0)::int,(v->>1)::real,(v->>2)::boolean,(v->>3)::real,v->4
from jsonb_array_elements($growth$${JSON.stringify(rows)}$growth$::jsonb) v
on conflict(source_id) do update set seed_seconds=excluded.seed_seconds,single_fruit=excluded.single_fruit,provider_seconds=excluded.provider_seconds,rewards=excluded.rewards;\n`;
await writeFile('supabase/growth-item-rules.sql',rules);
const migration=await readFile('supabase/migrations/20261025_growth.sql','utf8');
if(!migration.endsWith("notify pgrst,'reload schema';\ncommit;\n"))throw Error('Unexpected migration transaction boundary');
await writeFile('supabase/growth-deploy.sql',migration.replace("notify pgrst,'reload schema';\ncommit;\n",rules+"\nnotify pgrst,'reload schema';\ncommit;\n"));
console.log('Verified growth mappings:',rows.length);
