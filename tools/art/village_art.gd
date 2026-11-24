extends RefCounted
## Phase 4 art: village buildings, plaza/region props, interior furniture,
## forage item icons and butterflies. Deterministic.
##
## Every building/prop is anchored at the bottom-centre of its sprite (the
## door for buildings), matching the scenes in scenes/objects/.

const Painter := preload("res://tools/pixel_painter.gd")

const OUTLINE := Color("3d2b3d")
const WOOD := [Color("6b4430"), Color("8a5d3f"), Color("b07d55"), Color("cf9f72")]
const STONE := [Color("5d5868"), Color("7b7689"), Color("9d98ab"), Color("c2bdcc"), Color("dcd8e3")]
const LEAF := [Color("2f5a3c"), Color("3f7a4a"), Color("5c9656"), Color("85b56c"), Color("b4d48c")]
const GLASS := Color("9cc9de")
const GLASS_LIGHT := Color("c9e5f0")
const CREAM := Color("fbf3e3")

var _ok := true


func generate_all() -> bool:
	_gen_buildings()
	_gen_props()
	_gen_furniture()
	_gen_forage_icons()
	_gen_butterflies()
	return _ok


func _save(p: Painter, path: String) -> void:
	var err := p.save(path)
	if err != OK:
		push_error("[assets] could not save %s (error %d)" % [path, err])
		_ok = false
	else:
		print("[assets] wrote ", path)


# -------------------------------------------------------------- buildings ---

func _gen_buildings() -> void:
	_building("market", 112, 96, {
		"wall": [Color("e3d1b8"), Color("f1e4cc"), Color("fbf3e3")],
		"roof": [Color("2f5a48"), Color("427558"), Color("5e9366"), Color("86b27a"), Color("b4d48c")],
		"awning": [Color("e07a9a"), CREAM], "windows": 2, "sign": "basket"})
	_building("cafe", 96, 88, {
		"wall": [Color("d9a58a"), Color("ecc0a4"), Color("f6d8c2")],
		"roof": [Color("4e3326"), Color("6b4430"), Color("8a5d3f"), Color("a8774f"), Color("cf9f72")],
		"awning": [Color("86b27a"), CREAM], "windows": 2, "sign": "cup"})
	_building("library", 112, 104, {
		"wall": [STONE[1], STONE[2], STONE[3]],
		"roof": [Color("3f4a6b"), Color("566590"), Color("7486b0"), Color("9eacd0"), Color("c4cee8")],
		"windows": 2, "sign": "book", "round_window": true, "columns": true})
	_building("community_center", 128, 108, {
		"wall": [WOOD[1], WOOD[2], WOOD[3]],
		"roof": [Color("8f3f58"), Color("b4566f"), Color("cf7389"), Color("e39aa9"), Color("f2bfc8")],
		"windows": 4, "sign": "heart", "tower": true})
	_building("workshop", 96, 84, {
		"wall": [Color("7b6a5c"), Color("9a8775"), Color("b8a690")],
		"roof": [Color("4a4656"), Color("5d5868"), Color("7b7689"), Color("9d98ab"), Color("c2bdcc")],
		"windows": 1, "sign": "hammer", "barn_door": true})
	_building("old_florist", 96, 88, {
		"wall": [Color("c9a3ab"), Color("dcbcc2"), Color("ead4d8")],
		"roof": [Color("8a6a70"), Color("a9828a"), Color("c49aa3"), Color("d8b6bd"), Color("ead4d8")],
		"windows": 2, "sign": "flower", "broken": true})
	_building("villager_house_a", 80, 80, {
		"wall": [Color("e3d1b8"), Color("f1e4cc"), Color("fbf3e3")],
		"roof": [Color("3f4a6b"), Color("566590"), Color("7486b0"), Color("9eacd0"), Color("c4cee8")],
		"windows": 2, "chimney": true})
	_building("villager_house_b", 80, 80, {
		"wall": [Color("a8c49a"), Color("c2d8b4"), Color("dceacf")],
		"roof": [Color("8a4a32"), Color("a8603f"), Color("c47c56"), Color("d89c78"), Color("ecc0a4")],
		"windows": 2, "chimney": true})


