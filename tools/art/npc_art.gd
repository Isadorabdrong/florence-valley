extends RefCounted
## Phase 6 art: villager portraits (48x48) drawn from data/npcs/villagers.json
## (skin, hair and outfit colours, hairstyle and accessories).

const Painter := preload("res://tools/pixel_painter.gd")
const OUTLINE := Color("3d2b3d")
const SIZE := 48

var _ok := true


func generate_all() -> bool:
	var file := FileAccess.open("res://data/npcs/villagers.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	for id: String in data["npcs"]:
		_portrait(id, data["npcs"][id])
	return _ok


func _portrait(id: String, npc: Dictionary) -> void:
	var p := Painter.new(SIZE, SIZE, hash(id) & 0xFFFF)
	var skin := Color(npc["skin"][0])
	var skin_shade := Color(npc["skin"][1])
	var hair := Color(npc["hair"][0])
	var hair_shade := Color(npc["hair"][1])
	var outfit := Color(npc["outfit"][0])
	var outfit_shade := Color(npc["outfit"][1])
	var style: Dictionary = npc.get("portrait", {})
	var hairstyle := str(style.get("hair", "short"))
	# background
	p.disc(24, 24, 23.5, Color("fbf3e3"))
	p.disc(24, 24, 21.5, Color("fde3ea"))
	# long hair behind the shoulders
	if hairstyle == "long":
		p.rect(11, 18, 26, 24, hair_shade)
		p.ellipse(24, 20, 14, 12, hair_shade)
	# shoulders / outfit
	p.ellipse(24, 47, 18, 10, outfit)
	p.ellipse(19, 45, 8, 5, outfit.lightened(0.12))
	p.rect(6, 44, 36, 4, outfit_shade)
	match str(style.get("accessory", "")):
		"shawl":
			p.ellipse(24, 41, 17, 4, outfit.lightened(0.35))
			p.hline(9, 41, 30, outfit.lightened(0.5))
		"apron":
			p.rect(17, 40, 14, 8, Color("fbf3e3"))
			p.hline(17, 40, 14, Color("e6d3c3"))
		"scarf":
			p.ellipse(24, 38, 9, 3, Color("c4466a"))
			p.rect(26, 38, 3, 7, Color("c4466a"))
	# neck + face
	p.rect(20, 31, 8, 7, skin_shade)
	p.ellipse(24, 23, 10, 11.5, skin)
	p.ellipse(28, 26, 5, 7, skin_shade.lerp(skin, 0.5))
	# hair on top
	match hairstyle:
		"bun":
			p.disc(24, 9, 5, hair)
			p.ellipse(24, 15, 11, 6, hair)
			p.px(22, 7, hair.lightened(0.3))
		"long":
			p.ellipse(24, 14, 12, 7, hair)
			p.rect(12, 14, 4, 18, hair)
			p.rect(32, 14, 4, 18, hair)
		_:
			p.ellipse(24, 14, 11, 6.5, hair)
			p.rect(13, 14, 3, 6, hair)
			p.rect(32, 14, 3, 6, hair)
	p.hline(18, 13, 6, hair.lightened(0.25))
	# face details
	for ex in [20, 27]:
		p.rect(ex, 22, 2, 3, OUTLINE)
		p.px(ex, 22, Color.WHITE)
	p.rect(18, 26, 3, 2, Color("f29aa8"))
	p.rect(28, 26, 3, 2, Color("f29aa8"))
	p.hline(22, 29, 4, skin_shade.darkened(0.3))
	p.px(21, 28, skin_shade.darkened(0.3))
	p.px(26, 28, skin_shade.darkened(0.3))
	if style.get("beard", false):
		p.ellipse(24, 31, 7, 4, hair)
		p.hline(22, 29, 4, skin_shade.darkened(0.3))
	if style.get("glasses", false):
		for gx in [21, 28]:
			p.disc(gx, 23.5, 3.2, Color(1, 1, 1, 0.25))
		for gx in [21, 28]:
			for a in 16:
				var ang := TAU * a / 16.0
				p.px(int(gx + cos(ang) * 3.2), int(23.5 + sin(ang) * 3.2), OUTLINE)
		p.hline(24, 23, 2, OUTLINE)
	match str(style.get("accessory", "")):
		"cap":
			p.ellipse(24, 11, 12, 5, Color("6c9fc4"))
			p.rect(12, 12, 24, 3, Color("52709f"))
			p.hline(10, 15, 16, Color("52709f"))
		"bandana":
			p.rect(13, 13, 22, 3, Color("d9534f"))
			p.hline(13, 13, 22, Color("f08a7e"))
			p.px(35, 15, Color("d9534f"))
			p.px(36, 16, Color("d9534f"))
		"beret":
			p.ellipse(25, 9, 11, 4, Color("9c4f72"))
			p.px(25, 4, Color("9c4f72"))
	p.outline(OUTLINE)
	var err := p.save("res://assets/characters/portraits/%s.png" % id)
	if err != OK:
		push_error("[assets] portrait %s failed" % id)
		_ok = false
	else:
		print("[assets] wrote portrait ", id)
