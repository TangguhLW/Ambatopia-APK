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
 await mkdir('evidence/supabase-online',{recursive:true});
 const actors=[];
 for(let i=1;i<=9;i++)actors.push(await fixture(i));
 const observer=actors.pop();
 for(const actor of actors){
  const joined=await rpc(actor,'game_join',{p_world:world});
  check(joined.ok&&joined.data.type==='welcome','Crowd joins authenticated world');
  actor.player=joined.data.id;
  timers.push(setInterval(()=>rpc(actor,'game_heartbeat',{p_x:1616,p_y:768,p_player_id:actor.player}).catch(()=>{}),8000));
 }
 const clients=[];
 for(const actor of actors){
  const client=await realtime(actor);clients.push(client);
  await client.join('realtime:game:'+world);
  for(const sender of actors)await client.join('realtime:motion:'+world+':'+sender.id);
 }
 const dir=await mkdtemp(resolve('server/private/crowd-qa-'));
 const fixturePath=resolve(dir,'fixture.json'),readyPath=resolve(dir,'ready.json'),reportPath=resolve(dir,'report.json');
 const profile=await api('/rest/v1/game_profiles?id=eq.'+observer.id+'&select=*',{token:observer.token,method:'GET'});
 await writeFile(fixturePath,JSON.stringify({token:observer.token,profile:profile.data[0],world,expected:actors.length,ready_path:readyPath,report_path:reportPath}));
 const engine=JSON.parse(await readFile('tools/toolchain.json','utf8')).engine;
 const child=spawn(engine,['--headless','--path','.','--script','tests/supabase_crowd_live.gd','--',fixturePath],{env:{...process.env,APPDATA:resolve('tools/profile-crowd-qa')},windowsHide:true});
 let output='';child.stdout.on('data',b=>output+=b);child.stderr.on('data',b=>output+=b);
 const exited=new Promise(r=>child.once('exit',code=>r(code)));
 try{
  let ready=false;const deadline=Date.now()+35000;
  while(Date.now()<deadline){try{ready=JSON.parse(await readFile(readyPath,'utf8')).ready}catch{}if(ready||child.exitCode!==null)break;await new Promise(r=>setTimeout(r,100));}
  check(ready,'Actual Godot observer sees all eight peers and joins their private motion topics');
  const roster=await rpc(actors[0],'game_roster',{p_world:world});
  check(roster.ok&&roster.data.length===9,'Nine simultaneous authenticated players share the world');
  const sent=new Map(),received=new Set(),latencies=[],errors=[];
  clients.forEach((client,index)=>client.ws.addEventListener('message',event=>{
   let p;try{p=JSON.parse(event.data)}catch{return}
   if(['phx_error','phx_close','system'].includes(p.event))errors.push({event:p.event,payload:p.payload});
   if(p.event!=='broadcast'||p.payload?.event!=='motion')return;
   const payload=p.payload.payload;if(!Number.isInteger(payload.seq))return;
   const uid=p.topic.split(':').at(-1),key=uid+':'+payload.seq;
   if(!sent.has(key)||uid===actors[index].id)return;
   received.add(index+':'+key);latencies.push(performance.now()-sent.get(key));
  }));
  // 8 broadcasts/s * 9 players = <=72 events/s, below Free's 100/s.
  // Every sender is exercised; this is bounded sparse traffic, not 9*10 Hz capacity.
  const started=performance.now();
  for(let round=1;round<=8;round++)for(let i=0;i<actors.length;i++){
   const actor=actors[i],key=actor.id+':'+round;sent.set(key,performance.now());
   clients[i].send('realtime:motion:'+world+':'+actor.id,'broadcast',{type:'broadcast',event:'motion',payload:{seq:round,x:1500+i*20+round,y:768-(round%2)*20,vx:120,vy:round%2?-120:0,facing:i%2?-1:1,grounded:round%2===0,punch:round%3===0?.12:0,punch_dx:i%2?-1:1,punch_dy:0}});
   await new Promise(r=>setTimeout(r,125));
  }
  await new Promise(r=>setTimeout(r,800));
  check(received.size===sent.size*(actors.length-1),'Every crowd movement/jump/punch sample reaches every other protocol client');
  check(errors.length===0,'No Realtime disconnect or rate-limit error during bounded crowd run');
  const command=(actor,type,args={})=>rpc(actor,'game_command',{p_command:{type,session:actor.player,...args}});
  check((await command(actors[0],'place',{x:51,y:23,item:5})).ok,'Crowd owner places a lock');
  for(let i=1;i<actors.length;i++){
   const denied=await command(actors[i],'place',{x:49,y:23,item:1});check(!denied.ok,'Lock rejects crowd peer '+i);
  }
  check((await command(actors[1],'chat',{text:'Crowd bridge verification'})).ok,'Crowd chat accepted with server identity');
  check((await command(actors[0],'place',{x:48,y:23,item:1})).ok,'Crowd block edit committed');
  for(const actor of actors){const history=await rpc(actor,'game_events',{p_after:0});check(history.ok&&history.data.events.some(e=>e.packet.type==='chat')&&history.data.events.some(e=>e.packet.type==='tile'),'Every crowd peer can recover ordered chat and block state');}
  const code=await Promise.race([exited,new Promise((_,reject)=>setTimeout(()=>reject(Error('Crowd Godot timeout')),35000))]);
  const godot=JSON.parse(await readFile(reportPath,'utf8'));
  check(code===0&&godot.failures.length===0&&!/SCRIPT ERROR|ERROR:/.test(output),'Actual Godot world renders eight peers and receives their punch, movement, chat and block edit');
  latencies.sort((a,b)=>a-b);
  await writeFile('evidence/supabase-online/crowd.json',JSON.stringify({players:9,protocol_clients:8,godot_clients:1,checks,sent:sent.size,expected_deliveries:sent.size*7,received_deliveries:received.size,delivery_p50_ms:latencies[Math.floor(latencies.length*.5)],delivery_p95_ms:latencies[Math.floor(latencies.length*.95)],duration_ms:performance.now()-started,realtime_errors:errors,godot,traffic:'8 aggregate motion broadcasts/s, sparse per-player traffic; does not establish nine players at 10 Hz or a production capacity ceiling',limits_source:'https://supabase.com/docs/guides/realtime/limits'},null,2));
 }finally{if(child.exitCode===null)child.kill();await unlink(fixturePath).catch(()=>{});await writeFile('evidence/supabase-online/crowd-godot.log',output);}
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
 await writeFile('evidence/supabase-online/crowd-cleanup.json',JSON.stringify({accounts:created.length,world_cleaned:removedWorld.ok,checks:checks.filter(x=>x.includes('cleaned')),failure:error?.message||null,completed_checks:checks},null,2));
}
if(error)process.exitCode=1;else console.log('Live Supabase checks:',checks.length,'passed. Synthetic fixtures cleaned.');



