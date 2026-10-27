import config from '../data/network.json' with {type:'json'};
import {equipmentToAppearance} from './mapping.mjs';
export const PROJECT='https://hbptqogoihmguhdizqcf.supabase.co';
if(config.url!==PROJECT)throw Error('Wrong game database');
let access='',refresh='',expires=0,current=null;const listeners=new Set(),KEY='ambatopia-apk:session';
export async function request(path,body,method='POST',token=access){
 const response=await fetch(PROJECT+path,{method,headers:{apikey:config.publishable_key,...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json'},body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(20000)});
 const data=await response.json().catch(()=>null);if(!response.ok)throw Error(data?.msg||data?.message||data?.error_description||'Account request failed');return data;
}
async function accept(result){
 access=result.access_token;refresh=result.refresh_token;expires=result.expires_at||Date.now()/1000+result.expires_in;
 const rows=await request('/rest/v1/game_profiles?id=eq.'+encodeURIComponent(result.user.id)+'&select=*',undefined,'GET');if(rows.length!==1)throw Error('Game profile unavailable');
 const p=rows[0];current={id:p.id,grow_id:p.amba_id,role:p.role==='developer'?'superadmin':'player',appearance:equipmentToAppearance(p.outfit,p.settings.skin||0),god_mode:false};
 localStorage.setItem(KEY,JSON.stringify({refresh}));for(const f of listeners)f(current);return current;
}
export const session={
 get profile(){return current;},
 async getAccessToken(){if(access&&expires>Date.now()/1000+60)return access;if(!refresh){try{refresh=JSON.parse(localStorage.getItem(KEY))?.refresh||'';}catch{}}if(!refresh)return null;try{await accept(await request('/auth/v1/token?grant_type=refresh_token',{refresh_token:refresh},'POST',''));return access;}catch{access='';refresh='';current=null;localStorage.removeItem(KEY);return null;}},
 async authenticate(action,input){const name=input.growId;if(!/^[A-Za-z0-9_]{3,18}$/.test(name)||new TextEncoder().encode(input.password).length>72||input.password.length<10)throw Error('AmbaID: 3–18 characters; password: 10–72 bytes.');const body={email:name.toLowerCase()+'@players.ambatopia.invalid',password:input.password,...(action==='signup'?{data:{amba_id:name}}:{})};return accept(await request(action==='signup'?'/auth/v1/signup':'/auth/v1/token?grant_type=password',body,'POST',''));},
 async signOut(){const old=access;access='';refresh='';current=null;localStorage.removeItem(KEY);for(const f of listeners)f(null);if(old)await request('/auth/v1/logout',{},'POST',old);},
 subscribe(f){listeners.add(f);return()=>listeners.delete(f);},
 async testSession(value){if(!new URLSearchParams(location.search).has('qa'))throw Error('QA disabled');return accept(value);}
};
export const key=config.publishable_key;
