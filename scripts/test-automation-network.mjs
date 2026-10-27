import {writeFile} from 'node:fs/promises';
const peers=[],checks=[],sleep=ms=>new Promise(resolve=>setTimeout(resolve,ms));
async function until(predicate,label){const end=Date.now()+10000;while(!predicate()){if(Date.now()>end)throw Error('Timeout: '+label);await sleep(20);}checks.push(label);}
function peer(name){
 const p={socket:new WebSocket('ws://127.0.0.1:4192'),id:0,seq:0,tiles:new Map(),states:new Map(),rules:{},players:[],effects:[]};peers.push(p);
 p.socket.onopen=()=>p.socket.send(JSON.stringify({type:'join',name,world:'AUTOPROTOCOL'}));
 p.socket.onmessage=event=>{const m=JSON.parse(event.data);if(m.type==='welcome')p.id=m.id;if(m.type==='snapshot')p.players=m.players;if(m.type==='tile')p.tiles.set(`${m.x},${m.y}`,m.item);if(m.type==='item_state')p.states.set(`${m.x},${m.y}`,m.data);if(m.type==='world_rules')p.rules=m.rules;if(m.type==='effect')p.effects.push(m.event);};
 p.input={action:'none',item:0,x:49,y:23};
 p.timer=setInterval(()=>{if(p.id&&p.socket.readyState===1)p.socket.send(JSON.stringify({type:'input',seq:++p.seq,axis:0,jump:false,direct:false,...p.input}));},50);
 p.machine=(x,y,command,args={})=>p.socket.send(JSON.stringify({type:'machine',x,y,command,args}));
 return p;
}
const all=fn=>peers.every(fn);
async function place(p,x,y,item,label){await sleep(300);p.input={action:'place',item,x,y};await until(()=>all(other=>other.tiles.get(`${x},${y}`)===item),label);p.input.action='none';await sleep(300);}
try{
 const a=peer('AutoOwner'),b=peer('AutoPeer');
 await until(()=>a.id&&b.id&&a.players.length===2,'Two peers enter exported automation server');
 await place(a,51,23,202072,'Xenonite placement reaches both clients');
 a.machine(51,23,'xenonite',{power:'dbl',mode:'force'});
 await until(()=>all(p=>p.rules.force?.dbl),'Forced Double Jump world rule synchronized');
 await sleep(300);a.machine(51,23,'xenonite',{power:'dbl',mode:'block'});
 await until(()=>all(p=>p.rules.block?.dbl&&!p.rules.force?.dbl),'Blocking replaces force and reaches both clients');
 await place(a,49,23,205638,'MAGPLANT placement synchronized');
 a.machine(49,23,'select_target',{item:2});await sleep(300);a.machine(49,23,'deposit',{amount:10});
 await until(()=>all(p=>p.states.get('49,23')?.count===10),'MAGPLANT exact target and stock synchronized');
 await sleep(300);a.machine(49,23,'activate');
 await until(()=>all(p=>p.states.get('49,23')?.building),'MAGPLANT building mode shared');
 await sleep(300);a.input={action:'place',item:205640,x:49,y:22};await until(()=>all(p=>p.tiles.get('49,22')===200002&&p.states.get('49,23')?.count===9),'Remote places selected block and decrements shared stock exactly once');a.input.action='none';
 // The remote is consumed as a tool action, never placed as a world tile.

 await place(a,51,22,206946,'Gaia Beacon placement synchronized');
 a.machine(51,22,'select_target',{item:3});await sleep(300);a.machine(51,22,'deposit',{amount:1200});
 await until(()=>all(p=>p.states.get('51,22')?.count===1200),'Gaia Beacon stores only the selected seed');
 await place(a,51,21,200003,'Seed planted above Gaia Beacon');
 a.machine(51,21,'grow');await sleep(300);a.machine(51,21,'harvest');
 await until(()=>all(p=>p.states.get('51,22')?.count===1201),'Gaia Beacon automatically collects harvested floating seed for both peers');
 await until(()=>all(p=>p.states.get('49,23')?.count>9),'MAGPLANT simultaneously collects the matching harvested blocks');
 await place(a,49,21,206950,'Heart of Gaia placement synchronized');
 a.machine(49,21,'select_target',{item:2});await sleep(300);a.machine(49,21,'refuel',{amount:20});await sleep(300);a.machine(49,21,'activate');
 await until(()=>all(p=>p.states.get('49,21')?.enabled),'Fueled Gaia start state synchronized');
 await place(a,51,21,200003,'Second matching tree planted for automatic harvest');
 a.machine(51,21,'grow');
 await until(()=>all(p=>p.tiles.get('51,21')===0&&p.states.get('49,21')?.fuel===19),'Heart of Gaia harvests matching tree and replicates fuel consumption');
 await place(a,50,22,202242,'Crystal placement synchronized');
 for(const item of [2242,2248,2248,2248]){a.machine(50,22,'add_crystal',{item});await sleep(300);}
 await until(()=>all(p=>p.states.get('50,22')?.crystals?.['2242']===2&&p.states.get('50,22')?.crystals?.['2248']===3),'Crystal color mixture synchronized');
 await until(()=>all(p=>Array.isArray(p.states.get('50,22')?.chi_required)),'Persistent Chi requirement synchronized');
 await writeFile('evidence/automation-rules/network-automation.json',JSON.stringify({checks,failures:[],clients:2,transport:'local exported WebSocket server'},null,2));
 console.log(JSON.stringify({checks,failures:[]},null,2));
}finally{for(const p of peers){clearInterval(p.timer);p.socket.close();}}
