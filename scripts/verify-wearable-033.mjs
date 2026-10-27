import {readFile,writeFile,copyFile} from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import {createHash} from 'node:crypto';
const read=async path=>JSON.parse(await readFile(path,'utf8'));
async function hash(path){const digest=createHash('sha256');for await(const chunk of createReadStream(path))digest.update(chunk);return digest.digest('hex')}
const manifest=await read('data/build-info.json');
const running=await read('evidence/wearable-0331-running.json');
const profile=running.profile.replaceAll('\\','/')+'/GTRef';
const qa=await read(profile+'/qa-report.json');
if(qa.failures.length)throw Error(JSON.stringify(qa.failures));
if(!qa.wearable_033_performance)throw Error('Targeted exported visual scenarios missing');
const logs={};
for(const path of ['evidence/wearable-033-green.log','evidence/wearable-0331-all-final.log','evidence/wearable-0331-build.log','evidence/wearable-0331-windows.log','evidence/wearable-0331-windows-stderr.log']){
  const content=await readFile(path,'utf8');
  if(content.split(/\r?\n/).some(line=>/^FAIL:|^ERROR:|SCRIPT ERROR:/.test(line)))throw Error('Errors in '+path);
  logs[path]=content.match(/CHECKS: \d+ FAILED: \d+/)?.[0]||'No script/runtime errors';
}
for(const [path,expected] of Object.entries(manifest.hashes))if(await hash(path)!==expected)throw Error('Manifest mismatch: '+path);
const web=[];
for(const file of (await read('evidence/web-reference/source-baseline.json')).files)web.push({source:file.source,unchanged:await hash(file.source)===file.sha256});
if(web.some(file=>!file.unchanged))throw Error('Old web changed');
const apks=[];
for(const file of (await read('evidence/wardrobe-019-build-hashes.json')).filter(file=>/\.apk$/i.test(file.Path)))apks.push({path:file.Path,unchanged:await hash(file.Path)===file.Hash.toLowerCase()});
if(apks.some(file=>!file.unchanged))throw Error('Prior APK changed');
const original=await hash('C:/Users/user/AppData/Local/Growtopia/Growtopia.exe');
if(original!=='4325fe916b7435eeb50048608869fe81b1577b8f23fe3bfdd2b1beeb0a14d29c')throw Error('Original executable changed');
const source=await read('research/wearable-033/source-check.json');
if(!source.matches)throw Error('Simulator source changed');
const network=await read('evidence/wearable-033-real-network.json');
if(network.failures.length||network.clients!==12)throw Error('Network evidence missing');
const summary={version:manifest.version,build:{...running,sha256:await hash(running.exe),source_revision:manifest.source_revision,manifest_files:Object.keys(manifest.hashes).length},logs,windows:{scope:'targeted exported visual regression; extended Windows run ended before final report',checks:qa.checks.length,failures:qa.failures,performance:qa.wearable_033_performance},network,source,unchanged:{old_web:web,prior_apk:apks,growtopia_exe:original},limits:{exact_speed_increment:false,exact_shadow_timing:false,production_supabase_crowd_tested:false,all_item_effects_complete:false}};
await copyFile(profile+'/qa-report.json','evidence/wearable-0331-windows-final.json');
for(const name of ['spirit-online','online-inventory'])await copyFile(profile+'/qa-wearable-033-'+name+'.png','evidence/wearable-0331-'+name+'.png');
await writeFile('evidence/wearable-033-summary.json',JSON.stringify(summary,null,2));
console.log(JSON.stringify({version:summary.version,windows:summary.windows,network_clients:network.clients,old_web_verified:web.length,prior_apks_verified:apks.length,manifest_files:summary.build.manifest_files}));
