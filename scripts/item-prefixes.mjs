import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';
import {resolve} from 'node:path';
const nameKey=Buffer.from('PBG892FXX982ABC*');
export function readItemPrefix(bytes,start,expected,{strictCandidate=true}={}){
 let at=start;const need=n=>{if(at+n>bytes.length)throw Error('Truncated metadata');};
 const u8=()=>{need(1);return bytes[at++];},u16=()=>{need(2);const v=bytes.readUInt16LE(at);at+=2;return v;},u32=()=>{need(4);const v=bytes.readUInt32LE(at);at+=4;return v;};
 const string=(encoded=false)=>{const n=u16();if(n>1024)throw Error('String bound');need(n);const out=Buffer.from(bytes.subarray(at,at+n));at+=n;if(encoded)for(let i=0;i<n;i++)out[i]^=nameKey[(expected+i)%nameKey.length];return out.toString('utf8');};
 const id=u32();if(id!==expected)throw Error('Unexpected item ID');
 const flags=u16(),actionType=u8(),material=u8(),name=string(true),texture=string();
 if(!name||!/^[\x20-\x7e]+$/.test(name)||texture&&!/^[\w/.-]+\.rttex$/.test(texture))throw Error('Invalid prefix strings');
 const textureHash=u32(),visualEffect=u8(),cookingIngredient=u32(),textureX=u8(),textureY=u8(),renderType=u8(),stripe=u8(),collisionType=u8(),breakHits=u8();
 const dropChance=u32(),clothingType=u8(),rarity=u16(),maxAmount=u8();if(strictCandidate&&(actionType>127||collisionType>32))throw Error('Implausible prefix');
 return {id,name,texture,textureHash,textureX,textureY,flags,actionType,material,visualEffect,cookingIngredient,renderType,stripe,collisionType,breakHits,dropChance,clothingType,rarity,maxAmount,sourceOffset:start,prefixEnd:at};
}
export function decodeItemPrefixes(bytes){
 if(bytes.length<6)throw Error('Catalog header truncated');
 const version=bytes.readUInt16LE(0),declaredCount=bytes.readUInt32LE(2);
 if(version<11||version>27||declaredCount>100000)throw Error('Unsupported catalog header');
 const items=[];let at=6;let limitation='';
 for(let id=0;id<declaredCount;id++){
  let item;try{item=readItemPrefix(bytes,at,id);}catch(e){limitation=`Stopped at item ${id}: ${e.message}`;break;}
  if(id+1<declaredCount){const needle=Buffer.alloc(4);needle.writeUInt32LE(id+1);const candidates=[];let found=bytes.indexOf(needle,item.prefixEnd);while(found>=0&&found-item.prefixEnd<=32768){try{const candidate=readItemPrefix(bytes,found,id+1);let anchored=id+2>=declaredCount;if(!anchored){const nextNeedle=Buffer.alloc(4);nextNeedle.writeUInt32LE(id+2);let next=bytes.indexOf(nextNeedle,candidate.prefixEnd);while(next>=0&&next-candidate.prefixEnd<=32768){try{readItemPrefix(bytes,next,id+2);anchored=true;break;}catch{}next=bytes.indexOf(nextNeedle,next+1);}}if(anchored)candidates.push(found);}catch{}found=bytes.indexOf(needle,found+1);}if(candidates.length!==1){limitation=`Ambiguous or missing boundary after ${id}: ${candidates.length} candidates`;break;}at=candidates[0];}else at=bytes.length;
  item.recordEnd=at;item.uninterpretedTailBytes=at-item.prefixEnd;item.boundaryEvidence='unique next sequential ID with valid name/texture prefix; inferred boundary, not full tail decoding';items.push(item);
 }
 return {version,declaredCount,complete:items.length===declaredCount,items,limitation,coverage:'prefix metadata only; variable record tails and runtime behavior not decoded'};
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){const file='C:/Users/user/AppData/Local/Growtopia/cache/items.dat',bytes=await readFile(file);const result=decodeItemPrefixes(bytes);await writeFile('evidence/fidelity-2026-10-22/item-prefixes.json',JSON.stringify({source:file,sha256:createHash('sha256').update(bytes).digest('hex'),formatReference:'https://github.com/CLOEI/gtitem-r/blob/main/src/lib.rs',...result},null,2));console.log(JSON.stringify({version:result.version,count:result.items.length,declared:result.declaredCount,complete:result.complete,limitation:result.limitation,first:result.items.slice(0,12)}));}


