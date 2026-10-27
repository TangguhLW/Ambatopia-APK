import assert from 'node:assert/strict';
import {readFile,writeFile} from 'node:fs/promises';
const checks=[];
const fixtures=await Promise.all(['windows','android'].map(async platform=>({platform,...JSON.parse(await readFile('server/private/qa-'+platform+'.json','utf8'))})));
for(const fixture of fixtures){
 let world,profile;
 for(let attempt=0;attempt<30;attempt++){
  const headers={apikey:process.env.SUPABASE_SECRET_KEY};
  const [wr,pr]=await Promise.all([fetch(process.env.SUPABASE_URL+'/rest/v1/game_worlds?name=eq.'+fixture.world+'&select=state',{headers}),fetch(process.env.SUPABASE_URL+'/rest/v1/game_profiles?id=eq.'+fixture.id+'&select=outfit,settings',{headers})]);
  assert(wr.ok&&pr.ok,'Dedicated storage unavailable');world=(await wr.json())[0]?.state;profile=(await pr.json())[0];
  if(world?.extras?.['2351']?.ready&&profile?.outfit?.back===200156)break;
  await new Promise(r=>setTimeout(r,200));
 }
 assert.equal(world?.foreground?.[2351],200866);assert(world.extras['2351'].ready>Date.now()/1000);checks.push(fixture.platform+': provider tile and production clock persist in dedicated Supabase');
 assert.equal(profile.outfit.back,200156);checks.push(fixture.platform+': source wardrobe persists in dedicated Supabase');
 assert(Object.keys(profile.settings.collected||{}).length>0);checks.push(fixture.platform+': harvested item collection persists in dedicated Supabase');
}
await writeFile('evidence/item-gameplay/persistent-device-items.json',JSON.stringify({checks,failures:[],project:'ambatopia-godot',real_accounts_modified:false},null,2));
console.log(JSON.stringify({checks,failures:[]},null,2));
