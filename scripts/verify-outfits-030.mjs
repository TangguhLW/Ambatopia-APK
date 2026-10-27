import {readFile,writeFile,copyFile} from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import {createHash} from 'node:crypto';
const hash=async path=>{const h=createHash('sha256');for await(const chunk of createReadStream(path))h.update(chunk);return h.digest('hex');};
const read=async path=>JSON.parse(await readFile(path,'utf8'));
const running=await read('evidence/outfits-0302-running.json');
const qa=await read('tools/profile-outfits-0302/GTRef/qa-report.json');
if(qa.failures.length)throw Error('Exported QA failures: '+JSON.stringify(qa.failures));
const logs={};
for(const path of ['evidence/outfits-030-all.log','evidence/outfits-0302-focused.log','evidence/outfits-0302-compile.log','evidence/outfits-0302-build.log','evidence/outfits-0302-windows.log']){
 const text=await readFile(path,'utf8');
 const errors=text.split(/\r?\n/).filter(line=>/SCRIPT ERROR:|^ERROR:|^FAIL:/.test(line));
 if(errors.length)throw Error(path+': '+errors.slice(0,5).join('\n'));
 logs[path]={errors:[],checks:text.match(/CHECKS: (\d+) FAILED: (\d+)/)?.[0]||null};
}
const baseline=await read('evidence/web-reference/source-baseline.json');
const web=[];
for(const file of baseline.files){const current=await hash(file.source);web.push({source:file.source,unchanged:current===file.sha256});}
if(web.some(file=>!file.unchanged))throw Error('Old-web source changed');
const prior=await read('evidence/wardrobe-019-build-hashes.json');
const apk=[];
for(const file of prior.filter(row=>/\.apk$/i.test(row.Path))){const current=await hash(file.Path);apk.push({path:file.Path,unchanged:current.toLowerCase()===file.Hash.toLowerCase()});}
if(apk.some(file=>!file.unchanged))throw Error('Prior APK changed');
const original='C:/Users/user/AppData/Local/Growtopia/Growtopia.exe';
const original_sha256=await hash(original);
if(original_sha256!=='4325fe916b7435eeb50048608869fe81b1577b8f23fe3bfdd2b1beeb0a14d29c')throw Error('Original installation executable changed');
const manifest=await read('data/build-info.json');
for(const[path,expected]of Object.entries(manifest.hashes))if(await hash(path)!==expected)throw Error('Build provenance mismatch: '+path);
const audio=await read('data/machine-audio-index.json');
const wear=audio.entries['audio/change_clothes.wav'];
if(await hash('C:/Users/user/AppData/Local/Growtopia/'+wear.source)!==wear.sha256)throw Error('Native wear source mismatch');
const summary={version:manifest.version,build:{...running,sha256:await hash(running.exe),source_revision:manifest.source_revision},native_logs:logs,windows:{checks:qa.checks.length,failures:qa.failures,elapsed_ms:qa.elapsed_ms,effects:qa.effect_scenarios.map(row=>({name:row.name,fps:row.fps,p95_ms:row.frame_p95_ms}))},wear_audio:wear,source:{check:await read('research/machines-030/source-check.json'),machine_cases:7140,machine_definitions:210,chest_cases:504,chest_odds_authority:'Inspected simulator; official live-server odds are not established'},unchanged:{old_web:web,prior_apk:apk,growtopia_exe:original_sha256},pending:(await read('research/machines-030/gap-audit.json')).unrecovered,qualification:'Godot Windows only. Named outfits are local per account. Guild weather and the five Starship generators remain unrecovered. No cloud migration or old-web edit.'};
await copyFile('tools/profile-outfits-0302/GTRef/qa-report.json','evidence/outfits-0302-windows-final.json');
for(const name of ['outfits-030-before-open','outfits-030-slots','outfits-030-narrow','machines-030-frames'])await copyFile('tools/profile-outfits-0302/GTRef/qa-'+name+'.png','evidence/'+name+'-final.png');
summary.windows.performance_note='The final run paused render capture while the window was minimized. The raw costume_and_rlm mean FPS is retained but excluded as an uninterrupted performance baseline. Other recorded scenarios measured 60.10–60.18 FPS; all recorded p95 values were below 18 ms. This is Windows evidence, not an Android performance claim.';
await writeFile('evidence/outfits-030-summary.json',JSON.stringify(summary,null,2));
console.log(JSON.stringify({version:summary.version,checks:summary.windows.checks,failures:summary.windows.failures,old_web_verified:web.length,prior_apk_verified:apk.length,build_manifest_files:Object.keys(manifest.hashes).length,pending:summary.pending}));
