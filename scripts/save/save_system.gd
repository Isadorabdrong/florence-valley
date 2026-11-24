class_name SaveSystem
extends RefCounted
## Local save files: user://saves/slot_N.json
##
## File layout (JSON):
##   format          "florence_valley_save"
##   schema_version  int — bumped whenever the payload layout changes
##   game_version    string — informative
##   saved_at        unix time
##   summary         small dict for the load screen (not trusted for loading)
##   checksum        sha256 of `payload`
##   payload         the game data, itself a JSON string (so the checksum is
##                   computed over exactly the bytes that were written)
##
## Writes go to a .tmp file first and replace the save atomically; the
## previous save is kept as .bak and used automatically if the main file is
## corrupt. Older schema versions are migrated step by step (MIGRATIONS).

enum LoadError { NONE, MISSING, CORRUPT, UNSUPPORTED_VERSION, INVALID }

const FORMAT := "florence_valley_save"
const SCHEMA_VERSION := 5
const SLOT_COUNT := 3
const DEFAULT_DIR := "user://saves"

const ERROR_KEYS := {
	LoadError.MISSING: "SAVE_ERR_MISSING",
	LoadError.CORRUPT: "SAVE_ERR_CORRUPT",
	LoadError.UNSUPPORTED_VERSION: "SAVE_ERR_VERSION",
	LoadError.INVALID: "SAVE_ERR_INVALID",
}

## Tests point this at a separate folder.
static var save_dir := DEFAULT_DIR


static func slot_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


static func is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT


static func exists(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot)) or FileAccess.file_exists(slot_path(slot) + ".bak")


static func save(slot: int, data: Dictionary, summary: Dictionary = {}) -> Error:
	if not is_valid_slot(slot):
		return ERR_INVALID_PARAMETER
	var err := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_dir))
	if err != OK and err != ERR_ALREADY_EXISTS:
		return err
	var payload := JSON.stringify(data)
	var envelope := {
		"format": FORMAT,
		"schema_version": SCHEMA_VERSION,
		"game_version": str(ProjectSettings.get_setting("application/config/version", "")),
		"saved_at": int(Time.get_unix_time_from_system()),
		"summary": summary,
		"checksum": payload.sha256_text(),
		"payload": payload,
	}
	var path := slot_path(slot)
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope, "\t"))
	file.close()
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return ERR_CANT_OPEN
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			dir.remove(path.get_file() + ".bak")
		dir.rename(path.get_file(), path.get_file() + ".bak")
	return dir.rename(tmp.get_file(), path.get_file())


## Returns {"error": LoadError, "data": Dictionary, "from_backup": bool,
##          "migrated_from": int (or -1)}
static func load_slot(slot: int) -> Dictionary:
	var main := read_file(slot_path(slot))
	if main["error"] == LoadError.NONE:
		return main
	var backup := read_file(slot_path(slot) + ".bak")
	if backup["error"] == LoadError.NONE:
		backup["from_backup"] = true
		return backup
	return main


static func read_file(path: String) -> Dictionary:
	var result := {"error": LoadError.NONE, "data": {}, "from_backup": false, "migrated_from": -1, "summary": {},
		"saved_at": 0}
	if not FileAccess.file_exists(path):
		result["error"] = LoadError.MISSING
		return result
	var text := FileAccess.get_file_as_string(path)
	var envelope: Variant = JSON.parse_string(text)
	if typeof(envelope) != TYPE_DICTIONARY or envelope.get("format") != FORMAT:
		result["error"] = LoadError.CORRUPT
		return result
	var payload: Variant = envelope.get("payload")
	if typeof(payload) != TYPE_STRING or str(envelope.get("checksum", "")) != (payload as String).sha256_text():
		result["error"] = LoadError.CORRUPT
		return result
	var version := int(envelope.get("schema_version", -1))
	if version > SCHEMA_VERSION or version < 0:
		result["error"] = LoadError.UNSUPPORTED_VERSION
		return result
	var data: Variant = JSON.parse_string(payload)
	if typeof(data) != TYPE_DICTIONARY:
		result["error"] = LoadError.CORRUPT
		return result
	if version < SCHEMA_VERSION:
		data = migrate(data, version)
		result["migrated_from"] = version
	result["data"] = data
	result["summary"] = envelope.get("summary", {}) if typeof(envelope.get("summary")) == TYPE_DICTIONARY else {}
	result["saved_at"] = int(envelope.get("saved_at", 0))
	return result


