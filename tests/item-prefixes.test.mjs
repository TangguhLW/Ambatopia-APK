import test from 'node:test';
import assert from 'node:assert/strict';
import {existsSync} from 'node:fs';
const path=new URL('../scripts/item-prefixes.mjs',import.meta.url);
test('bounded metadata reader exists',()=>assert.ok(existsSync(path)));
test('truncated catalog cannot be reported as complete',async()=>{
 if(!existsSync(path))return;
 const {decodeItemPrefixes}=await import(path);
 assert.throws(()=>decodeItemPrefixes(Buffer.alloc(3)),/header/i);
 const bytes=Buffer.alloc(20);bytes.writeUInt16LE(27);bytes.writeUInt32LE(5,2);
 const result=decodeItemPrefixes(bytes);
 assert.equal(result.complete,false);assert.equal(result.items.length,0);
});
test('a plausible duplicate header is rejected when the following sequential record cannot follow it',async()=>{
 const {decodeItemPrefixes}=await import(path);const key=Buffer.from('PBG892FXX982ABC*');
 const record=(id,label)=>{const name=Buffer.from(label);for(let i=0;i<name.length;i++)name[i]^=key[(id+i)%16];const tex=Buffer.from('tiles_page1.rttex'),head=Buffer.alloc(10);head.writeUInt32LE(id);head[6]=17;head.writeUInt16LE(name.length,8);const length=Buffer.alloc(2);length.writeUInt16LE(tex.length);return Buffer.concat([head,name,length,tex,Buffer.alloc(16),Buffer.alloc(8)]);};
 const header=Buffer.alloc(6);header.writeUInt16LE(27);header.writeUInt32LE(3,2);
 const result=decodeItemPrefixes(Buffer.concat([header,record(0,'Blank'),record(1,'Seed'),record(2,'Dirt'),record(1,'Plausible false header')]));
 assert.equal(result.items.length,3);assert.equal(result.complete,true);
});
