extends RefCounted
## Phase 2 art: flower growth stages, tilled-soil overlay, item icons,
## the target cursor and particle textures. Deterministic, like the rest of
## the generator. Atlas layouts are documented above each function and are
## mirrored by the game code (SoilView, ItemRegistry).

const Painter := preload("res://tools/pixel_painter.gd")

const OUTLINE := Color("3d2b3d")
const FRAME_W := 16
const FRAME_H := 32
const BASE_Y := 29
const STEM := Color("4f8a46")
const STEM_DARK := Color("3a6b3a")
const LEAF_MID := Color("6aa35a")
const LEAF_LIGHT := Color("94c472")
const WITHER := [Color("6b5038"), Color("8a6a48"), Color("a88a62")]
const DIRT := [Color("4f3427"), Color("6f4a35"), Color("8a6248"), Color("a37a5a")]
const METAL := [Color("5d5868"), Color("9d98ab"), Color("c2bdcc"), Color("e6e3ec")]
const WOOD := [Color("6b4430"), Color("8a5d3f"), Color("b07d55"), Color("cf9f72")]

## Atlas row order must match FlowerData.atlas_row in resources/flowers/*.tres.
var SPECS: Array[Dictionary] = [
	{"id": "daisy", "shape": "daisy", "petals": [Color("d9d0cb"), Color("f4eee9"), Color("ffffff")],
		"center": Color("f2c14e"), "heads": [[-3, 15], [3, 13], [0, 17]]},
	{"id": "tulip", "shape": "tulip", "petals": [Color("b4566f"), Color("e07a9a"), Color("f5bfd0")],
		"center": Color("f5bfd0"), "heads": [[-3, 13], [3, 15]]},
	{"id": "rose", "shape": "rose", "petals": [Color("8f2f4a"), Color("c4466a"), Color("e8778f")],
		"center": Color("6e1f38"), "heads": [[-4, 15], [3, 16], [0, 12]]},
	{"id": "sunflower", "shape": "sunflower", "petals": [Color("d99a1e"), Color("f2c14e"), Color("f9dc7c")],
		"center": Color("6b4430"), "heads": [[0, 7]]},
	{"id": "lavender", "shape": "lavender", "petals": [Color("6f5a9e"), Color("9d8bc9"), Color("c9b3e6")],
		"center": Color("9d8bc9"), "heads": [[-4, 14], [-1, 11], [2, 12], [5, 15]]},
	{"id": "lily", "shape": "lily", "petals": [Color("dcb2c4"), Color("f7e6ee"), Color("ffffff")],
		"center": Color("e07a9a"), "heads": [[-3, 13], [3, 11]]},
	# Phase 7 — special flowers
	{"id": "orchid", "shape": "orchid", "petals": [Color("9c4f9c"), Color("d68fd6"), Color("f2c6f2")],
		"center": Color("f2c14e"), "heads": [[-3, 12], [3, 14]]},
	{"id": "peony", "shape": "rose", "petals": [Color("c96f93"), Color("f5bfd0"), Color("fde3ea")],
		"center": Color("e597b2"), "heads": [[-3, 13], [3, 14]]},
	{"id": "cherry_blossom", "shape": "daisy", "petals": [Color("e597b2"), Color("f5bfd0"), Color("fde3ea")],
		"center": Color("c96f93"), "heads": [[-3, 14], [3, 12], [0, 16]]},
	{"id": "dahlia", "shape": "sunflower", "petals": [Color("8f2f4a"), Color("d9534f"), Color("f08a7e")],
		"center": Color("f2c14e"), "heads": [[0, 9]]},
	{"id": "iris", "shape": "tulip", "petals": [Color("566590"), Color("9d8bc9"), Color("d7c6f0")],
		"center": Color("f2c14e"), "heads": [[-3, 12], [3, 14]]},
	{"id": "lotus", "shape": "lily", "petals": [Color("c96f93"), Color("f5bfd0"), Color("fde3ea")],
		"center": Color("f2c14e"), "heads": [[-3, 14], [3, 12]]},
	# Phase 7 — rare flowers
	{"id": "golden_rose", "shape": "rose", "petals": [Color("a8783a"), Color("f2c14e"), Color("fff3c4")],
		"center": Color("c99a55"), "heads": [[-3, 14], [3, 12]]},
	{"id": "moon_flower", "shape": "daisy", "petals": [Color("a9d3e6"), Color("e4f3f8"), Color("ffffff")],
		"center": Color("c9b3e6"), "heads": [[-3, 13], [3, 12], [0, 16]]},
	{"id": "celestial_lily", "shape": "lily", "petals": [Color("6c9fc4"), Color("a9d3e6"), Color("e4f3f8")],
		"center": Color("fff3c4"), "heads": [[-3, 12], [3, 13]]},
	{"id": "blue_orchid", "shape": "orchid", "petals": [Color("3f4a6b"), Color("6c9fc4"), Color("a9d3e6")],
		"center": Color("fff3c4"), "heads": [[-3, 13], [3, 11]]},
	{"id": "star_flower", "shape": "star", "petals": [Color("d99a1e"), Color("f9dc7c"), Color("fff3c4")],
		"center": Color("ffffff"), "heads": [[-3, 13], [3, 12]]},
]

