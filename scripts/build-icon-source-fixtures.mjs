import {readFile,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import vm from 'node:vm';
const require=createRequire(process.cwd()+'/../growtopia-local/package.json');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const text=await readFile('research/web-wardrobe/set.readable.js','utf8');
let fn,helpers;
traverse(parser.parse(text),{AssignmentExpression(p){
 if(p.node.left.type==='MemberExpression'&&p.node.left.object.name==='_0x2852b4'&&p.node.left.property.name==='iconCell'){
  fn=text.slice(p.node.right.start,p.node.right.end);
  const b=p.scope.getBinding('_0x2a521f');helpers=text.slice(b.path.node.init.start,b.path.node.init.end);
 }
}});
if(!fn||!helpers)throw Error('Source iconCell not found');
const ctx=vm.createContext({},{codeGeneration:{strings:false,wasm:false}});
new vm.Script(`const _0x2a521f=${helpers};const iconCell=${fn}`).runInContext(ctx,{timeout:1000});
const items=JSON.parse(await readFile('data/simulator/items.json'));
const cells={};
for(const [id,row] of Object.entries(items)){
 ctx.item={tx:row[2],ty:row[3],spread:row[4]};
 cells[id]=new vm.Script('iconCell(item)').runInContext(ctx,{timeout:1000});
}
await writeFile('evidence/inventory-026-source-cells.json',JSON.stringify({reference:'Isolated original simulator iconCell, no app execution',cells}));
console.log({source_cells:Object.keys(cells).length});
