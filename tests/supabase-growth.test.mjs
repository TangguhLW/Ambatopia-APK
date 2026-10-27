import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,access} from 'node:fs/promises';
import {PGlite} from '../tools/postgres/node_modules/@electric-sql/pglite/dist/index.js';
test('shared seed/provider runtime preserves ownership, source timers and persistent events',async()=>{
 const db=new PGlite();
 try{
  await db.exec(`create role anon;create role authenticated;create role service_role;create schema auth;
  create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.uid',true),'')::uuid$$;
  create table auth.users(id uuid primary key,raw_user_meta_data jsonb,raw_app_meta_data jsonb);
  create schema realtime;create table realtime.messages(topic text,extension text);
  create function realtime.topic() returns text language sql as $$select current_setting('test.topic',true)$$;
  create table realtime.sent(packet jsonb,event text,topic text,private boolean);
  create function realtime.send(jsonb,text,text,boolean) returns void language sql as $$insert into realtime.sent values($1,$2,$3,$4)$$;`);
  for(const name of ['20261023_accounts.sql','20261023_realtime.sql'])await db.exec(await readFile('supabase/migrations/'+name,'utf8'));
  await db.exec(await readFile('supabase/network-item-rules.sql','utf8'));
  await db.exec(await readFile('supabase/migrations/20261023_event_recovery.sql','utf8'));
  try{await access('supabase/growth-deploy.sql');await db.exec(await readFile('supabase/growth-deploy.sql','utf8'))}catch(error){if(error.code!=='ENOENT')throw error}
  const ids=['11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222'];
  for(let i=0;i<2;i++)await db.query(`insert into auth.users values($1,jsonb_build_object('amba_id',$2::text),'{"game_provisioned":true}')`,[ids[i],'Growth'+i]);
  const as=uid=>db.query(`select set_config('test.uid',$1,false)`,[uid]);
  const rpc=async(type,args={})=>{await db.exec(`update game_private.members set last_action='-infinity'`);const session=(await db.query('select player_id from game_private.members where uid=auth.uid()')).rows[0]?.player_id;return(await db.query('select public.game_command($1::jsonb) result',[JSON.stringify({type,session,...args})])).rows[0].result};
  const state=async()=> (await db.query(`select state from public.game_worlds where name='GROWTH'`)).rows[0].state;
  await as(ids[0]);await db.query(`select public.game_join('GROWTH')`);
  await rpc('place',{x:49,y:23,item:200003});
  assert.equal((await state()).extras['2349']?.seed,3,'Seed metadata must accompany a committed shared placement');
  assert.equal((await state()).extras['2349'].duration,31,'Dirt seed uses the verified 31-second source duration');
  await assert.rejects(rpc('machine',{x:49,y:23,command:'harvest',args:{}}),/growing/i);
  await rpc('machine',{x:49,y:23,command:'grow',args:{}});
  const grown=await state();assert(grown.extras['2349'].planted+grown.extras['2349'].duration<=Date.now()/1000);
  await rpc('machine',{x:49,y:23,command:'harvest',args:{}});
  const harvested=await state();assert.equal(harvested.foreground[2349],0);assert(!harvested.extras['2349']);assert(harvested.drops.some(row=>row.id===2)&&harvested.drops.some(row=>row.id===3));
  await rpc('place',{x:51,y:23,item:200866});assert((await state()).extras['2351'].ready>Date.now()/1000);
  await db.exec(await readFile('supabase/growth-deploy.sql','utf8'));
  assert((await state()).extras['2351'].ready>Date.now()/1000,'Reapplying the atomic migration preserves existing world metadata');
  await rpc('machine',{x:51,y:23,command:'grow',args:{}});await rpc('machine',{x:51,y:23,command:'harvest',args:{}});
  assert((await state()).drops.some(row=>row.id===868),'Science Station uses its source reward table');
  await rpc('place',{x:49,y:23,item:5});
  await as(ids[1]);await db.query(`select public.game_join('GROWTH')`);
  await assert.rejects(rpc('machine',{x:51,y:23,command:'grow',args:{}}),/locked/i);
  await assert.rejects(rpc('machine',{x:90,y:23,command:'grow',args:{}}),/reach/i);
  await as(ids[0]);await assert.rejects(rpc('machine',{x:51,y:23,command:'grow',args:{ready:0}}),/arguments/i);
  const events=(await db.query('select public.game_events(0) data')).rows[0].data.events;
  assert(events.some(row=>row.packet.type==='item_state'&&row.packet.drops),'Metadata and drops are recoverable through the ordered event stream');
  await db.exec('set role authenticated');await assert.rejects(db.query('select * from game_private.growth_rules'),/permission denied/);await assert.rejects(db.query(`select game_private.command_core_034('{}')`),/permission denied/);
 }finally{await db.close()}
});
