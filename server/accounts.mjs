import { RegistrationQuota } from './registration-quota.mjs';
import { createServer } from 'node:http';
import { timingSafeEqual } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { createReadStream, existsSync } from 'node:fs';
import { resolve } from 'node:path';

export const PROJECT = 'https://hbptqogoihmguhdizqcf.supabase.co';
export function identity(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_]{3,18}$/.test(value)) throw Error('Use 3–18 letters, numbers or underscores.');
  return value.toLowerCase();
}
export function password(value) {
  if (typeof value !== 'string' || value.length < 10 || value.length > 72) throw Error('Use a password between 10 and 72 characters.');
  return value;
}
export function alias(name) { return identity(name)+'@players.ambatopia.invalid'; }
export function reserved(name) { return identity(name) === 'thaney'; }
function equal(a,b) { const x=Buffer.from(a||''),y=Buffer.from(b||''); return x.length===y.length && x.length>20 && timingSafeEqual(x,y); }

export function createBroker(env=process.env) {
  if (env.SUPABASE_URL!==PROJECT || !env.SUPABASE_SECRET_KEY || !env.GAME_INTERNAL_TOKEN) throw Error('Dedicated game server configuration is required.');
  const rates=new Map();
  const quota=new RegistrationQuota(env.REGISTRATION_QUOTA_FILE||"server/private/registration-quota.json",env.GAME_INTERNAL_TOKEN);
  let presence={updated:0,worlds:[],players:[]};
  async function api(path,{method='GET',body,token,prefer}={}) {
    const headers={apikey:token?env.SUPABASE_PUBLISHABLE_KEY:env.SUPABASE_SECRET_KEY,'Content-Type':'application/json'};
    if(token) headers.Authorization='Bearer '+token;
    if(prefer) headers.Prefer=prefer;
    const response=await fetch(PROJECT+path,{method,headers,body:body===undefined?undefined:JSON.stringify(body),signal:AbortSignal.timeout(10000)});
    const text=await response.text();
    let data; try { data=JSON.parse(text); } catch { data=null; }
    if(!response.ok) { const error=Error('Account or storage request failed.'); error.status=response.status; throw error; }
    return data;
  }
  async function profile(token) {
    if(typeof token!=='string' || token.length>8192) throw Error('Please log in.');
    const user=await api('/auth/v1/user',{token});
    const rows=await api('/rest/v1/game_profiles?id=eq.'+encodeURIComponent(user.id)+'&select=*');
    const result=rows?.[0];
    if(!result || !user.app_metadata?.game_provisioned && !(result.role==='developer' && result.amba_id==='Thaney') || result.banned_until && Date.parse(result.banned_until)>Date.now()) throw Error('Account unavailable.');
    return result;
  }
  const server=createServer(async(req,res)=>{
    res.setHeader('Content-Type','application/json');
    res.setHeader('Cache-Control','no-store');
    res.setHeader('X-Content-Type-Options','nosniff');
    const reply=(status,value)=>{res.writeHead(status);res.end(JSON.stringify(value));};
    try {
      if(req.headers.origin || !['127.0.0.1:4193','localhost:4193'].includes(req.headers.host)) return reply(403,{error:'Local game requests only.'});
      if(req.method==='GET' && ['/download/android','/download/windows'].includes(req.url)){
        const android=req.url.endsWith('/android');
        const file=resolve(android?'build/android/GrowtopiaReconstruction.apk':'build/windows/GrowtopiaReconstruction.exe');
        if(!existsSync(file))return reply(404,{error:'Build not available yet.'});
        res.setHeader('Content-Type',android?'application/vnd.android.package-archive':'application/octet-stream');
        res.setHeader('Content-Disposition','attachment; filename="'+(android?'Ambatopia.apk':'Ambatopia.exe')+'"');
        createReadStream(file).on('error',()=>res.destroy()).pipe(res);return;
      }
      const now=Date.now(),ip=req.socket.remoteAddress;
      const requestToken=(req.headers.authorization||'').replace(/^Bearer /,'');
      const trusted=equal(requestToken,env.GAME_INTERNAL_TOKEN);
      const rate=rates.get(ip)||{start:now,count:0};
      if(now-rate.start>60000){rate.start=now;rate.count=0;}
      if(!trusted){rate.count++;rates.set(ip,rate);}
      if(!trusted && rate.count>120) return reply(429,{error:'Please wait before trying again.'});
      let text=''; for await(const chunk of req){text+=chunk;if(Buffer.byteLength(text)>(trusted?2000000:262144)){reply(413,{error:'Request too large.'});return;}}
      const body=text?JSON.parse(text):{};
      const token=(req.headers.authorization||'').replace(/^Bearer /,'');
      const internal=equal(token,env.GAME_INTERNAL_TOKEN);
      if(req.method==='GET' && req.url==='/health') return reply(200,{ok:true,project:'ambatopia-godot'});
      if(req.method==='GET' && req.url==='/online')return reply(200,{online:Date.now()-presence.updated<15000?presence.players.length:0});
      if(req.method==='POST' && req.url==='/auth/register'){
        const name=identity(body.name);password(body.password);
        if(reserved(name)) return reply(403,{error:'This AmbaID is reserved.'});
        const reservation=quota.reserve(ip);
        if(!reservation)return reply(429,{error:'This IP has reached the limit of two accounts. New registrations are blocked; existing accounts can still log in.'});
        try { await api('/auth/v1/admin/users',{method:'POST',body:{email:alias(name),password:body.password,email_confirm:true,app_metadata:{game_provisioned:true},user_metadata:{amba_id:body.name}}}); }
        catch(error){quota.release(reservation);throw error;}
        const session=await api('/auth/v1/token?grant_type=password',{method:'POST',body:{email:alias(name),password:body.password}});
        return reply(200,{access_token:session.access_token,refresh_token:session.refresh_token,profile:await profile(session.access_token)});
      }
      if(req.method==='POST' && req.url==='/auth/login'){
        const session=await api('/auth/v1/token?grant_type=password',{method:'POST',body:{email:alias(body.name),password:password(body.password)}});
        return reply(200,{access_token:session.access_token,refresh_token:session.refresh_token,profile:await profile(session.access_token)});
      }
      if(req.method==='POST' && req.url==='/auth/refresh'){
        if(typeof body.refresh_token!=='string' || body.refresh_token.length>512) throw Error('Invalid session');
        const session=await api('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:body.refresh_token}});
        return reply(200,{access_token:session.access_token,refresh_token:session.refresh_token,profile:await profile(session.access_token)});
      }
      if(req.method==='POST' && req.url==='/auth/verify') return reply(200,{profile:await profile(body.token)});
      if(internal && req.method==='POST' && req.url==='/internal/world') {
        if(!/^[A-Z0-9]{1,18}$/.test(body.name)) throw Error('Invalid world');
        if(body.state){
          await api('/rest/v1/game_worlds',{method:'POST',prefer:'resolution=merge-duplicates',body:{name:body.name,state:body.state,owner_id:body.owner_id||null,updated_at:new Date().toISOString()}});
          return reply(200,{ok:true});
        }
        return reply(200,{world:(await api('/rest/v1/game_worlds?name=eq.'+body.name+'&select=*'))?.[0]||null});
      }
      if(internal && req.method==='POST' && req.url==='/internal/presence') {
        presence={updated:Date.now(),worlds:Array.isArray(body.worlds)?body.worlds.slice(0,64):[],players:Array.isArray(body.players)?body.players.slice(0,64):[]};
        return reply(200,{ok:true});
      }
      if(internal && req.method==='POST' && req.url==='/internal/status'){
        const ids=Array.isArray(body.ids)?body.ids.filter(x=>/^[a-f0-9-]{36}$/.test(x)).slice(0,64):[];
        return reply(200,{players:ids.length?await api('/rest/v1/game_profiles?id=in.('+ids.join(',')+')&select=id,role,banned_until,settings'):[]});
      }
      if(req.method==='GET' && req.url==='/worlds'){
        await profile(token);
        const saved=await api('/rest/v1/game_worlds?select=name,owner_id&limit=64&order=updated_at.desc');
        const live=Date.now()-presence.updated<15000?presence.worlds:[];
        const merged=new Map(saved.map(x=>[x.name,{...x,count:0}]));
        for(const row of live)merged.set(row.name,{...merged.get(row.name),...row});
        if(!merged.has('START'))merged.set('START',{name:'START',count:0});
        return reply(200,{worlds:[...merged.values()].sort((a,b)=>b.count-a.count)});
      }
      if(internal && req.method==='POST' && req.url==='/internal/profile'){
        if(!/^[a-f0-9-]{36}$/.test(body.id)) throw Error('Invalid player');
        const current=(await api('/rest/v1/game_profiles?id=eq.'+body.id+'&select=played_seconds,settings'))?.[0];
        const collected=Object.fromEntries(Object.entries(body.collected||{}).filter(([id,n])=>/^\d{1,5}$/.test(id)&&Number.isInteger(n)&&n>=0&&n<=999999).slice(0,1024));
        await api('/rest/v1/game_profiles?id=eq.'+body.id,{method:'PATCH',body:{outfit:body.outfit||{},settings:{...current?.settings,collected,skin:Math.max(0,Math.min(5,Math.floor(Number(body.skin)||0)))},last_seen_at:new Date().toISOString(),played_seconds:Number(current?.played_seconds||0)+Math.max(0,Math.min(86400,Math.floor(Number(body.seconds)||0)))}});
        return reply(200,{ok:true});
      }
      if(req.method==='GET' && req.url==='/admin/players'){
        const actor=await profile(token);
        if(actor.role!=='developer')return reply(403,{error:'Developer access required.'});
        const players=await api('/rest/v1/game_profiles?select=id,amba_id,created_at,last_seen_at,played_seconds,banned_until&limit=200&order=created_at.desc');
        const worlds=await api('/rest/v1/game_worlds?select=name,owner_id&limit=1000');
        const live=Date.now()-presence.updated<15000?presence.players:[];
        return reply(200,{players:players.map(p=>{const online=live.find(x=>x.id===p.id);return {...p,online:!!online,ip:online?.ip||null,played_seconds:p.played_seconds+(online?.seconds||0)};}),worlds,logs:await api('/rest/v1/game_audit?select=*&order=created_at.desc&limit=100')});
      }
      if(req.method==='POST' && req.url==='/admin/moderate'){
        const actor=await profile(token);
        if(actor.role!=='developer')return reply(403,{error:'Developer access required.'});
        if(!/^[a-f0-9-]{36}$/.test(body.target)||!['ban','unban','curse','warn','promote','demote'].includes(body.action)||body.target===actor.id)throw Error('Invalid moderation target.');
        const rows=await api('/rest/v1/game_profiles?id=eq.'+body.target+'&select=id,role,settings');
        if(!rows?.length||rows[0].role==='developer')throw Error('Invalid moderation target.');
        const until=new Date(Date.now()+86400000).toISOString();
        let change={};
        if(body.action==='ban'||body.action==='unban')change.banned_until=body.action==='ban'?until:null;
        else if(body.action==='promote'||body.action==='demote')change.settings={...rows[0].settings,moderator:body.action==='promote'};
        else change.settings={...rows[0].settings,...(body.action==='curse'?{muted_until:until}:{warning:String(body.message||'Please follow the community rules.').slice(0,160)})};
        await api('/rest/v1/game_profiles?id=eq.'+body.target,{method:'PATCH',body:change});
        await api('/rest/v1/game_audit',{method:'POST',body:{actor_id:actor.id,target_id:body.target,action:body.action,detail:{until:body.action==='ban'||body.action==='curse'?until:null}}});
        return reply(200,{ok:true});
      }
      return reply(404,{error:'Not found'});
    } catch(error) { reply(error.status===429?429:400,{error:['SyntaxError','TypeError'].includes(error.name)?'Invalid request.':error.message}); }
  });
  server.requestTimeout=15000; server.headersTimeout=10000;
  return server;
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href){
 createBroker().listen(4193,'127.0.0.1',()=>console.log('AMBATOPIA_ACCOUNT_SERVER_READY 127.0.0.1:4193'));
}