var _ok := true


func generate_all() -> bool:
	_gen_flower_atlas()
	_gen_soil_atlas()
	_gen_item_icons()
	_gen_cursor()
	_gen_effects()
	return _ok


func _save(p: Painter, path: String) -> void:
	var err := p.save(path)
	if err != OK:
		push_error("[assets] could not save %s (error %d)" % [path, err])
		_ok = false
	else:
		print("[assets] wrote ", path)


# ---------------------------------------------------------------- flowers ---

## flower_atlas.png: one row per species (SPECS order), 16x32 frames.
##   cols 0-5: seed, sprout, young, developed, budding, bloom | col 6: withered
func _gen_flower_atlas() -> void:
	var atlas := Painter.new(FRAME_W * 7, FRAME_H * SPECS.size(), 501)
	for row in SPECS.size():
		for stage in 7:
			var frame := Painter.new(FRAME_W, FRAME_H, 600 + row * 10 + stage)
			_draw_plant(frame, SPECS[row], stage)
			atlas.blit_image(frame.image, stage * FRAME_W, row * FRAME_H)
	_save(atlas, "res://assets/flowers/flower_atlas.png")


func _draw_mound(p: Painter, w: float) -> void:
	p.ellipse(8, 29.5, w, 1.8, DIRT[1])
	p.hline(int(8 - w + 1), 29, int(w * 2.0 - 2), DIRT[2])


func _draw_plant(p: Painter, spec: Dictionary, stage: int) -> void:
	var withered := stage == 6
	if stage == 0:
		_draw_mound(p, 4.0)
		p.px(7, 28, Color("e6d3a8"))
		p.px(9, 29, Color("e6d3a8"))
		p.outline(DIRT[0])
		return
	if stage == 1:
		_draw_mound(p, 3.0)
		p.vline(8, 25, 4, STEM)
		p.px(7, 25, LEAF_MID)
		p.px(6, 24, LEAF_LIGHT)
		p.px(9, 26, LEAF_MID)
		p.px(10, 25, LEAF_LIGHT)
		p.outline(STEM_DARK.darkened(0.3))
		return
	var stem: Color = WITHER[0] if withered else STEM
	var leaf: Color = WITHER[1] if withered else LEAF_MID
	var leaf_light: Color = WITHER[2] if withered else LEAF_LIGHT
	var grow_t := 0.5 if stage == 2 else 1.0
	var shape: String = spec["shape"]
	var heads: Array = spec["heads"]
	var tops: Array = []
	for head: Array in heads:
		var hx: int = 8 + int(head[0])
		var top := int(lerpf(BASE_Y, float(head[1]) + 2.0, grow_t))
		if withered:
			top += 4 # drooping
		tops.append(Vector2i(hx, top))
		var span := maxi(BASE_Y - top, 1)
		for y in range(top, BASE_Y + 1):
			var t := float(y - top) / float(span)
			var x := int(round(lerpf(hx, 8.0, t * 0.7)))
			if withered and y < top + 3:
				x += 1
			p.px(x, y, stem)
			if shape == "sunflower":
				p.px(x + 1, y, STEM_DARK if not withered else WITHER[0])
			# leaves every 4px, alternating sides
			if y > top + 2 and y < BASE_Y - 1 and (y - top) % 4 == 2:
				var side := -1 if ((y / 4) + int(head[0])) % 2 == 0 else 1
				p.px(x + side, y, leaf)
				p.px(x + side * 2, y - 1, leaf_light)
				if shape == "sunflower":
					p.px(x + side * 3, y - 1, leaf)
					p.px(x + side * 2, y, leaf)
	if shape == "lavender" and not withered:
		for lx in [5, 7, 9, 11]:
			p.vline(lx, BASE_Y - 2, 3, Color("8fae8a"))
	if stage == 4:
		for t: Vector2i in tops:
			_draw_bud(p, spec, t.x, t.y)
	elif stage == 5:
		for t: Vector2i in tops:
			_draw_head(p, spec, t.x, t.y)
	p.outline((WITHER[0] if withered else STEM_DARK).darkened(0.35))