func _building(name: String, w: int, h: int, spec: Dictionary) -> void:
	var p := Painter.new(w, h, hash(name) & 0xFFFF)
	var wall: Array = spec["wall"]
	var roof: Array = spec["roof"]
	var cx := w / 2
	var roof_top := 6
	var roof_bottom := int(h * 0.46)
	var wall_top := roof_bottom - 3
	var base_y := h - 4
	if spec.get("chimney", false):
		p.rect(w - 26, 2, 8, roof_bottom - 8, STONE[2])
		p.vline(w - 26, 2, roof_bottom - 8, STONE[3])
		p.rect(w - 27, 1, 10, 3, STONE[1])
	if spec.get("tower", false):
		p.rect(cx - 9, 0, 18, roof_top + 14, wall[1])
		p.vline(cx - 9, 0, roof_top + 14, wall[2])
		p.disc(cx, 9, 4.5, CREAM)
		p.vline(cx, 6, 4, OUTLINE)
		p.hline(cx, 9, 3, OUTLINE)
	# walls
	for y in range(wall_top, base_y):
		for x in range(6, w - 6):
			var t := 0.75 - float(x - 6) / float(w * 2) + (0.05 if y < wall_top + 6 else 0.0)
			p.px(x, y, p.dithered_tone(wall, t, x, y, 0.12))
	if spec.get("columns", false):
		for colx in [10, w - 16, cx - 22, cx + 16]:
			p.rect(colx, wall_top + 2, 6, base_y - wall_top - 2, STONE[4])
			p.vline(colx + 5, wall_top + 2, base_y - wall_top - 2, STONE[2])
	if wall[0] == WOOD[1]:
		for y in range(wall_top + 4, base_y, 5):
			p.hline(6, y, w - 12, WOOD[0])
	# foundation
	p.rect(4, base_y - 1, w - 8, 4, STONE[1])
	p.hline(4, base_y - 1, w - 8, STONE[3])
	# door
	var door_w := 22 if spec.get("barn_door", false) else 12
	var door_h := 22
	var door_x := cx - door_w / 2
	var door_y := base_y - door_h
	p.rect(door_x - 1, door_y - 1, door_w + 2, door_h + 1, WOOD[0])
	p.rect(door_x, door_y, door_w, door_h, WOOD[1])
	for dx in range(door_x + 2, door_x + door_w, 3):
		p.vline(dx, door_y, door_h, WOOD[0])
	if spec.get("barn_door", false):
		for i in door_h:
			p.px(door_x + i * door_w / door_h, door_y + i, WOOD[3])
	p.px(door_x + door_w - 3, door_y + door_h / 2, Color("f2c14e"))
	# windows
	var count: int = spec.get("windows", 2)
	var slots: Array = []
	if count == 1:
		slots = [cx + door_w / 2 + 14]
	else:
		var span := (w - 24 - door_w) / 2
		for i in count:
			var left := i < count / 2
			var k := i if left else i - count / 2
			var per := count / 2
			var x0 := 10 + int((span - 14) * (k + 0.5) / per) if left else cx + door_w / 2 + 6 + int((span - 14) * (k + 0.5) / per)
			slots.append(x0)
	for wx: int in slots:
		var wy := wall_top + 8
		p.rect(wx - 1, wy - 1, 14, 14, CREAM)
		p.rect(wx, wy, 12, 12, GLASS)
		p.rect(wx, wy, 5, 4, GLASS_LIGHT)
		p.vline(wx + 6, wy, 12, CREAM)
		p.hline(wx, wy + 6, 12, CREAM)
		if spec.get("broken", false):
			for i in 3:
				p.rect(wx - 2, wy + 2 + i * 4, 16, 2, WOOD[2])
				p.hline(wx - 2, wy + 3 + i * 4, 16, WOOD[0])
		else:
			p.rect(wx - 2, wy + 13, 16, 3, WOOD[2])
			for fx in range(wx - 1, wx + 13, 2):
				p.px(fx, wy + 12, [Color("e07a9a"), Color("c9b3e6"), Color("f2c14e")][(fx / 2) % 3])
	if spec.has("awning"):
		var aw: Array = spec["awning"]
		for x in range(8, w - 8):
			for y in range(wall_top + 2, wall_top + 7):
				p.px(x, y, aw[0] if ((x / 4) % 2 == 0) else aw[1])
			if x % 4 != 3:
				p.px(x, wall_top + 7, aw[0] if ((x / 4) % 2 == 0) else aw[1])
	if spec.get("round_window", false):
		p.disc(cx, roof_bottom - 12, 6, CREAM)
		p.disc(cx, roof_bottom - 12, 4.6, GLASS)
		p.vline(cx, roof_bottom - 17, 10, CREAM)
	# roof (trapezoid with shingle rows)
	for y in range(roof_top, roof_bottom):
		var t := float(y - roof_top) / float(roof_bottom - roof_top)
		var hw := lerpf(w * 0.25, w * 0.5 - 1.0, t)
		for x in range(int(cx - hw), int(cx + hw) + 1):
			var row := (y - roof_top) / 4
			var light := 0.82 - (x - cx + hw) / (hw * 2.0) * 0.5 - t * 0.12
			var c := p.dithered_tone(roof, light, x, y, 0.15)
			if (y - roof_top) % 4 == 3:
				c = roof[1]
			elif (x + row * 3) % 6 == 0:
				c = roof[1]
			if spec.get("broken", false) and Painter.noise_hash(x / 3, y / 3, 91) > 0.93:
				c = WOOD[0]
			p.px(x, y, c)
	p.hline(int(cx - w * 0.25), roof_top, int(w * 0.5) + 1, roof[0])
	# sign above the door
	if spec.has("sign"):
		_sign(p, cx, door_y - 8, spec["sign"], spec.get("broken", false))
	if spec.get("broken", false):
		for i in 10:
			var cxk := 10 + int(Painter.noise_hash(i, 1, 7) * (w - 20))
			var cyk := wall_top + 4 + int(Painter.noise_hash(1, i, 7) * (base_y - wall_top - 10))
			p.px(cxk, cyk, wall[0].darkened(0.3))
			p.px(cxk + 1, cyk + 1, wall[0].darkened(0.3))
	# vines on the corner
	for i in 20:
		var vx := 6 + p.rng.randi_range(0, 6)
		var vy := p.rng.randi_range(wall_top, base_y - 2)
		p.px(vx, vy, LEAF[2] if i % 3 else LEAF[3])
	p.outline(OUTLINE)
	_shadow(p, cx, base_y + 2, w * 0.46, 2.5)
	_save(p, "res://assets/buildings/%s.png" % name)


