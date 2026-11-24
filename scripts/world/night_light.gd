class_name NightLight
extends PointLight2D
## Warm light from lamps and windows that fades in at dusk and out at dawn.
## GameplayScene drives every light in the "night_lights" group from the
## clock, so there is no per-light processing.

const GROUP := &"night_lights"
const COLOR := Color(1.0, 0.82, 0.55)

## Full brightness of this light at night.
@export var max_energy := 0.9
## Radius in pixels.
@export var radius := 40.0

static var _texture: GradientTexture2D


func _ready() -> void:
	add_to_group(GROUP)
	texture = shared_texture()
	texture_scale = radius / 32.0
	color = COLOR
	blend_mode = BLEND_MODE_ADD
	shadow_enabled = false
	set_level(0.0)


## 0..1 brightness for a time of day: off by day, ramps 17:30–19:30 and
## 5:00–6:30.
static func level_for(minutes: int) -> float:
	var m := float(posmod(minutes, 24 * 60))
	if m >= 17.5 * 60.0:
		return clampf((m - 17.5 * 60.0) / 120.0, 0.0, 1.0)
	if m < 5.0 * 60.0:
		return 1.0
	return clampf(1.0 - (m - 5.0 * 60.0) / 90.0, 0.0, 1.0)


func set_level(level: float) -> void:
	energy = max_energy * level
	visible = level > 0.01


## 64x64 soft radial falloff shared by all lights.
static func shared_texture() -> GradientTexture2D:
	if _texture == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		_texture = GradientTexture2D.new()
		_texture.gradient = g
		_texture.fill = GradientTexture2D.FILL_RADIAL
		_texture.fill_from = Vector2(0.5, 0.5)
		_texture.fill_to = Vector2(1.0, 0.5)
		_texture.width = 64
		_texture.height = 64
	return _texture
