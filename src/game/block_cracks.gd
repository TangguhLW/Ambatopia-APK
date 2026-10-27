extends RefCounted

static func region(hits: float, required: float) -> Rect2:
	var progress:=clampf(hits/maxf(1,required),0,0.999)
	return Rect2(clampi(int(progress*4),0,3)*32,0,32,32)
