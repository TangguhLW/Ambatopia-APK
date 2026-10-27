import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
import vm from 'node:vm';
const require=createRequire(process.cwd()+'/../growtopia-local/package.json');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const dir='research/machines-030';await mkdir(dir,{recursive:true});
const response=await fetch('https://growtopiasimulator.com/edit/');
if(!response.ok)throw Error('Public editor unavailable: '+response.status);
const html=await response.text();await writeFile(dir+'/edit.html',html);
const scriptPath=html.match(/src=["']([^"']*wp\.app\.js[^"']*)["']/)?.[1];
if(!scriptPath)throw Error('Editor entry point not found');
const scriptURL=new URL(scriptPath,'https://growtopiasimulator.com/edit/').href;
const scriptResponse=await fetch(scriptURL);if(!scriptResponse.ok)throw Error('Public script unavailable');
const shipped=Buffer.from(await scriptResponse.arrayBuffer());
const previous=await readFile('research/machines-029/wp.app.js');
const hash=b=>createHash('sha256').update(b).digest('hex');
await writeFile(dir+'/source-check.json',JSON.stringify({time:new Date().toISOString(),scriptURL,sha256:hash(shipped),matchesPrevious:hash(shipped)===hash(previous)},null,2));
if(hash(shipped)!==hash(previous))throw Error('Editor changed; decode the new version before extraction');
const source=await readFile('research/machines-029/edit.readable.js','utf8');
const ast=parser.parse(source);let frame,frames,helpers,outer;
traverse(ast,{
 FunctionDeclaration(path){if(path.node.id.name==='_0xb58b9f')frames=source.slice(path.node.start,path.node.end);},
 FunctionExpression(path){
  if(path.node.params[0]?.name!=='_0x26af42')return;
  frame=source.slice(path.node.start,path.node.end);
  helpers=path.scope.getBinding('_0x488416').path.node.init;
  outer=path.scope.getBinding('_0x502d6b').path.node.init;
 }
});
if(!frame||!frames||!helpers||!outer)throw Error('Original selector not found');
const isolated=`const _0x502d6b=${source.slice(outer.start,outer.end)};const _0x488416=${source.slice(helpers.start,helpers.end)};const _0x41070e=32;const _0x9a3c16=new Set([3,4,7,8,9,10]);${frames};globalThis.select=${frame};`;
await writeFile(dir+'/isolated-tile-selector.js',isolated);
let clock=0;
const context=vm.createContext({Date:{now:()=>clock},Math,Set});
vm.runInContext(isolated,context,{timeout:3000});
const rows=JSON.parse(await readFile('data/simulator/items.json'));
const samples=[],errors=[];
for(const [id,row] of Object.entries(rows)){
 if(![12,31,122,45,41,81,89,134].includes(row[7]))continue;
 const item={id:+id,act:row[7],spread:row[4],kind:row[13]||0,fr:row[14]||null,av:row[16]||0,val2:row[17]||0,fr2:row[18]||null};
 const png=await readFile('assets/simulator/atlas/'+row[1]+'.png');
 const width=png.readUInt32BE(16);
 for(const enabled of [false,true])for(const ms of [0,39,40,99,100,199,200,299,300,399,400,599,600,799,800,1000,3000]){
  clock=ms;context._0x3b64c7={W:{fl:[enabled?64:0],meta:{weather:enabled?row[16]:4},w:100},live:false};
  try{const result=context.select(item,'fg',0,[row[2],row[3]],{width});samples.push({id:+id,enabled,ms,columns:width/32,expected:[...result]});}
  catch(error){errors.push({id:+id,error:String(error)});break;}
 }
}
await writeFile(dir+'/tile-selector-fixtures.json',JSON.stringify({source:scriptURL,sha256:hash(shipped),samples,errors},null,2));
console.log({samples:samples.length,errors});