func _sign(p: Painter, x: int, y: int, icon: String, faded: bool) -> void:
	p.rect(x - 9, y - 5, 18, 10, CREAM if not faded else Color("e6d3c3"))
	p.hline(x - 9, y + 4, 18, Color("e3d1b8"))
	var c := Color("e07a9a") if not faded else Color("c49aa3")
	match icon:
		"basket":
			p.rect(x - 4, y - 1, 8, 4, WOOD[2])
			p.hline(x - 4, y - 2, 8, WOOD[1])
			p.px(x - 2, y - 3, Color("c4466a"))
			p.px(x + 1, y - 3, Color("f2c14e"))
		"cup":
			p.rect(x - 3, y - 2, 5, 5, Color("8a5d3f"))
			p.px(x + 2, y, Color("8a5d3f"))
			p.px(x - 1, y - 4, Color("dcd8e3"))
		"book":
			p.rect(x - 4, y - 3, 8, 6, Color("566590"))
			p.vline(x, y - 3, 6, CREAM)
		"heart":
			p.disc(x - 1.5, y - 1, 1.8, c)
			p.disc(x + 1.5, y - 1, 1.8, c)
			p.px(x, y + 2, c)
			p.hline(x - 2, y + 1, 5, c)
		"hammer":
			p.rect(x - 3, y - 3, 6, 2, STONE[1])
			p.vline(x, y - 1, 4, WOOD[1])
		"flower":
			for o: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
				p.px(x + o.x, y + o.y, c)
			p.px(x, y, Color("f2c14e"))


