import {readFile,writeFile,copyFile} from 'node:fs/promises';
import {createReadStream} from 'node:fs';
import {createHash} from 'node:crypto';
const read=async path=>JSON.parse(await readFile(path,'utf8'));
async function hash(path){const sum=createHash('sha256');for await(const bytes of createReadStream(path))sum.update(bytes);return sum.digest('hex')}
const manifest=await read('data/build-info.json');
for(const [path,expected] of Object.entries(manifest.hashes))if(await hash(path)!==expected)throw Error('Build manifest changed: '+path);
const running=await read('evidence/gui-0341-final-running.json');
const windows=await read(running.profile.replaceAll('\\','/')+'/GTRef/qa-report.json');
if(windows.failures.length||windows.checks.length<380)throw Error('Full Windows GUI did not pass');
const native=await readFile('evidence/native-0341-all.log','utf8');
if(!/CHECKS: \d+ FAILED: 0/.test(native)||/SCRIPT ERROR|^FAIL:/m.test(native))throw Error('Native regression failed');
for(const path of ['evidence/gui-0341-final-engine.log','evidence/gui-0341-final-stderr.log','evidence/build-0341.log'])if(/SCRIPT ERROR|^ERROR:/m.test(await readFile(path,'utf8')))throw Error('Runtime/build error: '+path);
const live=await read('evidence/supabase-online/live.json'),client=await read('evidence/supabase-online/godot-client.json'),crowd=await read('evidence/supabase-online/crowd.json');
for(const path of ['cleanup','crowd-cleanup']){const row=await read('evidence/supabase-online/'+path+'.json');if(row.failure||!row.world_cleaned)throw Error('Supabase fixture cleanup failed')}
if(client.failures.length||crowd.godot.failures.length||crowd.realtime_errors.length||crowd.received_deliveries!==crowd.expected_deliveries)throw Error('Supabase live regression failed');
const android=await read('evidence/android-0341/qa-report.json'),cleanup=await read('evidence/android-0341/cleanup.json');
const pendingGrowth=process.argv.includes('--allow-pending-growth');
const knownGrowthFailures=['Authenticated device receives persistent seed metadata','Authenticated device harvests a shared tree','Authenticated provider state replicated to device'];
if(!cleanup.account_removed||!cleanup.world_removed)throw Error('Android fixture cleanup failed');
if(!pendingGrowth&&(android.failures.length||cleanup.failure))throw Error('Android GUI/cloud checks failed');
if(pendingGrowth&&(android.failures.length!==3||android.failures.some(label=>!knownGrowthFailures.includes(label))))throw Error('Unexpected Android regression');
let cloud;
try{cloud=await read('evidence/android-0341/cloud.json')}catch(error){if(!pendingGrowth||error.code!=='ENOENT')throw error;cloud={project:'ambatopia-godot',login_verified:android.checks.includes('Exported app logs in to real Supabase fixture through account service'),world_join_verified:android.checks.includes('Authenticated exported app enters persistent shared world'),growth_migration_applied:false}}
if(/SCRIPT ERROR|ERROR:/.test(await readFile('evidence/android-0341/runtime-log.txt','utf8')))throw Error('Android runtime error');
const web=[];
for(const row of (await read('evidence/web-reference/source-baseline.json')).files)web.push({source:row.source,unchanged:await hash(row.source)===row.sha256});
if(web.some(row=>!row.unchanged))throw Error('Old web source changed');
const priorApks=[];
for(const row of (await read('evidence/wardrobe-019-build-hashes.json')).filter(row=>/\.apk$/i.test(row.Path)))priorApks.push({path:row.Path,unchanged:await hash(row.Path)===row.Hash.toLowerCase()});
if(priorApks.some(row=>!row.unchanged))throw Error('Previous APK changed');
const original=await hash('C:/Users/user/AppData/Local/Growtopia/Growtopia.exe');
if(original!=='4325fe916b7435eeb50048608869fe81b1577b8f23fe3bfdd2b1beeb0a14d29c')throw Error('Original executable changed');
await copyFile(running.profile.replaceAll('\\','/')+'/GTRef/qa-report.json','evidence/windows-0341-final.json');
const artifacts=[];
for(const path of ['build/windows/Ambatopia-0.34.1.exe','build/android/Ambatopia-0.34.1.apk'])artifacts.push({path,sha256:await hash(path)});
const summary={version:manifest.version,complete:!pendingGrowth,pending:pendingGrowth?'Seed/provider migration is locally tested but awaits Supabase dashboard login before deployment':null,source_revision:manifest.source_revision,manifest_files:Object.keys(manifest.hashes).length,artifacts,native:native.match(/CHECKS: \d+ FAILED: \d+/)[0],windows:{checks:windows.checks.length,failures:windows.failures,effects:windows.effect_scenarios,online_equivalent:windows.wearable_033_performance},android:{checks:android.checks.length,failures:android.failures,effects:android.effect_scenarios,online_equivalent:android.wearable_033_performance,cloud,cleanup},supabase:{native_client_checks:client.checks.length,failures:client.failures,two_player_motion_ms:live.motion_ms,crowd_players:crowd.players,received:crowd.received_deliveries,expected:crowd.expected_deliveries,p50_ms:crowd.delivery_p50_ms,p95_ms:crowd.delivery_p95_ms,traffic:crowd.traffic},unchanged:{old_web:web,prior_apks:priorApks,growtopia_exe:original},limits:['Crowd test uses bounded sparse traffic, not full 9-player 10 Hz capacity.','Realtime latency varies; no zero-lag claim.','Exact Spirit Guide echo timing and Speedy numeric increments remain adaptations.','No claim that every item effect or online gameplay feature is complete.']};
await writeFile('evidence/platforms-034-summary.json',JSON.stringify(summary,null,2));
console.log(JSON.stringify({version:summary.version,native:summary.native,windows:summary.windows.checks,android:summary.android.checks,live_players:crowd.players,old_web_verified:web.length,manifest_files:summary.manifest_files}));
