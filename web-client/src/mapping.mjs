import slots from '../data/item-bridge.json' with {type:'json'};
const serverBase={0:0,1:2,2:8,3:10,4:6,5:242,6:116,7:4};
export const webNative={0:0,1:2,2:16,3:8,4:10,5:100,6:548,7:116,8:14,9:102,10:242,11:1796,12:202,13:204,14:206,15:6,16:4};
const reverseWeb=new Map(Object.entries(webNative).map(([k,v])=>[v,+k]));
const reverseServer=new Map(Object.entries(serverBase).map(([k,v])=>[v,+k]));
export function toNative(id){if(!Number.isInteger(id)||id<0||id>299999)throw Error('Unknown server item');if(id>=200000)return id-200000;if(id>=100000)return id-100000;return serverBase[id]??id;}
export const toRuntime=id=>reverseServer.get(toNative(id))??(200000+toNative(id));
export const nativeForWeb=id=>webNative[id]??(id>=1000000?id-1000000:undefined);
export const webForNative=id=>reverseWeb.get(id)??1000000+id;
export const runtimeForWeb=id=>{const original=nativeForWeb(id);if(original===undefined)throw Error('Unknown block');return reverseServer.get(original)??200000+original;};
export const webForRuntime=id=>webForNative(toNative(id));
export function toWebSnapshot(world){return {schema:1,width:100,height:60,foreground:world.foreground.map(webForRuntime),background:world.background.map(webForRuntime),spawn:{x:world.main_door[0],y:world.main_door[1]},weather:world.weather||'sunny'};}
export function appearanceToEquipment(appearance){const equipment={};for(let id of appearance.outfit||[]){if(!Number.isInteger(id)||!slots[id])continue;equipment[slots[id]]=id;}return equipment;}
export function equipmentToAppearance(equipment,skin=0){return {outfit:Object.values(equipment||{}).map(id=>id>=200000?id-200000:id),skin:[[240,190,140],[197,139,96],[151,96,62],[98,61,43],[255,218,185],[109,175,91]][skin]||[240,190,140]};}
export function peerToWeb(row){return {user_id:row.uid,grow_id:row.name,sequence:row.sequence||0,x:(row.x-10)/32,y:(row.y-30)/32,facing:row.facing<0?'left':'right',animation:row.grounded?'idle':'jump',appearance:equipmentToAppearance(row.equipment,row.skin)};}
