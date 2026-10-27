import {readFile,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import vm from 'node:vm';
const require=createRequire(process.cwd()+'/../growtopia-local/package.json');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const source=await readFile('research/web-wardrobe/set.readable.js','utf8'),tree=parser.parse(source);
const names=['_0x22c24f','_0x50c777','_0x1a7cc6','_0x24449f','_0x591be8','_0xc879b0'];
const functions={};let helpers,fly,flyHelpers;
traverse(tree,{FunctionDeclaration(p){
 if(names.includes(p.node.id.name)){
  functions[p.node.id.name]=source.slice(p.node.start,p.node.end);
  if(p.node.id.name==='_0x22c24f'){const b=p.scope.getBinding('_0x41aa06');helpers=source.slice(b.path.node.init.start,b.path.node.init.end);}
 }
 if(p.node.id.name==='_0x47db38'){
  fly=source.slice(p.node.start,p.node.end);
  const b=p.scope.getBinding('_0x534488');flyHelpers=source.slice(b.path.node.init.start,b.path.node.init.end);
 }
}});
const context=vm.createContext({}, {codeGeneration:{strings:false,wasm:false}});
new vm.Script(`const _0x41aa06=${helpers};const _0x2eb58e=[48,16],_0x2a3ff6=[80,16];${Object.values(functions).join('\n')}`).runInContext(context,{timeout:1000});
const punches=JSON.parse(await readFile('data/punch-tracks.json'));
const fixtures=[];
for(const [id,profile] of Object.entries(punches.punches))for(let index=0;index<(profile.P||[]).length;index++){
 const particle=profile.P[index];if(!['pet','mid'].includes(particle.an))continue;
 for(const delta of [[-24,12],[18,-30]]){
  context.particle=particle;context.target=[48,-32];context.aim=profile.aim?.R||{};context.delta=delta;
  const result=new vm.Script('_0x22c24f(particle,target,_0x50c777(particle,aim),delta)').runInContext(context,{timeout:1000});
  if(result)fixtures.push({id,index,target:context.target,delta,result});
 }
}
// Execute only the isolated source follow helper, with midpoint random samples.
new vm.Script(`const _0x534488=${flyHelpers};let _0x1ea1a4;const _0x2cb0bb=(a,b)=>(a+b)/2;const _0x441296=(x,t,d)=>x<t?Math.min(t,x+d):Math.max(t,x-d);${fly}`).runInContext(context,{timeout:1000});
const flying=[];
for(const start of [[-60,-50,0,0],[50,40,-90,60],[400,100,0,0],[-20,-10,100,90]]){
 context.start=start;context.player={x:0,y:0,vx:0,vy:0};
 const result=new vm.Script(`_0x1ea1a4={x:start[0],y:start[1],vx:start[2],vy:start[3],tc:0,face:0};_0x47db38(player,1/60);({..._0x1ea1a4})`).runInContext(context,{timeout:1000});
 flying.push({start,result});
}
await writeFile('evidence/pet-source-fixtures.json',JSON.stringify({reference:'Isolated original simulator functions, midpoint random stream, 60 Hz',fixtures,flying}));
console.log({anchors:fixtures.length,flying:flying.length});