func _draw_bud(p: Painter, spec: Dictionary, x: int, top: int) -> void:
	var petals: Array = spec["petals"]
	match spec["shape"]:
		"lavender":
			for y in range(top - 5, top + 1):
				p.px(x, y, Color("8fae8a") if y % 2 == 0 else petals[0])
		"sunflower":
			p.disc(x + 0.5, top - 1.5, 2.6, LEAF_MID)
			p.px(x - 1, top - 4, petals[1])
			p.px(x + 2, top - 3, petals[1])
		_:
			p.px(x, top - 3, petals[1])
			p.rect(x - 1, top - 2, 2, 2, petals[1])
			p.px(x - 1, top - 2, petals[2])
			p.px(x - 1, top, LEAF_MID)
			p.px(x + 1, top, LEAF_MID)


func _draw_head(p: Painter, spec: Dictionary, x: int, top: int) -> void:
	var petals: Array = spec["petals"]
	var center: Color = spec["center"]
	var cy := top - 2
	match spec["shape"]:
		"daisy":
			for o: Vector2i in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2),
					Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]:
				p.px(x + o.x, cy + o.y, petals[2] if o.y <= 0 else petals[1])
			p.px(x, cy, center)
		"tulip":
			p.rect(x - 2, cy - 2, 5, 4, petals[1])
			p.vline(x - 2, cy - 2, 4, petals[2])
			p.vline(x + 2, cy - 1, 3, petals[0])
			p.px(x - 2, cy - 3, petals[1])
			p.px(x, cy - 3, petals[2])
			p.px(x + 2, cy - 3, petals[1])
			p.px(x - 1, cy - 2, petals[0])
			p.px(x + 1, cy - 2, petals[0])
		"rose":
			p.disc(x + 0.5, cy + 0.5, 2.6, petals[1])
			p.px(x - 1, cy - 1, petals[2])
			p.px(x, cy - 1, petals[2])
			p.px(x, cy, center)
			p.px(x + 1, cy, petals[0])
			p.px(x, cy + 1, petals[0])
			p.px(x + 1, cy - 1, petals[0])
		"sunflower":
			for i in 12:
				var a := TAU * i / 12.0
				var px_ := x + 0.5 + cos(a) * 3.6
				var py_ := cy + 0.5 + sin(a) * 3.6
				p.px(int(px_), int(py_), petals[1] if i % 3 else petals[2])
				p.px(int(x + 0.5 + cos(a) * 4.4), int(cy + 0.5 + sin(a) * 4.4), petals[0] if i % 2 else petals[1])
			p.disc(x + 0.5, cy + 0.5, 2.4, center)
			p.px(x - 1, cy - 1, Color("8a5d3f"))
			p.px(x + 1, cy + 1, Color("4e3326"))
		"lavender":
			for y in range(top - 7, top + 1):
				var c: Color = petals[1] if y % 2 == 0 else petals[2]
				p.px(x, y, c)
				if y > top - 6 and y % 2 == 1:
					p.px(x - 1, y, petals[0])
					p.px(x + 1, y, petals[1])
		"orchid":
			for o: Vector2i in [Vector2i(-2, -1), Vector2i(-1, -2), Vector2i(1, -2), Vector2i(2, -1)]:
				p.px(x + o.x, cy + o.y, petals[2])
			p.hline(x - 1, cy, 3, petals[1])
			p.px(x - 2, cy + 1, petals[1])
			p.px(x + 2, cy + 1, petals[1])
			p.px(x, cy + 1, petals[0])
			p.px(x, cy - 1, center)
		"star":
			for o: Vector2i in [Vector2i(0, -3), Vector2i(0, -2), Vector2i(-3, -1), Vector2i(-2, -1), Vector2i(3, -1),
					Vector2i(2, -1), Vector2i(-2, 2), Vector2i(2, 2), Vector2i(-1, 1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
				p.px(x + o.x, cy + o.y, petals[2] if o.y < 0 else petals[1])
			p.px(x, cy, center)
			p.px(x, cy - 4, Color("fff3c4", 0.7))
		"lily":
			for o: Vector2i in [Vector2i(0, -2), Vector2i(-2, -1), Vector2i(2, -1), Vector2i(-2, 1),
					Vector2i(2, 1), Vector2i(0, 2), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1),
					Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1)]:
				p.px(x + o.x, cy + o.y, petals[2] if o.y < 0 else petals[1])
			p.px(x, cy, center)
			p.px(x, cy + 1, petals[0])


