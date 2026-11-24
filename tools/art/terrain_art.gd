extends RefCounted
## Phase 4 terrain rows for assets/environments/terrain_atlas.png:
##   row 4: cobblestone  (16 neighbour masks)
##   row 5: sand         (16 masks)
##   row 6: cliff        (16 masks, solid)
##   row 7: forest floor x4 | lavender field x4 | meadow x4 | grove floor x4
##   row 8: wood floor x4 | rug x4 | wall face | wall top | doormat

const Painter := preload("res://tools/pixel_painter.gd")
const T := 16
const GRASS := Color("8db86b")


func draw_rows(p: Painter) -> void:
	for mask in 16:
		_cobble(p, mask * T, 4 * T, mask)
		_sand(p, mask * T, 5 * T, mask)
		_cliff(p, mask * T, 6 * T, mask)
	for v in 4:
		_ground(p, v * T, 7 * T, v, Color("6f9a58"), [Color("5f8a4c"), Color("8a6a48"), Color("c96f93")], 3)
		_ground(p, (4 + v) * T, 7 * T, v, Color("8fae7a"), [Color("9d8bc9"), Color("7865a6"), Color("c9b3e6")], 9)
		_ground(p, (8 + v) * T, 7 * T, v, Color("9cc67a"), [Color("f5bfd0"), Color("fbf7f2"), Color("f2c14e")], 7)
		_ground(p, (12 + v) * T, 7 * T, v, Color("4f7a52"), [Color("3f6646"), Color("6fa59a"), Color("b8e6d0")], 4)
		_wood(p, v * T, 8 * T, v)
		_rug(p, (4 + v) * T, 8 * T, v)
	_wall_face(p, 8 * T, 8 * T)
	_wall_top(p, 9 * T, 8 * T)
	_wood(p, 10 * T, 8 * T, 0)
	p.rect(10 * T + 3, 8 * T + 4, 10, 8, Color("b4566f"))
	p.rect(10 * T + 4, 8 * T + 5, 8, 6, Color("e07a9a"))
	for x in range(4, 12, 2):
		p.vline(10 * T + x, 8 * T + 5, 6, Color("cf7389"))


## Grass fringe on open sides (mask bit clear) like the path tiles.
func _fringe(p: Painter, ox: int, oy: int, mask: int, shade: Color, salt: int) -> void:
	for pass_i in 2:
		for i in T:
			var d := 1 + int(Painter.noise_hash(i, mask, salt) * 2.0)
			var col := shade if pass_i == 0 else GRASS
			var depth := d + 1 if pass_i == 0 else d
			for k in depth:
				if (mask & 1) == 0:
					p.px(ox + i, oy + k, col)
				if (mask & 2) == 0:
					p.px(ox + T - 1 - k, oy + i, col)
				if (mask & 4) == 0:
					p.px(ox + i, oy + T - 1 - k, col)
				if (mask & 8) == 0:
					p.px(ox + k, oy + i, col)


func _cobble(p: Painter, ox: int, oy: int, mask: int) -> void:
	p.rect(ox, oy, T, T, Color("a89d90"))
	var stones := [[1, 1, 6, 4], [8, 1, 7, 4], [1, 6, 4, 4], [6, 6, 5, 4], [12, 6, 3, 4],
		[1, 11, 7, 4], [9, 11, 6, 4]]
	for s: Array in stones:
		var tone := Painter.noise_hash(s[0] + mask, s[1], 5)
		var c := Color("d6cbbb") if tone > 0.5 else Color("c7bba9")
		p.rect(ox + s[0], oy + s[1], s[2], s[3], c)
		p.hline(ox + s[0], oy + s[1], s[2], Color("e6ddd0"))
		p.hline(ox + s[0], oy + s[1] + s[3] - 1, s[2], Color("b3a797"))
	_fringe(p, ox, oy, mask, Color("9c9184"), 13)


func _sand(p: Painter, ox: int, oy: int, mask: int) -> void:
	p.rect(ox, oy, T, T, Color("ecd9b0"))
	for y in T:
		for x in T:
			var n := Painter.noise_hash(x + mask * 3, y, 17)
			if n < 0.1:
				p.px(ox + x, oy + y, Color("dcc69a"))
			elif n > 0.95:
				p.px(ox + x, oy + y, Color("f8ecd2"))
	p.px(ox + 5, oy + 9, Color("f5bfd0"))
	p.px(ox + 11, oy + 4, Color("c2bdcc"))
	_fringe(p, ox, oy, mask, Color("d8c091"), 23)


