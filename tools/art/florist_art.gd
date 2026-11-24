extends RefCounted
## Phase 5 art: bouquet icons (item_icons.png row 4), the restored flower
## shop, its furniture and decorations, customer sprite sheets and the
## "waiting" bubble. Deterministic.

const Painter := preload("res://tools/pixel_painter.gd")
const PlayerArt := preload("res://tools/art/player_art.gd")
const VillageArt := preload("res://tools/art/village_art.gd")

const OUTLINE := Color("3d2b3d")
const WOOD := [Color("6b4430"), Color("8a5d3f"), Color("b07d55"), Color("cf9f72")]
const CREAM := Color("fbf3e3")
const STEM := Color("4f8a46")

## Customer heads (rows 0-12); bodies come from the player art (rows 13-23).
const HEAD_DOWN_LONG: Array[String] = [
	"................", "................", "................",
	".....oooooo.....",
	"....okkkkkko....",
	"...okkkkkkkko...",
	"...okKkkkkKko...",
	"...okkkkkkkko...",
	"...okssssssko...",
	"...oksessesko...",
	"...okcsssscko...",
	"...okKsSSsKko...",
	"...okKossoKko...",
]
const HEAD_DOWN_SHORT: Array[String] = [
	"................", "................", "................",
	".....oooooo.....",
	"....okkkkkko....",
	"...okkkkkkkko...",
	"...okKkkkkKko...",
	"...okkkkkkkko...",
	"...okssssssko...",
	"...oksessesko...",
	"...okcsssscko...",
	"....oKsSSsKo....",
	".....ossssso....",
]
const HEAD_UP: Array[String] = [
	"................", "................", "................",
	".....oooooo.....",
	"....okkkkkko....",
	"...okkkkkkkko...",
	"...okkkKKkkko...",
	"...okkkkkkkko...",
	"...okkkkkkkko...",
	"...okkkKKkkko...",
	"...okkkkkkkko...",
	"...oKkkkkkkKo...",
	"...okKkkkkKko...",
]
const HEAD_RIGHT: Array[String] = [
	"................", "................", "................",
	"....oooooo......",
	"...okkkkkkoo....",
	"..okkkkkkkkko...",
	"..okKkkkkkkko...",
	"...okkkkssssso..",
	"...okkkkssssso..",
	"...okkkkssseso..",
	"...okkkksscsso..",
	"...okKkkssssSo..",
	"...okKkoSsso....",
]

var _ok := true


func generate_all() -> bool:
	_gen_bouquet_icons()
	_gen_shop_building()
	_gen_furniture()
	_gen_customers()
	_gen_bubble()
	return _ok


func _save(p: Painter, path: String) -> void:
	var err := p.save(path)
	if err != OK:
		push_error("[assets] could not save %s (error %d)" % [path, err])
		_ok = false
	else:
		print("[assets] wrote ", path)


# --------------------------------------------------------------- bouquets ---