func _shadow(p: Painter, cx: float, cy: float, rx: float, ry: float) -> void:
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0 and p.get_px(x, y).a < 0.1:
				p.px(x, y, Color(0.24, 0.17, 0.24, 0.26))


# ------------------------------------------------------------------ props ---

func _gen_props() -> void:
	# fountain 48x40, origin (24, 38)
	var f := Painter.new(48, 40, 2001)
	f.ellipse(24, 30, 22, 8, STONE[2])
	f.ellipse(24, 29, 19, 6, Color("86bcd8"))
	f.hline(14, 27, 6, Color("c9e5f0"))
	f.rect(21, 12, 6, 17, STONE[3])
	f.vline(21, 12, 17, STONE[4])
	f.ellipse(24, 12, 8, 3, STONE[2])
	f.ellipse(24, 11, 6, 2, Color("86bcd8"))
	for i in 6:
		f.px(18 + i * 2, 6 + (i % 2) * 2, Color("c9e5f0"))
		f.px(19 + i * 2, 8 + (i % 3), Color("a9d3e6"))
	f.rect(2, 30, 44, 5, STONE[1])
	f.hline(2, 30, 44, STONE[3])
	f.outline(OUTLINE)
	_shadow(f, 24, 37, 22, 2)
	_save(f, "res://assets/objects/fountain.png")
	# bench 32x20, origin (16, 19)
	var b := Painter.new(32, 20, 2002)
	b.rect(2, 4, 28, 3, WOOD[2])
	b.rect(2, 9, 28, 3, WOOD[2])
	b.hline(2, 4, 28, WOOD[3])
	b.hline(2, 9, 28, WOOD[3])
	b.rect(4, 12, 2, 6, Color("4a4656"))
	b.rect(26, 12, 2, 6, Color("4a4656"))
	b.outline(OUTLINE)
	_save(b, "res://assets/objects/bench.png")
	# lamp post 12x40, origin (6, 39)
	var l := Painter.new(12, 40, 2003)
	l.rect(5, 10, 2, 28, Color("4a4656"))
	l.rect(3, 36, 6, 3, Color("4a4656"))
	l.rect(2, 2, 8, 9, Color("4a4656"))
	l.rect(3, 4, 6, 6, Color("f9dc7c"))
	l.px(4, 5, Color("fff3c4"))
	l.outline(OUTLINE)
	_save(l, "res://assets/objects/lamp.png")
	# notice board 32x32, origin (16, 31)
	var n := Painter.new(32, 32, 2004)
	n.rect(4, 6, 2, 25, WOOD[1])
	n.rect(26, 6, 2, 25, WOOD[1])
	n.rect(2, 4, 28, 18, WOOD[1])
	n.rect(4, 6, 24, 14, Color("c99a55"))
	n.rect(6, 8, 8, 6, CREAM)
	n.rect(16, 9, 9, 8, Color("f5bfd0"))
	n.rect(8, 15, 6, 4, Color("e6f0d8"))
	n.px(10, 8, Color("e07a9a"))
	n.px(20, 9, Color("c4466a"))
	n.outline(OUTLINE)
	_save(n, "res://assets/objects/notice_board.png")
	# festival stage 80x40, origin (40, 38)
	var s := Painter.new(80, 40, 2005)
	s.rect(2, 22, 76, 14, WOOD[2])
	s.hline(2, 22, 76, WOOD[3])
	for x in range(2, 78, 8):
		s.vline(x, 23, 13, WOOD[1])
	s.rect(2, 36, 76, 2, WOOD[0])
	s.rect(3, 2, 2, 21, WOOD[1])
	s.rect(75, 2, 2, 21, WOOD[1])
	for i in 18:
		var x := 5 + i * 4
		var y := 4 + int(sin(i * 0.35) * 2.0 + 2.0)
		s.px(x, y, Color("3d2b3d"))
		var flag: Color = [Color("e07a9a"), Color("f2c14e"), Color("9d8bc9"), Color("86b27a")][i % 4]
		s.rect(x, y + 1, 3, 2, flag)
		s.px(x + 1, y + 3, flag)
	s.outline(OUTLINE)
	_save(s, "res://assets/objects/stage.png")
	# dock 32x48, origin (16, 47): planks going north into the water
	var d := Painter.new(32, 48, 2006)
	for y in range(2, 46):
		d.hline(6, y, 20, WOOD[2] if (y / 3) % 2 == 0 else WOOD[3])
		if y % 3 == 0:
			d.hline(6, y, 20, WOOD[1])
	for py in [6, 24, 42]:
		d.rect(4, py, 3, 6, WOOD[0])
		d.rect(25, py, 3, 6, WOOD[0])
	d.outline(OUTLINE)
	_save(d, "res://assets/objects/dock.png")
	# landmark standing stone 24x36, origin (12, 35)
	var m := Painter.new(24, 36, 2007)
	m.shaded_ellipse(12, 18, 8, 15, STONE)
	m.rect(4, 26, 16, 8, STONE[2])
	for i in 9:
		m.px(6 + p_rand(i, 1) % 12, 8 + p_rand(i, 2) % 22, LEAF[3])
	for o: Vector2i in [Vector2i(0, -3), Vector2i(0, 3), Vector2i(-3, 0), Vector2i(3, 0)]:
		m.px(12 + o.x, 16 + o.y, Color("b8e6d0"))
	m.px(12, 16, Color("fff3c4"))
	m.outline(OUTLINE)
	_shadow(m, 12, 34, 10, 2)
	_save(m, "res://assets/objects/landmark.png")
	# amethyst rock 16x16, origin (8, 15)
	var a := Painter.new(16, 16, 2008)
	a.shaded_ellipse(8, 10, 6.5, 4.5, STONE)
	for c: Vector2i in [Vector2i(5, 6), Vector2i(9, 5), Vector2i(11, 8)]:
		a.vline(c.x, c.y - 2, 4, Color("9d8bc9"))
		a.vline(c.x + 1, c.y - 1, 3, Color("7865a6"))
		a.px(c.x, c.y - 3, Color("d7c6f0"))
	a.outline(OUTLINE)
	_shadow(a, 8, 14, 6.5, 1.5)
	_save(a, "res://assets/environments/rock_amethyst.png")


