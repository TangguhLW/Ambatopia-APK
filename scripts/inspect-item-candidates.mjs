import {readFile} from 'node:fs/promises';
import {readItemPrefix} from './item-prefixes.mjs';
const b=await readFile('C:/Users/user/AppData/Local/Growtopia/cache/items.dat');for(let id=3;id<11;id++){const n=Buffer.alloc(4);n.writeUInt32LE(id);let p=b.indexOf(n,6);const found=[];while(p>=0&&p<20000){try{found.push(readItemPrefix(b,p,id));}catch{}p=b.indexOf(n,p+1);}console.log(JSON.stringify({id,candidates:found.map(({name,textureX,textureY,sourceOffset,prefixEnd})=>({name,textureX,textureY,sourceOffset,prefixEnd}))}));}
