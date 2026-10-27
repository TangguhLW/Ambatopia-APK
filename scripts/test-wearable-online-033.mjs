import assert from 'node:assert/strict';
import {writeFile} from 'node:fs/promises';
const clients=[],checks=[];
const sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(test,label){const started=Date.now();while(!test()){if(Date.now()-started>7000)throw Error(label);await sleep(25)}checks.push(label)}
try {
  for(let i=0;i<12;i++){
    const client={socket:new WebSocket('ws://127.0.0.1:4198'),id:0,rows:[],sequence:0};
    client.socket.onopen=()=>client.socket.send(JSON.stringify({type:'join',name:`Cosmetic${i}`,world:'COSMETIC033'}));
    client.socket.onmessage=event=>{const packet=JSON.parse(event.data);if(packet.type==='welcome')client.id=packet.id;if(packet.type==='snapshot')client.rows=packet.players;};
    clients.push(client);
  }
  await until(()=>clients.every(c=>c.id&&c.rows.length===12),'Twelve real WebSocket clients share an isolated QA room');
  const player=clients[0],outfit={shirt:5264,neck:6064,feet:1740,hand:5480};
  player.socket.send(JSON.stringify({type:'outfit',equipment:outfit,skin:2,item_options:{pet_5480:false}}));
  await until(()=>clients.every(c=>{const row=c.rows.find(p=>p.id===player.id);return row.equipment.shirt===5264&&row.equipment.neck===6064&&row.equipment.hand===5480&&row.item_options.pet_5480===false&&row.skin===2}),'Exact source item IDs, skin and pet visibility reach every client');
  player.socket.send(JSON.stringify({type:'outfit',equipment:{},skin:0,item_options:{god:true}}));
  await sleep(250);
  assert(clients.every(c=>c.rows.find(p=>p.id===player.id).equipment.shirt===5264));checks.push('Invalid cosmetic payload is rejected without erasing the accepted outfit');
  const before=player.rows.find(p=>p.id===player.id).x;
  for(let i=0;i<8;i++){player.socket.send(JSON.stringify({type:'input',seq:++player.sequence,axis:1,action:'none',jump:false}));await sleep(50)}
  await until(()=>clients.every(c=>c.rows.find(p=>p.id===player.id).x>before+35),'Movement with stacked worn buffs is replicated to all clients');
  player.socket.send(JSON.stringify({type:'input',seq:++player.sequence,axis:0,action:'none',jump:false}));
  player.socket.send(JSON.stringify({type:'outfit',equipment:outfit,skin:2,item_options:{pet_5480:true}}));
  await until(()=>clients.every(c=>c.rows.find(p=>p.id===player.id).item_options.pet_5480===true),'Re-enabling the item pet reaches all clients');
  await writeFile('evidence/wearable-033-real-network.json',JSON.stringify({checks,failures:[],clients:12,transport:'isolated loopback WebSocket',public_supabase_tested:false},null,2));
  console.log(JSON.stringify({checks,failures:[]}));
} finally {for(const client of clients)client.socket.close()}