static func p_rand(i: int, salt: int) -> int:
	return int(Painter.noise_hash(i, salt, 99) * 1000.0)


# -------------------------------------------------------------- furniture ---

func _gen_furniture() -> void:
	# bed 32x32, origin (16, 31)
	var b := Painter.new(32, 32, 3001)
	b.rect(2, 2, 28, 28, WOOD[1])
	b.rect(4, 4, 24, 7, CREAM)
	b.rect(4, 11, 24, 17, Color("e07a9a"))
	for y in range(12, 27, 4):
		b.hline(4, y, 24, Color("f5bfd0"))
	for x in range(6, 28, 6):
		b.vline(x, 11, 17, Color("cf7389"))
	b.hline(2, 2, 28, WOOD[3])
	b.outline(OUTLINE)
	_save(b, "res://assets/objects/bed.png")
	# table 32x24, origin (16, 23)
	var t := Painter.new(32, 24, 3002)
	t.rect(2, 4, 28, 10, WOOD[2])
	t.hline(2, 4, 28, WOOD[3])
	t.rect(2, 14, 28, 2, WOOD[0])
	t.rect(4, 16, 3, 7, WOOD[1])
	t.rect(25, 16, 3, 7, WOOD[1])
	t.rect(13, 5, 6, 5, CREAM)
	t.disc(16, 5, 2.2, Color("e07a9a"))
	t.outline(OUTLINE)
	_save(t, "res://assets/objects/table.png")
	# bookshelf 32x40, origin (16, 39)
	var s := Painter.new(32, 40, 3003)
	s.rect(1, 1, 30, 38, WOOD[1])
	for shelf in 3:
		var y := 4 + shelf * 12
		s.rect(3, y, 26, 10, WOOD[0])
		var x := 4
		while x < 27:
			var bw := 2 + (x * 7 + shelf * 3) % 3
			var col: Color = [Color("b4566f"), Color("566590"), Color("5c9656"), Color("c99a55"), Color("9d8bc9")][(x + shelf) % 5]
			s.rect(x, y + 1 + (x % 2), bw, 9 - (x % 2), col)
			x += bw + 1
	s.outline(OUTLINE)
	_save(s, "res://assets/objects/bookshelf.png")
	# shop counter 48x28, origin (24, 27)
	var c := Painter.new(48, 28, 3004)
	c.rect(1, 8, 46, 18, WOOD[2])
	c.rect(1, 6, 46, 4, WOOD[3])
	for x in range(4, 46, 6):
		c.vline(x, 11, 14, WOOD[1])
	c.rect(6, 1, 8, 6, Color("c99a55"))
	c.rect(30, 2, 5, 5, Color("9d98ab"))
	c.disc(32, 1, 2.4, Color("5c9656"))
	c.px(31, 0, Color("e07a9a"))
	c.px(33, 1, Color("f2c14e"))
	c.outline(OUTLINE)
	_save(c, "res://assets/objects/counter.png")
	# potted plant 16x24, origin (8, 23)
	var pp := Painter.new(16, 24, 3005)
	pp.rect(4, 15, 8, 8, Color("c47c56"))
	pp.hline(3, 15, 10, Color("d89c78"))
	pp.shaded_disc(8, 9, 5.5, LEAF)
	pp.px(6, 7, Color("e07a9a"))
	pp.px(10, 9, Color("f2c14e"))
	pp.outline(OUTLINE)
	_save(pp, "res://assets/objects/potted_plant.png")


