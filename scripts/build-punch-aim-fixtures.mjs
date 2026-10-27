import {readFile,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import vm from 'node:vm';
const require=createRequire(process.cwd()+'/../growtopia-local/package.json');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const source=await readFile('research/web-wardrobe/set.readable.js','utf8'),tree=parser.parse(source);
const names=['_0x22c24f','_0x50c777','_0x1a7cc6','_0x24449f','_0x591be8','_0xc879b0'];
const functions={};let helpers;
traverse(tree,{FunctionDeclaration(p){if(names.includes(p.node.id.name)){functions[p.node.id.name]=source.slice(p.node.start,p.node.end);if(p.node.id.name==='_0x22c24f'){const binding=p.scope.getBinding('_0x41aa06');helpers=source.slice(binding.path.node.init.start,binding.path.node.init.end);}}}});
if(Object.keys(functions).length!==names.length||!helpers)throw Error('Source function inventory changed');
const context=vm.createContext({}, {codeGeneration:{strings:false,wasm:false}});
new vm.Script(`const _0x41aa06=${helpers};const _0x2eb58e=[48,16],_0x2a3ff6=[80,16];${Object.values(functions).join('\n')}`).runInContext(context,{timeout:1000});
const punches=JSON.parse(await readFile('data/punch-tracks.json'));
const fixtures=[],rejected=[];let supported=0,declined=0;
for(const [id,profile] of Object.entries(punches.punches))for(let index=0;index<(profile.P||[]).length;index++){
 const particle=profile.P[index];
 for(const target of [[48,16],[80,16],[48,-32],[30,58]]){
  context.particle=particle;context.target=target;context.aim=profile.aim?.R||{};
  const result=new vm.Script('_0x22c24f(particle,target,_0x50c777(particle,aim),null)').runInContext(context,{timeout:1000});
  if(result){supported++;fixtures.push({id,index,target,result});}else{declined++;rejected.push({id,index,target});}
 }
}
await writeFile('evidence/punch-aim-source-fixtures.json',JSON.stringify({reference:'Original simulator functions _22c24f and _50c777; no app execution or network access',supported,declined,fixtures,rejected}));
console.log({supported,declined});
