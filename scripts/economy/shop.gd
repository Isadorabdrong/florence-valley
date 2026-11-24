class_name Shop
extends RefCounted
## A shop defined in data/shops/*.json. Pure rules for buying and selling,
## operating on a Wallet and an Inventory.

enum Result { OK, NOT_ENOUGH_MONEY, INVENTORY_FULL, NOT_SOLD_HERE, NOTHING_TO_SELL, INVALID,
	NEEDS_MATERIALS, NEEDS_LEVEL, NEEDS_OLD_TOOL }

const RESULT_KEYS := {
	Result.NOT_ENOUGH_MONEY: "SHOP_NOT_ENOUGH_MONEY",
	Result.INVENTORY_FULL: "MSG_INVENTORY_FULL",
	Result.NOT_SOLD_HERE: "SHOP_NOT_SOLD",
	Result.NOTHING_TO_SELL: "SHOP_CANT_SELL",
	Result.INVALID: "SHOP_CANT_SELL",
	Result.NEEDS_MATERIALS: "SHOP_NEEDS_MATERIALS",
	Result.NEEDS_LEVEL: "SHOP_NEEDS_LEVEL",
	Result.NEEDS_OLD_TOOL: "SHOP_NEEDS_OLD_TOOL",
}

var id := ""
var name_key := ""
var greeting_key := ""
## [{item, seasonal, materials: [[id, n]], min_level, replaces}]
var stock: Array[Dictionary] = []
var sell_multiplier := 1.0


static func load_from_file(path: String) -> Shop:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Shop: cannot open %s" % path)
		return null
	var data: Variant = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Shop: invalid JSON in %s" % path)
		return null
	return from_dict(data)


static func from_dict(data: Dictionary) -> Shop:
	var shop := Shop.new()
	shop.id = str(data.get("id", ""))
	shop.name_key = str(data.get("name_key", ""))
	shop.greeting_key = str(data.get("greeting_key", ""))
	shop.sell_multiplier = clampf(float(data.get("sell_multiplier", 1.0)), 0.0, 10.0)
	for entry in data.get("stock", []):
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id := StringName(str(entry.get("item", "")))
		if not ItemRegistry.has_item(item_id):
			push_error("Shop %s: unknown item %s" % [shop.id, item_id])
			continue
		shop.stock.append({"item": item_id, "seasonal": bool(entry.get("seasonal", true)),
			"materials": entry.get("materials", []), "min_level": int(entry.get("min_level", 1)),
			"replaces": StringName(str(entry.get("replaces", "")))})
	return shop


func entry_for(item_id: StringName) -> Dictionary:
	for entry in stock:
		if entry["item"] == item_id:
			return entry
	return {}


## Gardening level needed to buy an item (entry or flower requirement).
func required_level(item_id: StringName) -> int:
	var lv := int(entry_for(item_id).get("min_level", 1))
	var item := ItemRegistry.item(item_id)
	if item and item.flower_id != &"":
		var fl := ItemRegistry.flower(item.flower_id)
		if fl:
			lv = maxi(lv, fl.min_level)
	return lv


func materials_for(item_id: StringName) -> Array:
	return entry_for(item_id).get("materials", [])


## Items for sale today. Seeds marked seasonal only appear in their seasons.
## Items above the player's level are listed (locked) so goals are visible.
func available_items(season: int) -> Array[ItemData]:
	var out: Array[ItemData] = []
	for entry in stock:
		var item := ItemRegistry.item(entry["item"])
		if item == null or item.buy_price <= 0:
			continue
		if entry["seasonal"] and item.flower_id != &"":
			var fl := ItemRegistry.flower(item.flower_id)
			if fl and not fl.grows_in(season):
				continue
		out.append(item)
	return out


func sells(item_id: StringName, season: int) -> bool:
	for item in available_items(season):
		if item.id == item_id:
			return true
	return false


func sell_price(item_id: StringName) -> int:
	var item := ItemRegistry.item(item_id)
	if item == null or item.is_tool():
		return 0
	return int(round(item.sell_price * sell_multiplier))


func buy(item_id: StringName, quantity: int, season: int, wallet: Wallet, inventory: Inventory,
		level: int = 99) -> Result:
	if quantity <= 0:
		return Result.INVALID
	if not sells(item_id, season):
		return Result.NOT_SOLD_HERE
	if level < required_level(item_id):
		return Result.NEEDS_LEVEL
	var replaces: StringName = entry_for(item_id).get("replaces", &"")
	if replaces != &"":
		quantity = 1
		if inventory.count_of(replaces) < 1:
			return Result.NEEDS_OLD_TOOL
	var cost := ItemRegistry.item(item_id).buy_price * quantity
	if not wallet.can_afford(cost):
		return Result.NOT_ENOUGH_MONEY
	for entry: Array in materials_for(item_id):
		if inventory.count_of(StringName(str(entry[0]))) < int(entry[1]) * quantity:
			return Result.NEEDS_MATERIALS
	if replaces == &"" and not inventory.can_add(item_id, quantity):
		return Result.INVENTORY_FULL
	wallet.spend(cost)
	for entry: Array in materials_for(item_id):
		inventory.remove_item(StringName(str(entry[0])), int(entry[1]) * quantity)
	if replaces != &"":
		# The upgraded tool takes the old one's slot.
		var slot := inventory.first_slot_of(replaces)
		inventory.take_slot(slot)
		inventory.put_in_slot(slot, item_id, 1)
	else:
		inventory.add_item(item_id, quantity)
	return Result.OK


## Sells up to `quantity` of an item from anywhere in the inventory.
func sell(item_id: StringName, quantity: int, wallet: Wallet, inventory: Inventory) -> Result:
	var price := sell_price(item_id)
	if price <= 0:
		return Result.NOTHING_TO_SELL
	var count := mini(quantity, inventory.count_of(item_id))
	if count <= 0:
		return Result.NOTHING_TO_SELL
	inventory.remove_item(item_id, count)
	wallet.add(price * count)
	return Result.OK


static func result_key(result: Result) -> String:
	return RESULT_KEYS.get(result, "")