func _cliff(p: Painter, ox: int, oy: int, mask: int) -> void:
	var tones := [Color("6e6a7a"), Color("8d899a"), Color("a7a2b3"), Color("c2bdcc")]
	for y in T:
		for x in T:
			var n := Painter.noise_hash(x + mask * 7, y, 31)
			var t := 0.55 + (n - 0.5) * 0.4 - (0.15 if (y % 5) == 4 else 0.0)
			p.px(ox + x, oy + y, p.dithered_tone(tones, t, x, y, 0.15))
	if (mask & 1) == 0:
		p.hline(ox, oy, T, GRASS)
		p.hline(ox, oy + 1, T, Color("6a9853"))
		p.hline(ox, oy + 2, T, tones[3])
	if (mask & 4) == 0:
		p.rect(ox, oy + T - 5, T, 4, tones[0])
		p.hline(ox, oy + T - 6, T, tones[1])
		p.hline(ox, oy + T - 1, T, Color("4f4a5c"))
	if (mask & 8) == 0:
		p.vline(ox, oy, T, tones[3])
	if (mask & 2) == 0:
		p.vline(ox + T - 1, oy, T, tones[0])


func _ground(p: Painter, ox: int, oy: int, v: int, base: Color, specks: Array, count: int) -> void:
	p.rect(ox, oy, T, T, base)
	for y in T:
		for x in T:
			var n := Painter.noise_hash(x + v * 19, y + count, 43)
			if n < 0.08:
				p.px(ox + x, oy + y, base.darkened(0.12))
			elif n > 0.95:
				p.px(ox + x, oy + y, base.lightened(0.12))
	for i in count:
		var x := ox + 1 + int(Painter.noise_hash(i, v, 51 + count) * 13.0)
		var y := oy + 1 + int(Painter.noise_hash(v, i, 57 + count) * 13.0)
		var c: Color = specks[i % specks.size()]
		p.px(x, y, c)
		if count >= 7 and i % 2 == 0:
			p.px(x, y + 1, base.darkened(0.2))


func _wood(p: Painter, ox: int, oy: int, v: int) -> void:
	p.rect(ox, oy, T, T, Color("c89c6c"))
	for row in 4:
		var y := oy + row * 4
		p.hline(ox, y + 3, T, Color("a87c52"))
		p.hline(ox, y, T, Color("d8b082"))
		var seam := ox + (row * 7 + v * 5) % T
		p.vline(seam, y, 3, Color("a87c52"))
	p.px(ox + 3 + v, oy + 6, Color("b48a5e"))


func _rug(p: Painter, ox: int, oy: int, v: int) -> void:
	p.rect(ox, oy, T, T, Color("cf7389"))
	for y in T:
		for x in T:
			if (x + y + v) % 6 == 0:
				p.px(ox + x, oy + y, Color("e39aa9"))
			elif (x - y + 16 + v) % 8 == 0:
				p.px(ox + x, oy + y, Color("b4566f"))
	p.disc(ox + 8, oy + 8, 2.2, Color("fbf3e3"))
	p.px(ox + 8, oy + 8, Color("f2c14e"))


func _wall_face(p: Painter, ox: int, oy: int) -> void:
	p.rect(ox, oy, T, T, Color("f1e4cc"))
	for x in range(1, T, 4):
		p.vline(ox + x, oy, 10, Color("f5d3d9"))
	p.px(ox + 3, oy + 4, Color("e597b2"))
	p.px(ox + 11, oy + 7, Color("e597b2"))
	p.rect(ox, oy + 10, T, 6, Color("a8774f"))
	p.hline(ox, oy + 10, T, Color("cf9f72"))
	p.hline(ox, oy + 15, T, Color("6b4430"))
	p.vline(ox + 7, oy + 11, 4, Color("8a5d3f"))


func _wall_top(p: Painter, ox: int, oy: int) -> void:
	p.rect(ox, oy, T, T, Color("6b4430"))
	p.hline(ox, oy, T, Color("8a5d3f"))
	for y in range(3, T, 5):
		p.hline(ox, oy + y, T, Color("5a3826"))
