import {readFile,writeFile,mkdir,copyFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const hash=b=>createHash('sha256').update(b).digest('hex');
const source='research/web-wardrobe/archive/l.json';
const bytes=await readFile(source),catalog=JSON.parse(bytes);
const manifest=JSON.parse(await readFile('web-client/vendor-assets/manifest.json'));
const verified=new Map(manifest.files.map(x=>[x.path,x]));
const sheets={},items={},names={},renderers={},icons={},atlas=[],metadata=[];let offset=0,recordOffset=0;
await mkdir('assets/web-wardrobe',{recursive:true});
for(const item of catalog.items){
 names[item.id]=item.name;
 icons[item.id]=item.ix;
 if(item.bk&&item.L?.length)renderers[item.id]=item.ro?.k||'basic';
 if(item.bk&&!/^[a-f0-9]{12}$/.test(item.bk))throw Error('Invalid atlas key');
 if(item.bk&&!sheets[item.bk]){
  const path='/set/atlas/b/'+item.bk+'.json',raw=await readFile('web-client/vendor-assets'+path);
  if(hash(raw)!==verified.get(path)?.sha256)throw Error('Unverified wardrobe resource '+path);
  let seed=2166136261;for(const c of 'b/'+item.bk)seed=Math.imul(seed^c.charCodeAt(0),16777619);
  const decoded=Buffer.from(raw),s0=(3068517375^seed)>>>0;
  for(let i=0;i<decoded.length;i++){let x=Math.imul((i+s0)|0,0x9E3779B1)^1817450254;x^=x>>>15;x=Math.imul(x,0x85EBCA6B);x^=x>>>13;decoded[i]^=x&255;}
  if(decoded.subarray(0,8).toString('hex')!=='89504e470d0a1a0a')throw Error('Invalid PNG '+item.bk);
  sheets[item.bk]={offset,bytes:decoded.length,width:decoded.readUInt32BE(16),height:decoded.readUInt32BE(20),sha256:hash(decoded),source_sha256:hash(raw),source:path};
  offset+=decoded.length;atlas.push(decoded);
 }
 const record=Buffer.from(JSON.stringify(item));items[item.id]=[recordOffset,record.length];recordOffset+=record.length;metadata.push(record);
}
// PNGs remain lossless; a single indexed pack avoids thousands of imports at startup.
await writeFile('assets/web-wardrobe/atlas.bin',Buffer.concat(atlas));
await writeFile('assets/web-wardrobe/records.bin',Buffer.concat(metadata));
const iconPath='web-client/dist/set/atlas/ic.png',iconBytes=await readFile(iconPath);
await copyFile(iconPath,'assets/web-wardrobe/icons.png');
await writeFile('data/web-wardrobe-index.json',JSON.stringify({source,source_sha256:hash(bytes),slots:catalog.slots,items,sheets,names,renderers,icons,icon_source:iconPath,icon_sha256:hash(iconBytes)}));
console.log(JSON.stringify({items:Object.keys(items).length,atlases:atlas.length,png_bytes:offset,metadata_bytes:recordOffset}));
