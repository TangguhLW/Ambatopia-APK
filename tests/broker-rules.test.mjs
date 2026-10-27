import {request as httpRequest} from 'node:http';
import {test} from 'node:test';import assert from 'node:assert/strict';import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {createBroker,PROJECT} from '../server/accounts.mjs';
test('Broker enforces promotion authority, trusted provisioning and two-account registration limit',async()=>{
 const folder=mkdtempSync(join(tmpdir(),'amba-broker-'));const realFetch=globalThis.fetch;const writes=[];let registrations=0;
 const ids={dev:'11111111-1111-4111-8111-111111111111',player:'22222222-2222-4222-8222-222222222222',mod:'33333333-3333-4333-8333-333333333333',untrusted:'44444444-4444-4444-8444-444444444444'};
 const profiles=Object.fromEntries(Object.entries(ids).map(([key,id])=>[id,{id,amba_id:key==='dev'?'Thaney':key,role:key==='dev'?'developer':'player',settings:{moderator:key==='mod'}}]));
 globalThis.fetch=async(url,options={})=>{assert.ok(String(url).startsWith(PROJECT));const path=new URL(url).pathname;const ok=data=>new Response(JSON.stringify(data),{status:200});
  if(path==='/auth/v1/user'){const token=options.headers.Authorization.replace('Bearer ','');return ok({id:ids[token]||ids.player,app_metadata:{game_provisioned:token!=='untrusted'}});}
  if(path==='/auth/v1/admin/users'){registrations++;assert.equal(JSON.parse(options.body).app_metadata.game_provisioned,true);return ok({id:ids.player});}
  if(path==='/auth/v1/token')return ok({access_token:'player',refresh_token:'fixture-refresh'});
  if(path==='/rest/v1/game_profiles'){if(options.method==='PATCH'){writes.push(JSON.parse(options.body));return ok(null);}const id=new URL(url).searchParams.get('id')?.replace('eq.','');return ok(id?[profiles[id]]:Object.values(profiles));}
  if(path==='/rest/v1/game_audit'){writes.push(JSON.parse(options.body||'null'));return ok([]);}
  throw Error('Unexpected mock call: '+path);
 };
 const server=createBroker({SUPABASE_URL:PROJECT,SUPABASE_SECRET_KEY:'fixture-key',SUPABASE_PUBLISHABLE_KEY:'fixture-public',GAME_INTERNAL_TOKEN:'fixture-internal-token-32-characters',REGISTRATION_QUOTA_FILE:join(folder,'quota.json')});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
 const call=(path,token,body)=>new Promise((resolve,reject)=>{const request=httpRequest({hostname:'127.0.0.1',port:server.address().port,path,method:'POST',headers:{Host:'127.0.0.1:4193','Content-Type':'application/json',Authorization:'Bearer '+token}},response=>{let text='';response.on('data',chunk=>text+=chunk);response.on('end',()=>resolve({status:response.statusCode,data:JSON.parse(text)}));});request.on('error',reject);request.end(JSON.stringify(body));});
 try{
  for(const token of ['player','mod'])assert.equal((await call('/admin/moderate',token,{target:ids.player,action:'promote'})).status,403);
  assert.equal((await call('/admin/moderate','dev',{target:ids.player,action:'promote'})).status,200);assert.equal(writes[0].settings.moderator,true);
  assert.equal((await call('/admin/moderate','dev',{target:ids.player,action:'demote'})).status,200);assert.equal(writes[2].settings.moderator,false);
  assert.equal((await call('/auth/verify','',{token:'untrusted'})).status,400);
  for(const name of ['FixtureOne','FixtureTwo'])assert.equal((await call('/auth/register','',{name,password:'fixture-password-123'})).status,200);
  assert.equal((await call('/auth/register','',{name:'FixtureThree',password:'fixture-password-123'})).status,429);assert.equal(registrations,2);
  assert.ok((await call('/internal/profile','player',{id:ids.player,collected:{'2':3}})).status>=400);
  assert.equal((await call('/internal/profile','fixture-internal-token-32-characters',{id:ids.player,collected:{'2':3,bad:5,'8':-1}})).status,200);
  assert.deepEqual(writes.at(-1).settings.collected,{'2':3});
  assert.equal(writes.at(-1).settings.moderator,false);
 }finally{await new Promise(resolve=>server.close(resolve));globalThis.fetch=realFetch;rmSync(folder,{recursive:true,force:true});}
});
