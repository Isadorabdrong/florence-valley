extends SceneTree
## Generates Florence Valley's original pixel-art assets procedurally.
##
## Usage (from the project folder):
##   godot --headless --path . --script res://tools/generate_assets.gd
##
## Output is deterministic. The PNGs are committed to the repository, so this
## only needs to run again after changing the art code below. The palette
## follows docs/ART_DIRECTION.md.

const Painter := preload("res://tools/pixel_painter.gd")
const PlayerArt := preload("res://tools/art/player_art.gd")
const FarmingArt := preload("res://tools/art/farming_art.gd")
const WorldArt := preload("res://tools/art/world_art.gd")
const TerrainArt := preload("res://tools/art/terrain_art.gd")
const VillageArt := preload("res://tools/art/village_art.gd")
const FloristArt := preload("res://tools/art/florist_art.gd")
const NpcArt := preload("res://tools/art/npc_art.gd")
const BuildArt := preload("res://tools/art/build_art.gd")

const TILE := 16
const OUTLINE := Color("3d2b3d")

# Shared palette (dark -> light)
var GRASS_BASE := Color("8db86b")
var GRASS_DARK := Color("7aa95e")
var GRASS_TUFT := Color("6a9853")
var GRASS_LIGHT := Color("a2c67e")
var LEAF := [Color("2f5a3c"), Color("3f7a4a"), Color("5c9656"), Color("85b56c"), Color("b4d48c")]
var BLOSSOM := [Color("9c4f72"), Color("c96f93"), Color("e597b2"), Color("f5bfd0"), Color("fde3ea")]
var PINE := [Color("223f37"), Color("2f5a48"), Color("427558"), Color("5e9366"), Color("86b27a")]
var BARK := [Color("4e3326"), Color("6b4430"), Color("8a5d3f"), Color("a8774f")]
var STONE := [Color("5d5868"), Color("7b7689"), Color("9d98ab"), Color("c2bdcc"), Color("dcd8e3")]
var WOOD := [Color("6b4430"), Color("8a5d3f"), Color("b07d55"), Color("cf9f72")]
var ROOF := [Color("8f3f58"), Color("b4566f"), Color("cf7389"), Color("e39aa9"), Color("f2bfc8")]
var CREAM := [Color("c9b49a"), Color("e3d1b8"), Color("f1e4cc"), Color("fbf3e3")]

var _failed := false


func _initialize() -> void:
	_gen_terrain_atlas()
	_gen_player()
	_gen_shadow()
	_gen_petal()
	_gen_tree("res://assets/environments/tree_oak.png", LEAF, 11, false)
	_gen_tree("res://assets/environments/tree_cherry.png", BLOSSOM, 23, true)
	_gen_pine()
	_gen_bush("res://assets/environments/bush_pink.png", [Color("e07a9a"), Color("f5bfd0")], 31)
	_gen_bush("res://assets/environments/bush_lilac.png", [Color("a98bd6"), Color("d7c6f0")], 37)
	_gen_bush("res://assets/environments/bush_white.png", [Color("f3ece6"), Color("fffaf5")], 41)
	_gen_rock()
	_gen_weed()
	_gen_fence_atlas()
	_gen_well()
	_gen_house()
	# Phase 2 — farming art (flowers, soil, item icons, cursor, effects)
	var farming := FarmingArt.new()
	if not farming.generate_all():
		_failed = true
	# Phase 3 — market cart, chest, weather particles/icons, coin
	if not WorldArt.new().generate_all():
		_failed = true
	# Phase 4 — village buildings, props, furniture, forage icons, butterflies
	if not VillageArt.new().generate_all():
		_failed = true
	# Phase 5 — bouquets, restored flower shop, shop furniture, customers
	if not FloristArt.new().generate_all():
		_failed = true
	# Phase 6 — villager portraits
	if not NpcArt.new().generate_all():
		_failed = true
	# Phase 7 — greenhouse, raised bed, build and tool icons
	if not BuildArt.new().generate_all():
		_failed = true
	if _failed:
		push_error("[assets] generation finished with errors")
		quit(1)
	else:
		print("[assets] all assets generated")
		quit(0)


func _save(p: Painter, path: String) -> void:
	var err := p.save(path)
	if err != OK:
		push_error("[assets] could not save %s (error %d)" % [path, err])
		_failed = true
	else:
		print("[assets] wrote ", path)


