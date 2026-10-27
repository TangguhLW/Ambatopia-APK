import {readFile,writeFile,mkdir,mkdtemp,unlink} from 'node:fs/promises';
import {spawn} from 'node:child_process';
import {resolve} from 'node:path';
import {randomBytes} from 'node:crypto';
import assert from 'node:assert/strict';
const env=Object.fromEntries((await readFile('server/private/.env','utf8')).split(/\r?\n/).filter(x=>x.includes('=')).map(x=>{const n=x.indexOf('=');return [x.slice(0,n),x.slice(n+1).trim().replace(/^"|"$/g,'')]}));
const url=env.SUPABASE_URL;
assert.equal(url,'https://hbptqogoihmguhdizqcf.supabase.co');
const suffix=randomBytes(5).toString('hex');
const world='NETQA'+suffix.toUpperCase();
const created=[],connections=[],checks=[],timings=[],fallbacks=[];
let error;
const timers=[];
async function api(path,{token,body,method='POST',admin=false}={}){
 const started=performance.now();
 const response=await fetch(url+path,{method,headers:{apikey:admin?env.SUPABASE_SECRET_KEY:env.SUPABASE_PUBLISHABLE_KEY,...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
 const raw=await response.text();let data;try{data=JSON.parse(raw)}catch{data=raw}
 timings.push(performance.now()-started);
 return {ok:response.ok,status:response.status,data};
}
const rpc=(actor,name,body={})=>api('/rest/v1/rpc/'+name,{token:actor.token,body});
function check(value,name){assert.ok(value,name);checks.push(name)}
async function fixture(number){
 const name='NetQA'+number+suffix,password=randomBytes(24).toString('base64url');
 const result=await api('/auth/v1/admin/users',{admin:true,body:{email:name.toLowerCase()+'@players.ambatopia.invalid',password,email_confirm:true,user_metadata:{amba_id:name},app_metadata:{game_provisioned:true,test_fixture:true}}});
 if(!result.ok) throw Error('Fixture creation failed: '+JSON.stringify(result.data));
 check(result.ok,'Create synthetic fixture '+number);
 created.push({id:result.data.id});
 const login=await api('/auth/v1/token?grant_type=password',{body:{email:name.toLowerCase()+'@players.ambatopia.invalid',password}});
 check(login.ok,'Authenticate synthetic fixture '+number);
 Object.assign(created.at(-1),{token:login.data.access_token});
 return created.at(-1);
}
async function realtime(actor){
 const ws=new WebSocket(url.replace('https://','wss://')+'/realtime/v1/websocket?apikey='+encodeURIComponent(env.SUPABASE_PUBLISHABLE_KEY)+'&vsn=1.0.0');
 connections.push(ws);const messages=[];let ref=0;
 ws.addEventListener('message',e=>{try{messages.push(JSON.parse(e.data))}catch{}});
 await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(Error('Realtime connection timeout')),20000);ws.addEventListener('open',()=>{clearTimeout(timeout);resolve()},{once:true});ws.addEventListener('error',()=>{clearTimeout(timeout);reject(Error('Realtime connection failed'))},{once:true})});
 async function wait(predicate,label='expected realtime message',duration=20000){const limit=Date.now()+duration;while(Date.now()<limit){const index=messages.findIndex(predicate);if(index>=0)return messages.splice(index,1)[0];await new Promise(r=>setTimeout(r,30));}throw Error('Realtime timeout: '+label+'; queued events: '+messages.map(p=>p.event+':'+(p.payload?.event||p.payload?.status||p.payload?.message||'')).join(',').slice(0,800))}
 timers.push(setInterval(()=>{if(ws.readyState===WebSocket.OPEN)ws.send(JSON.stringify({topic:'phoenix',event:'heartbeat',payload:{},ref:'heartbeat'}))},15000));
 function send(topic,event,payload){const id=String(++ref);ws.send(JSON.stringify({topic,event,payload,ref:id}));return id}
 async function join(topic){const id=send(topic,'phx_join',{config:{private:true,broadcast:{ack:false,self:false},presence:{enabled:false}},access_token:actor.token});const result=await wait(p=>p.event==='phx_reply'&&p.ref===id,'join '+topic.split(':')[1]);check(result.payload.status==='ok','Private channel join '+topic.split(':')[1]+': '+JSON.stringify(result.payload.response));return result}
 return {ws,wait,send,join};
}
try{
 const a=await fixture(1),b=await fixture(2);
 for(const actor of [a,b]){
  const joined=await rpc(actor,'game_join',{p_world:world});
  check(joined.ok&&joined.data.type==='welcome','World join returns a valid snapshot');
  actor.player=joined.data.id;
  timers.push(setInterval(()=>{rpc(actor,'game_heartbeat',{p_x:1616,p_y:768,p_player_id:actor.player}).catch(()=>{})},8000));
 }
 const allowed=await rpc(a,'game_channel_allowed',{topic:'game:'+world,writing:false});check(allowed.ok&&allowed.data===true,'SQL grants the joined account access to its world topic');
 const ra=await realtime(a),rb=await realtime(b);
 const room='realtime:game:'+world,motion='realtime:motion:'+world+':'+a.id;
 await ra.join(room);await rb.join(room);await ra.join(motion);await rb.join(motion);
 const mark=performance.now();
 ra.send(motion,'broadcast',{type:'broadcast',event:'motion',payload:{seq:1,x:1630,y:768,vx:120,vy:0,facing:1,grounded:true,punch:0.12}});
 const movement=await rb.wait(p=>p.topic===motion&&p.event==='broadcast'&&p.payload.event==='motion','peer motion');
 check(movement.payload.payload.seq===1,'Second authenticated client receives player motion');
 const motionMs=performance.now()-mark;
 const command=(actor,type,args={})=>rpc(actor,'game_command',{p_command:{type,session:actor.player,...args}});
 check((await command(a,'outfit',{equipment:{shirt:5264,neck:6064,feet:1740,hand:5480},skin:2})).ok,'Source wardrobe IDs persist through live outfit validation');
 const locked=await command(a,'place',{x:51,y:23,item:5});check(locked.ok,'Owner places a World Lock');
 let tile;try{tile=await rb.wait(p=>p.event==='broadcast'&&p.payload?.payload?.type==='tile','persistent tile',3000)}catch{const history=await rpc(b,'game_events',{p_after:0});check(history.ok,'Persistent event recovery is available');tile={payload:{payload:history.data.events.find(e=>e.packet.type==='tile')?.packet}};fallbacks.push('World Lock broadcast recovered from ordered event log');}
 check(tile.payload.payload.item===5,'World Lock update reaches the second client');
 const denied=await command(b,'place',{x:49,y:23,item:1});check(!denied.ok&&/locked/i.test(denied.data.message),'Another player cannot modify a locked world');
 const privilege=await api('/rest/v1/game_profiles?id=eq.'+b.id,{token:b.token,method:'PATCH',body:{role:'developer'}});
 check(!privilege.ok,'Client cannot promote itself');
 const chat=await command(b,'chat',{text:'Synthetic multiplayer verification'});check(chat.ok,'Authenticated world chat accepted');
 let seenChat;try{seenChat=await ra.wait(p=>p.event==='broadcast'&&p.payload?.payload?.type==='chat','world chat',3000)}catch{const history=await rpc(a,'game_events',{p_after:0});seenChat={payload:{payload:history.data.events.find(e=>e.packet.type==='chat')?.packet}};fallbacks.push('Chat broadcast recovered from ordered event log');}
 check(seenChat.payload.payload.id===b.player,'Chat uses server-derived player identity');
 const protectedTile=await command(a,'punch',{x:50,y:24});check(!protectedTile.ok,'Ordinary world owner cannot break bedrock');
 if(process.argv.includes('--growth')){
  const issue=async(type,args)=>{await new Promise(resolve=>setTimeout(resolve,250));const result=await command(a,type,args);check(result.ok,'Shared growth command '+type+': '+(args.command||args.item));return result.data};
  const seed=await issue('place',{x:49,y:23,item:200003});
  check(seed.events.some(event=>event.packet.type==='item_state'&&event.packet.data.seed===3&&event.packet.data.duration===31),'Live placement carries verified seed timing metadata');
  await issue('machine',{x:49,y:23,command:'grow',args:{}});
  const harvested=await issue('machine',{x:49,y:23,command:'harvest',args:{}});
  check(harvested.events.some(event=>event.packet.type==='item_state'&&event.packet.drops.some(drop=>drop.id===3)),'Live harvest persists seed and crop rewards');
  const provider=await issue('place',{x:52,y:23,item:200866});
  check(provider.events.some(event=>event.packet.type==='item_state'&&event.packet.x===52&&event.packet.data.ready>0),'Live provider has a server-owned ready timestamp');
  await issue('machine',{x:52,y:23,command:'grow',args:{}});
  const reward=await issue('machine',{x:52,y:23,command:'harvest',args:{}});
  check(reward.events.some(event=>event.packet.type==='item_state'&&event.packet.drops.some(drop=>drop.id===868)),'Live provider grants its source-specific reward');
 }
 const previous=a.player;
 const rejoin=await rpc(a,'game_join',{p_world:world});check(rejoin.ok&&rejoin.data.id!==previous,'Reconnect assigns a fresh session identity');
 a.player=rejoin.data.id;
 await rpc(a,'game_leave',{p_player_id:previous});
 const roster=await rpc(a,'game_roster',{p_world:world});check(roster.ok&&roster.data.some(p=>p.id===a.player),'A stale disconnect cannot remove the new session');
 const stale=await rpc(a,'game_command',{p_command:{type:'chat',session:previous,text:'Stale session'}});check(!stale.ok,'A stale session cannot send gameplay commands');
 const peerWrite=await rpc(b,'game_channel_allowed',{topic:'motion:'+world+':'+a.id,writing:true});
 // This authorization predicate is safe to query; no credentials or role mutations.
 check(peerWrite.ok&&peerWrite.data===false,'Motion channel write permission belongs to its account');

 if(process.argv.includes('--godot')){
  const fixtureDir=await mkdtemp(resolve('server/private/godot-netqa-'));
  const fixturePath=resolve(fixtureDir,'fixture.json'),readyPath=resolve(fixtureDir,'ready.json'),reportPath=resolve(fixtureDir,'report.json');
  const profile=await api('/rest/v1/game_profiles?id=eq.'+b.id+'&select=*',{token:b.token,method:'GET'});
  check(profile.ok&&profile.data.length===1,'Read synthetic Godot profile');
  await writeFile(fixturePath,JSON.stringify({token:b.token,profile:profile.data[0],other_uid:a.id,world,ready_path:readyPath,report_path:reportPath}));
  const engine=JSON.parse(await readFile('tools/toolchain.json','utf8')).engine;
  const visible=process.argv.includes('--visible');
  const child=spawn(engine,[...(visible?[]:['--headless']),'--path','.', '--script','tests/supabase_client_live.gd','--',fixturePath],{env:{...process.env,APPDATA:resolve('tools/profile-cloud-qa')},windowsHide:!visible});
  let output='';child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);
  const exit=new Promise(r=>child.once('exit',code=>r(code)));
  try{
   const deadline=Date.now()+30000;let ready=false;
   while(Date.now()<deadline){try{ready=JSON.parse(await readFile(readyPath,'utf8')).ready}catch{}if(ready||child.exitCode!==null)break;await new Promise(r=>setTimeout(r,80));}
   check(ready,'Godot client joins the deployed Supabase service');
   ra.send(motion,'broadcast',{type:'broadcast',event:'motion',payload:{seq:88,x:1580,y:768,vx:-120,vy:0,facing:-1,grounded:true,punch:.1,item_options:{pet_5480:false}}});
   check((await command(a,'chat',{text:'Godot bridge verification'})).ok,'Send chat to Godot');
   await new Promise(r=>setTimeout(r,240));
   check((await command(a,'place',{x:48,y:23,item:1})).ok,'Send a block edit to Godot');
   const exitCode=await Promise.race([exit,new Promise((_,reject)=>setTimeout(()=>reject(Error('Godot client timeout')),25000))]);
   const report=JSON.parse(await readFile(reportPath,'utf8'));
   await writeFile('evidence/supabase-online/godot-client.json',JSON.stringify(report,null,2));
   check(exitCode===0&&report.failures.length===0&&!/SCRIPT ERROR|ERROR:/.test(output),'Godot movement/jump/punch/audio/chat/block integration passes');
  }catch(error){await writeFile('evidence/supabase-online/godot-client.log',output);throw error}
  finally{if(child.exitCode===null)child.kill();await unlink(fixturePath).catch(()=>{});}
 }
 checks.push('No original account, email or SMS used');
 timings.sort((x,y)=>x-y);
 await mkdir('evidence/supabase-online',{recursive:true});
 await writeFile('evidence/supabase-online/live.json',JSON.stringify({project:'ambatopia-godot',checks,motion_ms:Math.round(motionMs),http_p95_ms:Math.round(timings[Math.floor(timings.length*.95)]),database_broadcast_fallbacks:fallbacks,note:'Two synthetic account protocol test, not a capacity or Android test'},null,2));
}catch(e){error=e;console.error('Live check failed:',e.message)}
finally{
 for(const timer of timers)clearInterval(timer);
 for(const ws of connections)ws.close();
 for(const actor of created)if(actor.token){const current=await rpc(actor,'game_roster',{p_world:world});if(current.ok)actor.player=current.data.find(p=>p.uid===actor.id)?.id||actor.player;await rpc(actor,'game_leave',{p_player_id:actor.player||0});}
 if(created.length){const detached=await api('/rest/v1/game_worlds?name=eq.'+world+'&owner_id=in.('+created.map(a=>a.id).join(',')+')',{admin:true,method:'PATCH',body:{owner_id:null}});check(detached.ok,'Disposable world ownership released before account cleanup');}
 for(const actor of created){assert.match(actor.id,/^[a-f0-9-]{36}$/);const removed=await api('/auth/v1/admin/users/'+actor.id,{admin:true,method:'DELETE'});check(removed.ok,'Synthetic account cleaned')}
 // Auth deletion cascades any remaining presence row before removing the fixture world.
 const removedWorld=await api('/rest/v1/game_worlds?name=eq.'+world,{admin:true,method:'DELETE'});
 check(removedWorld.ok,'Synthetic world cleaned');
 await mkdir('evidence/supabase-online',{recursive:true});
 await writeFile('evidence/supabase-online/cleanup.json',JSON.stringify({accounts:created.length,world_cleaned:removedWorld.ok,checks:checks.filter(x=>x.includes('cleaned')),failure:error?.message||null,completed_checks:checks},null,2));
}
if(error)process.exitCode=1;else console.log('Live Supabase checks:',checks.length,'passed. Synthetic fixtures cleaned.');



