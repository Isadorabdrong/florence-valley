extends RefCounted
## Phase 7 art: the greenhouse (ruined and restored), the raised flower bed
## and icons for placeable builds and upgraded tools (item_icons.png row 5).
## Build icons reuse the real sprites, shrunk to 16x16, so they always match.

const Painter := preload("res://tools/pixel_painter.gd")
const OUTLINE := Color("3d2b3d")
const WOOD := [Color("6b4430"), Color("8a5d3f"), Color("b07d55"), Color("cf9f72")]
const FRAME := [Color("6f8a6a"), Color("9cb894"), Color("dceacf")]
const GLASS := [Color("86bcd8"), Color("a9d3e6"), Color("e4f3f8")]

var _ok := true


func generate_all() -> bool:
	_greenhouse("greenhouse_ruined", true)
	_greenhouse("greenhouse", false)
	_raised_bed()
	_icons()
	return _ok


func _save(p: Painter, path: String) -> void:
	if p.save(path) != OK:
		push_error("[assets] could not save %s" % path)
		_ok = false
	else:
		print("[assets] wrote ", path)


## 80x72, origin (40, 71): glass house with a door in the middle.
func _greenhouse(name: String, ruined: bool) -> void:
	var p := Painter.new(80, 72, 7001 if ruined else 7002)
	var base_y := 68
	# glass walls
	for y in range(30, base_y):
		for x in range(4, 76):
			var c: Color = GLASS[1]
			if (x + y) % 9 == 0:
				c = GLASS[2]
			if ruined:
				c = c.lerp(Color("9a9a7a"), 0.45)
				if Painter.noise_hash(x / 6, y / 6, 3) > 0.78:
					c = Color(0.18, 0.14, 0.18, 0.0) # broken pane (transparent)
			p.px(x, y, c)
	# gable roof (glass triangle)
	for y in range(4, 31):
		var hw := int(lerpf(4.0, 38.0, float(y - 4) / 26.0))
		for x in range(40 - hw, 40 + hw + 1):
			var c: Color = GLASS[2] if (x - y) % 7 == 0 else GLASS[0].lerp(GLASS[1], 0.5)
			if ruined:
				c = c.lerp(Color("8a8a6a"), 0.5)
				if Painter.noise_hash(x / 5, y / 5, 9) > 0.8:
					continue
			p.px(x, y, c)
	# frame
	var frame: Color = FRAME[1] if not ruined else Color("8a7a6a")
	for x in range(4, 77, 12):
		p.rect(x, 30, 2, base_y - 30, frame)
	p.rect(4, 30, 72, 2, frame)
	p.rect(4, 48, 72, 2, frame)
	for i in 27:
		p.px(40 - int(i * 36.0 / 26.0), 4 + i, frame)
		p.px(40 + int(i * 36.0 / 26.0), 4 + i, frame)
	p.vline(40, 4, 27, frame)
	# foundation
	p.rect(2, base_y - 2, 76, 4, Color("9d98ab"))
	p.hline(2, base_y - 2, 76, Color("c2bdcc"))
	# door
	p.rect(34, 46, 12, 20, frame)
	p.rect(36, 48, 8, 18, GLASS[1] if not ruined else Color("6a6a5a"))
	if ruined:
		p.rect(33, 52, 14, 2, WOOD[2])
		p.rect(33, 58, 14, 2, WOOD[2])
		for i in 40:
			var vx := 4 + int(Painter.noise_hash(i, 1, 4) * 72.0)
			var vy := 30 + int(Painter.noise_hash(1, i, 4) * 36.0)
			p.px(vx, vy, Color("5c9656"))
			p.px(vx, vy + 1, Color("3f7a4a"))
	else:
		# plants visible through the glass
		for i in 14:
			var fx := 8 + i * 5
			if fx > 31 and fx < 48:
				continue
			p.disc(fx, 60, 3, Color("5c9656"))
			p.px(fx, 57, [Color("e07a9a"), Color("f2c14e"), Color("9d8bc9"), Color("ffffff")][i % 4])
	p.outline(OUTLINE)
	_save(p, "res://assets/buildings/%s.png" % name)


