import {randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
const base='http://127.0.0.1:4193';
const cloud=process.env.SUPABASE_URL;
const ids=[];
const checks=[];
async function local(path,body,token){const r=await fetch(base+path,{method:body?'POST':'GET',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined});return {status:r.status,data:await r.json()};}
async function rest(path,token,method='GET',body){const r=await fetch(cloud+'/rest/v1/'+path,{method,headers:{apikey:process.env.SUPABASE_PUBLISHABLE_KEY,Authorization:'Bearer '+token,'Content-Type':'application/json'},body:body?JSON.stringify(body):undefined});return {status:r.status,data:await r.json()};}
try{
 const stamp=Date.now().toString(36),secret=randomBytes(18).toString('hex');
 const a=await local('/auth/register',{name:'qa'+stamp+'a',password:secret});assert.equal(a.status,200);ids.push(a.data.profile.id);checks.push('Synthetic account A registered without email/SMS');
 const b=await local('/auth/register',{name:'qa'+stamp+'b',password:secret});assert.equal(b.status,200);ids.push(b.data.profile.id);checks.push('Synthetic account B registered');
 const third=await local('/auth/register',{name:'qa'+stamp+'c',password:secret});assert.equal(third.status,429);checks.push('Third registration from the same address is blocked');
 const own=await rest('game_profiles?select=*',a.data.access_token);assert.equal(own.status,200);assert.deepEqual(own.data.map(x=>x.id),[a.data.profile.id]);checks.push('RLS exposes own profile only');
 const cross=await rest('game_profiles?id=eq.'+b.data.profile.id,a.data.access_token);assert.deepEqual(cross.data,[]);checks.push('Cross-account profile read denied');
 const promote=await rest('game_profiles?id=eq.'+a.data.profile.id,a.data.access_token,'PATCH',{role:'developer'});assert(promote.status>=400);checks.push('Client role escalation denied');
 const mod=await rest('game_profiles?id=eq.'+a.data.profile.id,a.data.access_token,'PATCH',{settings:{moderator:true}});assert(mod.status>=400);checks.push('Client cannot self-promote through settings');
 const worlds=await rest('game_worlds?select=*',a.data.access_token);assert(worlds.status>=400);checks.push('Direct world table reads denied');
 const reserve=await local('/auth/register',{name:'Thaney',password:secret});assert.equal(reserve.status,403);checks.push('Reserved developer registration denied');
 const invalid=await local('/auth/verify',{token:'forged'});assert(invalid.status>=400);checks.push('Forged token rejected');
 const login=await local('/auth/login',{name:'qa'+stamp+'a',password:secret});assert.equal(login.status,200);checks.push('AmbaID password login works');
 const admin=await local('/admin/players',null,a.data.access_token);assert.equal(admin.status,403);checks.push('Ordinary account cannot inspect admin player data');
 console.log(JSON.stringify({checks,passed:checks.length},null,2));
}finally{
 for(const id of ids){const r=await fetch(cloud+'/auth/v1/admin/users/'+id,{method:'DELETE',headers:{apikey:process.env.SUPABASE_SECRET_KEY}});if(!r.ok)throw Error('Synthetic fixture cleanup failed');}
}
