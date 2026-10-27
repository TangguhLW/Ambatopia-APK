import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {publishIndex,validateIndex} from '../scripts/catalog-schema.mjs';
const item={id:1,name:'Dirt',aliases:[],page:0,preview:false,equip:false};
const catalog={schema_version:1,resource_version:27,entries:[item]};
test('duplicate IDs, invalid slot/frame cannot publish',()=>{
 assert.throws(()=>validateIndex({...catalog,entries:[item,item]}),/duplicate/);
 assert.throws(()=>validateIndex({...catalog,entries:[{...item,equip:true}]}),/Equipment/);
 assert.throws(()=>validateIndex({...catalog,entries:[{...item,preview:true,asset:'../escape.png',frame:[0,0,32,32]}]}),/asset/);
});
test('failed or incomplete replacement preserves active catalog bytes',async()=>{
 const dir=await mkdtemp(join(tmpdir(),'gt-catalog-')),file=join(dir,'index.json');
 try{
  await publishIndex(catalog,file);const before=await readFile(file);
  await assert.rejects(()=>publishIndex({...catalog,entries:[{...item,id:2}]},file),/remove/);
  await assert.rejects(()=>publishIndex({...catalog,entries:[item,item]},file),/duplicate/);
  assert.deepEqual(await readFile(file),before);
  await publishIndex({...catalog,entries:[item,{...item,id:2}]},file);
  assert.equal(JSON.parse(await readFile(file)).entries.length,2);
 }finally{await rm(dir,{recursive:true,force:true});}
});
