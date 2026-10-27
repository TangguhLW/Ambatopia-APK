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
 globalThis.localStorage={values:new Map(),getItem(k){return this.values.get(k)||null},setItem(k,v){this.values.set(k,v)},removeItem(k){this.values.delete(k)}};
 globalThis.location=new URL('http://127.0.0.1:4196/?qa=1');
 const {session}=await import('../web-client/src/session.mjs');
 const {api:game,state}=await import('../web-client/src/api.mjs');
 const a=await fixture(1),b=await fixture(2);
 const joined=await rpc(a,'game_join',{p_world:world});a.player=joined.data.id;
 await session.testSession({access_token:b.token,refresh_token:'',expires_in:3600,user:{id:b.id}});
 check(session.profile.id===b.id&&session.profile.role==='player','Web-engine client obtains its identity and role from dedicated Supabase');
 const view=await game.rpc('game_join',{p_world:world});b.player=state.sessionId;
 check(view.snapshot.foreground[2450]===3&&view.snapshot.foreground[2350]===15,'Dedicated terrain converts bedrock and white door correctly');
 const ra=await realtime(a);const bTopic='realtime:motion:'+world+':'+b.id,aTopic='realtime:motion:'+world+':'+a.id;
 await ra.join(bTopic);await ra.join(aTopic);
 await game.rpc('game_sync_motion',{p_x:50,p_y:23,p_facing:'right',p_animation:'walk',p_sequence:1});
 const move=await ra.wait(p=>p.topic===bTopic&&p.event==='broadcast','web client movement');
 check(move.payload.payload.x===1610&&move.payload.payload.y===766,'Web physics converts player foot anchor into server pixel coordinates');
 ra.send(aTopic,'broadcast',{type:'broadcast',event:'motion',payload:{seq:9,x:1590,y:766,vx:-120,vy:0,facing:-1,grounded:true,punch:.1}});
 await new Promise(r=>setTimeout(r,200));
 const received=await game.rpc('game_sync_motion',{});
 check(received.players.some(p=>p.user_id===a.id&&p.facing==='left'&&p.sequence===9),'Web client receives another authenticated player motion');
 check(received.events.some(e=>e.kind==='punch'&&e.payload.user_id===a.id),'Web client forwards the peer punch to the shared renderer');
 const outfit={outfit:[46,36,48,40,34,362]};await game.rpc('game_set_appearance',{p_appearance:outfit});
 const stored=await api('/rest/v1/game_profiles?id=eq.'+b.id+'&select=outfit',{token:b.token,method:'GET'});
 check(stored.data[0].outfit.hat===46&&stored.data[0].outfit.back===362,'Reference wardrobe saves correct slot IDs to the dedicated game profile');
 const lock=await game.rpc('game_place_lock',{p_x:51,p_y:23,p_kind:'world'});
 check(lock.owner_id===b.id&&state.world.snapshot.foreground[2351]===10,'Web lock control uses server-verified ownership and native lock ID');
 const denied=await rpc(a,'game_command',{p_command:{type:'place',session:a.player,x:49,y:23,item:1}});
 check(!denied.ok&&/locked/i.test(denied.data.message),'Other client is denied building inside the locked world');
 const chatId=await game.rpc('game_chat',{p_text:'Synthetic web APK bridge test'});
 check(!!chatId&&state.chat.at(-1).user_id===b.id,'Chat identity comes from the server roster');
 const edit=await game.rpc('game_edit',{p_edits:[{x:49,y:23,layer:'foreground',id:1}]});
 check(edit.edits[0].id===1&&state.world.snapshot.foreground[2349]===1,'Reference build action commits a native dirt tile');
 check(view.snapshot.foreground[2349]===0,'UI snapshot stays independent so committed edits still trigger native particles');
 await game.rpc('game_leave',{});
 check(!state.sessionId,'Web client closes its private session cleanly');
 await mkdir('evidence/web-client',{recursive:true});
 await writeFile('evidence/web-client/cloud-bridge.json',JSON.stringify({checks,failures:[],project:'ambatopia-godot',accounts:2,transport:'Actual packaged client API module + authenticated peer WebSocket',no_original_accounts:true},null,2));
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
 await writeFile('evidence/web-client/cloud-cleanup.json',JSON.stringify({accounts:created.length,world_cleaned:removedWorld.ok,checks:checks.filter(x=>x.includes('cleaned')),failure:error?.message||null,completed_checks:checks},null,2));
}
if(error)process.exitCode=1;else console.log('Live Supabase checks:',checks.length,'passed. Synthetic fixtures cleaned.');



