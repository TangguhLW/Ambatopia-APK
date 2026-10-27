from pathlib import Path
p=Path('server/registration-quota.mjs');p.write_text('''import {createHmac} from 'node:crypto';
import {readFileSync,writeFileSync,renameSync,existsSync,mkdirSync} from 'node:fs';
import {dirname} from 'node:path';
export class RegistrationQuota {
 constructor(file,secret){this.file=file;this.secret=secret;this.rows=existsSync(file)?JSON.parse(readFileSync(file,'utf8')):{};}
 key(ip){return createHmac('sha256',this.secret).update(ip.replace(/^::ffff:/,'')).digest('hex');}
 save(){mkdirSync(dirname(this.file),{recursive:true});writeFileSync(this.file+'.tmp',JSON.stringify(this.rows),{mode:0o600});renameSync(this.file+'.tmp',this.file);}
 reserve(ip){const key=this.key(ip);const count=this.rows[key]||0;if(count>=2)return null;this.rows[key]=count+1;this.save();return key;}
 release(key){if(key&&this.rows[key]){this.rows[key]--;this.save();}}
}
''')
p=Path('server/accounts.mjs');s=p.read_text().replace("import { createServer }", "import { RegistrationQuota } from './registration-quota.mjs';\nimport { createServer }")
s=s.replace('const rates=new Map();','const rates=new Map();\n  const quota=new RegistrationQuota(env.REGISTRATION_QUOTA_FILE||"server/private/registration-quota.json",env.GAME_INTERNAL_TOKEN);')
s=s.replace('rate.count++;rates.set(ip,rate);','if(!trusted){rate.count++;rates.set(ip,rate);}')
s=s.replace("if(req.method==='POST' && req.url==='/auth/register'){", "if(req.method==='GET' && req.url==='/online')return reply(200,{online:Date.now()-presence.updated<15000?presence.players.length:0});\n      if(req.method==='POST' && req.url==='/auth/register'){")
a=s.index("        await api('/auth/v1/admin/users'");b=s.index("        const session=",a)
s=s[:a]+'''        const reservation=quota.reserve(ip);
        if(!reservation)return reply(429,{error:'This IP has reached the limit of two accounts. New registrations are blocked; existing accounts can still log in.'});
        try { await api('/auth/v1/admin/users',{method:'POST',body:{email:alias(name),password:body.password,email_confirm:true,app_metadata:{game_provisioned:true},user_metadata:{amba_id:body.name}}}); }
        catch(error){quota.release(reservation);throw error;}
'''+s[b:]
s=s.replace('select=id,banned_until,settings','select=id,role,banned_until,settings')
s=s.replace("'ban','unban','curse','warn'","'ban','unban','curse','warn','promote','demote'")
s=s.replace("else change.settings={", "else if(body.action==='promote'||body.action==='demote')change.settings={...rows[0].settings,moderator:body.action==='promote'};\n        else change.settings={")
p.write_text(s)
p=Path('tests/registration-quota.test.mjs');p.write_text('''import {test} from 'node:test';import assert from 'node:assert/strict';import {mkdtempSync,rmSync} from 'node:fs';import {tmpdir} from 'node:os';import {join} from 'node:path';import {RegistrationQuota} from '../server/registration-quota.mjs';
test('Two accounts per address, persisted, normalized, failed reservation released',()=>{const dir=mkdtempSync(join(tmpdir(),'amba-quota-'));try{let q=new RegistrationQuota(join(dir,'quota.json'),'unit-test-secret');assert.ok(q.reserve('::ffff:127.0.0.1'));assert.ok(q.reserve('127.0.0.1'));assert.equal(q.reserve('127.0.0.1'),null);q=new RegistrationQuota(join(dir,'quota.json'),'unit-test-secret');assert.equal(q.reserve('127.0.0.1'),null);const k=q.reserve('192.0.2.1');q.release(k);assert.ok(q.reserve('192.0.2.1'));assert.ok(q.reserve('192.0.2.1'));assert.equal(q.reserve('192.0.2.1'),null);}finally{rmSync(dir,{recursive:true,force:true});}});
''')
p=Path('src/ui/login.gd');s=p.read_text().replace('var busy := false','var busy := false\nvar online_button: Button\nvar credentials: VBoxContainer')
s=s.replace('scroll.offset_left = 20','scroll.anchor_left = 0.1\n\tscroll.anchor_right = 0.9\n\tscroll.anchor_top = 0.08\n\tscroll.anchor_bottom = 0.92\n\tscroll.offset_left = 20')
s=s.replace('form.add_child(UI.label("Welcome to Ambatopia",30))','''form.add_child(UI.label("Welcome to Ambatopia",30))
	credentials = VBoxContainer.new()
	form.add_child(credentials)''')
