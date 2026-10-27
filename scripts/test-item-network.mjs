import assert from 'node:assert/strict';
import {writeFile} from 'node:fs/promises';
const peers=[],checks=[],sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function until(fn,label){const end=Date.now()+8000;while(!fn()){if(Date.now()>end)throw Error('Timeout: '+label);await sleep(20);}checks.push(label);}
function peer(name){
 const p={socket:new WebSocket('ws://127.0.0.1:4192'),id:0,seq:0,tiles:new Map(),states:new Map(),effects:[],players:[],weather:''};peers.push(p);
 p.socket.onopen=()=>p.socket.send(JSON.stringify({type:'join',name,world:'ITEMNET'}));
 p.socket.onmessage=e=>{const m=JSON.parse(e.data);if(m.type==='welcome')p.id=m.id;if(m.type==='snapshot')p.players=m.players;if(m.type==='tile')p.tiles.set(`${m.x},${m.y}`,m.item);if(m.type==='item_state')p.states.set(`${m.x},${m.y}`,m.data);if(m.type==='effect')p.effects.push(m.event);if(m.type==='weather')p.weather=m.key;};
 p.input={action:'none',item:0,x:49,y:23};
 p.timer=setInterval(()=>{if(p.id&&p.socket.readyState===1)p.socket.send(JSON.stringify({type:'input',seq:++p.seq,axis:0,jump:false,direct:false,...p.input}));},50);
 p.machine=(x,command,args={})=>p.socket.send(JSON.stringify({type:'machine',x,y:23,command,args}));
 return p;
}
try{
 const a=peer('ItemOwner'),b=peer('ItemGuest');
 await until(()=>a.id&&b.id&&a.players.length===2,'Two exported-server peers enter item world');
 a.input={action:'place',item:200003,x:49,y:23};
 await until(()=>peers.every(p=>p.tiles.get('49,23')===200003&&p.states.get('49,23')?.seed===3),'Seed placement and growth metadata reach both clients');a.input.action='none';
 await sleep(300);a.machine(49,'grow');
 await until(()=>peers.every(p=>{let d=p.states.get('49,23');return d?.planted+d?.duration<=Date.now()/1000;}),'Creative tree growth is authoritative and replicated');
 await sleep(300);a.machine(49,'harvest');
 await until(()=>peers.every(p=>p.tiles.get('49,23')===0&&p.effects.some(e=>e.type==='reward'&&e.item===2)),'Harvest creates the source output and removes the tree for both peers');
 await sleep(300);a.input={action:'place',item:200866,x:49,y:23};
 await until(()=>peers.every(p=>p.tiles.get('49,23')===200866&&p.states.get('49,23')?.ready>0),'Provider placement saves its production clock');a.input.action='none';
 await sleep(300);a.machine(49,'grow');await sleep(300);a.machine(49,'harvest');
 await until(()=>peers.every(p=>p.effects.some(e=>e.type==='reward'&&e.item===868)),'Provider produces its recovered Milk drop');
 a.input={action:'place',item:202978,x:51,y:23};
 await until(()=>peers.every(p=>p.tiles.get('51,23')===202978),'Vending Machine placement replicated');a.input.action='none';
 await sleep(300);a.machine(51,'deposit',{item:2,amount:5});
 await until(()=>peers.every(p=>p.states.get('51,23')?.stock?.['2']===5),'Machine stock replicated to both clients');
 await sleep(300);a.machine(51,'dispense');
 await until(()=>peers.every(p=>p.states.get('51,23')?.stock?.['2']===4),'Dispensing decrements shared stock');
 b.socket.send(JSON.stringify({type:'outfit',equipment:{back:200156},skin:0}));
 await until(()=>a.players.some(p=>p.id===b.id&&p.equipment.back===200156),'Source wardrobe outfit and effect source replicated');
 a.input={action:'place',item:200274,x:49,y:23};
 await until(()=>a.players.some(p=>p.id===a.id&&p.modifiers?.Frozen),'Consumable modifier is visible in authoritative snapshots');a.input.action='none';
 a.socket.send(JSON.stringify({type:'weather',key:'pop-city'}));
 await until(()=>peers.every(p=>p.weather==='pop-city'),'Complex weather selection is shared');
 await writeFile('evidence/item-gameplay/network-items.json',JSON.stringify({checks,failures:[],clients:2,transport:'local WebSocket'},null,2));
 console.log(JSON.stringify({checks,failures:[]},null,2));
}finally{for(const p of peers){clearInterval(p.timer);p.socket.close();}}
