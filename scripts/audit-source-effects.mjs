import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const read=async path=>JSON.parse(await readFile(path));
const index=await read('data/additional-effects-index.json');
const pack=await readFile('assets/web-wardrobe/additional-effects.bin');
const failures=[],missing=[];
for(const [sheet,row] of Object.entries(index)){
 if(row.missing){missing.push(sheet);continue;}
 const bytes=pack.subarray(row.offset,row.offset+row.bytes);
 if(createHash('sha256').update(bytes).digest('hex')!==row.output_sha256)failures.push({sheet,reason:'converted image hash mismatch'});
 const raw=await readFile('C:/Users/user/AppData/Local/Growtopia/'+row.source);
 if(createHash('sha256').update(raw).digest('hex')!==row.sha256)failures.push({sheet,reason:'source changed since import'});
 if(bytes.readUInt32BE(16)!==row.width||bytes.readUInt32BE(20)!==row.height)failures.push({sheet,reason:'PNG dimensions mismatch'});
}
const programs=await read('data/source-particle-programs.json');
const wardrobe=await read('research/web-wardrobe/archive/l.json');
const lpRows=wardrobe.items.flatMap(item=>(item.ef?.rows||[]).filter(row=>row.lp!=null).map(row=>({item:item.id,row})));
const executableRows=lpRows.filter(({row})=>programs.programs[row.lp]);
const absentRows=lpRows.filter(({row})=>!programs.programs[row.lp]).map(({item,row})=>({item,program:row.lp}));
const audioIndex=await read('data/punch-audio-index.json'),audioPack=await readFile('assets/web-wardrobe/punch-audio.bin');
for(const [name,row] of Object.entries(audioIndex)){
 if(row.missing){failures.push({sound:name,reason:'missing original recording'});continue;}
 const source=await readFile('C:/Users/user/AppData/Local/Growtopia/'+row.source);
 const bytes=audioPack.subarray(row.offset,row.offset+row.bytes);
 if(!source.equals(bytes)||createHash('sha256').update(bytes).digest('hex')!==row.sha256)failures.push({sound:name,reason:'packed audio differs from original'});
}
const pets=await read('data/pet-tracks.json'),punches=await read('data/punch-tracks.json');
const outside=[];
function bounds(sheet,c,kind,id){
 const row=index[sheet];if(!row||row.missing)return;
 if(c[0]<0||c[1]<0||c[2]<=0||c[3]<=0||c[0]+c[2]>row.width||c[1]+c[3]>row.height)outside.push({kind,id,sheet,rect:c});
}
for(const [id,pet] of Object.entries(pets.items))for(const c of pet.cut||[])bounds(c[0],c.slice(1), 'pet',id);
for(const [id,punch] of Object.entries(punches.punches))for(const p of punch.P||[])if(p.c)bounds(p.sheet,p.c,'punch',id);
const deaths=await read('data/death-tracks.json');
for(const [id,item] of Object.entries(deaths.items))for(const p of item.P||[])if(p.c){
 bounds(p.c[0],p.c.slice(1),'death-item',id);
 for(const frame of p.cl||[])bounds(p.c[0],[frame[1],frame[2],p.c[3],p.c[4]],'death-item-frame',id);
}
for(const [id,variants] of Object.entries(deaths.L))for(const p of variants){
 bounds(p.c[0],p.c.slice(1),'death',id);
 for(const frame of p.cl||[])bounds(p.c[0],[frame[1],frame[2],p.c[3],p.c[4]],'death-frame',id);
}
const report={sheets:Object.keys(index).length,verified_sheets:Object.keys(index).length-missing.length,pack_bytes:pack.length,missing,failures,source_particle_programs:Object.keys(programs.programs).length,unsupported_programs:programs.unsupported,legacy_rows_total:lpRows.length,absent_legacy_rows:absentRows,verified_punch_audio:Object.keys(audioIndex).length,executable_legacy_rows:executableRows.length,legacy_items:[...new Set(executableRows.map(row=>row.item))].length,pet_tracks:Object.keys(pets.items).length,punch_profiles:Object.keys(punches.punches).length,outside,limitations:['Native typed ef emitters, including ancestral variants, remain separate from legacy lp emitters.','Pet/mid punch anchors include live pet displacement; tip/ball/ld/owl attachment anchors still need separate render-object mapping.','Generic pet tracks use eleven source motion branches with bounded fixed-step history. The 77 class-row pet renderers and detailed headgear perch offsets are not validated by this revision.','Shifty cycle duration is an adaptation, not a measured native timing.','Supabase online Rayman charging and triple-hit enforcement are not implemented by this Windows-only offline revision.']};
await writeFile('evidence/source-effects-audit.json',JSON.stringify(report,null,2));
console.log(JSON.stringify({...report,unsupported_programs:Object.keys(programs.unsupported).length,limitations:undefined,outside:outside.length}));
if(failures.length||outside.length)process.exitCode=1;
