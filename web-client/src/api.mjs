import {session,request,key,PROJECT} from './session.mjs';
import {toWebSnapshot,webForRuntime,runtimeForWeb,appearanceToEquipment,equipmentToAppearance,peerToWeb} from './mapping.mjs';
export const state={world:null,sessionId:0,cursor:0,events:[],chat:[],peers:new Map(),position:{x:50,y:23},lastEvents:0,lastBeat:0,sequence:0};
let socket,ref=0,heartbeat,topics=new Set(),pending=new Map(),motionSeen=new Map(),pollPending;
const sql=(name,args={})=>request('/rest/v1/rpc/'+name,args);
const send=(topic,event,payload)=>{if(socket?.readyState===WebSocket.OPEN)socket.send(JSON.stringify({topic,event,payload,ref:String(++ref)}));return String(ref);};
async function subscribe(topic){if(topics.has(topic))return;topics.add(topic);const id=send(topic,'phx_join',{config:{private:true,broadcast:{ack:false,self:false},presence:{enabled:false}},access_token:await session.getAccessToken()});await new Promise((resolve,reject)=>{const t=setTimeout(()=>{pending.delete(id);reject(Error('Private channel timed out'));},15000);pending.set(id,{resolve:()=>{clearTimeout(t);resolve();},reject:error=>{clearTimeout(t);reject(error);}});});}
async function transport(){
 socket=new WebSocket(PROJECT.replace('https:','wss:')+'/realtime/v1/websocket?apikey='+encodeURIComponent(key)+'&vsn=1.0.0');topics.clear();
 socket.onmessage=event=>{let p;try{p=JSON.parse(event.data);}catch{return;}if(p.event==='phx_reply'){const job=pending.get(p.ref);if(job){pending.delete(p.ref);p.payload.status==='ok'?job.resolve():job.reject(Error('Private channel rejected'));}return;}if(p.event==='broadcast'&&p.payload.event==='motion'){
 const uid=p.topic.split(':').at(-1),m=p.payload.payload;if(uid===session.profile?.id||!state.peers.has(uid)||!Number.isInteger(m.seq)||m.seq<=(motionSeen.get(uid)||-1))return;
 for(const field of ['x','y','vx','vy','punch'])if(!Number.isFinite(m[field]))return;
 if(m.x<0||m.x>3200||m.y<0||m.y>1920||Math.abs(m.vx)>2000||Math.abs(m.vy)>2000||m.punch<0||m.punch>.2||![1,-1].includes(m.facing)||typeof m.grounded!=='boolean')return;
 motionSeen.set(uid,m.seq);const peer=state.peers.get(uid);Object.assign(peer,{x:(m.x-10)/32,y:(m.y-30)/32,facing:m.facing<0?'left':'right',animation:m.grounded?(Math.abs(m.vx)>1?'walk':'idle'):'jump',sequence:m.seq});
 if(m.punch>0)state.events.push({id:'punch:'+uid+':'+m.seq,kind:'punch',payload:{user_id:uid,x:Math.floor(peer.x)+(m.facing<0?-1:1),y:Math.floor(peer.y)}});
 }};
 await new Promise((resolve,reject)=>{const t=setTimeout(()=>reject(Error('Realtime connection timeout')),15000);socket.onopen=()=>{clearTimeout(t);resolve();};socket.onerror=()=>{clearTimeout(t);reject(Error('Realtime connection unavailable'));};});
 await subscribe('realtime:game:'+state.world.world.id);await subscribe('realtime:motion:'+state.world.world.id+':'+session.profile.id);
 heartbeat=setInterval(()=>send('phoenix','heartbeat',{}),20000);
}
async function roster(){const rows=await sql('game_roster',{p_world:state.world.world.id}),seen=new Set();for(const row of rows){seen.add(row.uid);const old=state.peers.get(row.uid),peer=peerToWeb(row);if(old)Object.assign(peer,{x:old.x,y:old.y,sequence:old.sequence,facing:old.facing,animation:old.animation});state.peers.set(row.uid,{...peer,player_id:row.id});state.playerIds[row.id]=row.uid;if(socket?.readyState===1)await subscribe('realtime:motion:'+state.world.world.id+':'+row.uid);}for(const uid of state.peers.keys())if(!seen.has(uid)){state.peers.delete(uid);motionSeen.delete(uid);}return {players:[...state.peers.values()],version:state.world.world.version};}
function ingest(rows){for(const event of rows||[]){if(event.sequence<=state.cursor)continue;state.cursor=event.sequence;const p=event.packet,id=String(event.sequence);if(p.type==='tile'){
 const edit={x:p.x,y:p.y,layer:p.layer,id:webForRuntime(p.item)};state.world.snapshot[p.layer][p.y*100+p.x]=edit.id;state.world.world.version++;state.events.push({id,kind:'edit',version:state.world.world.version,payload:{edits:[edit]}});
 }else if(p.type==='chat'){const peer=[...state.peers.values()].find(x=>x.player_id===p.id);const uid=peer?.user_id||state.playerIds?.[p.id]||'world';const message={id,user_id:uid,grow_id:p.name,text:p.text,created_at:new Date().toISOString()};state.chat.push(message);if(state.chat.length>50)state.chat.shift();state.events.push({id,kind:'chat',payload:message});
 }else if(p.type==='effect'&&p.event?.type==='tile_damaged'){state.events.push({id,kind:'punch',payload:{user_id:state.playerIds?.[p.id],x:p.event.tile[0],y:p.event.tile[1]}});}
 }}