# ------------------------------------------------------------------- soil ---

## soil_atlas.png (16x16 tiles):
##   row 0: tilled, dry  — column = neighbour mask (N=1, E=2, S=4, W=8)
##   row 1: tilled, wet  — same
##   row 2, col 0: fertiliser specks overlay
func _gen_soil_atlas() -> void:
	var p := Painter.new(FRAME_W * 16, FRAME_W * 3, 707)
	for mask in 16:
		_draw_tilled(p, mask * 16, 0, mask, false)
		_draw_tilled(p, mask * 16, 16, mask, true)
	for i in 14:
		var fx := p.rng.randi_range(2, 13)
		var fy := 32 + p.rng.randi_range(2, 13)
		p.px(fx, fy, Color("f3e3a0") if i % 3 else Color("9cc46f"))
		if i % 4 == 0:
			p.px(fx + 1, fy, Color("e6d3a8"))
	_save(p, "res://assets/environments/soil_atlas.png")


func _draw_tilled(p: Painter, ox: int, oy: int, mask: int, wet: bool) -> void:
	var base := Color("5e3f2e") if wet else Color("7a5440")
	var furrow := Color("4a3126") if wet else Color("61412f")
	var ridge := Color("6f4c3a") if wet else Color("957054")
	var rim := Color("3f2a20")
	var n := (mask & 1) == 0
	var e := (mask & 2) == 0
	var s := (mask & 4) == 0
	var w := (mask & 8) == 0
	var x0 := 1 if w else 0
	var x1 := 14 if e else 15
	var y0 := 1 if n else 0
	var y1 := 14 if s else 15
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var c := base
			if y % 4 == 3:
				c = furrow
			elif y % 4 == 1 and Painter.noise_hash(x + mask, y, 77) > 0.3:
				c = ridge
			p.px(ox + x, oy + y, c)
	if wet:
		for i in 3:
			p.px(ox + 3 + i * 4, oy + 2 + (i * 5) % 11, Color("7d6a66"))
	# rims on open sides; corners are left transparent for a rounded bed
	if n:
		p.hline(ox + x0, oy, x1 - x0 + 1, rim)
	if s:
		p.hline(ox + x0, oy + 15, x1 - x0 + 1, rim)
		p.hline(ox + x0, oy + 14, x1 - x0 + 1, furrow)
	if w:
		p.vline(ox, oy + y0, y1 - y0 + 1, rim)
	if e:
		p.vline(ox + 15, oy + y0, y1 - y0 + 1, rim)
	if n and w:
		p.image.set_pixel(ox + 1, oy + 1, rim)
	if n and e:
		p.image.set_pixel(ox + 14, oy + 1, rim)
	if s and w:
		p.image.set_pixel(ox + 1, oy + 14, rim)
	if s and e:
		p.image.set_pixel(ox + 14, oy + 14, rim)


