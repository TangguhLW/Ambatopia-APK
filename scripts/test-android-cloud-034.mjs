import {readFile,writeFile,mkdir,unlink} from 'node:fs/promises';
import {spawn,execFileSync} from 'node:child_process';
import {randomBytes} from 'node:crypto';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
const env=Object.fromEntries((await readFile('server/private/.env','utf8')).split(/\r?\n/).filter(x=>x.includes('=')).map(x=>{const n=x.indexOf('=');return [x.slice(0,n),x.slice(n+1).trim().replace(/^"|"$/g,'')]}));
assert.equal(env.SUPABASE_URL,'https://hbptqogoihmguhdizqcf.supabase.co');
const suffix=randomBytes(5).toString('hex'),name='PhoneQA'+suffix,world='ANDQA'+suffix.toUpperCase();
const password=randomBytes(24).toString('base64url'),checks=[];
const version=process.argv[2]||'0.34.1';
assert(/^\d+\.\d+\.\d+$/.test(version));
const evidence='evidence/android-'+version.replaceAll('.',''),fixturePath='server/private/qa-android.json';
const adb=resolve('tools/android-sdk/platform-tools/adb.exe'),pkg='org.thaney.growtopiareconstruction';
let uid,token,failure;
async function api(path,{admin=false,method='POST',body}={}){
 const response=await fetch(env.SUPABASE_URL+path,{method,headers:{apikey:admin?env.SUPABASE_SECRET_KEY:env.SUPABASE_PUBLISHABLE_KEY,...(!admin&&token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(25000)});
 const text=await response.text();let data;try{data=JSON.parse(text)}catch{data=text}return{ok:response.ok,status:response.status,data};
}
function adbRun(args){return execFileSync(adb,args,{encoding:'utf8',windowsHide:true,timeout:15000}).trim()}
try{
 await mkdir(evidence,{recursive:true});
 const created=await api('/auth/v1/admin/users',{admin:true,body:{email:name.toLowerCase()+'@players.ambatopia.invalid',password,email_confirm:true,user_metadata:{amba_id:name},app_metadata:{game_provisioned:true,test_fixture:true}}});
 assert(created.ok,'Create disposable Android fixture');uid=created.data.id;checks.push('Disposable account created without email/SMS');
 const login=await api('/auth/v1/token?grant_type=password',{body:{email:name.toLowerCase()+'@players.ambatopia.invalid',password}});
 assert(login.ok,'Fixture login');token=login.data.access_token;
 await writeFile(fixturePath,JSON.stringify({name,password,world}));
 const child=spawn('pwsh',['-NoProfile','-File','scripts/test-android.ps1','-SkipInstall','-Authenticated','-ApkPath','build/android/Ambatopia-'+version+'.apk','-EvidenceDirectory',evidence,'-TimeoutSeconds','420'],{windowsHide:true});
 let output='';child.stdout.on('data',data=>output+=data);child.stderr.on('data',data=>output+=data);
 const exitCode=await new Promise((resolve,reject)=>{child.once('error',reject);child.once('exit',resolve)});
 await writeFile(evidence+'/runner.log',output);
 const report=JSON.parse(await readFile(evidence+'/qa-report.json','utf8'));
 assert.equal(exitCode,0,'Physical Android GUI checks');assert.equal(report.failures.length,0,'Android assertions');
 checks.push('Physical Android GUI and real Supabase authentication passed');
 const roster=await api('/rest/v1/rpc/game_roster',{body:{p_world:world}});
 assert(roster.ok&&roster.data.some(row=>row.name===name),'Android presence exists in Supabase world');checks.push('Android presence observed in live Supabase roster');
 await writeFile(evidence+'/cloud.json',JSON.stringify({checks,world,project:'ambatopia-godot',transport:'native Android direct HTTPS/WSS, no localhost reverse tunnel'},null,2));
}catch(error){failure=error;console.error(error.message)}
finally{
 await unlink(fixturePath).catch(()=>{});
 if(uid){
  const verify=await api('/auth/v1/admin/users/'+uid,{admin:true,method:'GET'});
  assert(verify.ok&&verify.data.app_metadata?.test_fixture===true&&verify.data.user_metadata?.amba_id===name,'Cleanup must be restricted to the created fixture');
  const detach=await api('/rest/v1/game_worlds?name=eq.'+world+'&owner_id=eq.'+uid,{admin:true,method:'PATCH',body:{owner_id:null}});assert(detach.ok,'Detach fixture ownership');
  const deleted=await api('/auth/v1/admin/users/'+uid,{admin:true,method:'DELETE'});assert(deleted.ok,'Delete own temporary Auth account');
  const removed=await api('/rest/v1/game_worlds?name=eq.'+world,{admin:true,method:'DELETE'});assert(removed.ok,'Delete own synthetic world');
  await writeFile(evidence+'/cleanup.json',JSON.stringify({account_removed:deleted.ok,world_removed:removed.ok,original_accounts_used:false,email_sms_sent:false,failure:failure?.message||null},null,2));
 }
 try{
  adbRun(['shell','am','force-stop',pkg]);
  const component=adbRun(['shell','cmd','package','resolve-activity','--brief',pkg]).split(/\r?\n/).find(line=>line.startsWith(pkg+'/'));
  if(component)adbRun(['shell','am','start','-n',component]);
 }catch(error){console.error('Normal app restart unavailable:',error.message.split('\n')[0])}
}
if(failure)process.exitCode=1;else console.log('Android GUI + Supabase passed; synthetic account/world removed; normal app reopened.');