## Column = "icon" in data/recipes/bouquets.json.
func _gen_bouquet_icons() -> void:
	var old := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/item_icons.png"))
	if old == null:
		push_error("[assets] item_icons.png missing")
		_ok = false
		return
	var atlas := Painter.new(maxi(old.get_width(), 256), 16 * 5, 6001)
	atlas.blit_image(old, 0, 0)
	var specs := [
		# paper, paper shade, ribbon, flower colours
		[Color("d8b98a"), Color("b8976a"), Color("e07a9a"), [Color("fbf7f2"), Color("f2c14e"), Color("e07a9a")]],
		[Color("e6f0d8"), Color("b4d48c"), Color("f2c14e"), [Color("ffffff"), Color("ffffff"), Color("fbf7f2")]],
		[Color("fde3ea"), Color("f5bfd0"), Color("86b27a"), [Color("e07a9a"), Color("ffffff"), Color("f5bfd0")]],
		[Color("fff3c4"), Color("f9dc7c"), Color("9d8bc9"), [Color("f2c14e"), Color("9d8bc9"), Color("d9534f")]],
		[Color("f5bfd0"), Color("e597b2"), Color("c4466a"), [Color("c4466a"), Color("8f2f4a"), Color("e07a9a")]],
		[Color("d7c6f0"), Color("a98bd6"), Color("fbf3e3"), [Color("ffffff"), Color("9d8bc9"), Color("c4466a")]],
		[Color("c2d8b4"), Color("86a37a"), Color("c99a55"), [Color("7865a6"), Color("d9534f"), Color("c9b3e6")]],
		[Color("c9e5f0"), Color("86bcd8"), Color("fbf3e3"), [Color("ffffff"), Color("ffffff"), Color("8a5d3f")]],
		[Color("4a4656"), Color("2f2a3a"), Color("f2c14e"), [Color("f5bfd0"), Color("6fa59a"), Color("ffffff")]],
		# Phase 7 recipes: peony, oriental, autumn, crown, celestial, blossom
		[Color("fde3ea"), Color("f5bfd0"), Color("c96f93"), [Color("f5bfd0"), Color("fde3ea"), Color("e07a9a")]],
		[Color("2f5a48"), Color("223f37"), Color("f2c14e"), [Color("d68fd6"), Color("9d8bc9"), Color("f5bfd0")]],
		[Color("d8b98a"), Color("b8976a"), Color("8a4a32"), [Color("d9534f"), Color("8f2f4a"), Color("f2c14e")]],
		[Color("fff3c4"), Color("f2c14e"), Color("c99a55"), [Color("f2c14e"), Color("e4f3f8"), Color("fff3c4")]],
		[Color("3f4a6b"), Color("2f3654"), Color("e4f3f8"), [Color("a9d3e6"), Color("6c9fc4"), Color("b8e6d0")]],
		[Color("fde3ea"), Color("f5bfd0"), Color("86b27a"), [Color("f5bfd0"), Color("e597b2"), Color("fde3ea")]],
	]
	for i in specs.size():
		var p := Painter.new(16, 16, 6010 + i)
		_bouquet(p, specs[i], i == 8 or i == 12 or i == 13)
		p.outline(OUTLINE)
		atlas.blit_image(p.image, i * 16, 64)
	_save(atlas, "res://assets/ui/item_icons.png")


func _bouquet(p: Painter, spec: Array, sparkle: bool) -> void:
	# stems
	for x in [6, 8, 10]:
		p.vline(x, 8, 4, STEM)
	# paper cone
	for y in range(7, 15):
		var hw := lerpf(5.5, 1.0, float(y - 7) / 7.0)
		for x in range(int(8 - hw), int(8 + hw) + 1):
			p.px(x, y, spec[0] if x < 8 else spec[1])
	p.hline(6, 11, 5, spec[2])
	p.px(7, 12, spec[2])
	p.px(9, 12, spec[2])
	# blooms
	var colors: Array = spec[3]
	var heads := [Vector2i(5, 5), Vector2i(8, 3), Vector2i(11, 5), Vector2i(7, 7), Vector2i(10, 7)]
	for j in heads.size():
		var h: Vector2i = heads[j]
		p.disc(h.x + 0.5, h.y + 0.5, 1.7, colors[j % colors.size()])
		p.px(h.x, h.y, (colors[j % colors.size()] as Color).lightened(0.35))
	p.px(4, 7, Color("6aa35a"))
	p.px(12, 7, Color("6aa35a"))
	if sparkle:
		p.px(2, 2, Color("fff3c4"))
		p.px(13, 1, Color("fff3c4"))
		p.px(14, 10, Color("fff3c4"))


# --------------------------------------------------------------- building ---

