import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {decodeTexture,upright,png} from './import-assets.mjs';
const root='C:/Users/user/AppData/Local/Growtopia';
const out='research/guild-starship-031';
const hash=bytes=>createHash('sha256').update(bytes).digest('hex');
const files=[];
for(const name of ['gd_page1','gd_page2','gd_page3']){
 const source=`${root}/game/${name}.rttex`;
 const bytes=await readFile(source),image=decodeTexture(bytes);
 const converted=await readFile(`${out}/${name}.png`);
 if(hash(png(upright(image)))!==hash(converted))throw Error('Research conversion mismatch: '+name);
 files.push({source,source_sha256:hash(bytes),source_format:'RTPACK/RTTXTR RGBA8',width:image.width,height:image.height,output:`${out}/${name}.png`,output_sha256:hash(converted),transform:'Vertical row reversal to upright RGBA PNG; no resampling',usage:'Visually inspected guild/item atlas research; duplicate PNG is not bundled',version:'Installed items.dat schema v27; executable SHA recorded separately'});
}
await writeFile(`${out}/local-resource-manifest.json`,JSON.stringify({files,mascot_runtime:'Existing InventoryIcons local-source texture pack; no web thumbnail replacement',qualification:'Atlas contents do not establish Starship tile layouts'},null,2));
console.log(JSON.stringify({verified:files.length}));
