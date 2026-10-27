import {readFile,readdir,writeFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
const root='C:/Users/user/AppData/Local/Growtopia';
const digest=bytes=>createHash('sha256').update(bytes).digest('hex');
const matches=[];
async function scan(folder){
 for(const entry of await readdir(root+'/'+folder,{withFileTypes:true})){
  const path=folder+'/'+entry.name;
  if(entry.isDirectory()){await scan(path);continue;}
  if(!/\.(xml|yaml|json)$/.test(path))continue;
  const bytes=await readFile(root+'/'+path),text=bytes.toString('utf8');
  const lines=text.split(/\r?\n/).flatMap((line,index)=>/guild|mascot|starship|stellarix|greezak|hypertech|protostar/i.test(line)?[{line:index+1,text:line.trim()}]:[]);
  if(lines.length)matches.push({source:path,sha256:digest(bytes),lines});
 }
}
await scan('GameData');
const use=JSON.parse(await readFile('data/simulator/use.json'));
const rest=JSON.parse(await readFile('data/simulator/rest.json'));
const blasts=JSON.parse(await readFile('data/blast-templates.json'));
const weather=JSON.parse(await readFile('data/simulator/weather-layers.json'));
const report={source_check:'research/machines-030/source-check.json',local_text_resource_matches:matches,guild:{item:6280,source_entry:use.weather['6280'],renderer_recipe:Object.keys(weather.wx).filter(key=>/guild|mascot/i.test(key)),guild_model_in_source_rest:Object.keys(rest.data).filter(key=>/guild|mascot/i.test(key))},starship:{items:[6420,6422,6424,6666,12048],available_generator_templates:[6420,6422,6424,6666,12048].filter(id=>blasts.templates[String(id)]),star_metadata_fields:Object.keys(rest.data.star),qualification:'Sector/fuel/equipment metadata does not establish a ship tile layout'},unrecovered:['Guild mascot rendering and guild state','Five original Starship world generators','Calendar reward weights','Well contribution best-of-five algorithm and individual epic weights','Machine interactions and animation branches outside the 210 compared foreground definitions'],read_only:true};
await writeFile('research/machines-030/gap-audit.json',JSON.stringify(report,null,2));
console.log({matched_resource_files:matches.length,guild_recipe_count:report.guild.renderer_recipe.length,starship_generator_count:report.starship.available_generator_templates.length});
