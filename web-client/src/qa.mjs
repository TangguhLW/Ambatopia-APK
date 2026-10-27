const wait=ms=>new Promise(r=>setTimeout(r,ms));
export async function runQA(app){
 const report={platform:navigator.userAgent,checks:[],failures:[],timings:{},costumes:[]};const start=performance.now();
 const check=(value,name)=>{report.checks.push(name);if(!value)report.failures.push(name);};
 async function until(fn,ms=30000){const end=performance.now()+ms;while(performance.now()<end){if(fn())return true;await wait(50);}return false;}
 try{
 check(!!document.querySelector('.entry-menu'),'Original Ambatopia menu is present');
 await app.offline('WEBQA');check(app.route==='play','Offline mode enters original web in-world UI');
 const iframe=document.querySelector('.native-simulator');
 const loaded=await until(()=>iframe?.contentWindow?.GW?.on&&iframe.contentWindow.AmbatopiaNative&&!document.querySelector('.native-loading'));
 check(loaded,'Original simulator renderer finishes from packaged resources');if(!loaded)throw Error('Renderer not ready');
 report.timings.entry_ms=Math.round(performance.now()-start);
 const w=iframe.contentWindow,native=w.AmbatopiaNative;
 const realm=document.createElement('iframe');realm.src='/set/?avatar=1';realm.style.cssText='position:absolute;left:-10000px;width:280px;height:224px';document.body.append(realm);
 if(!await until(()=>realm.contentWindow?.plannerReady&&realm.contentWindow?.AmbatopiaNative))throw Error('Avatar reference realm not ready');
 const renderer=realm.contentWindow.AmbatopiaNative;renderer.prepareAvatar();
 const inventory=native.catalog();const text=JSON.stringify(inventory);const sheets=[...new Set(inventory.map(item=>item.bk).filter(x=>/^[a-f0-9]{12}$/.test(x)).map(x=>'b/'+x))];
 const debug=document.createElement('textarea');debug.id='qa-assets';debug.setAttribute('aria-label','QA asset inventory');debug.style.cssText='position:fixed;left:0;top:0;width:1px;height:1px;opacity:.01';debug.textContent=JSON.stringify({catalog:inventory,count:inventory.length,sheets,sample:inventory.find(i=>i.id===15416),basic:inventory.find(i=>i.id===46)});document.body.append(debug);
check(w.document.querySelector('#g2-rail')?.textContent.includes('4083'),'Full reference wardrobe categories are available');
 const samples=[{name:'Basic slots',ids:[46,36,48,40,34,362]},{name:'Legendbot',ids:[1780]},{name:'Constellation Wings',ids:[15416]},{name:'Mobile Suit',ids:[14232]},{name:'Barong',ids:[15576]},{name:'Angelic Circlet',ids:[15188]}];
 const canvas=document.createElement('canvas');canvas.width=280;canvas.height=224;const ctx=canvas.getContext('2d');
 for(const sample of samples){console.log('QA_COSTUME '+sample.name);await Promise.race([native.wear({outfit:sample.ids,skin:[240,190,140]}),wait(8000).then(()=>{throw Error('Costume timeout: '+sample.name)})]);await renderer.wear({outfit:sample.ids,skin:[240,190,140]});await wait(60);const worn=Object.values(native.character.worn).map(i=>i.id);check(sample.ids.every(id=>worn.includes(id)),'Reference wear path equips '+sample.name);const hashes=[];
 for(const [animation,facing] of [['idle','right'],['walk','right'],['jump','left']]){ctx.clearRect(0,0,280,224);await renderer.renderAvatar(ctx,{animation,facing,phase:1,time:250,punchAge:-1});const pixels=ctx.getImageData(0,0,280,224).data;let count=0,hash=0;for(let i=0;i<pixels.length;i++){hash=(Math.imul(hash,31)+pixels[i])>>>0;if(i%4===3&&pixels[i])count++;}check(count>30,sample.name+' renders '+animation+' '+facing);hashes.push(hash);}
 report.costumes.push({name:sample.name,ids:sample.ids,pose_hashes:hashes});}
 await native.wear({outfit:[46,36,48,40,34,362]});const hat=w.document.querySelector('#g2-q');check(!!hat,'Reference wardrobe search input is present');
 const before=w.GW.P.x;native.input.right=true;await wait(280);native.input.right=false;check(w.GW.P.x>before,'Original web player movement advances immediately');
 native.input.jump=true;await wait(90);check(!!native.act.air,'Original web jump animates');native.input.jump=false;await wait(500);
 check(native.punch({x:Math.floor(w.GW.P.x/32)+1,y:Math.floor(w.GW.P.y/32)})!==false,'Original web punch animation accepts an in-range target');
 const sheet=document.querySelector('.online-chat');sheet.open=true;const input=sheet.querySelector('input');input.value='Web engine APK QA';sheet.querySelector('form').dispatchEvent(new Event('submit',{bubbles:true,cancelable:true}));await wait(200);check(w.document.querySelector('.player-bubble')?.textContent==='Web engine APK QA','Reference bubble chat follows the native player layer');
 check([...document.querySelectorAll('.online-actions button')].filter(x=>x.getBoundingClientRect().width>0).every(x=>x.getBoundingClientRect().width>=36),'Visible action buttons retain touch size');
 await native.wear({outfit:[15576,15416,15188],skin:[240,190,140]});
 const times=[];for(let i=0;i<60;i++){const a=performance.now();await new Promise(requestAnimationFrame);times.push(performance.now()-a);}times.sort((a,b)=>a-b);report.timings.frame_p50_ms=times[30];report.timings.frame_p95_ms=times[57];
 }catch(error){report.failures.push(error.message);}
 report.elapsed_ms=Math.round(performance.now()-start);window.AmbatopiaQA=report;
 if(window.AmbatopiaAndroid)window.AmbatopiaAndroid.record(JSON.stringify(report));
 console.log('QA_RESULT '+JSON.stringify({checks:report.checks.length,failures:report.failures,timings:report.timings}));document.body.dataset.qa=report.failures.length?'failed':'passed';
}
