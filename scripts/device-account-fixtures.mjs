import fs from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
const cleanup=process.argv.includes('--cleanup');
for(const platform of ['windows','android']){
 const file='server/private/qa-'+platform+'.json';
 if(cleanup){
  let fixture;try{fixture=JSON.parse(await fs.readFile(file));}catch{continue;}
  const h={apikey:process.env.SUPABASE_SECRET_KEY};
  let r=await fetch(process.env.SUPABASE_URL+'/rest/v1/game_worlds?name=eq.'+fixture.world,{method:'DELETE',headers:h});if(!r.ok)throw Error('Fixture world cleanup failed');
  r=await fetch(process.env.SUPABASE_URL+'/auth/v1/admin/users/'+fixture.id,{method:'DELETE',headers:h});if(!r.ok)throw Error('Fixture account cleanup failed');
  await fs.unlink(file);
 }else{
  const fixture={name:'QA'+platform[0]+Date.now().toString(36),password:randomBytes(20).toString('hex'),world:'QADEVICE'+platform[0].toUpperCase()+Date.now().toString(36).slice(-5).toUpperCase()};
  const r=await fetch('http://127.0.0.1:4193/auth/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(fixture)});
  const data=await r.json();if(!r.ok)throw Error('Fixture registration failed: '+data.error);
  fixture.id=data.profile.id;await fs.writeFile(file,JSON.stringify(fixture));
 }
}
console.log(cleanup?'Synthetic device accounts cleaned':'Synthetic device accounts ready; credentials not printed');