# ---------------------------------------------------------------- terrain ---

## Atlas layout (16x16 tiles):
##   row 0: grass x4 | flowered grass x4
##   row 1: path  — column = neighbour mask (N=1, E=2, S=4, W=8 set when connected)
##   row 2: water — same mask convention
##   row 3: tilled soil — same mask convention
func _gen_terrain_atlas() -> void:
	var p := Painter.new(TILE * 16, TILE * 9, 1001)
	for i in 4:
		_draw_grass(p, i * TILE, 0, i, false)
		_draw_grass(p, (4 + i) * TILE, 0, i, true)
	for mask in 16:
		_draw_path(p, mask * TILE, TILE, mask)
		_draw_water(p, mask * TILE, TILE * 2, mask)
		_draw_soil(p, mask * TILE, TILE * 3, mask)
	TerrainArt.new().draw_rows(p) # Phase 4 rows 4-8
	_save(p, "res://assets/environments/terrain_atlas.png")


func _draw_grass(p: Painter, ox: int, oy: int, variant: int, flowers: bool) -> void:
	p.rect(ox, oy, TILE, TILE, GRASS_BASE)
	for y in TILE:
		for x in TILE:
			var n := Painter.noise_hash(x + variant * 17, y, 7)
			if n < 0.09:
				p.px(ox + x, oy + y, GRASS_DARK)
			elif n > 0.94:
				p.px(ox + x, oy + y, GRASS_LIGHT)
	for i in 3 + variant % 2:
		var tx := ox + p.rng.randi_range(1, 12)
		var ty := oy + p.rng.randi_range(2, 13)
		p.px(tx, ty, GRASS_TUFT)
		p.px(tx + 1, ty + 1, GRASS_TUFT)
		p.px(tx + 2, ty, GRASS_TUFT)
		p.px(tx + 1, ty, GRASS_LIGHT)
	if flowers:
		var petals := [Color("f4b6c8"), Color("fbeff2"), Color("c9b3e6"), Color("f7d27c")]
		for i in 2 + variant % 2:
			var fx := ox + p.rng.randi_range(2, 13)
			var fy := oy + p.rng.randi_range(2, 13)
			var petal: Color = petals[p.rng.randi_range(0, petals.size() - 1)]
			p.px(fx + 1, fy + 1, GRASS_TUFT)
			p.px(fx, fy - 1, petal)
			p.px(fx - 1, fy, petal)
			p.px(fx + 1, fy, petal)
			p.px(fx, fy + 1, petal)
			p.px(fx, fy, Color("e58fa8") if petal == Color("f7d27c") else Color("f7d27c"))


## Grass fringe on the sides of a tile that are NOT connected (mask bit clear).
func _draw_fringe(p: Painter, ox: int, oy: int, mask: int, shade: Color, salt: int) -> void:
	# pass 1: shade lines, pass 2: grass — so corners stay clean.
	for pass_i in 2:
		for i in TILE:
			var d := 2 + int(Painter.noise_hash(i, mask, salt) * 2.0)
			var col := shade if pass_i == 0 else GRASS_BASE
			var depth := d + 1 if pass_i == 0 else d
			for k in depth:
				if (mask & 1) == 0:
					p.px(ox + i, oy + k, col)
				if (mask & 2) == 0:
					p.px(ox + TILE - 1 - k, oy + i, col)
				if (mask & 4) == 0:
					p.px(ox + i, oy + TILE - 1 - k, col)
				if (mask & 8) == 0:
					p.px(ox + k, oy + i, col)


func _draw_path(p: Painter, ox: int, oy: int, mask: int) -> void:
	p.rect(ox, oy, TILE, TILE, Color("dcc398"))
	for y in TILE:
		for x in TILE:
			var n := Painter.noise_hash(x + mask * 31, y + 5, 11)
			if n < 0.12:
				p.px(ox + x, oy + y, Color("cdb085"))
			elif n > 0.95:
				p.px(ox + x, oy + y, Color("ecdcb8"))
	for i in 2:
		var sx := ox + p.rng.randi_range(3, 11)
		var sy := oy + p.rng.randi_range(4, 11)
		p.px(sx, sy, Color("b89f7c"))
		p.px(sx + 1, sy, Color("b89f7c"))
		p.px(sx, sy - 1, Color("efe2c4"))
	_draw_fringe(p, ox, oy, mask, Color("c4a87c"), 3)


