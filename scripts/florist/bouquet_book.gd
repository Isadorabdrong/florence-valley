class_name BouquetBook
extends RefCounted
## Bouquet recipes (data/recipes/bouquets.json). A bouquet is always made of
## exactly INGREDIENTS items; the first recipe whose requirements can be
## matched by the chosen items wins (recipes are ordered rare → simple).

const PATH := "res://data/recipes/bouquets.json"
const INGREDIENTS := 3
const TYPE_KEYS := {
	"simple": "BOUQUET_TYPE_SIMPLE", "romantic": "BOUQUET_TYPE_ROMANTIC",
	"sophisticated": "BOUQUET_TYPE_SOPHISTICATED", "seasonal": "BOUQUET_TYPE_SEASONAL", "rare": "BOUQUET_TYPE_RARE",
}

static var _recipes: Array[Dictionary] = []


static func recipes() -> Array[Dictionary]:
	if _recipes.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file == null:
			push_error("BouquetBook: cannot open %s" % PATH)
			return _recipes
		var data: Variant = JSON.parse_string(file.get_as_text())
		if typeof(data) != TYPE_DICTIONARY:
			push_error("BouquetBook: invalid JSON")
			return _recipes
		for r: Dictionary in data.get("recipes", []):
			_recipes.append(r)
	return _recipes


static func clear_cache() -> void:
	_recipes.clear()


static func recipe(id: StringName) -> Dictionary:
	for r in recipes():
		if r["id"] == String(id):
			return r
	return {}


## One predicate per ingredient unit, e.g. 2× rose → two "rose" predicates.
static func _requirements(r: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for ing: Dictionary in r.get("ingredients", []):
		for i in int(ing.get("count", 1)):
			out.append(ing)
	return out


static func item_satisfies(item_id: StringName, req: Dictionary) -> bool:
	if req.has("item"):
		return String(item_id) == str(req["item"])
	if req.has("any"):
		return (req["any"] as Array).has(String(item_id))
	if req.has("tag"):
		var item := ItemRegistry.item(item_id)
		return item != null and item.tags.has(str(req["tag"]))
	return false


## Can these items fill the recipe's slots (in some order)?
static func matches(r: Dictionary, items: Array[StringName]) -> bool:
	var reqs := _requirements(r)
	if reqs.size() != items.size():
		return false
	return _assign(reqs, items, 0, [])


static func _assign(reqs: Array[Dictionary], items: Array[StringName], index: int, used: Array) -> bool:
	if index == reqs.size():
		return true
	for i in items.size():
		if used.has(i) or not item_satisfies(items[i], reqs[index]):
			continue
		used.append(i)
		if _assign(reqs, items, index + 1, used):
			return true
		used.pop_back()
	return false


## The recipe these items make, or {} if none.
static func find(items: Array[StringName]) -> Dictionary:
	if items.size() != INGREDIENTS:
		return {}
	for r in recipes():
		if matches(r, items):
			return r
	return {}


static func ingredients_value(items: Array[StringName]) -> int:
	var total := 0
	for id in items:
		var item := ItemRegistry.item(id)
		if item:
			total += item.sell_price
	return total


## Consistency checks (tests). Returns problems.
static func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	var ids := {}
	for r in recipes():
		var id := str(r.get("id", ""))
		if ids.has(id):
			problems.append("duplicate recipe %s" % id)
		ids[id] = true
		if not TYPE_KEYS.has(str(r.get("type"))):
			problems.append("%s: unknown type %s" % [id, r.get("type")])
		if _requirements(r).size() != INGREDIENTS:
			problems.append("%s: needs exactly %d ingredients" % [id, INGREDIENTS])
		for ing: Dictionary in r.get("ingredients", []):
			for item_id in ([ing["item"]] if ing.has("item") else ing.get("any", [])):
				if not ItemRegistry.has_item(StringName(str(item_id))):
					problems.append("%s: unknown item %s" % [id, item_id])
	return problems