async function events(){if(pollPending)return pollPending;pollPending=(async()=>{const r=await sql('game_events',{p_after:state.cursor});ingest(r.events);state.lastEvents=Date.now();})().finally(()=>pollPending=null);return pollPending;}
async function beat(){await sql('game_heartbeat',{p_x:state.position.x*32+10,p_y:state.position.y*32+30,p_player_id:state.sessionId});state.lastBeat=Date.now();}
async function command(type,args={}){if(['place','punch'].includes(type))await beat();const result=await sql('game_command',{p_command:{type,session:state.sessionId,cursor:state.cursor,...args}});ingest(result.events);return result;}
async function join(name){await close(false);const result=await sql('game_join',{p_world:name});state.sessionId=result.id;state.cursor=result.cursor||0;state.events=[];state.chat=[];state.world={world:{id:name,name,version:0,updated_at:new Date().toISOString()},snapshot:toWebSnapshot(result.world),locks:result.world.locks||[],players:[]};state.position={x:(1616-10)/32,y:(768-30)/32};state.playerIds={};const rows=await sql('game_roster',{p_world:name});for(const row of rows){state.playerIds[row.id]=row.uid;state.peers.set(row.uid,{...peerToWeb(row),player_id:row.id});}await transport();await roster();state.world.players=[...state.peers.values()];return structuredClone(state.world);}
async function close(leave=true){clearInterval(heartbeat);if(socket){socket.onmessage=null;socket.close();socket=null;}topics.clear();motionSeen.clear();for(const job of pending.values())job.reject(Error('World connection closed'));pending.clear();if(leave&&state.sessionId)await sql('game_leave',{p_player_id:state.sessionId});state.peers.clear();state.sessionId=0;}
export const api={session,async rpc(name,a={}){
 switch(name){
 case 'game_me':return session.profile;
 case 'game_touch':return true;
 case 'game_worlds_list':return (await sql('game_world_list')).filter(w=>!a.p_query||w.name.includes(a.p_query.toUpperCase())).map(w=>({id:w.name,name:w.name,player_count:w.count}));
 case 'game_create_world':if(!/^[A-Za-z0-9]{1,18}$/.test(a.p_name))throw Error('Use a 1–18 character world name');return a.p_name.toUpperCase();
 case 'game_join':return join(a.p_world);
 case 'game_state':return structuredClone({...state.world,players:[...state.peers.values()]});
 case 'game_roster':return roster();
 case 'game_sync_motion':{
 if(a.p_sequence!=null){state.position={x:a.p_x,y:a.p_y};const animation=a.p_animation,facing=a.p_facing==='left'?-1:1;send('realtime:motion:'+state.world.world.id+':'+session.profile.id,'broadcast',{type:'broadcast',event:'motion',payload:{seq:++state.sequence,x:a.p_x*32+10,y:a.p_y*32+30,vx:animation==='walk'?150*facing:0,vy:animation==='jump'?-150:0,facing,grounded:animation!=='jump',punch:0}});const self=state.peers.get(session.profile.id);if(self)Object.assign(self,{x:a.p_x,y:a.p_y,facing:a.p_facing,animation,sequence:a.p_sequence});}
 if(Date.now()-state.lastBeat>8000)await beat();if(Date.now()-state.lastEvents>800)await events();return {cursor:state.cursor,head:state.cursor,version:state.world.world.version,players:[...state.peers.values()].filter(p=>p.user_id!==session.profile.id),events:state.events.splice(0)};}
 case 'game_heartbeat':return beat();
 case 'game_leave':await close();return true;
 case 'game_chat_history':return state.chat;
 case 'game_locks_list':return state.world.locks.map(l=>({id:l.x+','+l.y,x:l.x,y:l.y,kind:({5:'world',200242:'world',201796:'diamond',200202:'small',200204:'big',200206:'huge'})[l.item]||'world',owner_id:l.owner,owner_name:state.peers.get(l.owner)?.grow_id||'Owner',tiles:l.tiles?.length?l.tiles:Array.from({length:6000},(_,i)=>i),grants:[]}));
 case 'game_place_lock':{const id=({world:10,diamond:11,small:12,big:13,huge:14})[a.p_kind];await command('place',{x:a.p_x,y:a.p_y,item:runtimeForWeb(id)});const lock={x:a.p_x,y:a.p_y,item:runtimeForWeb(id),owner:session.profile.id,area:['world','diamond'].includes(a.p_kind)?0:({small:10,big:48,huge:200})[a.p_kind],tiles:[]};state.world.locks.push(lock);return {lock_id:a.p_x+','+a.p_y,kind:a.p_kind,x:a.p_x,y:a.p_y,owner_id:session.profile.id,owner_name:session.profile.grow_id,version:state.world.world.version};}
 case 'game_remove_lock':{const [x,y]=a.p_lock.split(',').map(Number);await command('punch',{x,y});if(state.world.snapshot.foreground[y*100+x]!==0)throw Error('Lock needs more hits. Punch again.');state.world.locks=state.world.locks.filter(l=>l.x!==x||l.y!==y);return {version:state.world.world.version};}
 case 'game_set_appearance':{const equipment=appearanceToEquipment(a.p_appearance);await command('outfit',{equipment,skin:0});session.profile.appearance=a.p_appearance;return a.p_appearance;}
 case 'game_chat':await command('chat',{text:a.p_text});return state.chat.at(-1)?.id;
 case 'game_respawn':{const p=await command('respawn');state.position={x:(p.x-10)/32,y:(p.y-30)/32};return {...state.position,sequence:a.p_sequence+1};}
 case 'game_edit':{if(a.p_edits.length!==1)throw Error('One block per action');const edit=a.p_edits[0];await command('place',{x:edit.x,y:edit.y,item:runtimeForWeb(edit.id)});return {version:state.world.world.version,edits:a.p_edits,saved_at:new Date().toISOString()};}
 case 'game_punch':{const before=state.world.snapshot.foreground[a.p_y*100+a.p_x];await command('punch',{x:a.p_x,y:a.p_y});const after=state.world.snapshot.foreground[a.p_y*100+a.p_x];return {version:state.world.world.version,edits:after!==before?[{x:a.p_x,y:a.p_y,layer:'foreground',id:after}]:[],tile_id:before,remaining:0};}
 default:throw Error('This operation is not available in the dedicated game service yet.');
 }
}};
