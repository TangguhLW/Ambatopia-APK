import assert from 'node:assert/strict';
import {writeFile} from 'node:fs/promises';
const peers=[],checks=[],sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function until(fn,label){const end=Date.now()+8000;while(!fn()){if(Date.now()>end)throw Error('Timeout: '+label);await sleep(20);}checks.push(label);}
function peer(name){
 const p={socket:new WebSocket('ws://127.0.0.1:4192'),id:0,seq:0,tiles:new Map(),states:new Map(),effects:[],shots:[],players:[],weather:''};peers.push(p);
 p.socket.onopen=()=>p.socket.send(JSON.stringify({type:'join',name,world:'SPECIALNET'}));
 p.socket.onmessage=e=>{const m=JSON.parse(e.data);if(m.type==='welcome')p.id=m.id;if(m.type==='projectiles')p.shots=m.shots;if(m.type==='snapshot')p.players=m.players;if(m.type==='tile')p.tiles.set(`${m.x},${m.y}`,m.item);if(m.type==='item_state')p.states.set(`${m.x},${m.y}`,m.data);if(m.type==='effect')p.effects.push(m.event);if(m.type==='weather')p.weather=m.key;};
 p.input={action:'none',item:0,x:49,y:23};
 p.timer=setInterval(()=>{if(p.id&&p.socket.readyState===1)p.socket.send(JSON.stringify({type:'input',seq:++p.seq,axis:0,jump:false,direct:false,...p.input}));},50);
 p.machine=(x,command,args={})=>p.socket.send(JSON.stringify({type:'machine',x,y:23,command,args}));
 return p;
}
try{
 const a=peer('ItemOwner'),b=peer('ItemGuest');
 await until(()=>a.id&&b.id&&a.players.length===2,'Two exported-server peers enter item world');
 a.input={action:'place',item:203354,x:49,y:23};
 await until(()=>peers.every(p=>p.tiles.get('49,23')===203354),'Sewing Machine reaches both clients');a.input.action='none';
 await sleep(300);a.machine(49,'deposit',{item:3336,amount:3});
 await until(()=>peers.every(p=>p.states.get('49,23')?.stock?.['3336']===3),'Exact silk inputs are shared');
 await sleep(300);a.machine(49,'sew');
 await until(()=>peers.every(p=>p.states.get('49,23')?.stock?.['3336']===0&&p.effects.some(e=>e.type==='reward'&&e.item===7030)),'Sewing consumes bolts and replicates its exact reward');
 a.input={action:'place',item:203316,x:51,y:23};
 await until(()=>peers.every(p=>p.tiles.get('51,23')===203316&&p.states.get('51,23')?.born>0),'Silkworm birth and lifecycle replicated');a.input.action='none';
 await sleep(300);a.machine(51,'care',{item:386});
 await until(()=>peers.every(p=>p.states.get('51,23')?.feeds===1),'Silkworm feeding and RGB state replicated');
 b.socket.send(JSON.stringify({type:'outfit',equipment:{back:14232,hair:14192},skin:0}));
 await until(()=>a.players.some(p=>p.id===b.id&&p.equipment.back===14232&&p.equipment.hair===14192),'Native animated wardrobe identities reach other peer');
 a.input={action:'place',item:204344,x:49,y:22};
 await until(()=>peers.every(p=>p.tiles.get('49,22')===204344),'Blaster placement replicated');a.input.action='none';
 await sleep(300);a.socket.send(JSON.stringify({type:'machine',x:49,y:22,command:'configure',args:{period:2,speed:110,enabled:true}}));
 await until(()=>peers.every(p=>p.states.get('49,22')?.speed===110&&p.states.get('49,22')?.enabled),'Source-specific blaster settings synchronized');
 await until(()=>peers.every(p=>p.shots.length>0&&p.shots[0].vx===110),'Authoritative moving projectiles reach both peers');
 a.input={action:'punch',item:0,x:49,y:22};
 await until(()=>peers.every(p=>p.tiles.get('49,22')===0),'Blaster can be broken through normal punch action');a.input.action='none';
 await until(()=>peers.every(p=>p.shots.length===0),'Final empty projectile update clears both clients');
 await writeFile('evidence/special-rules/network-special.json',JSON.stringify({checks,failures:[],clients:2,transport:'local WebSocket'},null,2));
 console.log(JSON.stringify({checks,failures:[]},null,2));
}finally{for(const p of peers){clearInterval(p.timer);p.socket.close();}}
