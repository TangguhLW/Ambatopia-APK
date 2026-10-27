import {readItemPrefix} from './item-prefixes.mjs';
export function parseItemsDat(bytes,{maxVersion=27}={}){
 let at=0;const need=n=>{if(!Number.isInteger(n)||n<0||at+n>bytes.length)throw Error(`Truncated field at ${at}`);};
 const uint=n=>{need(n);const v=bytes.readUIntLE(at,n);at+=n;return v;};
 const blob=n=>{need(n);const b=bytes.subarray(at,at+n);at+=n;return b.toString('hex');};
 const string=()=>{const n=uint(2);if(n>32768)throw Error('String exceeds bound');need(n);const s=bytes.subarray(at,at+n).toString('utf8');at+=n;return s;};
 const version=uint(2),count=uint(4);if(version<22||version>maxVersion||count>100000)throw Error(`Unsupported version/count ${version}/${count}`);
 const items=[];
 for(let id=0;id<count;id++){
  let p;try{p=readItemPrefix(bytes,at,id,{strictCandidate:false});}catch(e){throw Error(`Item ${id} at ${at}: ${e.message}`);}at=p.prefixEnd;
  const item={...p,altFile:string(),altHash:uint(4),audioVolumeRaw:uint(4),petName:string(),petPrefix:string(),petSuffix:string(),petAbility:string(),seedBase:uint(1),seedOverlay:uint(1),treeBase:uint(1),treeOverlay:uint(1),baseColor:uint(4),overlayColor:uint(4),ingredientsRaw:uint(4),growTime:uint(4),animationFlagsRaw:uint(4),extraOptions:string(),texturePath2:string(),extraOptions2:string(),unknownBase80:blob(80),punchOptions:string(),unknown12:blob(13),lightRangeRaw:uint(4),unknown14:blob(4),chairRaw:blob(25),chairTexture:string(),renderer:string(),unknown17:blob(4),rendererHash:uint(4),unknown19:blob(9),unknown21:blob(2),description:string()};
  if(version>=23)item.recipeRaw=blob(4);
  if(version>=24)item.slipperyRaw=uint(1);
  if(version>=25){item.hitEffect=string();item.hitEffectHash=uint(4);}
  if(version>=26)item.unknown26=uint(1);
  if(version>=27){const length=uint(2);item.uninterpretedExtension=blob(length);}
  item.recordEnd=at;items.push(item);
 }
 if(at!==bytes.length)throw Error(`Unconsumed trailing bytes: ${bytes.length-at}`);
 return {version,count,consumed:at,items};
}
