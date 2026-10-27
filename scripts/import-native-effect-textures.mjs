import {readFile, writeFile, mkdir} from 'node:fs/promises';
import {basename} from 'node:path';
import {createHash} from 'node:crypto';
import {decodeTexture, upright, png} from './import-assets.mjs';
const files=JSON.parse(await readFile('research/special-rules/renderer-textures.json','utf8'));
await mkdir('assets/native-effects',{recursive:true});
const evidence=[];
for(const file of files){
 if(!/^game\/[a-z0-9_]+\.rttex$/i.test(file))throw Error('Unexpected renderer texture path');
 const bytes=await readFile('C:/Users/user/AppData/Local/Growtopia/'+file);
 const image=upright(decodeTexture(bytes)),output=png(image);
 const destination='assets/native-effects/'+basename(file,'.rttex')+'.png';
 await writeFile(destination,output);
 evidence.push({source:file,sha256:createHash('sha256').update(bytes).digest('hex'),destination,output_sha256:createHash('sha256').update(output).digest('hex'),width:image.width,height:image.height});
}
await writeFile('evidence/special-rules/native-texture-provenance.json',JSON.stringify(evidence,null,2));
console.log('Imported native effect sheets:',evidence.length);
