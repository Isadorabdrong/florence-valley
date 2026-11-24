class_name FarmActionResolver
extends RefCounted
## Decides what using an item (or interacting) on a cell would do, without
## doing it. FarmController executes the result; the cursor uses it to show
## whether an action is possible. World queries are injected as callables so
## the rules are unit-testable without a scene.

enum Action {
	NONE, TILL, UNTILL, WATER, REFILL, PLANT, FERTILIZE, HARVEST,
	CLEAR_WEED, BREAK_ROCK, CLEAR_CROP, SLEEP, OPEN_SHOP, OPEN_CHEST,
	INTERACT, FORAGE, TALK, GIFT, PLACE, PICK_UP,
}

## Object kinds reported by object_kind_at
const KIND_NONE := &""
const KIND_ROCK := &"rock"
const KIND_WEED := &"weed"
const KIND_WELL := &"well"
## Generic interactive object; what it does comes from world.json.
const KIND_INTERACT := &"interact"
const KIND_BED := &"bed"
const KIND_FORAGE := &"forage"
const KIND_NPC := &"npc"
## A player build (removable with the pickaxe).
const KIND_PLACED := &"placed"
const KIND_SOLID := &"solid"
const KIND_SHOP := &"shop"
const KIND_CHEST := &"chest"
## Objects whose interaction wins over any held item (except the can at the well).
const INTERACTIVE_KINDS: Array[StringName] = [KIND_INTERACT, KIND_SHOP, KIND_CHEST, KIND_BED, KIND_FORAGE, KIND_NPC]

const TILLABLE_TERRAIN: Array[String] = ["grass", "grass_flowers", "soil"]
const WATER_TERRAIN := "water"

var soil: SoilGrid
## () -> int (Calendar.Season)
var season: Callable
## (Vector2i) -> String
var terrain_at: Callable
## (Vector2i) -> StringName (one of the KIND_* constants)
var object_kind_at: Callable
## () -> int, () -> int
var can_charges: Callable
var can_capacity: Callable
## () -> bool. Tilling/planting only where the map allows farming.
var farming_allowed: Callable
## (Vector2i, ItemData) -> String: "" if a build fits, else a message key.
var can_place: Callable


static func result(action: Action, reason_key: String = "") -> Dictionary:
	return {"action": action, "reason": reason_key}


func resolve_use(cell: Vector2i, item: ItemData) -> Dictionary:
	if item != null and object_kind_at.call(cell) == KIND_NPC and not item.is_tool():
		return result(Action.GIFT)
	if item != null and item.is_placeable():
		var reason: String = can_place.call(cell, item) if can_place.is_valid() else "MSG_CANT_USE_HERE"
		return result(Action.PLACE) if reason.is_empty() else result(Action.NONE, reason)
	if item == null or INTERACTIVE_KINDS.has(object_kind_at.call(cell)):
		return resolve_interact(cell)
	var farming := not farming_allowed.is_valid() or bool(farming_allowed.call())
	if not farming and (item.category == ItemData.Category.SEED or item.category == ItemData.Category.FERTILIZER \
			or item.tool_kind == ItemData.ToolKind.HOE):
		return result(Action.NONE, "MSG_NO_FARMING_HERE")
	match item.category:
		ItemData.Category.TOOL:
			return _resolve_tool(cell, item.tool_kind)
		ItemData.Category.SEED:
			return _resolve_seed(cell, item)
		ItemData.Category.FERTILIZER:
			if not soil.is_tilled(cell):
				return result(Action.NONE, "MSG_NEEDS_TILLED")
			if soil.is_fertilized(cell):
				return result(Action.NONE, "MSG_ALREADY_FERTILIZED")
			return result(Action.FERTILIZE)
	return result(Action.NONE, "MSG_CANT_USE_HERE")