s=s.replace('form.add_child(field)','credentials.add_child(field)').replace('form.add_child(password_field)','credentials.add_child(password_field)').replace('form.add_child(actions)','credentials.add_child(actions)')
s=s.replace('secondary.add_child(UI.button("Local test multiplayer",func(): app.navigate("multiplayer"),20))','''online_button = UI.button("Online mode · checking...",choose_online,20)
	secondary.add_child(online_button)''')
s=s.replace('password_field.text_submitted.connect(func(_text): authenticate(false))','''password_field.text_submitted.connect(func(_text): authenticate(false))
	credentials.visible = app.accounts.access_token.is_empty()
	if not credentials.visible:
		error.text = "Signed in as " + app.accounts.profile.amba_id
	update_online()

func update_online() -> void:
	var result: Dictionary = await app.accounts.request("/online",{},HTTPClient.METHOD_GET)
	if is_instance_valid(online_button):
		online_button.text = "Online mode · %d online" % int(result.get("online",0)) if result.ok else "Online mode · server unavailable"

func choose_online() -> void:
	if app.accounts.access_token.is_empty():
		credentials.show()
		field.grab_focus()
		return
	app.profile = {"id":app.accounts.profile.id,"display_name":app.accounts.profile.amba_id}
	app.shared_selection = true
	app.navigate("worlds")''')
p.write_text(s)
p=Path('tests/suites/ambatopia_ui.gd');s=p.read_text().replace('size()==836','size()==863');p.write_text(s)
p=Path('src/game/avatar_view.gd');s=p.read_text().replace('var worn_cache:', 'var motion := {}\nvar amba_texture: Texture2D\nvar worn_cache:')
s=s.replace('\ttexture_filter =', '\tfor action in ["walk","punch","jump"]:\n\t\tmotion[action] = load("res://assets/ambatopia/motion/"+action+".png")\n\tamba_texture = load("res://assets/ambatopia/amba-body.png")\n\ttexture_filter =',1)
s=s.replace('\tvar skin :=', '''	if player.amba:
		draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
		var bounce := absf(sin(elapsed*12))*1.5 if absf(player.velocity.x)>1 and player.grounded else 0.0
		draw_texture_rect(amba_texture,Rect2(-16,-32-bounce,32,32),false)
		draw_set_transform(Vector2.ZERO)
		return
	if player.catalog_equipment.is_empty() and player.equipment.values().all(func(value): return value < 0):
		var action := "walk"
		var index := 0
		if player.punch_time > 0:
			action = "punch"
			index = clampi(int((1-player.punch_time/0.18)*5),0,4)
		elif not player.grounded:
			action = "jump"
			index = 3 if player.velocity.y<0 else 6
		elif absf(player.velocity.x)>1:
			index = int(elapsed*18)%8
		draw_set_transform(Vector2.ZERO,0,Vector2(player.facing,1))
		draw_texture_rect_region(motion[action],Rect2(-48,-60,96,64),Rect2(index*96,0,96,64))
		draw_set_transform(Vector2.ZERO)
		return
	var skin :=''',1)
p.write_text(s)