# ------------------------------------------------------------------ icons ---

## item_icons.png (16x16):
##   row 0: hoe, watering can, scythe, pickaxe, fertiliser, stone, fiber
##   row 1: seed packets (SPECS order) | row 2: cut flowers (SPECS order)
func _gen_item_icons() -> void:
	var atlas := Painter.new(16 * 32, 16 * 3, 909)
	var tools := [_icon_hoe, _icon_can, _icon_scythe, _icon_pickaxe, _icon_fertilizer, _icon_stone, _icon_fiber]
	for i in tools.size():
		var p := Painter.new(16, 16, 910 + i)
		(tools[i] as Callable).call(p)
		p.outline(OUTLINE)
		atlas.blit_image(p.image, i * 16, 0)
	for i in SPECS.size():
		var seed_p := Painter.new(16, 16, 930 + i)
		_icon_seed_packet(seed_p, SPECS[i])
		seed_p.outline(OUTLINE)
		atlas.blit_image(seed_p.image, i * 16, 16)
		var flower_p := Painter.new(16, 16, 950 + i)
		_icon_flower(flower_p, SPECS[i])
		flower_p.outline(STEM_DARK.darkened(0.4))
		atlas.blit_image(flower_p.image, i * 16, 32)
	_save(atlas, "res://assets/ui/item_icons.png")


func _diag(p: Painter, x0: int, y0: int, x1: int, y1: int, c: Color, c2: Color) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	for i in steps + 1:
		var t := float(i) / maxf(steps, 1)
		var x := int(round(lerpf(x0, x1, t)))
		var y := int(round(lerpf(y0, y1, t)))
		p.px(x, y, c)
		p.px(x + 1, y, c2)


func _icon_hoe(p: Painter) -> void:
	_diag(p, 3, 14, 10, 4, WOOD[2], WOOD[1])
	p.rect(9, 2, 5, 2, METAL[2])
	p.hline(9, 2, 5, METAL[3])
	p.rect(12, 4, 2, 3, METAL[1])


func _icon_can(p: Painter) -> void:
	p.rect(3, 7, 8, 7, Color("8fb3c9"))
	p.vline(3, 7, 7, Color("b9d3e2"))
	p.vline(10, 7, 7, Color("6c8ea6"))
	p.hline(3, 13, 8, Color("6c8ea6"))
	_diag(p, 10, 10, 13, 5, Color("8fb3c9"), Color("6c8ea6"))
	p.rect(13, 4, 2, 2, Color("b9d3e2"))
	p.hline(4, 4, 6, Color("6c8ea6"))
	p.vline(4, 4, 3, Color("6c8ea6"))
	p.vline(9, 4, 3, Color("6c8ea6"))
	p.px(5, 9, Color("e07a9a"))
	p.px(6, 10, Color("e07a9a"))


func _icon_scythe(p: Painter) -> void:
	_diag(p, 5, 14, 8, 3, WOOD[2], WOOD[1])
	for i in 7:
		var x := 8 + i
		var y := 2 + int(round(pow(i / 6.0, 2.0) * 5.0))
		p.px(x, y, METAL[3] if i < 3 else METAL[2])
		p.px(x, y + 1, METAL[1])


func _icon_pickaxe(p: Painter) -> void:
	_diag(p, 4, 14, 9, 5, WOOD[2], WOOD[1])
	for i in 11:
		var x := 3 + i
		var y := 5 - int(round(sin(i / 10.0 * PI) * 3.0))
		p.px(x, y, METAL[2])
		p.px(x, y + 1, METAL[1])
	p.px(8, 2, METAL[3])


