import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {parseItemsDat} from '../scripts/items-dat.mjs';
const file=await readFile('C:/Users/user/AppData/Local/Growtopia/cache/items.dat');
test('v27 local snapshot consumes all declared records in order, including variable extension',()=>{
 const d=parseItemsDat(file);assert.equal(d.version,27);assert.equal(d.count,16434);assert.equal(d.consumed,file.length);
 assert.equal(d.items[362].name,'Angel Wings');assert.equal(d.items[16258].uninterpretedExtension,'36');
 assert.equal(d.items.at(-1).name,'Immortal Puppy Leash Seed');
 for(let i=0;i<d.count;i++){assert.equal(d.items[i].id,i);assert.equal(d.items[i].sourceOffset,i?d.items[i-1].recordEnd:6);}
});
test('truncated data, bad ID, unknown versions and trailing garbage fail closed',()=>{
 for(const cut of [0,5,285,571,file.length-1])assert.throws(()=>parseItemsDat(file.subarray(0,cut)));
 const bad=Buffer.from(file);bad.writeUInt32LE(20,286);assert.throws(()=>parseItemsDat(bad),/Unexpected item ID/);
 const future=Buffer.from(file);future.writeUInt16LE(28);assert.throws(()=>parseItemsDat(future),/Unsupported/);
 assert.throws(()=>parseItemsDat(Buffer.concat([file,Buffer.from([0])])),/Unconsumed/);
});
test('reviewed H-pun v22 layout is not silently accepted as v27',()=>assert.throws(()=>parseItemsDat(file,{maxVersion:22}),/Unsupported/));
