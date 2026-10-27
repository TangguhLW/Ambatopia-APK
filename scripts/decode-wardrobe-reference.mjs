import {createHash} from 'node:crypto';import {readdirSync,mkdirSync} from 'node:fs';
import {createRequire} from 'node:module';import {readFileSync,writeFileSync} from 'node:fs';import vm from 'node:vm';
const require=createRequire(process.cwd()+'/../growtopia-local/package.json'),parser=require('@babel/parser'),traverse=require('@babel/traverse').default,generate=require('@babel/generator').default,t=require('@babel/types');
const input=process.argv[2]||'web-client/dist/set/app.js',output=process.argv[3]||'research/web-wardrobe/set.readable.js';
const decoderFile=output.replace(/\.js$/,'.decoder-only.js');
const source=readFileSync(input,'utf8'),ast=parser.parse(source,{sourceType:'script'}),context=vm.createContext({});
const decoderNodes=ast.program.body.filter(n=>n.type==='FunctionDeclaration'&&n.id.name.startsWith('a0_'));
const first=ast.program.body[0].expression,rotation=first.type==='SequenceExpression'?first.expressions[0]:first;
writeFileSync(decoderFile,decoderNodes.map(n=>source.slice(n.start,n.end)).join('\n')+'\n('+source.slice(rotation.start,rotation.end)+');');
vm.runInContext(readFileSync(decoderFile,'utf8'),context,{timeout:5000});
const unknown=Symbol('unknown');let decoded=0;
function value(n,scope,env={},depth=0){
 if(!n||depth>14)return unknown;
 if(t.isNumericLiteral(n)||t.isStringLiteral(n)||t.isBooleanLiteral(n))return n.value;
 if(t.isIdentifier(n)){if(Object.hasOwn(env,n.name))return env[n.name];return unknown;}
 if(t.isUnaryExpression(n)){const a=value(n.argument,scope,env,depth+1);if(a===unknown)return unknown;return n.operator==='-'?-a:n.operator==='+'?+a:n.operator==='!'?!a:n.operator==='~'?~a:unknown;}
 if(t.isBinaryExpression(n)){const a=value(n.left,scope,env,depth+1),b=value(n.right,scope,env,depth+1);if(a===unknown||b===unknown)return unknown;switch(n.operator){case '+':return a+b;case '-':return a-b;case '*':return a*b;case '/':return a/b;case '%':return a%b;case '^':return a^b;case '&':return a&b;case '|':return a|b;case '<<':return a<<b;case '>>':return a>>b;case '>>>':return a>>>b;case '===':return a===b;case '!==':return a!==b;case '<':return a<b;case '>':return a>b;case '<=':return a<=b;case '>=':return a>=b;default:return unknown;}}
 if(t.isCallExpression(n)&&t.isIdentifier(n.callee)){
  const args=n.arguments.map(a=>value(a,scope,env,depth+1));if(args.some(a=>a===unknown))return unknown;
  if(n.callee.name.startsWith('a0_')&&typeof context[n.callee.name]==='function'){try{return context[n.callee.name](...args);}catch{return unknown;}}
  const binding=scope.getBinding(n.callee.name);let fn=binding?.path.node;
  if(t.isVariableDeclarator(fn))fn=fn.init;
  if(!t.isFunction(fn)||fn.body.body?.length!==1||!t.isReturnStatement(fn.body.body[0])||fn.params.some(p=>!t.isIdentifier(p)))return unknown;
  return value(fn.body.body[0].argument,binding.path.scope,Object.fromEntries(fn.params.map((p,i)=>[p.name,args[i]])),depth+1);
 }
 return unknown;
}
traverse(ast,{CallExpression:{exit(path){const v=value(path.node,path.scope);if(typeof v==='string'){path.replaceWith(t.stringLiteral(v));decoded++;}}},BinaryExpression:{exit(path){const v=value(path.node,path.scope);if(typeof v==='string')path.replaceWith(t.stringLiteral(v));else if(typeof v==='number'&&Number.isFinite(v))path.replaceWith(t.valueToNode(v));else if(typeof v==='boolean')path.replaceWith(t.booleanLiteral(v));}}});
traverse(ast,{MemberExpression(p){if(t.isStringLiteral(p.node.property)&&t.isValidIdentifier(p.node.property.value)){p.node.property=t.identifier(p.node.property.value);p.node.computed=false;}},IfStatement:{exit(p){const test=p.node.test;if(t.isBooleanLiteral(test)){if(test.value)p.replaceWith(p.node.consequent);else if(p.node.alternate)p.replaceWith(p.node.alternate);else p.remove();}}}});
traverse(ast,{AssignmentExpression(p){if(p.node.left.type==='MemberExpression'&&p.node.left.object.name==='window'&&p.node.left.property.name==='plannerReady')console.log(JSON.stringify({hookOffset:p.node.start,anchor:source.slice(p.node.start,p.node.start+100)}));}});
writeFileSync(output,generate(ast,{comments:false,compact:false}).code);
console.log(JSON.stringify({decodedStringCalls:decoded,output,applicationExecuted:false,decoderOnly:true}));
