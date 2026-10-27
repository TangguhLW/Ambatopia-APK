import {readFile,writeFile,readdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const hash=b=>createHash('sha256').update(b).digest('hex');
async function files(folder){const result=[];for(const entry of await readdir(folder,{withFileTypes:true})){const path=folder+'/'+entry.name;if(entry.isDirectory())result.push(...await files(path));else if(path.endsWith('.gd'))result.push(path)}return result}
const selected=[...await files('src'),'project.godot','assets/reference/manifest.json','data/catalog-index.json','data/local-sprite-overrides.json','data/network.json','data/web-wardrobe-index.json','assets/web-wardrobe/atlas.bin','assets/web-wardrobe/records.bin','assets/web-wardrobe/particles.bin','data/wardrobe-particles.json','assets/ambatopia/main-theme.mp3'];
selected.push('data/additional-effects-index.json','data/source-particle-programs.json','data/punch-tracks.json','data/pet-tracks.json','assets/web-wardrobe/additional-effects.bin');
selected.push('data/death-tracks.json','data/source-movement-rules.json');
selected.push('data/punch-audio-index.json','assets/web-wardrobe/punch-audio.bin');
selected.push('data/inventory-icons.json','assets/inventory/icons.bin');
selected.push('data/machine-audio-index.json','assets/web-wardrobe/machine-audio.bin','data/blast-templates.json');
selected.push("data/machine-recovered-029.json","data/native-weather-029.json");
selected.push('data/chest-rewards-030.json');
selected.push('data/clothing-mods-032.json');
for(const file of await readdir("assets/machines-weather"))if(file.endsWith(".png"))selected.push("assets/machines-weather/"+file);
const hashes={};for(const path of selected.sort())hashes[path]=hash(await readFile(path));
const source_revision=hash(Buffer.from(JSON.stringify(hashes)));
await writeFile('data/build-info.json',JSON.stringify({version:'0.34.1-ambatopia-native',engine:'Godot 4.7.2',renderer:'gl_compatibility',source_revision,hashes},null,2));
console.log('Build source revision:',source_revision);
