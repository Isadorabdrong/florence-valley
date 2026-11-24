extends RefCounted
## Florence Valley palette grade, applied to every generated sprite and tile
## when it is saved (tools/pixel_painter.gd). It pushes the art towards a
## natural garden look: richer, warmer greens, rosy pinks and golden
## yellows, with lilacs leaning to mauve. Blues (water, sky) are untouched.
## Character sheets and UI are skipped: their exact colours are used by the
## outfit palette swap and the interface theme.

const SKIP_PREFIXES := ["res://assets/characters/", "res://assets/ui/"]


static func applies_to(path: String) -> bool:
	for prefix: String in SKIP_PREFIXES:
		if path.begins_with(prefix):
			return false
	return true


static func grade_image(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			img.set_pixel(x, y, grade(c))


## Pulls `h` (0..1) toward `target` by `amount`, the short way round.
static func _toward(h: float, target: float, amount: float) -> float:
	var d := fposmod(target - h + 0.5, 1.0) - 0.5
	return fposmod(h + d * amount, 1.0)


static func grade(c: Color) -> Color:
	var h := c.h * 360.0
	var s := c.s
	var v := c.v
	if s < 0.08:
		return c # greys, whites, outlines stay
	var nh := c.h
	if h >= 65.0 and h < 175.0:
		# greens: natural leaf green, a touch warmer and richer
		nh = _toward(c.h, 100.0 / 360.0, 0.4)
		s = minf(s * 1.08, 1.0)
		v = v * 0.96
	elif h >= 290.0 or h < 12.0:
		# pinks and reds: rose / coral
		nh = _toward(c.h, 352.0 / 360.0, 0.4)
		s = minf(s * 1.1, 1.0)
	elif h >= 12.0 and h < 30.0 and s < 0.45 and v > 0.75:
		# creams and peaches: golden warmth
		nh = _toward(c.h, 35.0 / 360.0, 0.4)
		s = minf(s * 1.15 + 0.02, 1.0)
	elif h >= 30.0 and h < 65.0:
		# yellows and wood: golden
		nh = _toward(c.h, 42.0 / 360.0, 0.4)
		s = minf(s * 1.15, 1.0)
	elif h >= 245.0 and h < 290.0:
		# lilacs lean to mauve-rose
		nh = _toward(c.h, 305.0 / 360.0, 0.3)
		s = s * 0.95
	else:
		return c
	return Color.from_hsv(nh, s, v, c.a)
