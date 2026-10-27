import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,writeFile,readFile,mkdir} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {syncAssets,validateActiveAssets} from '../scripts/import-assets.mjs';

test('failed incremental refresh retains the active files and manifest',async()=>{
 const root=await mkdtemp(join(tmpdir(),'ambatopia-sync-'));
 const output=join(root,'output');await mkdir(output);
 await writeFile(join(output,'manifest.json'),'[]');
 await writeFile(join(output,'font.ttf'),'last-good');
 await assert.rejects(syncAssets(join(root,'missing-install'),output));
 assert.equal(await readFile(join(output,'font.ttf'),'utf8'),'last-good');
 assert.equal(await readFile(join(output,'manifest.json'),'utf8'),'[]');
});

test('reference manifest only maps relative project assets to local source files',async()=>{
 const entries=JSON.parse(await readFile(new URL('../assets/reference/manifest.json',import.meta.url)));
 assert.equal(entries.length,52);
 for(const required of ['face','eyes2','extraleg','sleeve','block_cracks','material_wood_damage','material_wood_break','material_punch_glass','material_metal_hit','material_punch_miss','material_punch_locked'])assert.ok(entries.some(e=>e.id===required));
 for(const entry of entries){
  assert.match(entry.sha256,/^[a-f0-9]{64}$/);
  assert.match(entry.output_sha256,/^[a-f0-9]{64}$/);
  assert.ok(!entry.source.includes('..')&&!entry.source.includes(':'));
  assert.match(entry.output_file,/^[a-z0-9_]+\.(png|ttf|wav)$/);
 }
});

test('a missing mapped source is an explicit failure, not a fallback success',async()=>{
 const root=await mkdtemp(join(tmpdir(),'ambatopia-missing-'));
 await writeFile(join(root,'manifest.json'),JSON.stringify([{id:'required',source:'missing.rttex',output_file:'required.png'}]));
 const result=await validateActiveAssets(join(root,'source'),root);
 assert.equal(result.ok,false);assert.deepEqual(result.failures,['required']);
});
