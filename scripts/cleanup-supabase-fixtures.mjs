import {readFile,writeFile} from 'node:fs/promises';
import assert from 'node:assert/strict';
const env=Object.fromEntries((await readFile('server/private/.env','utf8')).split(/\r?\n/).filter(x=>x.includes('=')).map(x=>{const n=x.indexOf('=');return [x.slice(0,n),x.slice(n+1).trim().replace(/^"|"$/g,'')]}));
assert.equal(env.SUPABASE_URL,'https://hbptqogoihmguhdizqcf.supabase.co');
async function api(path,method='GET',body){const response=await fetch(env.SUPABASE_URL+path,{method,headers:{apikey:env.SUPABASE_SECRET_KEY,'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body)});assert.ok(response.ok,'Fixture cleanup request failed: '+response.status);return response.status===204?null:response.json()}
const {users}=await api('/auth/v1/admin/users?per_page=1000');
const fixtures=users.filter(u=>u.app_metadata?.test_fixture===true&&/^NetQA[12][a-f0-9]{10}$/.test(u.user_metadata?.amba_id));
const worlds=[...new Set(fixtures.map(u=>'NETQA'+u.user_metadata.amba_id.slice(-10).toUpperCase()))];
for(const world of worlds){
 const group=fixtures.filter(u=>world.endsWith(u.user_metadata.amba_id.slice(-10).toUpperCase()));
 await api('/rest/v1/game_worlds?name=eq.'+world+'&owner_id=in.('+group.map(u=>u.id).join(',')+')','PATCH',{owner_id:null});
 for(const u of group)await api('/auth/v1/admin/users/'+u.id,'DELETE');
 await api('/rest/v1/game_worlds?name=eq.'+world,'DELETE');
}
await writeFile('evidence/render-regression/recovered-cleanup.json',JSON.stringify({synthetic_accounts_removed:fixtures.length,synthetic_worlds_removed:worlds,scope:'Only Auth-admin-marked NetQA fixtures; original accounts excluded'},null,2));
console.log('Recovered fixture cleanup:',fixtures.length,'temporary accounts removed.');
