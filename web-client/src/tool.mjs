window.addEventListener('error',e=>console.error('RENDER_ERROR '+(e.error?.stack||e.message)));
import {installDiscordGuard} from '../reference/remove-discord.mjs';
import {installAudio} from '../reference/audio.mjs';
import {installNativeLayout} from '../reference/tool-layout.mjs';
installDiscordGuard();installAudio({menuMusic:false});installNativeLayout();
const params=new URLSearchParams(location.search);
if(params.has('avatar'))window.requestAnimationFrame=()=>0;
if(params.has('avatar')||params.has('online')){const entries=new Map();Object.defineProperty(window,'localStorage',{value:{getItem:k=>entries.get(k)??null,setItem:(k,v)=>entries.set(k,String(v)),removeItem:k=>entries.delete(k),clear:()=>entries.clear(),key:i=>[...entries.keys()][i]??null,get length(){return entries.size;}}});}
localStorage.setItem('gs_gazette','2026-10-14');
const marker=document.querySelector('script[data-game-src]');if(!marker)throw Error('Renderer bootstrap is missing');
const script=document.createElement('script');script.src=marker.dataset.gameSrc;script.onerror=()=>console.error('RENDERER_LOAD_FAILED',script.src);document.body.append(script);