func _draw_water(p: Painter, ox: int, oy: int, mask: int) -> void:
	p.rect(ox, oy, TILE, TILE, Color("86bcd8"))
	for y in TILE:
		for x in TILE:
			if Painter.noise_hash(x + mask * 13, y, 19) < 0.08:
				p.px(ox + x, oy + y, Color("7ab2d1"))
	for i in 2:
		p.hline(ox + p.rng.randi_range(2, 10), oy + p.rng.randi_range(3, 12), 3, Color("a9d3e6"))
	var bank := Color("b5946a")
	var bank_dark := Color("8f7150")
	var shadow := Color("6c9fc4")
	var foam := Color("d6ecf4")
	for i in TILE:
		var j := int(Painter.noise_hash(i, mask, 29) * 2.0)
		if (mask & 1) == 0:
			p.vline(ox + i, oy, 1 + j, GRASS_BASE)
			p.px(ox + i, oy + 1 + j, bank)
			p.px(ox + i, oy + 2 + j, bank_dark)
			p.px(ox + i, oy + 3 + j, shadow)
		if (mask & 4) == 0:
			p.px(ox + i, oy + TILE - 1, GRASS_BASE)
			p.px(ox + i, oy + TILE - 2, GRASS_BASE if j == 1 else bank)
			p.px(ox + i, oy + TILE - 3, bank)
			p.px(ox + i, oy + TILE - 4, foam)
		if (mask & 8) == 0:
			p.hline(ox, oy + i, 1 + j, GRASS_BASE)
			p.px(ox + 1 + j, oy + i, bank)
			p.px(ox + 2 + j, oy + i, shadow)
		if (mask & 2) == 0:
			p.hline(ox + TILE - 1 - j, oy + i, 1 + j, GRASS_BASE)
			p.px(ox + TILE - 2 - j, oy + i, bank)
			p.px(ox + TILE - 3 - j, oy + i, foam)


func _draw_soil(p: Painter, ox: int, oy: int, mask: int) -> void:
	p.rect(ox, oy, TILE, TILE, Color("8a6248"))
	for y in TILE:
		for x in TILE:
			var n := Painter.noise_hash(x + mask * 7, y, 41)
			if y % 4 == 1:
				p.px(ox + x, oy + y, Color("6f4d38"))
			elif y % 4 == 2 and n > 0.35:
				p.px(ox + x, oy + y, Color("a1795a"))
			elif n < 0.08:
				p.px(ox + x, oy + y, Color("7b5640"))
	var rim := Color("5f4130")
	var lip := Color("a88262")
	if (mask & 1) == 0:
		p.hline(ox, oy, TILE, rim)
		p.hline(ox, oy + 1, TILE, lip)
	if (mask & 4) == 0:
		p.hline(ox, oy + TILE - 1, TILE, rim)
		p.hline(ox, oy + TILE - 2, TILE, Color("6f4d38"))
	if (mask & 8) == 0:
		p.vline(ox, oy, TILE, rim)
		p.vline(ox + 1, oy, TILE, lip)
	if (mask & 2) == 0:
		p.vline(ox + TILE - 1, oy, TILE, rim)


# ----------------------------------------------------------------- player ---

## Sheet: 4 columns (frames) x 3 rows (down, up, right), 16x24 per frame.
##   frame 0 idle | 1 left leg lifted | 2 body bob (contact) | 3 right leg lifted
func _gen_player() -> void:
	var pal := {
		"o": OUTLINE, "h": Color("ecc883"), "H": Color("c99a55"), "r": Color("e07a9a"),
		"k": Color("8a5236"), "K": Color("6a3b27"), "s": Color("f6cfb0"), "S": Color("e3a888"),
		"e": OUTLINE, "c": Color("f29aa8"), "w": Color("fbf1e4"), "W": Color("e6d3c3"),
		"b": Color("6f8fc0"), "B": Color("52709f"), "t": Color("6b4430"),
	}
	var arts: Array = [PlayerArt.DOWN, PlayerArt.UP, PlayerArt.RIGHT]
	var p := Painter.new(PlayerArt.WIDTH * 4, PlayerArt.HEIGHT * 3, 77)
	for row in arts.size():
		var base: Array = arts[row]
		if not _validate_art(base, PlayerArt.WIDTH, PlayerArt.HEIGHT, "player row %d" % row):
			return
		for f in 4:
			p.blit_ascii(_player_frame(base, f), pal, f * PlayerArt.WIDTH, row * PlayerArt.HEIGHT)
	_save(p, "res://assets/characters/player_sheet.png")


