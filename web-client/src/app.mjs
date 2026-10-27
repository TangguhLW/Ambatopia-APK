import {session} from './session.mjs';
import {api} from './api.mjs';
import {offlineApi,offlineProfile} from './offline.mjs';
import {renderMenu} from '../reference/screens/menu.mjs';
import {renderAuth} from '../reference/screens/auth.mjs';
import {renderWorlds} from '../reference/screens/worlds.mjs';
import {renderLoading} from '../reference/screens/loading.mjs';
import {renderPlay} from '../reference/screens/play.mjs';
import {installAudio} from '../reference/audio.mjs';
import {createMenuScene} from '../reference/menu-scene.mjs';
import {installPreferences} from '../reference/preferences.mjs';
const root=document.querySelector('#app');installPreferences();const audio=installAudio(),scene=createMenuScene(document.querySelector('.landscape'));
let screen,route='menu',local=false,generation=0,entering;
const identity={get profile(){return local?offlineProfile:session.profile;},authenticate:(...a)=>session.authenticate(...a),getAccessToken:()=>session.getAccessToken(),signOut:()=>session.signOut()};
export const ctx={session:identity,get api(){return local?offlineApi:api;},navigate,start,enterWorld,logout:async()=>{if(!local)await session.signOut();local=false;navigate('menu');}};
function navigate(name,params={}){generation++;screen?.dispose?.();route=name;document.body.classList.toggle('playing',name==='play');document.body.dataset.screen=name;audio.screen(name);scene.screen(name);screen=({menu:renderMenu,auth:renderAuth,worlds:renderWorlds,loading:renderLoading,play:renderPlay})[name]?.(root,ctx,params);if(!screen&&name==='developer'){root.textContent='Developer account is recognized. Advanced moderation is not yet connected in this client.';const b=document.createElement('button');b.textContent='Back';b.onclick=()=>navigate('worlds');root.append(b);}document.querySelector('#account-label').textContent=identity.profile?.grow_id||'Welcome to Ambatopia';if(name==='menu'){
 const buttons=root.querySelector('.entry-buttons'),offline=document.createElement('button');offline.textContent='Offline mode';offline.onclick=()=>{local=true;ctx.api.rpc('game_create_world',{p_name:'OFFLINE'}).then(id=>enterWorld(id));};buttons.append(offline);
 }root.focus({preventScroll:true});return screen;}
async function start(){if(local&&route==='play'){navigate('worlds',{initial:await offlineApi.rpc('game_worlds_list',{})});return;}local=false;const loading=navigate('loading'),ticket=generation;try{if(!await session.getAccessToken()){navigate('auth');return;}if(ticket!==generation)return;loading.step(0);const initial=await api.rpc('game_worlds_list',{});loading.step(1);loading.step(2);navigate('worlds',{initial});}catch(e){loading.error(e);}}
async function enterWorld(id){if(entering)return entering;entering=(async()=>{const value=await ctx.api.rpc('game_join',{p_world:id});navigate('play',{state:value});})().finally(()=>entering=null);return entering;}
window.AmbatopiaApp={ctx,session,api,get route(){return route;},get local(){return local;},navigate,enterWorld,start,offline:async(name='OFFLINE')=>{local=true;return enterWorld(name);}};
window.addEventListener('error',event=>console.error('APP_ERROR',event.message));window.addEventListener('unhandledrejection',event=>console.error('APP_PROMISE',event.reason?.message||String(event.reason)));
window.AmbatopiaBack=()=>{if(route==='play')ctx.api.rpc('game_leave',{}).finally(()=>navigate(local?'menu':'worlds'));else navigate('menu');};
navigate('menu');
if(new URLSearchParams(location.search).has('qa'))import('./qa.mjs').then(m=>m.runQA(window.AmbatopiaApp));
