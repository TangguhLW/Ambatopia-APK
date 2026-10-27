import {createHmac} from 'node:crypto';
import {readFileSync,writeFileSync,renameSync,existsSync,mkdirSync} from 'node:fs';
import {dirname} from 'node:path';
export class RegistrationQuota {
 constructor(file,secret){this.file=file;this.secret=secret;this.rows=existsSync(file)?JSON.parse(readFileSync(file,'utf8')):{};}
 key(ip){return createHmac('sha256',this.secret).update(ip.replace(/^::ffff:/,'')).digest('hex');}
 save(){mkdirSync(dirname(this.file),{recursive:true});writeFileSync(this.file+'.tmp',JSON.stringify(this.rows),{mode:0o600});renameSync(this.file+'.tmp',this.file);}
 reserve(ip){const key=this.key(ip);const count=this.rows[key]||0;if(count>=2)return null;this.rows[key]=count+1;this.save();return key;}
 release(key){if(key&&this.rows[key]){this.rows[key]--;this.save();}}
}