func _validate_art(rows: Array, w: int, h: int, label: String) -> bool:
	if rows.size() != h:
		push_error("[assets] %s: expected %d rows, got %d" % [label, h, rows.size()])
		_failed = true
		return false
	for i in rows.size():
		if (rows[i] as String).length() != w:
			push_error("[assets] %s: row %d has width %d (expected %d)" % [label, i, (rows[i] as String).length(), w])
			_failed = true
			return false
	return true


func _player_frame(base: Array, frame: int) -> Array:
	var grid: Array = []
	for row: String in base:
		var chars: Array = []
		for i in row.length():
			chars.append(row[i])
		grid.append(chars)
	var h := grid.size()
	var w: int = (grid[0] as Array).size()
	match frame:
		1, 3:
			var x_from := 0 if frame == 1 else w / 2
			var x_to := w / 2 if frame == 1 else w
			for y in range(19, h):
				for x in range(x_from, x_to):
					grid[y][x] = base[y + 1][x] if y + 1 < h else "."
		2:
			for y in range(19, 0, -1):
				for x in w:
					grid[y][x] = base[y - 1][x]
			for x in w:
				grid[0][x] = "."
	var out: Array = []
	for row: Array in grid:
		out.append("".join(PackedStringArray(row)))
	return out


func _gen_shadow() -> void:
	var p := Painter.new(14, 6, 3)
	p.ellipse(7, 3, 6.5, 2.6, Color(0.24, 0.17, 0.24, 0.32))
	_save(p, "res://assets/characters/shadow.png")


func _gen_petal() -> void:
	var p := Painter.new(4, 4, 5)
	p.px(1, 0, Color("f5bfd0"))
	p.px(0, 1, Color("f5bfd0"))
	p.px(1, 1, Color("fde3ea"))
	p.px(2, 1, Color("e597b2"))
	p.px(1, 2, Color("e597b2"))
	p.px(2, 2, Color("c96f93"))
	_save(p, "res://assets/environments/petal.png")


# ------------------------------------------------------------- vegetation ---

## 48x64 broadleaf tree; origin (trunk base) at (24, 60).
func _gen_tree(path: String, tones: Array, seed_value: int, blossoms: bool) -> void:
	var p := Painter.new(48, 64, seed_value)
	_draw_trunk(p, 24, 61, 36)
	var blobs := [
		[24, 27, 16], [13, 31, 9], [35, 31, 9], [24, 15, 11],
		[16, 20, 9], [32, 20, 9], [24, 34, 10],
	]
	for b: Array in blobs:
		p.shaded_disc(b[0], b[1], b[2], tones)
	# leaf clusters: tiny highlight crescents on the lit side of the canopy
	for i in 22:
		var x := p.rng.randi_range(8, 38)
		var y := p.rng.randi_range(8, 38)
		if p.is_solid(x, y) and p.is_solid(x - 1, y - 1):
			p.px(x, y, tones[tones.size() - 1] if (x + y) < 46 else tones[2])
			p.px(x + 1, y, tones[3])
	if blossoms:
		for i in 26:
			var bx := p.rng.randi_range(8, 40)
			var by := p.rng.randi_range(6, 40)
			if p.is_solid(bx, by):
				p.px(bx, by, Color("fffafc"))
	else:
		for i in 9:
			var fx := p.rng.randi_range(10, 38)
			var fy := p.rng.randi_range(10, 38)
			if p.is_solid(fx, fy) and p.is_solid(fx + 1, fy + 1):
				p.px(fx, fy, Color("f3e3a0"))
	p.outline(tones[0].darkened(0.45))
	_draw_ground_shadow(p, 24, 61, 14, 3.5)
	_save(p, path)


