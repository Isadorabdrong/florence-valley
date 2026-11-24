extends RefCounted
## Procedural pixel-art drawing helpers used by the asset generator.
##
## Everything is deterministic (seeded hashing / RNG), so regenerating the
## assets always produces identical PNGs. This is a development tool only —
## it is never loaded by the running game.

const BAYER4: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var image: Image
var rng := RandomNumberGenerator.new()


func _init(width: int, height: int, seed_value: int = 1) -> void:
	image = Image.create_empty(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	rng.seed = seed_value


func inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height()


func get_px(x: int, y: int) -> Color:
	if not inside(x, y):
		return Color(0, 0, 0, 0)
	return image.get_pixel(x, y)


func is_solid(x: int, y: int) -> bool:
	return get_px(x, y).a > 0.5


func px(x: int, y: int, c: Color) -> void:
	if not inside(x, y):
		return
	if c.a >= 0.999:
		image.set_pixel(x, y, c)
	else:
		image.set_pixel(x, y, image.get_pixel(x, y).blend(c))


func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			px(xx, yy, c)


func hline(x: int, y: int, length: int, c: Color) -> void:
	rect(x, y, length, 1, c)


func vline(x: int, y: int, length: int, c: Color) -> void:
	rect(x, y, 1, length, c)


func disc(cx: float, cy: float, r: float, c: Color) -> void:
	ellipse(cx, cy, r, r, c)


func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				px(x, y, c)


## Ordered-dither threshold in [0, 1) for the given pixel.
static func bayer(x: int, y: int) -> float:
	return BAYER4[(posmod(y, 4)) * 4 + posmod(x, 4)] / 16.0


## Deterministic per-pixel noise in [0, 1].
static func noise_hash(x: int, y: int, s: int) -> float:
	var n: int = x * 374761393 + y * 668265263 + s * 982451653
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


## Picks a tone from a dark->light list for a brightness value in [0, 1],
## using ordered dithering so gradients look hand-pixelled.
func dithered_tone(tones: Array, t: float, x: int, y: int, dither: float = 0.22) -> Color:
	t += (bayer(x, y) - 0.5) * dither
	var idx := clampi(int(t * tones.size()), 0, tones.size() - 1)
	return tones[idx]


## Sphere-shaded ellipse lit from the upper-left. Used for foliage, rocks, bushes.
func shaded_ellipse(cx: float, cy: float, rx: float, ry: float, tones: Array, rim_dark: bool = true) -> void:
	var light := Vector2(-0.6, -0.8).normalized()
	for y in range(floori(cy - ry) - 1, ceili(cy + ry) + 2):
		for x in range(floori(cx - rx) - 1, ceili(cx + rx) + 2):
			var n := Vector2((x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry)
			var d := n.length()
			if d > 1.0:
				continue
			var t := (n.dot(light) * 0.5 + 0.5) * 0.85 + (1.0 - d) * 0.25
			if rim_dark and d > 0.86:
				t -= 0.2
			px(x, y, dithered_tone(tones, t, x, y))


func shaded_disc(cx: float, cy: float, r: float, tones: Array, rim_dark: bool = true) -> void:
	shaded_ellipse(cx, cy, r, r, tones, rim_dark)


## Draws a 1px outline around every opaque region.
func outline(c: Color) -> void:
	var src := image.duplicate() as Image
	var w := image.get_width()
	var h := image.get_height()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			var touches := false
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx := x + o.x
				var ny := y + o.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
					touches = true
					break
			if touches:
				image.set_pixel(x, y, c)


## Blits ASCII art. `palette` maps single characters to colours; any other
## character (usually ".") is left transparent.
func blit_ascii(rows: Array, palette: Dictionary, ox: int, oy: int, flip_h: bool = false) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if palette.has(ch):
				var tx := ox + (row.length() - 1 - x if flip_h else x)
				px(tx, oy + y, palette[ch])


func blit_image(other: Image, x: int, y: int) -> void:
	image.blend_rect(other, Rect2i(0, 0, other.get_width(), other.get_height()), Vector2i(x, y))


func save(path: String) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var PaletteGrade: GDScript = load("res://tools/palette_grade.gd")
	if PaletteGrade.applies_to(path):
		var graded := image.duplicate() as Image
		PaletteGrade.grade_image(graded)
		return graded.save_png(path)
	return image.save_png(path)