# ------------------------------------------------------------ forage icons ---

## Extends assets/ui/item_icons.png to 16 columns x 4 rows and draws the
## forage items in row 3 (columns listed in resources/items/forage_*.tres).
func _gen_forage_icons() -> void:
	var old := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/item_icons.png"))
	if old == null:
		push_error("[assets] item_icons.png missing (generate farming art first)")
		_ok = false
		return
	var atlas := Painter.new(maxi(old.get_width(), 256), 16 * 4, 4001)
	atlas.blit_image(old, 0, 0)
	var icons := [_ic_violet, _ic_cherry_branch, _ic_poppy, _ic_lotus, _ic_shell, _ic_clay,
		_ic_amethyst, _ic_wild_lavender, _ic_glow_moss, _ic_mushroom, _ic_pinecone, _ic_snowdrop]
	for i in icons.size():
		var p := Painter.new(16, 16, 4010 + i)
		(icons[i] as Callable).call(p)
		p.outline(OUTLINE)
		atlas.blit_image(p.image, i * 16, 48)
	_save(atlas, "res://assets/ui/item_icons.png")


func _stem(p: Painter) -> void:
	p.vline(8, 8, 7, Color("4f8a46"))
	p.px(7, 11, Color("6aa35a"))
	p.px(9, 12, Color("6aa35a"))


func _petals(p: Painter, cx: int, cy: int, c: Color, center: Color) -> void:
	for o: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0),
			Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1)]:
		p.px(cx + o.x, cy + o.y, c)
	p.px(cx, cy, center)


func _ic_violet(p: Painter) -> void:
	_stem(p)
	_petals(p, 8, 6, Color("7865a6"), Color("f2c14e"))
	p.px(7, 5, Color("9d8bc9"))


func _ic_cherry_branch(p: Painter) -> void:
	for i in 10:
		p.px(3 + i, 13 - i, Color("6b4430"))
	for c: Vector2i in [Vector2i(5, 9), Vector2i(8, 6), Vector2i(11, 4), Vector2i(10, 8)]:
		p.disc(c.x + 0.5, c.y + 0.5, 1.8, Color("f5bfd0"))
		p.px(c.x, c.y, Color("e597b2"))


func _ic_poppy(p: Painter) -> void:
	_stem(p)
	p.disc(8.5, 5.5, 3.2, Color("d9534f"))
	p.px(7, 4, Color("f08a7e"))
	p.px(8, 5, Color("3d2b3d"))