func _draw_trunk(p: Painter, cx: int, base_y: int, top_y: int) -> void:
	for y in range(top_y, base_y):
		for x in range(cx - 4, cx + 4):
			var tone := 1
			if x <= cx - 3:
				tone = 3
			elif x <= cx - 1:
				tone = 2
			elif x >= cx + 2:
				tone = 0
			p.px(x, y, BARK[tone])
	for i in 6:
		var bx := p.rng.randi_range(cx - 2, cx + 1)
		var by := p.rng.randi_range(top_y + 2, base_y - 4)
		p.vline(bx, by, 2, BARK[0])
	# roots
	p.hline(cx - 6, base_y - 1, 2, BARK[1])
	p.px(cx - 5, base_y - 2, BARK[2])
	p.hline(cx + 4, base_y - 1, 2, BARK[0])
	p.px(cx + 4, base_y - 2, BARK[1])


func _draw_ground_shadow(p: Painter, cx: float, cy: float, rx: float, ry: float) -> void:
	var shadow := Color(0.24, 0.17, 0.24, 0.26)
	for y in range(floori(cy - ry), ceili(cy + ry) + 1):
		for x in range(floori(cx - rx), ceili(cx + rx) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0 and p.get_px(x, y).a < 0.1:
				p.px(x, y, shadow)


## 32x56 pine for the forest border; origin at (16, 53).
func _gen_pine() -> void:
	var p := Painter.new(32, 56, 59)
	_draw_trunk(p, 16, 54, 42)
	var tiers := [[4, 20, 6], [14, 32, 10], [24, 44, 13]]
	for tier: Array in tiers:
		var top: int = tier[0]
		var bottom: int = tier[1]
		var half_w: int = tier[2]
		for y in range(top, bottom + 1):
			var t := float(y - top) / float(bottom - top)
			var hw := lerpf(1.0, half_w, t)
			for x in range(int(16 - hw), int(16 + hw) + 1):
				var lx := (x - 16.0) / maxf(hw, 1.0)
				var b := 0.75 - lx * 0.45 - t * 0.25
				p.px(x, y, p.dithered_tone(PINE, b, x, y))
		# scalloped bottom edge of each tier
		for x in range(16 - half_w, 16 + half_w + 1, 3):
			p.px(x, bottom + 1, PINE[1])
	p.outline(PINE[0].darkened(0.5))
	_draw_ground_shadow(p, 16, 54, 10, 2.5)
	_save(p, "res://assets/environments/tree_pine.png")


## 16x16 flowering bush; origin at (8, 15).
func _gen_bush(path: String, flower_colors: Array, seed_value: int) -> void:
	var p := Painter.new(16, 16, seed_value)
	p.shaded_ellipse(5, 9, 4.5, 4.5, LEAF)
	p.shaded_ellipse(11, 9, 4.5, 4.5, LEAF)
	p.shaded_ellipse(8, 6.5, 5, 4.5, LEAF)
	for i in 6:
		var x := p.rng.randi_range(2, 13)
		var y := p.rng.randi_range(3, 11)
		if p.is_solid(x, y):
			p.px(x, y, flower_colors[0])
			p.px(x, y - 1, flower_colors[1])
	p.outline(LEAF[0].darkened(0.45))
	_draw_ground_shadow(p, 8, 14.5, 7, 1.6)
	_save(p, path)


func _gen_rock() -> void:
	var p := Painter.new(16, 16, 61)
	p.shaded_ellipse(8, 10, 6.5, 4.5, STONE)
	p.shaded_ellipse(6, 9, 3.5, 3, STONE)
	p.px(9, 9, STONE[1])
	p.px(10, 10, STONE[1])
	p.px(10, 11, STONE[0])
	p.outline(STONE[0].darkened(0.45))
	_draw_ground_shadow(p, 8, 14, 6.5, 1.5)
	_save(p, "res://assets/environments/rock.png")


func _gen_weed() -> void:
	var p := Painter.new(16, 16, 67)
	var blades := [[4, 8, -1], [6, 5, 0], [8, 4, 0], [10, 6, 1], [12, 9, 1], [7, 7, -1], [9, 7, 1]]
	for b: Array in blades:
		var x: int = b[0]
		var top: int = b[1]
		var lean: int = b[2]
		for y in range(top, 14):
			var xx := x + (lean if y < top + 2 else 0)
			p.px(xx, y, GRASS_TUFT if y > top + 3 else Color("9cc46f"))
	p.px(8, 3, Color("e8e3a0"))
	p.px(6, 4, Color("e8e3a0"))
	p.outline(Color("3f5f36"))
	_save(p, "res://assets/environments/weed.png")


# ------------------------------------------------------------ structures ---

## 16 fence pieces (16x16) in one row; column index = neighbour mask.
func _gen_fence_atlas() -> void:
	var atlas := Painter.new(TILE * 16, TILE, 71)
	for mask in 16:
		var p := Painter.new(TILE, TILE, 71 + mask)
		var rail_light: Color = WOOD[3]
		var rail: Color = WOOD[2]
		if (mask & 2) != 0:
			p.rect(9, 5, 7, 2, rail)
			p.hline(9, 5, 7, rail_light)
			p.rect(9, 9, 7, 2, rail)
			p.hline(9, 9, 7, rail_light)
		if (mask & 8) != 0:
			p.rect(0, 5, 7, 2, rail)
			p.hline(0, 5, 7, rail_light)
			p.rect(0, 9, 7, 2, rail)
			p.hline(0, 9, 7, rail_light)
		if (mask & 1) != 0:
			p.rect(7, 0, 2, 3, rail)
			p.vline(7, 0, 3, rail_light)
		if (mask & 4) != 0:
			p.rect(7, 13, 2, 3, rail)
			p.vline(7, 13, 3, rail_light)
		# post
		p.rect(6, 2, 4, 12, WOOD[1])
		p.vline(6, 2, 12, WOOD[2])
		p.vline(9, 3, 11, WOOD[0])
		p.hline(6, 2, 4, WOOD[3])
		p.outline(Color("4e3326"))
		atlas.blit_image(p.image, mask * TILE, 0)
	_save(atlas, "res://assets/objects/fence_atlas.png")


## 32x44 stone well with a rose shingle roof; origin at (16, 42).
func _gen_well() -> void:
	var p := Painter.new(32, 44, 83)
	# posts
	p.rect(4, 8, 3, 22, WOOD[1])
	p.vline(4, 8, 22, WOOD[2])
	p.rect(25, 8, 3, 22, WOOD[1])
	p.vline(27, 8, 22, WOOD[0])
	# crank + rope + bucket
	p.hline(6, 13, 20, WOOD[0])
	p.vline(16, 14, 9, Color("d8c39a"))
	p.rect(14, 22, 5, 4, WOOD[2])
	p.hline(14, 22, 5, WOOD[3])
	p.hline(14, 25, 5, WOOD[0])
	# stone cylinder
	for y in range(28, 41):
		for x in range(3, 29):
			var row := (y - 28) / 3
			var brick_x := (x + (row % 2) * 3) % 6
			var tone := 2
			if brick_x == 0 or (y - 28) % 3 == 0:
				tone = 0
			elif x < 9:
				tone = 3
			elif x > 23:
				tone = 1
			p.px(x, y, STONE[tone])
	p.ellipse(16, 28, 13, 3.5, STONE[3])
	p.ellipse(16, 28, 10, 2.2, Color("44627e"))
	p.hline(12, 28, 5, Color("6c9fc4"))
	# roof
	for y in range(0, 10):
		var hw := 6 + y * 1.1
		for x in range(int(16 - hw), int(16 + hw) + 1):
			var shingle := ((x + (y / 2) * 2) % 4 == 0) or y % 3 == 2
			var t := 0.7 - (x - 16.0) / 30.0
			var c := p.dithered_tone(ROOF, t, x, y)
			p.px(x, y, ROOF[1] if shingle else c)
	p.outline(OUTLINE)
	_draw_ground_shadow(p, 16, 41, 14, 2.5)
	_save(p, "res://assets/objects/well.png")


## 96x92 cottage. Origin (bottom centre of the foundation) at (48, 90).
func _gen_house() -> void:
	var p := Painter.new(96, 92, 97)
	var beam: Color = WOOD[1]
	var beam_dark: Color = WOOD[0]
	# chimney (behind roof)
	p.rect(66, 2, 10, 22, STONE[2])
	p.vline(66, 2, 22, STONE[3])
	p.vline(75, 2, 22, STONE[1])
	for y in range(4, 24, 4):
		p.hline(66, y, 10, STONE[1])
	p.rect(65, 1, 12, 3, STONE[1])
	p.hline(65, 1, 12, STONE[3])
	# walls
	for y in range(44, 84):
		for x in range(10, 86):
			var t := 0.75 - (x - 10) / 220.0 + (0.08 if y < 50 else 0.0)
			p.px(x, y, p.dithered_tone(CREAM, t, x, y, 0.12))
	# timber frame
	p.rect(10, 44, 76, 3, beam)
	p.rect(10, 64, 76, 2, beam)
	for bx in [10, 40, 55, 83]:
		p.rect(bx, 44, 3, 40, beam)
		p.vline(bx + 2, 44, 40, beam_dark)
	# diagonal braces
	for i in 18:
		p.px(13 + i, 46 + i, beam)
		p.px(82 - i, 46 + i, beam)
	# foundation
	for y in range(82, 90):
		for x in range(8, 88):
			var brick := ((x + ((y - 82) / 4) * 4) % 8 == 0) or (y - 82) % 4 == 3
			p.px(x, y, STONE[0] if brick else (STONE[2] if x < 48 else STONE[1]))
	# door
	p.rect(42, 62, 12, 22, WOOD[1])
	p.ellipse(48, 63, 6, 4, WOOD[1])
	for dx in [44, 47, 50]:
		p.vline(dx, 61, 23, WOOD[0])
	p.vline(43, 62, 22, WOOD[2])
	p.px(51, 73, Color("f7d27c"))
	p.px(51, 74, Color("c99a55"))
	# heart-shaped flower wreath on the door
	p.disc(48, 66, 2.6, Color("7fae62"))
	p.px(47, 65, Color("e07a9a"))
	p.px(49, 66, Color("f5bfd0"))
	p.px(48, 67, Color("e597b2"))
	# step stones
	p.rect(40, 88, 16, 3, STONE[2])
	p.hline(40, 88, 16, STONE[3])
	# windows with flower boxes
	for wx in [18, 64]:
		p.rect(wx, 50, 14, 12, Color("fbf3e3"))
		p.rect(wx + 1, 51, 12, 10, Color("9cc9de"))
		p.rect(wx + 1, 51, 5, 4, Color("c9e5f0"))
		p.vline(wx + 7, 51, 10, Color("fbf3e3"))
		p.hline(wx + 1, 56, 12, Color("fbf3e3"))
		p.rect(wx - 1, 62, 16, 4, WOOD[2])
		p.hline(wx - 1, 65, 16, WOOD[0])
		for fx in range(wx, wx + 14, 2):
			var col := [Color("e07a9a"), Color("c9b3e6"), Color("fbeff2"), Color("f7d27c")][(fx / 2) % 4] as Color
			p.px(fx, 61, col)
			p.px(fx + 1, 60, Color("6a9853"))
	# roof: trapezoid of shingle rows
	for y in range(8, 48):
		var t := float(y - 8) / 40.0
		var hw := lerpf(24.0, 46.0, t)
		for x in range(int(48 - hw), int(48 + hw) + 1):
			var row := (y - 8) / 4
			var edge := (y - 8) % 4 == 3
			var notch := (x + row * 3) % 6 == 0
			var light := 0.82 - (x - 48 + hw) / (hw * 2.0) * 0.5 - t * 0.12
			var c := p.dithered_tone(ROOF, light, x, y, 0.15)
			if edge:
				c = ROOF[0] if notch else ROOF[1]
			elif notch:
				c = ROOF[1]
			p.px(x, y, c)
	# ridge
	p.hline(24, 7, 49, ROOF[0])
	p.hline(25, 6, 47, ROOF[3])
	# gable window
	p.disc(48, 26, 6, Color("fbf3e3"))
	p.disc(48, 26, 4.6, Color("9cc9de"))
	p.px(46, 24, Color("c9e5f0"))
	p.px(47, 24, Color("c9e5f0"))
	p.vline(48, 22, 9, Color("fbf3e3"))
	p.hline(44, 26, 9, Color("fbf3e3"))
	# climbing roses on the left corner
	for i in 34:
		var vx := p.rng.randi_range(4, 16)
		var vy := p.rng.randi_range(40, 84)
		if p.is_solid(vx, vy) or vx >= 10:
			p.px(vx, vy, LEAF[2] if i % 3 else LEAF[3])
			if i % 4 == 0:
				p.px(vx, vy - 1, Color("e07a9a"))
	p.outline(OUTLINE)
	_draw_ground_shadow(p, 48, 89, 44, 3)
	_save(p, "res://assets/objects/house.png")
