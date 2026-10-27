import {readFile,writeFile} from 'node:fs/promises';
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
const require=createRequire(process.cwd()+'/../growtopia-local/package.json');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const bytes=await readFile('research/web-wardrobe/set.readable.js'),ast=parser.parse(bytes.toString());
const registry=new Map();
traverse(ast,{VariableDeclarator(p){if(p.node.id.name==='_0x2eaab1'&&p.get('init').isObjectExpression())for(const prop of p.get('init.properties'))registry.set(String(prop.node.key.value??prop.node.key.name),prop.get('value'));},AssignmentExpression(p){const l=p.node.left;if(l.type==='MemberExpression'&&l.object.name==='_0x2eaab1'&&l.property.type==='NumericLiteral'){let v=p.get('right');while(v.isAssignmentExpression())v=v.get('right');registry.set(String(l.property.value),v);}}});
const constant=x=>Array.isArray(x)&&x[0]==='c';
function literal(e){
 if(constant(e))return {known:true,value:e[1]};
 if(!Array.isArray(e)||e[0]!=='op')return {known:false};
 const a=literal(e[2]),b=literal(e[3]);if(!a.known||!b.known)return {known:false};
 const ops={'===':(a,b)=>a===b,'!==':(a,b)=>a!==b,'==':(a,b)=>a==b,'!=':(a,b)=>a!=b,'+':(a,b)=>a+b,'-':(a,b)=>a-b,'*':(a,b)=>a*b,'<':(a,b)=>a<b,'>':(a,b)=>a>b,'<=':(a,b)=>a<=b,'>=':(a,b)=>a>=b};
 return ops[e[1]]?{known:true,value:ops[e[1]](a.value,b.value)}:{known:false};
}
function objectFor(p,depth=0){
 if(!p?.node||depth>12)return null;
 if(p.isObjectExpression())return p;
 if(p.isMemberExpression()&&p.node.object.name==='_0x2eaab1')return objectFor(registry.get(String(p.node.property.value)),depth+1);
 if(p.isIdentifier()){
  const binding=p.scope.getBinding(p.node.name);
  if(binding?.path.isVariableDeclarator())return objectFor(binding.path.get('init'),depth+1);
 }
 return null;
}
function propertyFor(p,key,depth=0){
 if(!p?.node||depth>12)return null;
 const object=objectFor(p);
 const direct=object?.get('properties').find(x=>x.node.key&&(x.node.key.name??x.node.key.value)===key);
 if(direct)return direct.get('value');
 for(const spread of object?.get('properties')||[])if(spread.isSpreadElement()){const inherited=propertyFor(spread.get('argument'),key,depth+1);if(inherited)return inherited;}
 if(p.isIdentifier()){
  const binding=p.scope.getBinding(p.node.name);
  for(const ref of binding?.referencePaths||[]){
   const member=ref.parentPath,assignment=member.parentPath;
   if(member.isMemberExpression()&&(member.node.property.name??member.node.property.value)===key&&assignment.isAssignmentExpression()&&assignment.get('left')===member)return assignment.get('right');
  }
  if(binding?.path.isVariableDeclarator()&&binding.path.get('init').isIdentifier())return propertyFor(binding.path.get('init'),key,depth+1);
 }
 return null;
}
function fnFor(path,depth=0){
 if(depth>14)return null;
 if(path.isFunction())return path;
 if(path.isIdentifier()){
  const b=path.scope.getBinding(path.node.name);if(!b)return null;
  return b.path.isFunction()?b.path:b.path.isVariableDeclarator()?fnFor(b.path.get('init'),depth+1):null;
 }
 if(path.isMemberExpression()){
  const key=path.node.computed?path.node.property.value:path.node.property.name;
  const prop=propertyFor(path.get('object'),key);
  return prop?fnFor(prop,depth+1):null;
 }
 return null;
}
function exp(p,env={},depth=0){
 if(depth>32)throw Error('expression depth');
 const n=p.node;if(!n)return ['c',0];
 if(p.isNumericLiteral()||p.isStringLiteral()||p.isBooleanLiteral())return ['c',n.value];
 if(p.isNullLiteral())return ['c',0];
 if(p.isIdentifier()){
  if(n.name in env)return env[n.name];
  if(n.name==='undefined')return ['c',0];
  if(n.name==='_0x277894')return {_rand:true};
  const f=fnFor(p);if(f)return {_fn:f};
  const b=p.scope.getBinding(n.name);
  if(b?.path.isVariableDeclarator()&&b.path.node.init&&b.constant)return exp(b.path.get('init'),env,depth+1);
  throw Error('identifier '+n.name);
 }
 if(p.isMemberExpression()){
  const obj=p.get('object'),key=n.computed?n.property.value:n.property.name;
  if(obj.isIdentifier()&&env[obj.node.name]?.[0]==='particle')return ['field',String(key)];
  if(obj.isIdentifier({name:'_0x551020'})&&key==='own')return ['field','owner'];
  if(obj.isIdentifier({name:'Math'})&&key==='PI')return ['c',Math.PI];
  const prop=propertyFor(obj,key);
  if(prop)return exp(prop,env,depth+1);
  if(n.computed||obj.isIdentifier()&&env[obj.node.name]||obj.isMemberExpression()&&obj.node.object.name==='_0x551020')return ['get',exp(obj,env,depth+1),n.computed?exp(p.get('property'),env,depth+1):['c',String(key)]];
  throw Error('member '+String(key));
 }
 if(p.isUnaryExpression())return ['unary',n.operator,exp(p.get('argument'),env,depth+1)];
 if(p.isAssignmentExpression()){
  const left=exp(p.get('left'),env);if(!['field','local'].includes(left[0]))throw Error('assignment expression target');
  const value=exp(p.get('right'),env);return ['assign',left[0],left[1],n.operator==='='?value:['op',n.operator.slice(0,-1),left,value]];
 }
 if(p.isSequenceExpression())return ['seq',...p.get('expressions').map(x=>exp(x,env,depth+1))];
 if(p.isBinaryExpression()||p.isLogicalExpression())return ['op',n.operator,exp(p.get('left'),env,depth+1),exp(p.get('right'),env,depth+1)];
 if(p.isConditionalExpression()){
  const test=exp(p.get('test'),env,depth+1),known=literal(test);
  return known.known?exp(p.get(known.value?'consequent':'alternate'),env,depth+1):['choose',test,exp(p.get('consequent'),env,depth+1),exp(p.get('alternate'),env,depth+1)];
 }
 if(p.isArrayExpression())return ['array',...p.get('elements').map(x=>exp(x,env,depth+1))];
 if(p.isObjectExpression())return ['object',...p.get('properties').map(x=>[String(x.node.key.name??x.node.key.value),exp(x.get('value'),env,depth+1)])];
 if(p.isCallExpression()){
  const mapped=p.get('callee');
  if(mapped.isMemberExpression()&&mapped.node.property.name==='map'&&p.get('arguments.0').isFunction()){
   const callback=p.get('arguments.0'),next={...env};next[callback.node.params[0].name]=['local','__mapped_value'];
   return ['map',exp(mapped.get('object'),env,depth+1),exp(callback.get('body'),next,depth+1)];
  }
  const args=p.get('arguments').map(x=>exp(x,env,depth+1));
  const callee=p.get('callee');
  if(callee.isMemberExpression()&&callee.get('object').isIdentifier({name:'Math'}))return ['math',callee.node.property.name??callee.node.property.value,...args];
  if(callee.isMemberExpression()&&callee.get('object').isIdentifier({name:'performance'})&&callee.node.property.name==='now')return ['field','clock_ms'];
  if(callee.isIdentifier({name:'_0x277894'}))return ['random_range',...args];
  if(callee.isIdentifier()&&env[callee.node.name]?._rand)return ['random_range',...args];
  if(callee.isIdentifier()&&env[callee.node.name]?.[0]==='function')throw Error('dynamic callback');
  const f=callee.isIdentifier()&&env[callee.node.name]?._fn||fnFor(callee);
  if(!f)throw Error('call '+(callee.node.name??callee.node.property?.name));
  const next={...env};f.node.params.forEach((x,i)=>next[x.name]=args[i]??['c',0]);
  const body=f.get('body');
  if(!body.isBlockStatement())return exp(body,next,depth+1);
  const helperRows=body.get('body').filter(x=>!x.isFunctionDeclaration());
  if(helperRows.length===1&&helperRows[0].isReturnStatement())return exp(helperRows[0].get('argument'),next,depth+1);
  return ['invoke',rows(body.get('body'),next)];
 }
 throw Error('expression '+n.type);
}
function rows(paths,env){
 const out=[];
 for(const p of paths){
  if(p.isFunctionDeclaration()||p.isEmptyStatement())continue;
  if(p.isBlockStatement()){out.push(...rows(p.get('body'),env));continue;}
  if(p.isVariableDeclaration()){
   for(const d of p.get('declarations')){if(objectFor(d.get('init'))||d.get('init').isFunction())continue;const key=d.node.id.name;out.push(['local',key,exp(d.get('init'),env)]);env[key]=['local',key];}continue;
  }
  if(p.isReturnStatement()){out.push(['return',p.node.argument?exp(p.get('argument'),env):['c',0]]);continue;}
  if(p.isIfStatement()){
   const branch=k=>{const b=p.get(k);return b?.node?rows(b.isBlockStatement()?b.get('body'):[b],{...env}):[];};
   const test=exp(p.get('test'),env),known=literal(test);
   if(known.known)out.push(...branch(known.value?'consequent':'alternate'));
   else out.push(['if',test,branch('consequent'),branch('alternate')]);continue;
  }
  if(p.isExpressionStatement()){out.push(...statement(p.get('expression'),env));continue;}
  throw Error('statement '+p.node.type);
 }
 return out;
}
let inlineDepth=0;
function statement(p,env){
 if(p.isSequenceExpression())return p.get('expressions').flatMap(x=>statement(x,env));
 if(p.isLogicalExpression())return [['if',exp(p.get('left'),env),p.node.operator==='&&'?statement(p.get('right'),env):[],p.node.operator==='||'?statement(p.get('right'),env):[]]];
 if(p.isConditionalExpression()){
  const test=exp(p.get('test'),env),known=literal(test);
  return known.known?statement(p.get(known.value?'consequent':'alternate'),env):[['if',test,statement(p.get('consequent'),env),statement(p.get('alternate'),env)]];
 }
 if(p.isAssignmentExpression()){
  if(p.get('left').isMemberExpression()&&objectFor(p.get('left.object'))&&!env[p.node.left.object.name])return [];
  if(p.get('right').isFunction()&&p.get('left').isMemberExpression()&&objectFor(p.get('left.object')))return [];
  const left=exp(p.get('left'),env);if(!['field','local'].includes(left[0]))throw Error('assignment target');
  let value=exp(p.get('right'),env);if(p.node.operator!=='=')value=['op',p.node.operator.slice(0,-1),left,value];
  return [[left[0]==='field'?'set':'local',left[1],value]];
 }
 if(p.isCallExpression()){
  const f=fnFor(p.get('callee'));
  if(!f||inlineDepth>=12)throw Error('unresolved side effect call');
  const args=p.get('arguments').map(x=>exp(x,env));
  const next={...env};f.node.params.forEach((x,i)=>next[x.name]=args[i]??['c',0]);
  inlineDepth++;
  try{
   const body=f.get('body');
   return [['call',body.isBlockStatement()?rows(body.get('body'),next):[['return',exp(body,next)]]]];
  }finally{inlineDepth--;}
 }
 throw Error('expression statement '+p.node.type);
}
function compile(f){
 if(!f.isFunction()){const resolved=fnFor(f);return resolved?compile(resolved):[['return',exp(f)]];}
 const env={};f.node.params.forEach((p,i)=>env[p.name]=i===0?['particle']:['dt']);
 const body=f.get('body');return body.isBlockStatement()?rows(body.get('body'),env):[['return',exp(body,env)]];
}
const programs={},unsupported={},aliases={},parents={};
traverse(ast,{AssignmentExpression(p){
 const left=p.node.left;if(left.type!=='MemberExpression'||left.object.name!=='_0x2eaab1'||left.property.type!=='NumericLiteral')return;
 let value=p.get('right');while(value.isAssignmentExpression())value=value.get('right');
 if(value.isMemberExpression()&&value.node.object.name==='_0x2eaab1'){aliases[left.property.value]=value.node.property.value;return;}
 if(!value.isObjectExpression())return;
 const id=String(left.property.value);
 try{
  const program={source_line:p.node.loc.start.line};
  function properties(value,depth=0){if(depth>12)throw Error('spread depth');return value.get('properties').flatMap(p=>{if(!p.isSpreadElement())return [p];const object=objectFor(p.get('argument'));if(!object)throw Error('unresolved spread');return properties(object,depth+1);});}
  for(const prop of properties(value)){
   const key=prop.node.key.name??prop.node.key.value;
   if(['init','up','cell'].includes(key))program[key]=compile(prop.get('value'));
   if(key==='add'){
    if(prop.get('value').isFunction())program.add_program=compile(prop.get('value'));
    else program.add=prop.node.value.value??0;
   }
   if(key==='fs')program.fs=prop.node.value.value;
   if(key==='sh'){
    if(prop.get('value').isFunction())program.sh_program=compile(prop.get('value'));
    else {const value=exp(prop.get('value'));if(!constant(value))throw Error('dynamic sheet expression');program.sh=value[1];}
   }
   if(key==='an'&&prop.get('value').isArrayExpression())program.an=prop.node.value.elements.map(x=>x.value);
  }
  if((!program.init||!program.cell)&&!parents[id])throw Error('missing initializer/cell');
  programs[id]=program;
 }catch(error){unsupported[id]=String(error.message);}
}});
for(const [id,value] of registry){
 if(value.parentPath.isObjectProperty()){
  const program={source_line:value.node.loc.start.line};
  for(const prop of value.get('properties')){
   const key=prop.node.key.name??prop.node.key.value;
   if(['init','up','cell'].includes(key))program[key]=compile(prop.get('value'));
   if(key==='add')program.add=prop.node.value.value;
  }
  programs[id]=program;
 }
 if(value.isCallExpression()&&value.get('callee').isIdentifier({name:'_0x1f8713'})){
  const args=value.get('arguments'),count=exp(args[0]),target=exp(args[1]),callback=args[2];
  if(!constant(count)||!constant(target)||!callback.isFunction())throw Error('Particle factory signature changed');
  const env={};for(const p of callback.node.params)env[p.name]=['field','an'];
  const body=callback.get('body');
  const angle=body.isBlockStatement()?rows(body.get('body'),env):[['return',exp(body,env)]];
  programs[id]={source_line:value.node.loc.start.line,factory:{count:count[1],target:target[1],angle,jitter:8}};
 }
}
for(let i=0;i<5;i++)for(const [id,target] of Object.entries(aliases))if(programs[target])programs[id]=programs[target];
for(let i=0;i<5;i++)for(const [id,target] of Object.entries(parents))if(programs[target]&&programs[id])programs[id]={...programs[target],...programs[id]};
for(const [id,program] of Object.entries(programs))if(!program.factory&&(!program.init||!program.up||!program.cell)){unsupported[id]='unresolved source inheritance';delete programs[id];}
await writeFile('data/source-particle-programs.json',JSON.stringify({sha256:createHash('sha256').update(bytes).digest('hex'),programs,unsupported}));
console.log(JSON.stringify({compiled:Object.keys(programs).length,unsupported:Object.keys(unsupported).length,required:Object.fromEntries([17,18,19,59,65,78].map(k=>[k,programs[k]?'compiled':unsupported[k]||'absent']))}));