func _gen_shop_building() -> void:
	var v := VillageArt.new()
	v._building("florist", 96, 88, {
		"wall": [Color("e8b4c0"), Color("f5d3d9"), Color("fde3ea")],
		"roof": [Color("8f3f58"), Color("b4566f"), Color("cf7389"), Color("e39aa9"), Color("f2bfc8")],
		"awning": [Color("e07a9a"), CREAM], "windows": 2, "sign": "flower"})
	if not v._ok:
		_ok = false


# -------------------------------------------------------------- furniture ---

func _gen_furniture() -> void:
	# display stand 32x24, origin (16, 23): two tiers holding items
	var s := Painter.new(32, 24, 6101)
	s.rect(2, 8, 28, 4, WOOD[2])
	s.hline(2, 8, 28, WOOD[3])
	s.rect(2, 16, 28, 4, WOOD[2])
	s.hline(2, 16, 28, WOOD[3])
	s.rect(3, 12, 2, 11, WOOD[1])
	s.rect(27, 12, 2, 11, WOOD[1])
	s.rect(3, 20, 26, 2, WOOD[0])
	s.outline(OUTLINE)
	_save(s, "res://assets/objects/display_stand.png")
	# workbench 32x24, origin (16, 23)
	var w := Painter.new(32, 24, 6102)
	w.rect(1, 6, 30, 9, WOOD[2])
	w.hline(1, 6, 30, WOOD[3])
	w.rect(1, 15, 30, 2, WOOD[0])
	w.rect(3, 17, 3, 6, WOOD[1])
	w.rect(26, 17, 3, 6, WOOD[1])
	w.rect(4, 2, 10, 5, Color("f5d3d9"))
	w.hline(4, 2, 10, Color("fde3ea"))
	w.disc(19, 4, 2.4, Color("e07a9a"))
	w.disc(24, 4, 2.4, Color("9d8bc9"))
	w.px(19, 4, Color("fde3ea"))
	w.px(24, 4, Color("d7c6f0"))
	w.px(16, 9, Color("9d98ab"))
	w.px(17, 10, Color("9d98ab"))
	w.px(18, 9, Color("9d98ab"))
	w.outline(OUTLINE)
	_save(w, "res://assets/objects/workbench.png")
	# decorations
	var vase := Painter.new(16, 24, 6103)
	vase.shaded_ellipse(8, 17, 5, 6, [Color("566590"), Color("7486b0"), Color("c4cee8"), Color("fbf3e3")])
	vase.rect(6, 9, 4, 3, Color("7486b0"))
	for c: Vector2i in [Vector2i(5, 5), Vector2i(8, 3), Vector2i(11, 5)]:
		vase.vline(c.x, c.y + 2, 4, STEM)
		vase.disc(c.x + 0.5, c.y + 0.5, 1.6, Color("f5bfd0"))
	vase.outline(OUTLINE)
	_save(vase, "res://assets/objects/deco_vase.png")
	var garland := Painter.new(48, 16, 6104)
	for x in 48:
		var y := int(3.0 + sin(x / 47.0 * PI) * 7.0)
		garland.px(x, y, Color("5c9656"))
		garland.px(x, y + 1, Color("85b56c"))
		if x % 5 == 2:
			garland.disc(x + 0.5, y + 1.5, 1.6, [Color("e07a9a"), Color("f2c14e"), Color("c9b3e6")][(x / 5) % 3])
	garland.outline(OUTLINE)
	_save(garland, "res://assets/objects/deco_garland.png")
	var lamp := Painter.new(32, 24, 6105)
	lamp.vline(16, 0, 6, Color("c99a55"))
	lamp.ellipse(16, 9, 11, 4, Color("f2c14e"))
	lamp.ellipse(16, 8, 9, 2.5, Color("f9dc7c"))
	for x in range(7, 26, 3):
		lamp.vline(x, 11, 4 + (x % 2) * 3, Color("d7c6f0"))
		lamp.px(x, 15 + (x % 2) * 3, Color("9d8bc9"))
	lamp.outline(OUTLINE)
	_save(lamp, "res://assets/objects/deco_chandelier.png")
	var fountain := Painter.new(24, 24, 6106)
	fountain.ellipse(12, 18, 10, 4, Color("c2bdcc"))
	fountain.ellipse(12, 17, 8, 2.5, Color("86bcd8"))
	fountain.rect(10, 7, 4, 10, Color("dcd8e3"))
	fountain.ellipse(12, 7, 5, 2, Color("c2bdcc"))
	for i in 4:
		fountain.px(9 + i * 2, 3 + i % 2, Color("c9e5f0"))
	fountain.outline(OUTLINE)
	_save(fountain, "res://assets/objects/deco_fountain.png")
	var diffuser := Painter.new(12, 16, 6107)
	diffuser.rect(3, 8, 6, 7, Color("c9b3e6"))
	diffuser.hline(3, 8, 6, Color("d7c6f0"))
	for x in [4, 6, 8]:
		diffuser.vline(x, 2, 6, WOOD[1])
	diffuser.px(5, 0, Color("ffffff", 0.7))
	diffuser.px(7, 1, Color("ffffff", 0.6))
	diffuser.outline(OUTLINE)
	_save(diffuser, "res://assets/objects/diffuser.png")