## 16x20 raised bed with flowers, origin (8, 19).
func _raised_bed() -> void:
	var p := Painter.new(16, 20, 7010)
	p.rect(1, 10, 14, 8, WOOD[2])
	p.hline(1, 10, 14, WOOD[3])
	p.hline(1, 17, 14, WOOD[0])
	p.rect(2, 8, 12, 3, Color("7a5440"))
	for i in 5:
		var x := 3 + i * 2
		p.vline(x, 4, 5, Color("4f8a46"))
		p.disc(x + 0.5, 4, 1.4, [Color("e07a9a"), Color("f2c14e"), Color("9d8bc9"), Color("fbf7f2"), Color("e597b2")][i])
	p.outline(OUTLINE)
	_save(p, "res://assets/objects/raised_bed.png")


## item_icons.png row 5. Column order must match resources/build/*.tres.
func _icons() -> void:
	var old := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/item_icons.png"))
	var atlas := Painter.new(maxi(old.get_width(), 512), 16 * 6, 7020)
	atlas.blit_image(old, 0, 0)
	var terrain := Image.load_from_file(ProjectSettings.globalize_path("res://assets/environments/terrain_atlas.png"))
	var fence := Image.load_from_file(ProjectSettings.globalize_path("res://assets/objects/fence_atlas.png"))
	var sources := [
		fence.get_region(Rect2i(16 * 10, 0, 16, 16)), # fence (E+W)
		terrain.get_region(Rect2i(16 * 15, 16 * 4, 16, 16)), # stone path
		_load("raised_bed.png", "objects"),
		_load("bench.png", "objects"),
		_load("lamp.png", "objects"),
		_load("potted_plant.png", "objects"),
		_load("tree_cherry.png", "environments"),
		_load("tree_oak.png", "environments"),
		_load("fountain.png", "objects"),
		terrain.get_region(Rect2i(16 * 15, 16 * 2, 16, 16)), # pond
		_load("table.png", "objects"),
		_load("bookshelf.png", "objects"),
	]
	for i in sources.size():
		var img: Image = sources[i]
		atlas.blit_image(_fit(img), i * 16, 80)
	# upgraded tools: copper can, steel hoe
	var can := Painter.new(16, 16, 7030)
	can.rect(3, 7, 8, 7, Color("c47c56"))
	can.vline(3, 7, 7, Color("d89c78"))
	can.vline(10, 7, 7, Color("8a4a32"))
	can.hline(3, 13, 8, Color("8a4a32"))
	for i in 4:
		can.px(10 + i, 10 - i, Color("c47c56"))
		can.px(11 + i, 10 - i, Color("8a4a32"))
	can.rect(13, 4, 2, 2, Color("d89c78"))
	can.hline(4, 4, 6, Color("8a4a32"))
	can.vline(4, 4, 3, Color("8a4a32"))
	can.vline(9, 4, 3, Color("8a4a32"))
	can.outline(OUTLINE)
	atlas.blit_image(can.image, 12 * 16, 80)
	var hoe := Painter.new(16, 16, 7031)
	for i in 11:
		hoe.px(3 + int(i * 0.7), 14 - i, WOOD[2])
		hoe.px(4 + int(i * 0.7), 14 - i, WOOD[1])
	hoe.rect(8, 2, 6, 2, Color("e6e3ec"))
	hoe.hline(8, 2, 6, Color("ffffff"))
	hoe.rect(12, 4, 2, 3, Color("9d98ab"))
	hoe.outline(OUTLINE)
	atlas.blit_image(hoe.image, 13 * 16, 80)
	_save(atlas, "res://assets/ui/item_icons.png")


func _load(file: String, folder: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path("res://assets/%s/%s" % [folder, file]))


## Shrinks (nearest) and centres an image inside 16x16.
func _fit(img: Image) -> Image:
	var copy := img.duplicate() as Image
	var used := copy.get_used_rect()
	if used.size.x > 0:
		copy = copy.get_region(used)
	var scale := minf(16.0 / copy.get_width(), 16.0 / copy.get_height())
	if scale < 1.0:
		copy.resize(maxi(1, int(copy.get_width() * scale)), maxi(1, int(copy.get_height() * scale)), Image.INTERPOLATE_NEAREST)
	var out := Image.create_empty(16, 16, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	out.blit_rect(copy, Rect2i(Vector2i.ZERO, copy.get_size()), Vector2i((16 - copy.get_width()) / 2, (16 - copy.get_height()) / 2))
	return out
