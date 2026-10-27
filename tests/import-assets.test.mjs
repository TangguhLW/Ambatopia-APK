import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,readFile,writeFile,mkdir} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {existsSync} from 'node:fs';
import {createHash} from 'node:crypto';
const modulePath=new URL('../scripts/import-assets.mjs',import.meta.url);
test('asset importer is implemented',()=>assert.ok(existsSync(modulePath),'verified importer must exist'));
test('RGBA decode preserves pixel bytes and rejects corrupt layout',async()=>{
 if(!existsSync(modulePath))return;
 const {decodeTexture}=await import(modulePath);
 const raw=Buffer.alloc(128);raw.write('RTTXTR');raw.writeUInt32LE(1,8);raw.writeUInt32LE(1,12);raw.writeUInt32LE(5121,16);raw.writeUInt32LE(1,20);raw.writeUInt32LE(1,24);raw[28]=1;Buffer.from([10,20,30,255]).copy(raw,124);
 assert.deepEqual([...decodeTexture(raw).pixels],[10,20,30,255]);
 assert.throws(()=>decodeTexture(raw.subarray(0,127)),/layout/i);
 assert.throws(()=>decodeTexture(Buffer.from('nope')),/header/i);
});
test('failed asset import preserves previous output',async()=>{
 if(!existsSync(modulePath))return;
 const {importAssets}=await import(modulePath);
 const root=await mkdtemp(join(tmpdir(),'gt-assets-'));const out=join(root,'assets');await mkdir(out);await writeFile(join(out,'marker'),'good');
 await assert.rejects(importAssets(join(root,'missing'),out));assert.equal(await readFile(join(out,'marker'),'utf8'),'good');
});
test('RTTEX bottom-up rows become upright display rows',async()=>{
 const {upright}=await import(modulePath);
 assert.equal(typeof upright,'function','orientation transform must be explicit');
 const pixels=Buffer.from([1,2,3,4,5,6,7,8]);
 assert.deepEqual([...upright({width:1,height:2,pixels}).pixels],[5,6,7,8,1,2,3,4]);
});
test('active import detects changed source and modified output instead of using stale cache',async()=>{
 const {validateActiveAssets}=await import(modulePath);
 assert.equal(typeof validateActiveAssets,'function');
 const root=await mkdtemp(join(tmpdir(),'gt-active-'));const source=join(root,'source'),out=join(root,'output');await mkdir(source);await mkdir(out);
 const digest=v=>createHash('sha256').update(v).digest('hex');
 await writeFile(join(source,'texture'),'source');await writeFile(join(out,'test.png'),'decoded');
 await writeFile(join(out,'manifest.json'),JSON.stringify([{id:'test',source:'texture',sha256:digest('source'),output_file:'test.png',output_sha256:digest('decoded')} ]));
 assert.equal((await validateActiveAssets(source,out)).ok,true);
 await writeFile(join(source,'texture'),'changed');assert.equal((await validateActiveAssets(source,out)).ok,false);
 await writeFile(join(source,'texture'),'source');await writeFile(join(out,'test.png'),'tampered');assert.equal((await validateActiveAssets(source,out)).ok,false);
});
