class_name ItemRegistry
extends RefCounted
## Central lookup for item and flower definitions.
## Loads every .tres in the data folders once and derives seed/flower items
## from each FlowerData, so a new species needs only one resource file.

const ITEM_DIRS: Array[String] = ["res://resources/tools", "res://resources/items", "res://resources/build"]
const FLOWER_DIR := "res://resources/flowers"
const ICON_ATLAS := preload("res://assets/ui/item_icons.png")
const ICON_SIZE := 16
const SEED_ICON_ROW := 1
const FLOWER_ICON_ROW := 2
const BOUQUET_ICON_ROW := 4

static var _items: Dictionary = {}
static var _flowers: Dictionary = {}
static var _icons: Dictionary = {}
static var _loaded := false


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for dir in ITEM_DIRS:
		for res in _load_dir(dir):
			if res is ItemData:
				_register_item(res)
	for res in _load_dir(FLOWER_DIR):
		if res is FlowerData:
			var flower := res as FlowerData
			for problem in flower.validate():
				push_error("ItemRegistry: flower %s" % problem)
			_flowers[flower.id] = flower
			_register_item(_make_seed(flower))
			_register_item(_make_cut_flower(flower))
	for recipe in BouquetBook.recipes():
		_register_item(_make_bouquet(recipe))


## Drops cached definitions (used at shutdown and by tools).
static func clear_cache() -> void:
	_items.clear()
	_flowers.clear()
	_icons.clear()
	_loaded = false


static func item(id: StringName) -> ItemData:
	ensure_loaded()
	return _items.get(id)


static func has_item(id: StringName) -> bool:
	ensure_loaded()
	return _items.has(id)


static func flower(id: StringName) -> FlowerData:
	ensure_loaded()
	return _flowers.get(id)


static func all_flowers() -> Array[FlowerData]:
	ensure_loaded()
	var list: Array[FlowerData] = []
	for f: FlowerData in _flowers.values():
		list.append(f)
	list.sort_custom(func(a: FlowerData, b: FlowerData) -> bool: return a.atlas_row < b.atlas_row)
	return list


static func all_item_ids() -> Array[StringName]:
	ensure_loaded()
	var ids: Array[StringName] = []
	for id: StringName in _items:
		ids.append(id)
	return ids


static func seed_id(flower_id: StringName) -> StringName:
	return StringName("seed_" + String(flower_id))


static func flower_item_id(flower_id: StringName) -> StringName:
	return StringName("flower_" + String(flower_id))


static func max_stack(id: StringName) -> int:
	var data := item(id)
	return data.max_stack if data else 0


static func icon(id: StringName) -> Texture2D:
	ensure_loaded()
	if _icons.has(id):
		return _icons[id]
	var data := item(id)
	if data == null:
		return null
	var atlas := AtlasTexture.new()
	atlas.atlas = ICON_ATLAS
	atlas.region = Rect2(data.icon_coords * ICON_SIZE, Vector2(ICON_SIZE, ICON_SIZE))
	_icons[id] = atlas
	return atlas


## Multi-line description for tooltips / the inventory detail panel.
static func describe(id: StringName) -> String:
	var data := item(id)
	if data == null:
		return ""
	var lines: PackedStringArray = [TranslationServer.translate(data.description_key)]
	var fl := flower(data.flower_id) if data.flower_id != &"" else null
	if data.category == ItemData.Category.BOUQUET:
		var recipe := BouquetBook.recipe(id)
		lines.append(TranslationServer.translate(BouquetBook.TYPE_KEYS.get(str(recipe.get("type")), "")))
		if recipe.has("season"):
			lines.append(TranslationServer.translate("BOUQUET_IN_SEASON") % TranslationServer.translate(Calendar.SEASON_KEYS[int(recipe["season"])]))
	if fl and data.category == ItemData.Category.SEED:
		var season_names := PackedStringArray()
		for s in fl.seasons:
			season_names.append(TranslationServer.translate(Calendar.SEASON_KEYS[s]))
		lines.append(TranslationServer.translate("DESC_SEASONS") % ", ".join(season_names))
		lines.append(TranslationServer.translate("DESC_GROWTH") % fl.total_growth_days())
		lines.append(TranslationServer.translate("DESC_WATER") % TranslationServer.translate(
			["WATER_LOW", "WATER_MEDIUM", "WATER_HIGH"][fl.water_need]))
		if fl.regrows:
			lines.append(TranslationServer.translate("DESC_REGROWS") % fl.days_to_regrow())
		if fl.special != FlowerData.Special.NONE:
			lines.append(TranslationServer.translate(
				["", "SPECIAL_NEEDS_FERTILIZER", "SPECIAL_LOVES_WATER", "SPECIAL_GREENHOUSE_ONLY"][fl.special]))
	return "\n".join(lines)


static func _register_item(data: ItemData) -> void:
	if data.id == &"":
		push_error("ItemRegistry: item without id")
		return
	if _items.has(data.id):
		push_error("ItemRegistry: duplicate item id %s" % data.id)
		return
	_items[data.id] = data


static func _make_seed(fl: FlowerData) -> ItemData:
	var data := ItemData.new()
	data.id = seed_id(fl.id)
	data.name_key = fl.name_key
	data.name_format_key = "ITEM_SEEDS_OF"
	data.description_key = "ITEM_SEED_DESC"
	data.category = ItemData.Category.SEED
	data.buy_price = fl.seed_price
	data.sell_price = maxi(1, fl.seed_price / 2)
	data.icon_coords = Vector2i(fl.atlas_row, SEED_ICON_ROW)
	data.flower_id = fl.id
	return data


static func _make_cut_flower(fl: FlowerData) -> ItemData:
	var data := ItemData.new()
	data.id = flower_item_id(fl.id)
	data.name_key = fl.name_key
	data.description_key = fl.description_key
	data.category = ItemData.Category.FLOWER
	data.sell_price = fl.sell_price
	data.icon_coords = Vector2i(fl.atlas_row, FLOWER_ICON_ROW)
	data.flower_id = fl.id
	data.tags = PackedStringArray(["flower"]) + fl.tags
	return data


## Bouquets are defined by their recipe (data/recipes/bouquets.json).
static func _make_bouquet(recipe: Dictionary) -> ItemData:
	var data := ItemData.new()
	var id := str(recipe["id"])
	data.id = StringName(id)
	data.name_key = "ITEM_" + id.to_upper()
	data.description_key = "ITEM_" + id.to_upper() + "_DESC"
	data.category = ItemData.Category.BOUQUET
	data.max_stack = 20
	data.sell_price = int(recipe.get("value", 0))
	data.icon_coords = Vector2i(int(recipe.get("icon", 0)), BOUQUET_ICON_ROW)
	data.tags = PackedStringArray(["bouquet", str(recipe.get("type", "simple"))])
	return data


## Lists resources in a folder. Exported builds rename text resources to
## *.remap, so that suffix is stripped before loading.
static func _load_dir(dir_path: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("ItemRegistry: missing folder %s" % dir_path)
		return out
	var files := dir.get_files()
	files.sort()
	for file in files:
		var name := file.trim_suffix(".remap")
		if not name.ends_with(".tres"):
			continue
		var res := load(dir_path.path_join(name))
		if res:
			out.append(res)
	return out
