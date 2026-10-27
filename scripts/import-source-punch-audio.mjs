import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const tracks=JSON.parse(await readFile('data/punch-tracks.json'));
const names=[...new Set(Object.values(tracks.punches).flatMap(p=>(p.snd||[]).map(x=>x[1])))].sort();
const entries={},chunks=[];let offset=0;
for(const name of names){
 if(!/^[a-zA-Z0-9_]+$/.test(name))throw Error('Unsafe sound name');
 const source=({spooky_20:'audio/notes/spooky_20.wav',Flamego:'audio/flame_go.wav'})[name]||`audio/${name}.wav`;
 try{
  const raw=await readFile('C:/Users/user/AppData/Local/Growtopia/'+source);
  if(raw.toString('ascii',0,4)!=='RIFF'||raw.toString('ascii',8,12)!=='WAVE')throw Error('Not a WAV');
  entries[name]={source,offset,bytes:raw.length,sha256:createHash('sha256').update(raw).digest('hex'),name_mapping:name==='Flamego'?'Simulator Flamego mapped to locally named flame_go; same recording identity across versions is unverified.':'Source recording name'};chunks.push(raw);offset+=raw.length;
 }catch(error){if(error.code!=='ENOENT')throw error;entries[name]={source,missing:true};}
}
await writeFile('assets/web-wardrobe/punch-audio.bin',Buffer.concat(chunks));
await writeFile('data/punch-audio-index.json',JSON.stringify(entries,null,2));
console.log({available:Object.values(entries).filter(x=>!x.missing).length,missing:Object.keys(entries).filter(x=>entries[x].missing),bytes:offset});
