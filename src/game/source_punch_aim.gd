extends RefCounted

static func point(rule: Array,target: Vector2) -> Vector2:
	var base:=Vector2(rule[1],rule[2])
	match str(rule[0]):
		"t":return target+base
		"a":return base+Vector2(rule[3],rule[4]).rotated((target-base).angle())
	return base

static func values(cv: Dictionary,key: String,n: int) -> Array:
	var raw: Array=cv.get(key,[0]);var result: Array=[]
	for i in n:result.append(float(raw[mini(i,raw.size()-1)]))
	return result

# Source _22c24f accepts an affine retarget only when near/far captures agree.
static func resolve(p: Dictionary,target: Vector2,aim: Dictionary,anchor_delta:=Vector2.ZERO) -> Dictionary:
	if p.get("fol",false) or p.has("t080") or p.get("cv80",{}).has("t"):return {}
	var near:=Vector2(p.at[0],p.at[1]);var far:=Vector2(p.at80[0],p.at80[1]) if p.has("at80") else near
	var selected: Dictionary={};var closest:=0.7
	for row in aim.get("sp",[]):
		if not row.get("p") is Array or not row.get("a") is Array or not row.get("s") is Array:continue
		var legacy: bool=str(p.get("k","")).begins_with("L")
		if legacy and int(str(p.k).substr(1))!=int(row.id) or not legacy and not row.id is String:continue
		if row.p[0]!="an":
			if not p.has("an"):
				var distance:=point(row.p,Vector2(48,16)).distance_to(near) if row.p.size()>2 else INF
				if distance<=closest:closest=distance;selected=row
		elif p.has("an") and selected.is_empty():selected=row
	var at:=near
	var a:=near;var b:=far;var c:=near
	var sa:=near;var sb:=far;var sc:=near
	var fixed_angle:=false;var fixed_scale:=false
	if not selected.is_empty():
		if selected.p[0]!="an":at=point(selected.p,target)
		else:at+=anchor_delta
		if not p.has("at80"):far=near if selected.p[0]=="an" else point(selected.p,Vector2(80,16))
		a=Vector2(selected.a[1],selected.a[2]) if selected.a[0]=="q" else near
		b=Vector2(selected.a[1],selected.a[2]) if selected.a[0]=="q" else far
		c=Vector2(selected.a[1],selected.a[2]) if selected.a[0]=="q" else at
		sa=Vector2(selected.s[1],selected.s[2]) if selected.s[0]=="q" else near
		sb=Vector2(selected.s[1],selected.s[2]) if selected.s[0]=="q" else far
		sc=Vector2(selected.s[1],selected.s[2]) if selected.s[0]=="q" else at
		fixed_angle=selected.a[0]=="f";fixed_scale=selected.s[0]=="f"
	else:
		if not p.has("at80") or p.has("an"):return {}
		var shift: bool=absf(far.x-near.x-32)<1 and absf(far.y-near.y)<1
		if not shift and far.distance_to(near)>3:return {}
		at=near+target-Vector2(48,16) if shift else near;c=at;sc=at
	var v0:=Vector2(48,16)-a;var v1:=Vector2(80,16)-b;var vt:=target-c
	if v0.length()<1 or v1.length()<1 or vt.length()<0.001:return {}
	var dir0:=v0.normalized();var dir1:=dir0 if fixed_angle else v1.normalized();var dirt:=dir0 if fixed_angle else vt.normalized()
	var l0:=Vector2(48,16).distance_to(sa);var l1:=Vector2(80,16).distance_to(sb);var lt:=target.distance_to(sc)
	if not fixed_scale and l0<1:return {}
	var far_scale:=1.0 if fixed_scale else l1/l0;var new_scale:=1.0 if fixed_scale else lt/l0
	if p.has("life80") and absf(float(p.life80)/float(p.life)-far_scale)>0.03*far_scale:return {}
	var base: Dictionary=p.cv;var farther: Dictionary=base.duplicate()
	for key in p.get("cv80",{}):farther[key]=p.cv80[key]
	var count: int=base.get("t",[]).size()
	if count==0:return {}
	var xs:=values(base,"x",count);var ys:=values(base,"y",count);var fx:=values(farther,"x",count);var fy:=values(farther,"y",count)
	var along: Array=[];var residual: Array=[]
	for i in count:
		var d: float=xs[i]/dir0.x if absf(dir0.x)>=absf(dir0.y) else ys[i]/dir0.y
		along.append(d);residual.append(Vector2(xs[i],ys[i])-dir0*d)
	var factor:=0.0
	for index in 2:
		var candidate: float=far_scale if index==0 else 1.0
		if index==1 and p.has("life80"):continue
		var valid:=true
		for i in count:
			var expected: Vector2=dir1*float(along[i])*candidate+residual[i]
			if expected.distance_to(Vector2(fx[i],fy[i]))>1+0.03*Vector2(fx[i],fy[i]).length():valid=false;break
		if valid:factor=new_scale if candidate==far_scale else 1.0;break
	if factor==0:return {}
	var result:=p.duplicate(true);result.at=[at.x,at.y]
	result.cv.x=[];result.cv.y=[]
	for i in count:
		var transformed: Vector2=dirt*float(along[i])*factor+residual[i]
		result.cv.x.append(transformed.x);result.cv.y.append(transformed.y)
	var sx:=values(base,"sx",count);var fsx:=values(farther,"sx",count);var stretch: bool=absf(far_scale-1)>0.02
	for i in count:
		if absf(fsx[i]-sx[i]*far_scale)>0.01+0.02*absf(fsx[i]):stretch=false;break
	if not sx.any(func(value):return absf(value)>0.01):stretch=false
	if stretch:result.cv.sx=sx.map(func(value):return value*new_scale)
	var turn:=rad_to_deg(dir0.angle_to(dirt));var far_turn:=rad_to_deg(dir0.angle_to(dir1))
	var r:=values(base,"r",count);var fr:=values(farther,"r",count);result.cv.r=[]
	for i in count:result.cv.r.append(r[i]+(turn if stretch or absf(far_turn)>2 and absf(wrapf(fr[i]-r[i]-far_turn,-180,180))<1.5 else 0))
	if p.has("life80"):result.life=float(p.life)*new_scale
	return result
