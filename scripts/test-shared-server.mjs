import {writeFile,mkdir} from 'node:fs/promises';
import assert from 'node:assert/strict';
const pause=ms=>new Promise(r=>setTimeout(r,ms));
const count=Number(process.argv[2]||12);if(!Number.isInteger(count)||count<2||count>64)throw Error("Choose 2–64 local clients");const clients=[];const checks=[];
async function until(predicate,label,timeout=6000){const start=Date.now();while(!predicate()){if(Date.now()-start>timeout)throw Error('Timeout: '+label);await pause(25);}checks.push(label);}
try{
 for(let i=0;i<count;i++){
  const peer={socket:new WebSocket('ws://127.0.0.1:4192'),seq:0,id:0,players:[],messages:[],tiles:new Map(),effects:[],input:{axis:0,action:'none',x:0,y:0,item:0}};
  peer.socket.addEventListener('open',()=>peer.socket.send(JSON.stringify({type:'join',name:'Probe'+i,world:'NETPROBE'})));
  peer.socket.addEventListener('message',event=>{const m=JSON.parse(event.data);if(m.type==='welcome')peer.id=m.id;if(m.type==='snapshot')peer.players=m.players;if(m.type==='chat')peer.messages.push(m);if(m.type==='tile')peer.tiles.set(`${m.x},${m.y}`,m.item);if(m.type==='effect')peer.effects.push(m);});
  peer.timer=setInterval(()=>{if(peer.id&&peer.socket.readyState===1)peer.socket.send(JSON.stringify({type:'input',seq:++peer.seq,jump:false,direct:false,...peer.input}));},50);
  clients.push(peer);
  await pause(30);
 }
 await until(()=>clients.every(p=>p.id&&p.players.length===count),count+' real WebSocket clients share one world');
 const p=clients[0],start=p.players.find(x=>x.id===p.id).x;p.input={axis:1,action:'none'};await pause(350);p.input={axis:0,action:'none'};
 await until(()=>clients[1].players.some(x=>x.id===p.id&&x.x>start+20),'Movement replicated to other client');
 p.socket.send(JSON.stringify({type:'chat',text:'Shared protocol hello'}));
 await until(()=>clients.every(c=>c.messages.some(m=>m.text==='Shared protocol hello')),'Chat replicated to all '+count+' clients');
 p.input={axis:-1,action:'none'};await pause(350);p.input={axis:0,action:'place',item:1,x:49,y:23};
 await until(()=>clients.every(c=>c.tiles.get('49,23')===1),'Block placement replicated');
 p.input={axis:0,action:'punch',item:0,x:49,y:23};
 await until(()=>clients.every(c=>c.tiles.get('49,23')===0),'Punch breaks block and replicates');
 p.input={axis:0,action:'place',item:5,x:49,y:23};
 await until(()=>clients.every(c=>c.tiles.get('49,23')===5),'World Lock replicated');
 p.input={axis:0,action:'place',item:5,x:49,y:22};
 clients[1].input={axis:0,action:'place',item:1,x:51,y:22};await pause(500);
 assert.notEqual(p.tiles.get('49,22'),5);assert.notEqual(p.tiles.get('51,22'),1);checks.push('Duplicate lock and non-owner mutation rejected');
 assert(clients[1].effects.some(e=>e.event.type==='punch_started'));checks.push('Punch effect replicated');
 await mkdir('evidence/multiplayer-2026-10-23',{recursive:true});
 await writeFile('evidence/multiplayer-2026-10-23/protocol-'+count+'.json',JSON.stringify({checks,failures:[],clients:clients.length,transport:'loopback WebSocket',public_deployment:false},null,2));
 console.log(JSON.stringify({checks,failures:[]},null,2));
}finally{for(const c of clients){clearInterval(c.timer);c.socket.close();}}
