class_name Villagers
extends RefCounted
## Registry of villagers (data/npcs/villagers.json) and their dialogue
## (data/dialogues/villagers.json), plus schedule resolution.

const NPC_PATH := "res://data/npcs/villagers.json"
const DIALOGUE_PATH := "res://data/dialogues/villagers.json"

static var _npcs: Dictionary = {}
static var _dialogue: Dictionary = {}


static func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Villagers: invalid %s" % path)
		return {}
	return parsed


static func data() -> Dictionary:
	if _npcs.is_empty():
		_npcs = _load(NPC_PATH)
	return _npcs


static func clear_cache() -> void:
	_npcs = {}
	_dialogue = {}


static func config() -> Dictionary:
	return data().get("friendship", {})


static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in data().get("npcs", {}):
		out.append(id)
	return out


static func npc(id: String) -> Dictionary:
	return (data().get("npcs", {}) as Dictionary).get(id, {})


static func display_name(id: String) -> String:
	return str(npc(id).get("name", id))


static func dialogue(id: String) -> Dictionary:
	if _dialogue.is_empty():
		_dialogue = _load(DIALOGUE_PATH)
	return (_dialogue.get("dialogue", {}) as Dictionary).get(id, {})


static func is_birthday(id: String, season: int, day: int) -> bool:
	var b: Array = npc(id).get("birthday", [-1, -1])
	return int(b[0]) == season and int(b[1]) == day


## The schedule variant for today: the first whose conditions all match
## (weekdays / seasons / rain); a variant without conditions is the default.
static func schedule_for(id: String, weekday: int, season: int, raining: bool) -> Array:
	for variant: Dictionary in npc(id).get("schedule", []):
		var when: Dictionary = variant.get("when", {})
		if when.has("weekdays") and not JsonUtil.has_int(when["weekdays"], weekday):
			continue
		if when.has("seasons") and not JsonUtil.has_int(when["seasons"], season):
			continue
		if when.has("rain") and bool(when["rain"]) != raining:
			continue
		return variant.get("entries", [])
	return []


## Where a villager is at a time: {"map", "cell", "facing"}; {} = at home
## (not visible anywhere).
static func where(id: String, minutes: int, weekday: int, season: int, raining: bool) -> Dictionary:
	var current: Array = []
	for entry: Array in schedule_for(id, weekday, season, raining):
		if int(entry[0]) <= minutes:
			current = entry
	if current.is_empty() or current[1] == null:
		return {}
	var facing := Vector2.DOWN
	match str(current[4]) if current.size() > 4 else "down":
		"up":
			facing = Vector2.UP
		"left":
			facing = Vector2.LEFT
		"right":
			facing = Vector2.RIGHT
	return {"map": StringName(str(current[1])), "cell": Vector2i(int(current[2]), int(current[3])), "facing": facing}


## "loved" / "liked" / "neutral" / "disliked" for an item.
static func gift_reaction(id: String, item_id: StringName) -> String:
	var gifts: Dictionary = npc(id).get("gifts", {})
	var item := ItemRegistry.item(item_id)
	for reaction in ["loved", "disliked", "liked"]:
		for entry in gifts.get(reaction, []):
			var e := str(entry)
			if e.begins_with("tag:"):
				if item and item.tags.has(e.trim_prefix("tag:")):
					return reaction
			elif e == String(item_id):
				return reaction
	return "neutral"


static func can_gift(item_id: StringName) -> bool:
	var item := ItemRegistry.item(item_id)
	return item != null and not item.is_tool()
