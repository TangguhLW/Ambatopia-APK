import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const use=JSON.parse(await readFile('data/simulator/use.json'));
const extra=JSON.parse(await readFile('data/simulator/extra.json'));
const paths=new Set();
paths.add('audio/change_clothes.wav');
function visit(value){if(typeof value==='string'&&/^audio\/[\w/.-]+\.(mp3|ogg|wav)$/.test(value))paths.add(value);else if(value&&typeof value==='object')Object.values(value).forEach(visit);}
visit(use.music);visit(extra.sfx);
for(const row of Object.values(extra.sfx))if(['sfx_fg','sfx_bg'].includes(row.kind)&&typeof row.sound==='string'&&/^[\w/]+\.wav$/.test(row.sound))paths.add('audio/'+row.sound);
const entries={},chunks=[];let offset=0;
for(const path of [...paths].sort()){
 let actual=path,raw;
 try{raw=await readFile('C:/Users/user/AppData/Local/Growtopia/'+actual)}catch(error){
  if(error.code!=='ENOENT')throw error;
  actual=path.replace(/^audio\/mp3\//,'audio/ogg/').replace(/\.mp3$/,'.ogg');
  try{raw=await readFile('C:/Users/user/AppData/Local/Growtopia/'+actual)}catch(missing){if(missing.code!=='ENOENT')throw missing;entries[path]={source:actual,missing:true};continue;}
 }
 const format=raw.toString('ascii',0,4)==='OggS'?'ogg':raw.toString('ascii',0,4)==='RIFF'&&raw.toString('ascii',8,12)==='WAVE'?'wav':actual.endsWith('.mp3')?'mp3':null;
 if(!format)throw Error('Unrecognized audio format: '+actual);
 entries[path]={source:actual,format,offset,bytes:raw.length,sha256:createHash('sha256').update(raw).digest('hex'),mapping:actual===path?'Exact source path':'Same basename local OGG; encoding differs from simulator MP3'};
 chunks.push(raw);offset+=raw.length;
}
await writeFile('assets/web-wardrobe/machine-audio.bin',Buffer.concat(chunks));
await writeFile('data/machine-audio-index.json',JSON.stringify({music:use.music,sfx:extra.sfx,entries},null,2));
console.log({available:Object.values(entries).filter(x=>!x.missing).length,missing:Object.keys(entries).filter(k=>entries[k].missing),bytes:offset});