func _ic_lotus(p: Painter) -> void:
	p.ellipse(8, 12, 6, 2, Color("5c9656"))
	for o: Vector2i in [Vector2i(-3, 0), Vector2i(3, 0), Vector2i(0, -3), Vector2i(-2, -2), Vector2i(2, -2)]:
		p.px(8 + o.x, 9 + o.y, Color("f5bfd0"))
		p.px(8 + o.x, 10 + o.y, Color("e597b2"))
	p.px(8, 9, Color("f2c14e"))


func _ic_shell(p: Painter) -> void:
	p.shaded_ellipse(8, 9, 5, 4, [Color("d89c78"), Color("ecc0a4"), Color("f6d8c2"), Color("fbf3e3")])
	for x in [6, 8, 10]:
		p.vline(x, 6, 6, Color("d89c78"))


func _ic_clay(p: Painter) -> void:
	p.shaded_ellipse(8, 9, 5.5, 4.5, [Color("8a4a32"), Color("a8603f"), Color("c47c56"), Color("d89c78")])


func _ic_amethyst(p: Painter) -> void:
	for c: Vector2i in [Vector2i(6, 7), Vector2i(9, 5), Vector2i(11, 8)]:
		p.rect(c.x, c.y, 2, 7, Color("9d8bc9"))
		p.vline(c.x + 1, c.y + 1, 6, Color("7865a6"))
		p.px(c.x, c.y - 1, Color("d7c6f0"))
	p.hline(4, 14, 9, Color("9d98ab"))


func _ic_wild_lavender(p: Painter) -> void:
	for x in [6, 8, 10]:
		p.vline(x, 8, 7, Color("8fae8a"))
		for y in range(3, 8):
			p.px(x, y, Color("9d8bc9") if y % 2 else Color("c9b3e6"))


func _ic_glow_moss(p: Painter) -> void:
	p.shaded_ellipse(8, 10, 6, 4, [Color("2f5a48"), Color("427558"), Color("6fa59a"), Color("b8e6d0")])
	p.px(6, 8, Color("fff3c4"))
	p.px(10, 9, Color("fff3c4"))


func _ic_mushroom(p: Painter) -> void:
	p.rect(7, 9, 3, 5, CREAM)
	p.ellipse(8.5, 8, 5, 3, Color("b4566f"))
	p.px(6, 7, CREAM)
	p.px(10, 7, CREAM)


func _ic_pinecone(p: Painter) -> void:
	p.shaded_ellipse(8, 9, 3.5, 5, [Color("4e3326"), Color("6b4430"), Color("8a5d3f"), Color("a8774f")])
	for y in range(6, 13, 2):
		p.hline(6, y, 5, Color("4e3326"))


func _ic_snowdrop(p: Painter) -> void:
	_stem(p)
	p.rect(7, 4, 3, 4, Color("ffffff"))
	p.px(8, 8, Color("b4d48c"))
	p.px(7, 3, Color("6aa35a"))


# -------------------------------------------------------------- butterfly ---

## butterflies.png: 4 colour rows x 2 frames (wings open / closed), 8x6.
func _gen_butterflies() -> void:
	var p := Painter.new(16, 24, 5001)
	var colors := [[Color("e07a9a"), Color("f5bfd0")], [Color("9d8bc9"), Color("d7c6f0")],
		[Color("f2c14e"), Color("f9dc7c")], [Color("6c9fc4"), Color("a9d3e6")]]
	for row in 4:
		var c: Array = colors[row]
		var oy := row * 6
		# open
		p.rect(0, oy + 1, 3, 3, c[0])
		p.rect(5, oy + 1, 3, 3, c[0])
		p.px(1, oy + 1, c[1])
		p.px(6, oy + 1, c[1])
		p.vline(3, oy + 1, 4, OUTLINE)
		p.vline(4, oy + 1, 4, OUTLINE)
		# closed
		p.rect(10, oy, 2, 4, c[0])
		p.rect(12, oy, 2, 4, c[1])
		p.vline(11, oy + 1, 4, OUTLINE)
	_save(p, "res://assets/environments/butterflies.png")
