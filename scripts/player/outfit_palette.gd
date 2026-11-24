class_name OutfitPalette
extends RefCounted
## Outfit colour options (data/configuration/character_options.json) applied
## through a palette-swap shader, so one sprite sheet supports every outfit.

const DATA_PATH := "res://data/configuration/character_options.json"
const SHADER := preload("res://shaders/palette_swap.gdshader")

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		_cache = _load()
	return _cache


static func count() -> int:
	return (data().get("outfits", []) as Array).size()


static func outfit(index: int) -> Dictionary:
	var list: Array = data().get("outfits", [])
	if list.is_empty():
		return {}
	return list[clampi(index, 0, list.size() - 1)]


static func make_material(index: int) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var src: Dictionary = data().get("outfit_source", {})
	var dst := outfit(index)
	mat.set_shader_parameter("src_main", Color(src.get("main", "6f8fc0")))
	mat.set_shader_parameter("src_shade", Color(src.get("shade", "52709f")))
	mat.set_shader_parameter("dst_main", Color(dst.get("main", src.get("main", "6f8fc0"))))
	mat.set_shader_parameter("dst_shade", Color(dst.get("shade", src.get("shade", "52709f"))))
	return mat


static func _load() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("OutfitPalette: cannot open %s" % DATA_PATH)
		return {"outfits": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not (parsed as Dictionary).has("outfits"):
		push_error("OutfitPalette: invalid data in %s" % DATA_PATH)
		return {"outfits": []}
	return parsed
