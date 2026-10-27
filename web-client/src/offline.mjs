import {createTerrain} from '../reference/world-format.mjs';
export const offlineProfile={id:'offline',grow_id:'Offline',role:'player',appearance:{outfit:[]}};
let current,sequence=0,events=[],chat=[],locks=[];const worlds=new Map();
const save=()=>{localStorage.setItem('ambatopia-apk:world:'+current.world.id,JSON.stringify(current));};
const version=()=>++current.world.version;
export const offlineApi={async rpc(name,a={}){switch(name){
 case 'game_me':case 'game_touch':return offlineProfile;
 case 'game_worlds_list':return [...worlds.keys()].map(name=>({id:name,name,player_count:0}));
 case 'game_create_world':return a.p_name;
 case 'game_join':{let cached;try{cached=JSON.parse(localStorage.getItem('ambatopia-apk:world:'+a.p_world));}catch{}current=cached||{world:{id:a.p_world,name:a.p_world,version:0,updated_at:new Date().toISOString()},snapshot:createTerrain(a.p_world),players:[]};current.players=[{user_id:'offline',grow_id:'Offline',x:current.snapshot.spawn.x,y:current.snapshot.spawn.y,sequence:0,appearance:offlineProfile.appearance}];worlds.set(a.p_world,current);events=[];locks=[];return structuredClone(current);}
 case 'game_state':return structuredClone(current);
 case 'game_roster':return {players:current.players,version:current.world.version};
 case 'game_sync_motion':return {cursor:sequence,head:sequence,version:current.world.version,players:[],events:events.splice(0)};
 case 'game_heartbeat':return true;
 case 'game_leave':save();return true;
 case 'game_chat_history':return chat;
 case 'game_locks_list':return locks;
 case 'game_set_appearance':offlineProfile.appearance=a.p_appearance;return a.p_appearance;
 case 'game_chat':{const id=String(++sequence);chat.push({id,user_id:'offline',grow_id:'Offline',text:a.p_text,created_at:new Date().toISOString()});return id;}
 case 'game_edit':{for(const e of a.p_edits)current.snapshot[e.layer][e.y*100+e.x]=e.id;const v=version();save();return {version:v,edits:a.p_edits,saved_at:new Date().toISOString()};}
 case 'game_punch':{const at=a.p_y*100+a.p_x,old=current.snapshot.foreground[at];if([3,15].includes(old))throw Error('UNBREAKABLE');const edits=old?[{x:a.p_x,y:a.p_y,layer:'foreground',id:0}]:[];current.snapshot.foreground[at]=0;const v=version();save();return {version:v,edits,tile_id:old};}
 case 'game_respawn':return {...current.snapshot.spawn,sequence:0};
 case 'game_place_lock':{const id=({world:10,diamond:11,small:12,big:13,huge:14})[a.p_kind];current.snapshot.foreground[a.p_y*100+a.p_x]=id;const v=version(),l={id:a.p_x+','+a.p_y,lock_id:a.p_x+','+a.p_y,x:a.p_x,y:a.p_y,kind:a.p_kind,owner_id:'offline',owner_name:'Offline',tiles:[],grants:[],version:v};locks.push(l);save();return l;}
 case 'game_remove_lock':{const l=locks.find(l=>l.id===a.p_lock);if(!l)throw Error('Lock not found');current.snapshot.foreground[l.y*100+l.x]=0;locks=locks.filter(x=>x!==l);const v=version();save();return {version:v};}
 default:throw Error('This action is not available in offline play.');
}}};
