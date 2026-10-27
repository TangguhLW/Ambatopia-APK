import assert from 'node:assert/strict';
import {randomBytes} from 'node:crypto';
import {writeFile} from 'node:fs/promises';
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const accounts=[],clients=[],checks=[];
const world='QA'+Date.now().toString(36).toUpperCase();
async function call(path,body,token){const r=await fetch('http://127.0.0.1:4193'+path,{method:body?'POST':'GET',headers:{'Content-Type':'application/json',...(token?{Authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined});const data=await r.json();if(!r.ok)throw Error(path+': '+data.error);return data;}
async function until(fn,label){const start=Date.now();while(!fn()){if(Date.now()-start>15000)throw Error('Timeout: '+label);await pause(40);}checks.push(label);}
function connect(account){const p={socket:new WebSocket('ws://127.0.0.1:4192'),seq:0,id:0,packets:[],input:{axis:0,action:'none',x:0,y:0,item:0}};p.socket.addEventListener('open',()=>p.socket.send(JSON.stringify({type:'join',name:'spoofed-name',world,token:account?.access_token})));p.socket.addEventListener('message',e=>{const x=JSON.parse(e.data);p.packets.push(x);if(x.type==='welcome'){p.id=x.id;p.welcome=x;}});p.timer=setInterval(()=>{if(p.id&&p.socket.readyState===1)p.socket.send(JSON.stringify({type:'input',seq:++p.seq,jump:false,direct:false,...p.input}));},50);clients.push(p);return p;}
try{
 const denied=connect(null);await until(()=>denied.packets.some(x=>x.ok===false),'Unauthenticated join rejected');denied.socket.close();
 const secret=randomBytes(18).toString('hex');
 for(const suffix of ['A','B']){const x=await call('/auth/register',{name:world+suffix,password:secret});accounts.push(x);}
 const a=connect(accounts[0]),b=connect(accounts[1]);await until(()=>a.id&&b.id,'Two authenticated clients enter shared world');
 assert.equal(a.welcome.players.find(x=>x.id===a.id).name,accounts[0].profile.amba_id);checks.push('Server ignores spoofed client display name');
 a.socket.send(JSON.stringify({type:'developer',command:'invisible',enabled:true}));await pause(200);
 assert(b.packets.some(x=>x.type==='snapshot'&&x.players.some(p=>p.id===a.id)));checks.push('Ordinary player cannot enable developer invisibility');
 a.input={axis:0,action:'place',item:5,x:49,y:23};await until(()=>b.packets.some(x=>x.type==='tile'&&x.item===5),'Authenticated owner places World Lock');a.input={axis:0,action:'none'};
 b.input={axis:0,action:'place',item:1,x:51,y:23};await pause(400);b.input={axis:0,action:'none'};assert(!b.packets.some(x=>x.type==='tile'&&x.x===51&&x.item===1));checks.push('Different account cannot modify locked world');
 a.socket.send(JSON.stringify({type:'outfit',equipment:{hand:98},skin:2}));await pause(300);a.socket.close();await pause(1500);
 const saved=await call('/internal/world',{name:world},process.env.GAME_INTERNAL_TOKEN);assert.equal(saved.world.owner_id,accounts[0].profile.id);assert.equal(saved.world.state.foreground[23*100+49],5);checks.push('World and owner persisted in Supabase after disconnect');
 const again=connect(accounts[0]);await until(()=>again.id,'Owner can reconnect');assert.equal(again.welcome.players.find(x=>x.id===again.id).equipment.hand,98);checks.push('Saved wardrobe restored after reconnect');
 await writeFile('evidence/ambatopia-2026-10-23/authenticated-game.json',JSON.stringify({checks,passed:checks.length,world},null,2));console.log(JSON.stringify({checks,passed:checks.length},null,2));
}finally{
 for(const c of clients){clearInterval(c.timer);c.socket.close();}
 await pause(1800);
 const headers={apikey:process.env.SUPABASE_SECRET_KEY};
 let r=await fetch(process.env.SUPABASE_URL+'/rest/v1/game_worlds?name=eq.'+world,{method:'DELETE',headers});if(!r.ok)throw Error('Test world cleanup failed');
 for(const a of accounts){r=await fetch(process.env.SUPABASE_URL+'/auth/v1/admin/users/'+a.profile.id,{method:'DELETE',headers});if(!r.ok)throw Error('Test account cleanup failed');}
}
