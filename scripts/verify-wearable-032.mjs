import {readFile,writeFile,copyFile} from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import {createHash} from 'node:crypto';
const suffix=process.argv[2]||'032';
if(!/^032(?:1)?$/.test(suffix))throw Error('Unknown verification profile');
const hash=async path=>{const h=createHash('sha256');for await(const chunk of createReadStream(path))h.update(chunk);return h.digest('hex');};
const read=async path=>JSON.parse(await readFile(path,'utf8'));
const running=await read(`evidence/wearable-${suffix}-running.json`);
const profile=`tools/profile-wearable-${suffix}/GTRef`;
const qa=await read(profile+'/qa-report.json');
if(qa.failures.length)throw Error('Exported QA failures: '+JSON.stringify(qa.failures));
if(qa.wearable_032?.length!==4)throw Error('Missing targeted wearable scenarios');
const logs={};
for(const path of ['evidence/wearable-032-green.log','evidence/wearable-032-all-final.log',`evidence/wearable-${suffix}-build.log`,`evidence/wearable-${suffix}-windows.log`]){
 const text=await readFile(path,'utf8');
 const errors=text.split(/\r?\n/).filter(line=>/SCRIPT ERROR:|^ERROR:|^FAIL:/.test(line));
 if(errors.length)throw Error(path+': '+errors.slice(0,5).join('\n'));
 logs[path]={errors:[],checks:text.match(/CHECKS: (\d+) FAILED: (\d+)/)?.[0]||null};
}
const web=[];
for(const file of (await read('evidence/web-reference/source-baseline.json')).files)web.push({source:file.source,unchanged:await hash(file.source)===file.sha256});
if(web.some(file=>!file.unchanged))throw Error('Old-web source changed');
const apk=[];
for(const file of (await read('evidence/wardrobe-019-build-hashes.json')).filter(row=>/\.apk$/i.test(row.Path)))apk.push({path:file.Path,unchanged:(await hash(file.Path)).toLowerCase()===file.Hash.toLowerCase()});
if(apk.some(file=>!file.unchanged))throw Error('Prior APK changed');
const originalHash=await hash('C:/Users/user/AppData/Local/Growtopia/Growtopia.exe');
if(originalHash!=='4325fe916b7435eeb50048608869fe81b1577b8f23fe3bfdd2b1beeb0a14d29c')throw Error('Original installation executable changed');
const manifest=await read('data/build-info.json');
for(const[path,expected]of Object.entries(manifest.hashes))if(await hash(path)!==expected)throw Error('Build provenance mismatch: '+path);
const sources=await read('research/wearable-032/sources.json');
const live=await read('research/wearable-032/live-source-check.json');
if(!live.matches_inspected_source)throw Error('Simulator bundle changed; review source evidence');
const textures=await read('data/additional-effects-index.json');
const textureChecks=[];
for(const key of ['particles','particles2','particles4']){
 const item=textures[key];if(!item||item.missing)throw Error('Missing source texture: '+key);
 if(await hash('C:/Users/user/AppData/Local/Growtopia/'+item.source)!==item.sha256)throw Error('Original texture changed');
 textureChecks.push({key,source:item.source,sha256:item.sha256});
}
const summary={version:manifest.version,build:{...running,sha256:await hash(running.exe),source_revision:manifest.source_revision,manifest_files:Object.keys(manifest.hashes).length},native_logs:logs,windows:{checks:qa.checks.length,failures:qa.failures,elapsed_ms:qa.elapsed_ms,wearables:qa.wearable_032,combined_effects:qa.wearable_032_performance,effects:qa.effect_scenarios},source:{live,speedy_items:sources.speedy_items,textureChecks},unchanged:{old_web:web,prior_apk:apk,growtopia_exe:originalHash},pending:{typed_item_records_needing_review:sources.pending_typed_items.length,stacking:'Exact special speed stacking magnitudes not recovered',spirit_guide_perk:'Spirit Board break probability not implemented',shadow:'Visual ground shadow geometry is an adaptation',starships:'Five original layouts remain unrecovered'},qualification:'Windows native Godot only; no Android or live online-crowd performance claim. Registry validates Speedy identities, not every item special effect.'};
await copyFile(profile+'/qa-report.json',`evidence/wearable-${suffix}-windows-final.json`);
for(const name of ['5264','6064','1740','4988','front-pet'])await copyFile(profile+'/qa-wearable-032-'+name+'.png',`evidence/wearable-${suffix}-${name}-final.png`);
await writeFile('evidence/wearable-032-summary.json',JSON.stringify(summary,null,2));
console.log(JSON.stringify({version:summary.version,checks:summary.windows.checks,failures:summary.windows.failures,combined_effects:summary.windows.combined_effects,old_web_verified:web.length,prior_apk_verified:apk.length,manifest_files:summary.build.manifest_files,speedy_items:sources.speedy_items,pending:summary.pending}));
