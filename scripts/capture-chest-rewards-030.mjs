import {readFile,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import vm from 'node:vm';
const require=createRequire(process.cwd()+'/../growtopia-local/package.json');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const source=await readFile('research/machines-029/edit.readable.js','utf8');
const ast=parser.parse(source);let scope;
traverse(ast,{VariableDeclarator(path){if(path.node.id.name==='_0x16ffdb')scope=path.scope;}});
if(!scope)throw Error('Original chest handler not found');
const dependencies=['_0x45ff1d','_0x29569f','_0x16f66e','_0x8b1e50','_0x3ed370','_0x484663','_0x16ffdb'];
const isolated=dependencies.map(name=>{const n=scope.getBinding(name).path.node.init;return 'const '+name+'='+source.slice(n.start,n.end)+';';}).join('\n')+'\nglobalThis.chest=_0x16ffdb;globalThis.common=_0x29569f;globalThis.rare=_0x16f66e;';
await writeFile('research/machines-030/isolated-chest-handler.js',isolated);
let queue=[],output=[];
const math=Object.create(Math);math.random=()=>{if(!queue.length)throw Error('Unexpected random draw');return queue.shift();};
const context=vm.createContext({Math:math,Set,_0x197a23:(id,amount)=>output.push([id,amount])});
vm.runInContext(isolated,context,{timeout:3000});
const fixtures=[];
for(const id of [392,3402,9350])for(const rare of [0,1/800-1e-9,1/800,1/350-1e-9,1/350,0.5,0.999999])for(const override of [0,1/5000-1e-9,1/5000,0.5])for(const pick of [0,0.1,0.25,0.5,0.75,0.999999]){
 const random=[rare,override,pick];queue=random.slice();output=[];
 context.chest({id,i:0});
 if(output.length!==1||queue.length!==0)throw Error('Unexpected source chest output');
 const random_hex=random.map(value=>{const bytes=Buffer.alloc(8);bytes.writeDoubleLE(value);return bytes.toString('hex');});
 fixtures.push({id,random,random_hex,expected:output[0]});
}
await writeFile('research/machines-030/chest-fixtures.json',JSON.stringify({samples:fixtures},null,2));
const data={source:'https://growtopiasimulator.com/edit/wp.app.js?v=dad4259b31',authority:'Simulator replay; original production server odds are not established',common:[...context.common],rare:[...context.rare],super_add:[13124,13116,13126,13128,13114],override:[11702,362],rare_denominator:{392:800,3402:800,9350:350},override_denominator:5000,amount5:[11694,11696,7810,7808,4400,390,3408,4422,3404],amount2:[4418,5660]};
await writeFile('data/chest-rewards-030.json',JSON.stringify(data,null,2));
console.log({samples:fixtures.length,common:data.common.length,rare:data.rare.length});
