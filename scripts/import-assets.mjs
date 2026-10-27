import {readFile,writeFile,mkdir,rename,rm,stat} from 'node:fs/promises';
import {join,resolve} from 'node:path';
import {inflateSync,deflateSync} from 'node:zlib';
import {createHash,randomUUID} from 'node:crypto';
import {pathToFileURL} from 'node:url';
const selected={block_cracks:'game/crack.rttex',eyes2:'game/player_eyes2.rttex',face:'game/player_face.rttex',extraleg:'game/player_extraleg.rttex',sleeve:'game/player_sleeve.rttex',action_particles:'game/particles.rttex',itembox:'game/gui_itembox.rttex',panel_up:'game/gui_box_upwhite.rttex',chat_icon:'interface/large/btn_chat.rttex',panel:'game/gui_box_white.rttex',panel_tinted:'game/gui_box.rttex',slot:'interface/large/btn_tabs1.rttex',slot_selected:'interface/large/btn_tabs2.rttex',menu_toggle:'interface/large/menu_button.rttex',chat_handle:'interface/large/gui_chat_move_handle.rttex',social:'interface/large/social_buttons01.rttex',hills1:'game/hills1.rttex',hills2:'game/hills2.rttex',hills3:'game/hills3.rttex',menu_background:'interface/large/main_menu_bg_themed.rttex',sky:'game/b_skybg.rttex',sun:'game/sun.rttex',title:'interface/large/game_title.rttex',left:'interface/large/left_arrow.rttex',right:'interface/large/right_arrow.rttex',jump:'interface/large/jump_icon.rttex',punch:'interface/large/punch_icon.rttex',chat:'interface/large/chat_button.rttex',menu:'interface/large/generic_menu.rttex',body:'game/player_body_only.rttex',head:'game/player_head.rttex',arm:'game/player_arm.rttex',puncharm:'game/player_puncharm.rttex',feet:'game/player_feet.rttex',eyes:'game/player_eyes.rttex',hair:'game/player_hairhair.rttex',shirts:'game/player_shirt.rttex',pants:'game/player_pants.rttex',tiles:'game/tiles_page1.rttex',cloud:'game/cloud.rttex'};
const sha=b=>createHash('sha256').update(b).digest('hex');
export {png};
export function decodeTexture(source){
 let b=source;if(b.subarray(0,6).toString()==='RTPACK')b=inflateSync(b.subarray(32),{maxOutputLength:64*1024*1024});
 if(b.length<124||b.subarray(0,6).toString()!=='RTTXTR')throw Error('Unsupported texture header');
 const height=b.readUInt32LE(8),width=b.readUInt32LE(12);
 if(b.readUInt32LE(16)!==5121||b[28]!==1||!width||!height||width>4096||height>4096||width*height*4+124!==b.length)throw Error('Unsupported pixel layout');
 return {width,height,originalWidth:b.readUInt32LE(24),originalHeight:b.readUInt32LE(20),pixels:b.subarray(124)};
}
function crc(b){let c=0xffffffff;for(const n of b){c^=n;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0);}return(c^0xffffffff)>>>0;}
export function upright(image){const row=image.width*4,pixels=Buffer.alloc(image.pixels.length);for(let y=0;y<image.height;y++)image.pixels.copy(pixels,y*row,(image.height-y-1)*row,(image.height-y)*row);return {...image,pixels};}
function chunk(t,b){const a=Buffer.from(t),s=Buffer.alloc(4),c=Buffer.alloc(4);s.writeUInt32BE(b.length);c.writeUInt32BE(crc(Buffer.concat([a,b])));return Buffer.concat([s,a,b,c]);}
function png({width,height,pixels}){const h=Buffer.alloc(13);h.writeUInt32BE(width);h.writeUInt32BE(height,4);h[8]=8;h[9]=6;const row=width*4,raw=Buffer.alloc((row+1)*height);for(let y=0;y<height;y++)pixels.copy(raw,y*(row+1)+1,y*row,(y+1)*row);return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',h),chunk('IDAT',deflateSync(raw)),chunk('IEND',Buffer.alloc(0))]);}
export async function importAssets(source,out){
 const exe=await readFile(join(source,'Growtopia.exe'));
 if(sha(exe)!=='4325fe916b7435eeb50048608869fe81b1577b8f23fe3bfdd2b1beeb0a14d29c')throw Error('Installed reference executable changed; review evidence before import');
 const stage=out+'.stage-'+randomUUID(),backup=out+'.backup-'+randomUUID();await mkdir(stage,{recursive:true});const manifest=[];
 try{
  for(const [id,path] of Object.entries(selected)){const bytes=await readFile(join(source,path));const decoded=decodeTexture(bytes);const outputBytes=png(upright(decoded));await writeFile(join(stage,id+'.png'),outputBytes);const {pixels,...dimensions}=decoded;manifest.push({id,source:path,sha256:sha(bytes),...dimensions,output_file:id+'.png',output_sha256:sha(outputBytes),transform:'vertical row reversal: bottom-up RTTEX to top-down PNG',evidence:'recovered-bytes; orientation confirmed by title text and themed background; frame interpretation separately provisional'});}
  for(const [id,path] of Object.entries({material_wood_damage:'audio/wood_damage.wav',material_wood_break:'audio/wood_break.wav',material_punch_glass:'audio/punch_glass.wav',material_metal_hit:'audio/metal_hit.wav',material_punch_miss:'audio/punch_miss.wav',material_punch_locked:'audio/punch_locked.wav',font:'GameData/UI/Font/Century-Gothic-Bold.ttf',click_sound:'audio/click.wav',jump_sound:'audio/jump.wav',punch_sound:'audio/punch.wav',place_sound:'audio/tile_created.wav',break_sound:'audio/tile_removed.wav'})){const bytes=await readFile(join(source,path));const ext=path.endsWith('.ttf')?'ttf':'wav';await writeFile(join(stage,id+'.'+ext),bytes);manifest.push({id,source:path,sha256:sha(bytes),output_file:id+'.'+ext,output_sha256:sha(bytes),evidence:'recovered-bytes; event mapping provisional'});}
  await writeFile(join(stage,'manifest.json'),JSON.stringify(manifest,null,2));
  let existed=false;try{await stat(out);existed=true;}catch{}
  if(existed)await rename(out,backup);
  try{await rename(stage,out);}catch(e){if(existed)await rename(backup,out);throw e;}
  if(existed)await rm(backup,{recursive:true});
  return manifest;
 }catch(e){await rm(stage,{recursive:true,force:true});throw e;}
}
export async function validateActiveAssets(source,out){
 const entries=JSON.parse(await readFile(join(out,'manifest.json'),'utf8'));const failures=[];
 for(const entry of entries){try{if(!entry.output_sha256||sha(await readFile(join(source,entry.source)))!==entry.sha256||sha(await readFile(join(out,entry.output_file)))!==entry.output_sha256)failures.push(entry.id);}catch{failures.push(entry.id);}}
 return {ok:failures.length===0,checked:entries.length,failures};
}
export async function syncAssets(source,out){
 // Decode into a disposable workspace before touching the active asset set.
 const stage=out+'.verify-'+randomUUID();
 try {
  const manifest=await importAssets(source,stage);
  const changed=[];
  for(const entry of manifest){
   let current;try{current=sha(await readFile(join(out,entry.output_file)));}catch{}
   if(current!==entry.output_sha256)changed.push(entry);
  }
  await mkdir(out,{recursive:true});
  const backups=new Map();
  try {
   for(const entry of changed){
    const path=join(out,entry.output_file);
    try{backups.set(path,await readFile(path));}catch{backups.set(path,null);}
    await writeFile(path,await readFile(join(stage,entry.output_file)));
   }
   const pending=join(out,'manifest.pending.json');
   await writeFile(pending,JSON.stringify(manifest,null,2));
   await rename(pending,join(out,'manifest.json'));
  }catch(error){
   for(const [path,bytes] of backups){if(bytes===null)await rm(path,{force:true});else await writeFile(path,bytes);}
   throw error;
  }
  return {checked:manifest.length,changed:changed.map(x=>x.id),unchanged:manifest.length-changed.length};
 }finally{await rm(stage,{recursive:true,force:true});}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(resolve(process.argv[1])).href){
 const source=process.argv[process.argv.indexOf('--source')+1],out=process.argv[process.argv.indexOf('--out')+1];
 if(!process.argv.includes('--source')||!process.argv.includes('--out'))throw Error('Use --source <install> --out <project assets/reference>');
 if(process.argv.includes('--sync'))console.log(JSON.stringify(await syncAssets(source,resolve(out))));
 else {const manifest=await importAssets(source,resolve(out));console.log('Verified assets imported:',manifest.length);}
}







