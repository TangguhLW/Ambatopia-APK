import {readFile,writeFile,rename,rm} from 'node:fs/promises';
import {randomUUID} from 'node:crypto';
export function validateIndex(index){
 if(index?.schema_version!==1||!Number.isInteger(index.resource_version)||!Array.isArray(index.entries)||index.entries.length===0)throw Error('Invalid catalog schema');
 const ids=new Set();
 for(const item of index.entries){
  if(!Number.isInteger(item.id)||item.id<0||ids.has(item.id)||typeof item.name!=='string'||!Array.isArray(item.aliases)||!Number.isInteger(item.page))throw Error('Invalid or duplicate identity');
  ids.add(item.id);
  if(item.equip&&(!item.preview||typeof item.slot!=='string'))throw Error('Equipment lacks verified frame/slot');
  if(item.preview&&(!/^assets\/catalog\/[a-f0-9]+\.png$/.test(item.asset)||!Array.isArray(item.frame)||item.frame.length!==4||item.frame.some(n=>!Number.isInteger(n)||n<0)))throw Error('Invalid asset frame');
 }
 return true;
}
export async function publishIndex(index,path){
 validateIndex(index);
 const previous=await readFile(path,'utf8').then(JSON.parse).catch(e=>{if(e.code==='ENOENT')return null;throw e;});
 if(previous){const ids=new Set(index.entries.map(i=>i.id));if(previous.entries.some(i=>!ids.has(i.id)))throw Error('Would remove existing IDs; review required');}
 const staging=path+'.next-'+randomUUID();
 try{await writeFile(staging,JSON.stringify(index));await rename(staging,path);}catch(e){await rm(staging,{force:true});throw e;}
}