# -------------------------------------------------------------- customers ---

## Two sheets laid out like player_sheet.png (rows down/up/right, 4 frames).
## Colours: overalls b/B and hair k/K are recoloured per customer in-game.
func _gen_customers() -> void:
	var pal := {
		"o": OUTLINE, "k": Color("8a5236"), "K": Color("6a3b27"), "s": Color("f6cfb0"), "S": Color("e3a888"),
		"e": OUTLINE, "c": Color("f29aa8"), "w": Color("fbf1e4"), "W": Color("e6d3c3"),
		"b": Color("6f8fc0"), "B": Color("52709f"), "t": Color("6b4430"), "r": Color("e07a9a"),
	}
	var variants := {"customer_a": HEAD_DOWN_LONG, "customer_b": HEAD_DOWN_SHORT}
	for name: String in variants:
		var p := Painter.new(16 * 4, 24 * 3, 6200)
		var bodies := [PlayerArt.DOWN, PlayerArt.UP, PlayerArt.RIGHT]
		var heads := [variants[name], HEAD_UP, HEAD_RIGHT]
		for row in 3:
			var base: Array = []
			base.append_array(heads[row])
			for y in range(13, 24):
				base.append(bodies[row][y])
			for r: String in base:
				if r.length() != 16:
					push_error("[assets] %s row has width %d" % [name, r.length()])
					_ok = false
					return
			for f in 4:
				p.blit_ascii(_frame(base, f), pal, f * 16, row * 24)
		_save(p, "res://assets/characters/%s.png" % name)


## Same frame logic as the player (leg lifts and a body bob).
func _frame(base: Array, frame: int) -> Array:
	var grid: Array = []
	for row: String in base:
		var chars: Array = []
		for i in row.length():
			chars.append(row[i])
		grid.append(chars)
	match frame:
		1, 3:
			var x_from := 0 if frame == 1 else 8
			for y in range(19, 24):
				for x in range(x_from, x_from + 8):
					grid[y][x] = base[y + 1][x] if y + 1 < 24 else "."
		2:
			for y in range(19, 0, -1):
				for x in 16:
					grid[y][x] = base[y - 1][x]
			for x in 16:
				grid[0][x] = "."
	var out: Array = []
	for row: Array in grid:
		out.append("".join(PackedStringArray(row)))
	return out


func _gen_bubble() -> void:
	var p := Painter.new(10, 12, 6300)
	p.rect(1, 1, 8, 8, CREAM)
	p.px(4, 9, CREAM)
	p.px(5, 9, CREAM)
	p.px(5, 10, CREAM)
	p.vline(5, 2, 4, Color("e07a9a"))
	p.px(5, 7, Color("e07a9a"))
	p.outline(OUTLINE)
	_save(p, "res://assets/ui/bubble_wait.png")
