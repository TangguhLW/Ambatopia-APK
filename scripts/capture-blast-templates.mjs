import {readFile,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import vm from 'node:vm';
const require=createRequire(process.cwd()+'/../growtopia-local/package.json');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const source=await readFile('research/web-wardrobe/set.readable.js','utf8');
let outer,target;
traverse(parser.parse(source),{AssignmentExpression(p){
 if(p.node.left.type==='MemberExpression'&&p.node.left.object.name==='_0x9f4901'&&p.node.left.property.name==='blastWorld'){
  outer=p.getFunctionParent().node;target=p.findParent(q=>q.isIfStatement()).node;
 }
}});
if(!outer||!target)throw Error('Blast generator closure not found');
const before=outer.body.body.filter(n=>n.start<target.start).map(n=>source.slice(n.start,n.end)).join('\n');
const assignment=target.test.expressions.slice(0,2).map(n=>source.slice(n.start,n.end)).join(';');
const context=vm.createContext({global:{GW:{}}},{codeGeneration:{strings:false,wasm:false}});
new vm.Script(await readFile('research/web-wardrobe/set-decoder-only.js','utf8')).runInContext(context,{timeout:5000});
new vm.Script(before+'\n'+assignment).runInContext(context,{timeout:5000});
const extra=JSON.parse(await readFile('data/simulator/extra.json'));
const templates={},unavailable={};
for(const [id,rule] of Object.entries(extra.consumable)){
 if(rule.kind!=='world_blast')continue;
 templates[id]=[];
 for(let variant=0;variant<4;variant++){
  context.seed=(Number(id)*2654435761+variant+1)>>>0;
  new vm.Script('Math.random=()=>{seed^=seed<<13;seed^=seed>>>17;seed^=seed<<5;return (seed>>>0)/4294967296}').runInContext(context);
  context.blast=Number(id);
  const world=new vm.Script('global.GW.blastWorld(blast)').runInContext(context,{timeout:5000});
  if(!world){unavailable[id]=rule.name+': no generator in inspected simulator';delete templates[id];break;}
  templates[id].push(world);
 }
 console.log(id,rule.name,templates[id]?.[0]?.spawn,templates[id]?.[0]?.weather);
}
await writeFile('data/blast-templates.json',JSON.stringify({reference:'Original isolated simulator blastWorld; four seeded source-generated variants per blast',templates,unavailable}));