## Context action (E): harvest, sleep in the house, refill at the well.
func resolve_interact(cell: Vector2i) -> Dictionary:
	if soil.is_harvestable(cell):
		return result(Action.HARVEST)
	match object_kind_at.call(cell):
		KIND_INTERACT:
			return result(Action.INTERACT)
		KIND_BED:
			return result(Action.SLEEP)
		KIND_FORAGE:
			return result(Action.FORAGE)
		KIND_NPC:
			return result(Action.TALK)
		KIND_SHOP:
			return result(Action.OPEN_SHOP)
		KIND_CHEST:
			return result(Action.OPEN_CHEST)
		KIND_WELL:
			return _refill()
	return result(Action.NONE)


func _resolve_tool(cell: Vector2i, kind: ItemData.ToolKind) -> Dictionary:
	var obj: StringName = object_kind_at.call(cell)
	match kind:
		ItemData.ToolKind.HOE:
			if soil.is_withered(cell):
				return result(Action.CLEAR_CROP)
			if soil.has_crop(cell):
				return result(Action.NONE, "MSG_HAS_CROP")
			if soil.is_tilled(cell):
				return result(Action.NONE, "MSG_ALREADY_TILLED")
			if obj == KIND_WEED or obj == KIND_ROCK:
				return result(Action.NONE, "MSG_CLEAR_FIRST")
			if obj != KIND_NONE:
				return result(Action.NONE, "MSG_BLOCKED")
			if not TILLABLE_TERRAIN.has(terrain_at.call(cell)):
				return result(Action.NONE, "MSG_CANT_TILL")
			return result(Action.TILL)
		ItemData.ToolKind.WATERING_CAN:
			if obj == KIND_WELL or terrain_at.call(cell) == WATER_TERRAIN:
				return _refill()
			if not soil.is_tilled(cell):
				return result(Action.NONE, "MSG_NOTHING_TO_WATER")
			if int(can_charges.call()) <= 0:
				return result(Action.NONE, "MSG_CAN_EMPTY")
			if soil.is_watered(cell):
				return result(Action.NONE, "MSG_ALREADY_WATERED")
			return result(Action.WATER)
		ItemData.ToolKind.SCYTHE:
			if obj == KIND_WEED:
				return result(Action.CLEAR_WEED)
			if soil.is_harvestable(cell):
				return result(Action.HARVEST)
			if soil.is_withered(cell):
				return result(Action.CLEAR_CROP)
			return result(Action.NONE, "MSG_NOTHING_TO_CUT")
		ItemData.ToolKind.PICKAXE:
			if obj == KIND_PLACED:
				return result(Action.PICK_UP)
			if obj == KIND_ROCK:
				return result(Action.BREAK_ROCK)
			if soil.is_tilled(cell) and not soil.has_crop(cell):
				return result(Action.UNTILL)
			return result(Action.NONE, "MSG_NOTHING_TO_BREAK")
	return result(Action.NONE, "MSG_CANT_USE_HERE")


func _resolve_seed(cell: Vector2i, item: ItemData) -> Dictionary:
	match soil.can_plant(cell, item.flower_id, int(season.call())):
		SoilGrid.PlantError.NONE:
			return result(Action.PLANT)
		SoilGrid.PlantError.NOT_TILLED:
			return result(Action.NONE, "MSG_NEEDS_TILLED")
		SoilGrid.PlantError.OCCUPIED:
			return result(Action.NONE, "MSG_HAS_CROP")
		SoilGrid.PlantError.OUT_OF_SEASON:
			return result(Action.NONE, "MSG_OUT_OF_SEASON")
		SoilGrid.PlantError.NEEDS_GREENHOUSE:
			return result(Action.NONE, "MSG_NEEDS_GREENHOUSE")
	return result(Action.NONE, "MSG_CANT_USE_HERE")


func _refill() -> Dictionary:
	if int(can_charges.call()) >= int(can_capacity.call()):
		return result(Action.NONE, "MSG_CAN_FULL")
	return result(Action.REFILL)
