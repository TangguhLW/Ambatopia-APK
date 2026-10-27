import {readFile,writeFile,stat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root=new URL('../',import.meta.url);
const read=path=>readFile(new URL(path,root),'utf8');
const windows=JSON.parse(await read('evidence/windows/qa-report.json'));
const android=JSON.parse(await read('evidence/android/qa-report.json'));
const units=await read('evidence/verified-unit-tests.log');
const match=units.match(/CHECKS: (\d+) FAILED: (\d+)/);
if(!match||Number(match[2])||windows.failures.length||android.failures.length)throw Error('Cannot finalize failing evidence');
const artifacts=[];
for(const path of ['build/windows/GrowtopiaReconstruction.exe','build/android/GrowtopiaReconstruction.apk']){
 const file=new URL(path,root);const bytes=await readFile(file);artifacts.push({path,bytes:(await stat(file)).size,sha256:createHash('sha256').update(bytes).digest('hex')});
}
const acceptance={date:'2026-10-22',milestone:'First runnable Windows + Android local build',ambatopia_changes:false,commits_or_pushes:false,public_deployment:false,engine:'Godot 4.7.2 Standard / GDScript / Compatibility',verified:{godot_checks:Number(match[1]),godot_failures:0,asset_importer_tests:4,windows_exported_runtime_checks:windows.checks.length,android_physical_device_checks:android.checks.length,android_device:'Xiaomi M2003J15SC / Android 12 (API 31) / arm64',android_signature:'v2 and v3 verified, local debug key',network_permissions:'No permissions listed by aapt; no official servers or accounts'},artifacts,scope:{implemented:['Reference-derived menu/font/selected sprites/icons/sounds','Clearly identified local profile and world chooser','Local worlds, safe main-door spawn and bedrock','Movement/jump, multi-touch controls, visible punch, distinct place/wrench','Selected blocks/equipment and local inventory','Short player-following local chat bubble','Local save/reopen, corrupt-data handling, Back and window-close flows'],not_claimed:['100% visual/behavior parity','Complete official item catalog','Multiplayer or real account authentication','Authoritative lock ownership','Farming/trading/economy and advanced systems','Web build or broad device/DPI coverage']},evidence:['evidence/windows/qa-report.json','evidence/android/qa-report.json','evidence/verified-unit-tests.log','evidence/verified-asset-tests.log','evidence/apk-signature.log','evidence/behavior-gaps.json']};
await writeFile(new URL('evidence/acceptance.json',root),JSON.stringify(acceptance,null,2));
const performance={date:'2026-10-22',measurement:'Short instrumented real-render sessions, synthetic local fixtures',windows:windows.timings_ms,android:android.timings_ms,static_memory_bytes:{windows:windows.static_memory_bytes||null,android:android.static_memory_bytes||null},targets:{local_entry_ms:1000,p95_frame_ms:16.7},results:{local_entry_met_both:Math.max(windows.timings_ms.local_world_entry,android.timings_ms.local_world_entry)<=1000,p95_frame_met_both:Math.max(windows.timings_ms.frame_p95,android.timings_ms.frame_p95)<=16.7},limitations:'Menu timing starts after app ready. No cold-launch, peak memory, long-session or multiplayer load measurement. 0 static-memory readings from Windows release builds are unavailable, not zero use.'};
await writeFile(new URL('evidence/performance.json',root),JSON.stringify(performance,null,2));
console.log(JSON.stringify({checks:acceptance.verified,artifacts,performance:performance.results}));
