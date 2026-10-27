import {readFile,writeFile} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
const env=Object.fromEntries((await readFile('server/private/.env','utf8')).split(/\r?\n/).filter(x=>x.includes('=')).map(x=>{const n=x.indexOf('=');return [x.slice(0,n),x.slice(n+1).trim().replace(/^"|"$/g,'')]}));
assert.equal(env.SUPABASE_URL,'https://hbptqogoihmguhdizqcf.supabase.co');
const users=[],checks=[];
async function api(path,body,admin=false,method='POST',token){
 const response=await fetch(env.SUPABASE_URL+path,{method,headers:{apikey:admin?env.SUPABASE_SECRET_KEY:env.SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
 const raw=await response.text();let data;try{data=JSON.parse(raw)}catch{data=raw}return {ok:response.ok,status:response.status,data};
}
function check(value,label){assert.ok(value,label);checks.push(label)}
let failure;
try{
 for(let i=0;i<2;i++){
  const name='AuthQA'+randomBytes(4).toString('hex'),password=randomBytes(24).toString('base64url'),email=name.toLowerCase()+'@players.ambatopia.invalid';
  const signup=await api('/auth/v1/signup',{email,password,data:{amba_id:name,ip_address:'203.0.113.'+(i+1),game_role:'developer'}});
  if(signup.data?.user?.id)users.push(signup.data.user.id);
  check(signup.ok&&!!signup.data.access_token,'Native signup '+(i+1)+' creates an immediately usable session');
  const login=await api('/auth/v1/token?grant_type=password',{email,password});
  check(login.ok&&!!login.data.access_token,'Password login '+(i+1)+' succeeds');
  const profile=await api('/rest/v1/game_profiles?id=eq.'+signup.data.user.id,undefined,false,'GET',login.data.access_token);
  check(profile.ok&&profile.data[0]?.role==='player','Client metadata cannot grant developer privileges');
 }
 const name='AuthQA'+randomBytes(4).toString('hex');
 const third=await api('/auth/v1/signup',{email:name.toLowerCase()+'@players.ambatopia.invalid',password:randomBytes(24).toString('base64url'),data:{amba_id:name,ip_address:'198.51.100.77'}});
 if(third.data?.user?.id)users.push(third.data.user.id);
 check(!third.ok&&/two accounts/i.test(JSON.stringify(third.data)),'Third native account is blocked despite a forged metadata IP');
}catch(error){failure=error.message}
finally{
 for(const id of users){assert.match(id,/^[a-f0-9-]{36}$/);const removed=await api('/auth/v1/admin/users/'+id,undefined,true,'DELETE');check(removed.ok,'Synthetic native account removed');}
 await writeFile('evidence/supabase-online/native-auth.json',JSON.stringify({checks,failure,fixture_accounts:users.length,no_email_or_sms:true},null,2));
}
if(failure)throw Error(failure);
console.log('Native Auth:',checks.length,'checks passed; synthetic accounts cleaned.');
