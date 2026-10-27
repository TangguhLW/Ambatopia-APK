import {readFile,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire(process.cwd()+'/../growtopia-local/package.json');
const parser=require('@babel/parser'),traverse=require('@babel/traverse').default;
const versions=[];
for(const [path,name] of [['research/web-wardrobe/set.readable.js','_0x2eaab1'],['research/effects-024/app.readable.js','_0x29bd1e']]){
 const source=await readFile(path,'utf8'),tree=parser.parse(source),entries=new Set();let guard;
 traverse(tree,{VariableDeclarator(p){if(p.node.id.name===name&&p.get('init').isObjectExpression())for(const prop of p.node.init.properties)entries.add(Number(prop.key.value??prop.key.name));},AssignmentExpression(p){const l=p.node.left;if(l.type==='MemberExpression'&&l.object.name===name&&l.property.type==='NumericLiteral')entries.add(l.property.value);},IfStatement(p){if(guard)return;const test=source.slice(p.node.test.start,p.node.test.end);if(test.includes(name+'[')&&test.includes('.lp'))guard={line:p.node.loc.start.line,condition:test,consequent:source.slice(p.node.consequent.start,p.node.consequent.end)};}});
 versions.push({path,sha256:createHash('sha256').update(source).digest('hex'),registry:name,has_comet:entries.has(112),has_meteor:entries.has(113),has_neptune_factories:entries.has(36)&&entries.has(232),has_chaos_302:entries.has(302),guard});
}
const catalog=JSON.parse(await readFile('research/web-wardrobe/archive/l.json'));
const item=catalog.items.find(x=>x.id===8488);
if(versions.some(x=>x.has_chaos_302)||!versions[1].guard)throw Error('Source behavior changed; re-inspect Chaos');
const report={live_url:'https://growtopiasimulator.com/set/',script_url:'https://growtopiasimulator.com/set/app.js?v=67acd14fd1',versions,chaos:{id:8488,declared_legacy:item.ef.rows,frame_atlas:item.bk,sequence:item.st.stand,conclusion:'Both captured source versions omit program 302. The live source guard skips that particle row. Preserve the original eight-frame clothing animation, without inventing a replacement particle program.'}};
await writeFile('evidence/rides-024-source-audit.json',JSON.stringify(report,null,2));
console.log({versions:versions.length,chaos_particle_program_available:false,chaos_frames:item.st.stand[3].length});
