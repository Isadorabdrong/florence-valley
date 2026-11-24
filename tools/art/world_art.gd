extends RefCounted
## Phase 3 art: flower market cart, storage chest, weather particles,
## weather icons and the Pétala coin. Deterministic like the rest.

const Painter := preload("res://tools/pixel_painter.gd")

const OUTLINE := Color("3d2b3d")
const WOOD := [Color("6b4430"), Color("8a5d3f"), Color("b07d55"), Color("cf9f72")]
const PINK := [Color("b4566f"), Color("e07a9a"), Color("f5bfd0"), Color("fde3ea")]
const CREAM := Color("fbf3e3")

var _ok := true


func generate_all() -> bool:
	_gen_market_cart()
	_gen_chest()
	_gen_particles()
	_gen_weather_icons()
	_gen_coin()
	return _ok


func _save(p: Painter, path: String) -> void:
	var err := p.save(path)
	if err != OK:
		push_error("[assets] could not save %s (error %d)" % [path, err])
		_ok = false
	else:
		print("[assets] wrote ", path)


## 48x48 flower cart with a striped awning. Origin (48/2, 46).
func _gen_market_cart() -> void:
	var p := Painter.new(48, 48, 1301)
	# poles
	p.rect(5, 10, 2, 30, WOOD[1])
	p.rect(41, 10, 2, 30, WOOD[0])
	# awning: alternating pink / cream stripes with scalloped edge
	for y in range(4, 14):
		var inset := maxi(0, 4 - (y - 4))
		for x in range(2 + inset, 46 - inset):
			var stripe := ((x - 2) / 5) % 2 == 0
			var c: Color = PINK[1] if stripe else CREAM
			if y < 6:
				c = PINK[0] if stripe else Color("e6d3c3")
			p.px(x, y, c)
	for x in range(2, 46):
		if ((x - 2) % 5) in [1, 2, 3]:
			p.px(x, 14, PINK[1] if ((x - 2) / 5) % 2 == 0 else CREAM)
	# counter
	p.rect(4, 28, 40, 14, WOOD[2])
	p.hline(4, 28, 40, WOOD[3])
	for x in range(4, 44, 6):
		p.vline(x, 30, 12, WOOD[1])
	p.hline(4, 41, 40, WOOD[0])
	# flower buckets on the counter
	var blooms := [Color("e07a9a"), Color("f2c14e"), Color("9d8bc9"), Color("fbf3e3"), Color("c4466a"), Color("f5bfd0")]
	for i in 6:
		var bx := 7 + i * 6
		p.rect(bx, 24, 4, 4, Color("9d98ab"))
		p.vline(bx, 24, 4, Color("c2bdcc"))
		p.disc(bx + 2, 21, 2.4, Color("5c9656"))
		for j in 4:
			p.px(bx + j % 3, 19 + j / 2 + (i % 2), blooms[i])
	# hanging sign
	p.rect(17, 15, 14, 7, CREAM)
	p.hline(17, 21, 14, Color("e3d1b8"))
	p.disc(24, 18, 2, PINK[1])
	p.px(24, 18, Color("f2c14e"))
	# wheels
	p.disc(10, 43, 4, WOOD[0])
	p.disc(10, 43, 2, WOOD[2])
	p.disc(38, 43, 4, WOOD[0])
	p.disc(38, 43, 2, WOOD[2])
	p.outline(OUTLINE)
	_save(p, "res://assets/objects/market_cart.png")


## 16x16 wooden chest with a brass latch. Origin (8, 15).
func _gen_chest() -> void:
	var p := Painter.new(16, 16, 1303)
	p.rect(1, 5, 14, 10, WOOD[2])
	p.rect(1, 3, 14, 4, WOOD[1])
	p.hline(1, 3, 14, WOOD[3])
	p.hline(1, 7, 14, WOOD[0])
	p.vline(1, 3, 12, WOOD[3])
	p.vline(14, 3, 12, WOOD[0])
	p.vline(4, 3, 12, Color("c99a55"))
	p.vline(11, 3, 12, Color("c99a55"))
	p.rect(7, 6, 2, 3, Color("f2c14e"))
	p.px(7, 8, Color("c99a55"))
	p.outline(OUTLINE)
	_save(p, "res://assets/objects/chest.png")


