import {readFile} from 'node:fs/promises';
const b=await readFile('C:/Users/user/AppData/Local/Growtopia/cache/items.dat'); console.log(JSON.stringify({length:b.length,version:b.readUInt16LE(0),itemCount:b.readUInt32LE(2),header:b.subarray(0,64).toString('hex')}));