func _icon_fertilizer(p: Painter) -> void:
	p.rect(3, 5, 10, 9, Color("c9a26e"))
	p.vline(3, 5, 9, Color("ddbb8a"))
	p.vline(12, 5, 9, Color("a8834f"))
	p.hline(3, 13, 10, Color("a8834f"))
	p.rect(6, 2, 4, 3, Color("ddbb8a"))
	p.hline(5, 4, 6, Color("8a5d3f"))
	p.px(7, 8, LEAF_LIGHT)
	p.px(8, 9, LEAF_MID)
	p.px(7, 10, LEAF_MID)
	p.px(9, 8, LEAF_LIGHT)


func _icon_stone(p: Painter) -> void:
	p.shaded_ellipse(8, 9, 5.5, 4.5, [Color("5d5868"), Color("7b7689"), Color("9d98ab"), Color("c2bdcc")])


func _icon_fiber(p: Painter) -> void:
	for i in 5:
		_diag(p, 4 + i, 14, 6 + i * 2, 2 + i % 2, LEAF_MID if i % 2 else LEAF_LIGHT, STEM)
	p.hline(4, 9, 8, Color("c9a26e"))


func _icon_seed_packet(p: Painter, spec: Dictionary) -> void:
	var petals: Array = spec["petals"]
	p.rect(3, 2, 10, 12, Color("fbf3e3"))
	p.vline(12, 2, 12, Color("e3d1b8"))
	p.rect(3, 2, 10, 2, petals[0])
	p.disc(8, 8.5, 2.6, petals[1])
	p.px(7, 7, petals[2])
	p.px(8, 8, spec["center"])
	p.px(8, 12, STEM)
	p.px(9, 11, LEAF_MID)


func _icon_flower(p: Painter, spec: Dictionary) -> void:
	p.vline(8, 9, 6, STEM)
	p.px(7, 12, LEAF_MID)
	p.px(6, 11, LEAF_LIGHT)
	p.px(9, 13, LEAF_MID)
	var top := 10 if spec["shape"] != "lavender" else 11
	if spec["shape"] == "sunflower":
		top = 9
	_draw_head(p, spec, 8, top)


# --------------------------------------------------------- cursor + fx ---

func _gen_cursor() -> void:
	var p := Painter.new(18, 18, 3)
	var c := Color("fbf3e3")
	for corner: Vector2i in [Vector2i(1, 1), Vector2i(16, 1), Vector2i(1, 16), Vector2i(16, 16)]:
		var dx := 1 if corner.x == 1 else -1
		var dy := 1 if corner.y == 1 else -1
		for i in 4:
			p.px(corner.x + dx * i, corner.y, c)
			p.px(corner.x, corner.y + dy * i, c)
	p.outline(OUTLINE)
	_save(p, "res://assets/ui/cursor.png")


func _gen_effects() -> void:
	var dust := Painter.new(3, 3, 1)
	dust.rect(0, 1, 3, 1, Color("a37a5a"))
	dust.px(1, 0, Color("c4a87c"))
	dust.px(1, 2, Color("8a6248"))
	_save(dust, "res://assets/effects/dust.png")
	var drop := Painter.new(2, 3, 2)
	drop.px(0, 0, Color("e4f3f8"))
	drop.rect(0, 1, 2, 2, Color("86bcd8"))
	_save(drop, "res://assets/effects/droplet.png")
	var leaf := Painter.new(3, 2, 3)
	leaf.hline(0, 0, 2, LEAF_LIGHT)
	leaf.hline(1, 1, 2, LEAF_MID)
	_save(leaf, "res://assets/effects/leaf.png")
	var sparkle := Painter.new(3, 3, 4)
	sparkle.px(1, 0, Color("fff3c4"))
	sparkle.px(0, 1, Color("fff3c4"))
	sparkle.px(2, 1, Color("fff3c4"))
	sparkle.px(1, 2, Color("fff3c4"))
	sparkle.px(1, 1, Color("ffffff"))
	_save(sparkle, "res://assets/effects/sparkle.png")