func _gen_particles() -> void:
	var rain := Painter.new(1, 5, 1)
	rain.px(0, 0, Color(0.85, 0.93, 1.0, 0.25))
	rain.px(0, 1, Color(0.85, 0.93, 1.0, 0.5))
	rain.rect(0, 2, 1, 3, Color(0.85, 0.93, 1.0, 0.8))
	_save(rain, "res://assets/effects/rain.png")
	var snow := Painter.new(3, 3, 2)
	snow.px(1, 0, Color(1, 1, 1, 0.7))
	snow.px(0, 1, Color(1, 1, 1, 0.7))
	snow.px(2, 1, Color(1, 1, 1, 0.7))
	snow.px(1, 2, Color(1, 1, 1, 0.7))
	snow.px(1, 1, Color.WHITE)
	_save(snow, "res://assets/effects/snow.png")


## weather_icons.png: 12x12 each, Weather.Kind order:
## sunny, rain, storm, fog, snow, wind
func _gen_weather_icons() -> void:
	var atlas := Painter.new(12 * 6, 12, 1305)
	var icons := [_icon_sun, _icon_rain, _icon_storm, _icon_fog, _icon_snow, _icon_wind]
	for i in icons.size():
		var p := Painter.new(12, 12, 1310 + i)
		(icons[i] as Callable).call(p)
		p.outline(OUTLINE)
		atlas.blit_image(p.image, i * 12, 0)
	_save(atlas, "res://assets/ui/weather_icons.png")


func _cloud(p: Painter, y: int) -> void:
	p.disc(4, y + 1, 2.6, Color("e6e3ec"))
	p.disc(7, y, 3.0, Color("f4f2f7"))
	p.rect(2, y + 1, 8, 3, Color("e6e3ec"))
	p.hline(2, y + 3, 8, Color("c2bdcc"))


func _icon_sun(p: Painter) -> void:
	p.disc(6, 6, 3.2, Color("f2c14e"))
	p.px(5, 5, Color("f9dc7c"))
	for o: Vector2i in [Vector2i(0, -5), Vector2i(0, 5), Vector2i(-5, 0), Vector2i(5, 0)]:
		p.px(6 + o.x, 6 + o.y, Color("f2c14e"))


func _icon_rain(p: Painter) -> void:
	_cloud(p, 2)
	for x in [3, 6, 9]:
		p.vline(x, 8, 2, Color("86bcd8"))


func _icon_storm(p: Painter) -> void:
	_cloud(p, 2)
	p.px(6, 7, Color("f2c14e"))
	p.px(5, 8, Color("f2c14e"))
	p.px(6, 9, Color("f2c14e"))
	p.px(5, 10, Color("f2c14e"))


func _icon_fog(p: Painter) -> void:
	for y in [3, 6, 9]:
		p.hline(1 + (y % 2), y, 9, Color("dcd8e3"))


func _icon_snow(p: Painter) -> void:
	for o: Vector2i in [Vector2i(0, -4), Vector2i(0, 4), Vector2i(-4, 0), Vector2i(4, 0),
			Vector2i(-3, -3), Vector2i(3, 3), Vector2i(-3, 3), Vector2i(3, -3)]:
		p.px(6 + o.x, 6 + o.y, Color.WHITE)
	p.disc(6, 6, 1.6, Color("e4f3f8"))


func _icon_wind(p: Painter) -> void:
	p.hline(1, 4, 7, Color("dcd8e3"))
	p.px(8, 3, Color("dcd8e3"))
	p.hline(3, 7, 7, Color("dcd8e3"))
	p.px(10, 6, Color("dcd8e3"))
	p.px(5, 9, Color("85b56c"))
	p.px(6, 10, Color("85b56c"))


## 10x10 Pétala coin (✿): golden flower medallion.
func _gen_coin() -> void:
	var p := Painter.new(10, 10, 1320)
	p.disc(5, 5, 4.4, Color("f2c14e"))
	p.disc(5, 5, 3.2, Color("f9dc7c"))
	for o: Vector2i in [Vector2i(0, -2), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(2, 0)]:
		p.px(5 + o.x, 5 + o.y, Color("e07a9a"))
	p.px(5, 5, Color("c99a55"))
	p.outline(Color("8a5d3f"))
	_save(p, "res://assets/ui/coin.png")
