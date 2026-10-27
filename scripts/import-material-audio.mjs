import {readFile,writeFile,copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root='C:/Users/user/AppData/Local/Growtopia/';
const manifest=JSON.parse(await readFile('assets/reference/manifest.json'));
for(const name of ['glass_hit','rock_hit','rock_destroy','metal_destroy','punch_organic']){
 const source=`audio/${name}.wav`,output_file=`material_${name}.wav`,bytes=await readFile(root+source);
 const sha256=createHash('sha256').update(bytes).digest('hex');
 await copyFile(root+source,`assets/reference/${output_file}`);
 const entry={id:`material_${name}`,source,sha256,output_file,output_sha256:sha256,transform:'none; byte-for-byte WAV copy',evidence:'Local original recording; material routing is a native adaptation of simulator hs metadata.'};
 const index=manifest.findIndex(x=>x.id===entry.id||x.id===`${name}_sound`);if(index<0)manifest.push(entry);else manifest[index]=entry;
}
await writeFile('assets/reference/manifest.json',JSON.stringify(manifest,null,2));
console.log('Five original material recordings copied and hashed.');