## Upgrades payloads from older schema versions, one step at a time.
static func migrate(data: Dictionary, from_version: int) -> Dictionary:
	var current := data
	for v in range(from_version, SCHEMA_VERSION):
		match v:
			0:
				current = _migrate_0_to_1(current)
			1:
				current = _migrate_1_to_2(current)
			2:
				current = _migrate_2_to_3(current)
			3:
				current = _migrate_3_to_4(current)
			4:
				current = _migrate_4_to_5(current)
	return current


## Schema 0 (pre-release builds) stored money as "gold" and had no clock.
static func _migrate_0_to_1(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	if out.has("gold") and not out.has("money"):
		out["money"] = out["gold"]
	out.erase("gold")
	if not out.has("clock"):
		out["clock"] = {"minutes": GameClock.DAY_START}
	return out


## Schema 1 (v0.3) had a single map: put the player on the farm and add
## the exploration block introduced with the world in v0.4.
static func _migrate_1_to_2(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	var world: Dictionary = out.get("world", {}) if typeof(out.get("world")) == TYPE_DICTIONARY else {}
	if not world.has("map"):
		world["map"] = "farm"
	out["world"] = world
	if not out.has("exploration"):
		out["exploration"] = {"discoveries": [], "visited": ["farm"], "forage_picked": {}}
	return out


## Schema 2 (v0.4) had no flower shop: start with it unrestored.
static func _migrate_2_to_3(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	if not out.has("florist"):
		out["florist"] = {"restored": false, "reputation": 0}
	return out


## Schema 3 (v0.5) had no villagers or quests: start the story fresh.
static func _migrate_3_to_4(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	if not out.has("relationships"):
		out["relationships"] = {}
	if not out.has("quests"):
		out["quests"] = {}
	return out


## Schema 4 (v0.6) had no progression, builds or greenhouse.
static func _migrate_4_to_5(data: Dictionary) -> Dictionary:
	var out := data.duplicate(true)
	for key in ["progression", "placed"]:
		if not out.has(key):
			out[key] = {}
	if not out.has("greenhouse"):
		out["greenhouse"] = {"restored": false, "soil": {}}
	return out


static func delete(slot: int) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := slot_path(slot) + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Information for the load screen, one entry per slot:
## {"slot", "state": "empty"|"ok"|"corrupt", "summary", "saved_at", "from_backup"}
static func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot in range(1, SLOT_COUNT + 1):
		var entry := {"slot": slot, "state": "empty", "summary": {}, "saved_at": 0, "from_backup": false}
		if exists(slot):
			var r := load_slot(slot)
			if r["error"] == LoadError.NONE:
				entry["state"] = "ok"
				entry["summary"] = r["summary"]
				entry["saved_at"] = r["saved_at"]
				entry["from_backup"] = r["from_backup"]
			else:
				entry["state"] = "corrupt"
		out.append(entry)
	return out


static func first_free_slot() -> int:
	for slot in range(1, SLOT_COUNT + 1):
		if not exists(slot):
			return slot
	return -1


static func most_recent_slot() -> int:
	var best := -1
	var best_time := -1
	for entry in list_slots():
		if entry["state"] == "ok" and int(entry["saved_at"]) > best_time:
			best_time = int(entry["saved_at"])
			best = entry["slot"]
	return best


static func error_key(error: LoadError) -> String:
	return ERROR_KEYS.get(error, "")
