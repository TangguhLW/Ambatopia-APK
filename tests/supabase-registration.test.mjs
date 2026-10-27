import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {PGlite} from '../tools/postgres/node_modules/@electric-sql/pglite/dist/index.js';
test('native Auth registration hook limits the trusted IP and protects developer identity',async()=>{
 const db=new PGlite();
 try{
 await db.exec(`create role anon;create role authenticated;create role service_role;create role supabase_auth_admin;
 create schema auth;create function auth.uid() returns uuid language sql as $$select null::uuid$$;
 create table auth.users(id uuid primary key,email text,raw_user_meta_data jsonb,raw_app_meta_data jsonb);
 create schema game_private;`);
 await db.exec(await readFile(new URL('../supabase/migrations/20261023_accounts.sql',import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../supabase/migrations/20261023_native_registration.sql',import.meta.url),'utf8'));
 const event=(id,name,ip='192.0.2.42')=>({metadata:{ip_address:ip},user:{id,email:name.toLowerCase()+'@players.ambatopia.invalid',user_metadata:{amba_id:name},app_metadata:{}}});
 const hook=async e=>(await db.query('select public.game_before_user_created($1::jsonb) as result',[JSON.stringify(e)])).rows[0].result;
 const first=event('11111111-1111-4111-8111-111111111111','FixtureOne');
 assert.deepEqual(await hook(first),{});
 assert.deepEqual(await hook(first),{},'same Auth request is idempotent');
 await db.query(`insert into auth.users values($1,$2,$3::jsonb,'{}')`,[first.user.id,first.user.email,JSON.stringify(first.user.user_metadata)]);
 assert.equal((await db.query(`select role from public.game_profiles`)).rows[0].role,'player');
 assert.equal((await db.query(`select confirmed from game_private.account_ips where uid=$1`,[first.user.id])).rows[0].confirmed,true);
 assert.deepEqual(await hook(event('22222222-2222-4222-8222-222222222222','FixtureTwo')),{});
 assert.equal((await hook(event('33333333-3333-4333-8333-333333333333','FixtureThree'))).error.http_code,429);
 assert.equal((await hook(event('44444444-4444-4444-8444-444444444444','Thaney'))).error.http_code,403);
 const forged=event('55555555-5555-4555-8555-555555555555','DifferentIP','');
 forged.user.user_metadata.ip_address='198.51.100.42';
 assert.equal((await hook(forged)).error.http_code,403,'profile metadata cannot supply the trusted IP');
 const raw=(await db.query('select * from game_private.account_ips')).rows;
 assert.equal(raw.length,2);assert.ok(raw.every(x=>/^[a-f0-9]{64}$/.test(x.ip_hash)));
 await db.exec('set role authenticated');
 await assert.rejects(hook(first),/permission denied/);
 await assert.rejects(db.query('select * from game_private.account_ips'),/permission denied/);
	await db.exec('reset role');
	await db.query('delete from auth.users where id=$1',[first.user.id]);
	assert.equal((await db.query('select count(*)::int n from game_private.account_ips where uid=$1',[first.user.id])).rows[0].n,0);
 }finally{await db.close();}
});
