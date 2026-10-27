import {readFile,readdir,rm,realpath} from 'node:fs/promises';
import {resolve,join,basename,dirname} from 'node:path';
const index=JSON.parse(await readFile('data/catalog-index.json'));
const manifest=JSON.parse(await readFile(index.details+'/asset-manifest.json'));
const keep=new Set(manifest.map(i=>basename(i.path)));
const root=await realpath('assets/catalog');
if(root!==resolve(process.cwd(),'assets/catalog'))throw Error('Managed asset folder must stay within project');
let removed=0;
for(const file of await readdir(root,{withFileTypes:true})){
 if(!file.isFile()||!/^\w{24}\.png(?:\.import)?$/.test(file.name)||keep.has(file.name.replace(/\.import$/,'')))continue;
 const path=join(root,file.name);
 if(dirname(path)!==root)throw Error('Asset cleanup path escaped');
 await rm(path);removed++;
}
console.log('Unused generated catalog files removed:',removed);
