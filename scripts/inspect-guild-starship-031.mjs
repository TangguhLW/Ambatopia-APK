import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import vm from 'node:vm';
const dir='research/guild-starship-031';
const hash=data=>createHash('sha256').update(data).digest('hex');
const page=await fetch('https://growtopiasimulator.com/edit/');if(!page.ok)throw Error('Editor unavailable');
const html=await page.text();await writeFile(dir+'/edit.html',html);
const entry=html.match(/src=["']([^"']*wp\.app\.js[^"']*)["']/)?.[1];if(!entry)throw Error('Editor entry not found');
const url=new URL(entry,'https://growtopiasimulator.com/edit/').href;
const response=await fetch(url);if(!response.ok)throw Error('Bundle unavailable');
const bytes=Buffer.from(await response.arrayBuffer());
const original=await readFile('research/machines-029/wp.app.js');
const sourceCheck={url,checked_at:new Date().toISOString(),sha256:hash(bytes),matches_inspected_bundle:hash(bytes)===hash(original)};
await writeFile(dir+'/source-check.json',JSON.stringify(sourceCheck,null,2));
if(!sourceCheck.matches_inspected_bundle)throw Error('Bundle changed: decode the new version before testing old functions');
const require=createRequire(process.cwd()+'/../growtopia-local/package.json');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const source=await readFile('research/machines-029/edit.readable.js','utf8');let outer,target;
traverse(parser.parse(source),{AssignmentExpression(p){
 if(p.node.left.type==='MemberExpression'&&p.node.left.object.name==='_0x5cc376'&&p.node.left.property.name==='blastWorld'){
  outer=p.getFunctionParent().node;target=p.findParent(q=>q.isIfStatement()).node;
 }
}});
if(!outer||!target)throw Error('Source blast closure not found');
const before=outer.body.body.filter(n=>n.start<target.start).map(n=>source.slice(n.start,n.end)).join('\n');
const assignment=target.test.expressions.slice(0,2).map(n=>source.slice(n.start,n.end)).join(';');
const isolated=before+'\n'+assignment;await writeFile(dir+'/isolated-blasts.js',isolated);
const context=vm.createContext({global:{GW:{}}},{codeGeneration:{strings:false,wasm:false}});
new vm.Script(await readFile('research/machines-029/decoder-only.js','utf8')).runInContext(context,{timeout:5000});
new vm.Script(isolated).runInContext(context,{timeout:5000});
const metadata=JSON.parse(await readFile('research/catalog/local-items-v27.json'));
const ships=[];
for(const id of [6420,6422,6424,6666,12048]){
 context.blast=id;
 const result=new vm.Script('global.GW.blastWorld(blast)').runInContext(context,{timeout:5000});
 const row=metadata.items[id];
 ships.push({id,name:row.name,local_texture:row.texture,local_texture_cell:[row.textureX,row.textureY],local_description:row.description,documented_variant_count:row.description.includes('one of 3')?3:null,source_generator_return:result===null?'null':result===undefined?'undefined':'world-data',layout_recovered:result!=null});
}
const report={source:sourceCheck,native_executable:{path:'C:/Users/user/AppData/Local/Growtopia/Growtopia.exe',sha256:'4325fe916b7435eeb50048608869fe81b1577b8f23fe3bfdd2b1beeb0a14d29c',rea_observed_format:'pe',rea_observed_architecture:'x86_64',native_decompilation:'Not established: no configured Ghidra/IDA provider; no claim of absence in native code'},ships,qualification:'Descriptions and equipment metadata establish ship classes, not tile layouts. No invented layouts are substituted.'};
await writeFile(dir+'/starship-findings.json',JSON.stringify(report,null,2));
console.log(JSON.stringify({source:sourceCheck,ships:ships.map(s=>({id:s.id,variants:s.documented_variant_count,return:s.source_generator_return}))}));
