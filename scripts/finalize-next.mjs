import {readFile,writeFile,copyFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const out='evidence/ambatopia-next';
const json=async p=>JSON.parse(await readFile(p,'utf8'));
const w=await json('evidence/windows/qa-report.json'),a=await json('evidence/android/qa-report.json');
const protocol=await json('evidence/multiplayer-2026-10-23/protocol-64.json');
const accounts=await json(out+'/accounts-tests.log');
if(w.failures.length||a.failures.length||protocol.failures.length||accounts.passed!==12)throw Error('Verification failed');
const artifacts=[];
for(const path of ['build/windows/GrowtopiaReconstruction.exe','build/android/GrowtopiaReconstruction.apk']){
 const b=await readFile(path);artifacts.push({path,bytes:b.length,sha256:createHash('sha256').update(b).digest('hex')});
}
const report={date:'2026-10-23',version:'0.6.0',status:'Runnable intermediate build; full fidelity remains unfinished',old_web_modified:false,public_deployment:false,
 verified:{godot_checks:1329,node_tests:22,account_rls_checks:12,authenticated_windows_checks:w.checks.length,authenticated_android_checks:a.checks.length,software_clients:64,protocol_checks:protocol.checks.length},
 data:{native_items:16434,simulator_items:16508,weather_choices:80,weather_layer_images:375,simulator_atlas_downloaded:166,simulator_atlas_upstream_404:3,standard_wearables:1080,registered_locks:31},
 implemented:['Reference-video walk/jump/punch sprite playback','Simulator catalog search, static blocks and background layers','Weather selection with live common layers and image fallbacks','Server-owned area/world locks and protected tiles','Developer protected-tile breaking and Transform Amba','Developer-only promotion/demotion of moderators','Global /sb with durable 30-minute cooldown','Owner /kick /pull /ban with 24-hour world ban','Session-aware login overlay and offline/online choices with online count','Two-account IP registration quota in local broker; synthetic tests use separate quota files'],
 limitations:['Not all clothing/effects, seeds, consumables, blasts, providers, machines or gacha have working behavior. Catalog presence is not implementation.','27 complex weather recipes use still-image fallbacks; special weather effects and native geometry remain incomplete.','Area coverage uses bounded adjacent-tile expansion, not proven identical to every native lock rule.','Current authenticated session is reused in memory; restart requires login.','IP quota covers broker registrations after this update. Historical account IPs are unavailable. Direct Supabase Auth users without the server provisioning marker cannot enter the game, but native Auth registration settings were not changed during the dashboard outage.','64-client test is loopback software load, not 64 devices or public latency validation. Physical HP testing is landscape; portrait checks are renderer captures.','Android frame p95 is above 16.7ms; no constant 60 FPS or zero-bug guarantee.','Real Thaney password login was not retried after automatic approval review rejected it; developer permissions are tested with synthetic core identities and mocked broker responses.'],
 timings:{windows:w.timings_ms,android:a.timings_ms},artifacts};
await writeFile(out+'/result.json',JSON.stringify(report,null,2));
await writeFile('evidence/acceptance.json',JSON.stringify(report,null,2));
for(const [platform,report] of [['windows',w],['android',a]])await writeFile(out+'/'+platform+'-authenticated.json',JSON.stringify(report,null,2));
const board='evidence/fidelity-2026-10-22';await mkdir(board+'/next',{recursive:true});
for(const name of ['simulator-390x844.png','simulator-844x390.png','night-1280x720.png','amba-1280x720.png','login-390x844.png'])await copyFile(out+'/'+name,board+'/next/'+name);
let html=await readFile(board+'/comparison.html','utf8');
html=html.replace(/<section id="next-update">[\s\S]*?<\/section>/,'');
html=html.replace('</html>',`<section id="next-update"><h2>0.6 — video player, katalog simulator, lock dan perintah world</h2><p>1.329 pemeriksaan Godot, 22 tes Node, 12 tes akun/RLS, Windows + HP fisik, dan 64 client loopback. Server kembali memakai login normal; akun uji dibersihkan.</p><p>16.508 entri simulator dan 80 pilihan weather tersedia. Jumlah data bukan jaminan semua perilaku item selesai. Efek khusus, farming, mesin dan cuaca kompleks masih parsial.</p><div class="pair"><img src="next/simulator-390x844.png" alt="Inventory portrait"><img src="next/simulator-844x390.png" alt="Inventory landscape"></div><img src="next/amba-1280x720.png" alt="Transform Amba"><p>Hosting masih PC lokal + USB. Ambatopia web lama tidak diubah.</p></section></html>`);
await writeFile(board+'/comparison.html',html);
console.log(JSON.stringify({verified:report.verified,timings:report.timings,artifacts},null,2));

