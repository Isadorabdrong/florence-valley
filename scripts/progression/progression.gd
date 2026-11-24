class_name Progression
extends RefCounted
## Gardening XP and levels, gameplay statistics and achievements
## (data/progression/progression.json). Pure: GameState feeds it events and
## a stat provider, and applies level/achievement rewards.

signal level_up(level: int)
## XP total changed (drives the HUD bar).
signal xp_changed(xp: int)
signal achievement_unlocked(id: String)

const PATH := "res://data/progression/progression.json"

static var _data: Dictionary = {}

var xp := 0
var level := 1
## Counters: "harvested_total", "harvested:<flower>", "crafted_total", …
var stats: Dictionary = {}
var achievements: Dictionary = {} # id -> day unlocked


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _data


static func xp_for(source: String) -> int:
	return int((data().get("xp", {}) as Dictionary).get(source, 0))


static func level_for(total_xp: int) -> int:
	var levels: Array = data().get("levels", [0])
	var lv := 1
	for i in levels.size():
		if total_xp >= int(levels[i]):
			lv = i + 1
	return lv


static func max_level() -> int:
	return (data().get("levels", [0]) as Array).size()


static func achievement_defs() -> Array:
	return data().get("achievements", [])


func reset() -> void:
	xp = 0
	level = 1
	stats.clear()
	achievements.clear()
	xp_changed.emit(xp)


## XP needed for the next level (or -1 at max) and progress in [0, 1].
func next_level_xp() -> int:
	var levels: Array = data().get("levels", [0])
	return int(levels[level]) if level < levels.size() else -1


func level_progress() -> float:
	var levels: Array = data().get("levels", [0])
	if level >= levels.size():
		return 1.0
	var a := int(levels[level - 1])
	var b := int(levels[level])
	return clampf(float(xp - a) / float(b - a), 0.0, 1.0)


## Adds XP; returns the list of levels reached (rewards are applied by GameState).
func add_xp(amount: int) -> Array[int]:
	var reached: Array[int] = []
	if amount <= 0:
		return reached
	xp += amount
	xp_changed.emit(xp)
	var new_level := level_for(xp)
	while level < new_level:
		level += 1
		reached.append(level)
		level_up.emit(level)
	return reached


static func level_reward(lv: int) -> Dictionary:
	return (data().get("level_rewards", {}) as Dictionary).get(str(lv), {})


func add_stat(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount


func stat(key: String) -> int:
	return int(stats.get(key, 0))


## Distinct values recorded under a prefix, e.g. "harvested:" → species count.
func count_prefix(prefix: String) -> int:
	var n := 0
	for key: String in stats:
		if key.begins_with(prefix) and int(stats[key]) > 0:
			n += 1
	return n


## Unlocks every achievement whose stat (from `provider`: (String) -> int)
## reached its goal. Returns the newly unlocked definitions.
func check_achievements(provider: Callable, day: int) -> Array[Dictionary]:
	var unlocked: Array[Dictionary] = []
	for a: Dictionary in achievement_defs():
		var id := str(a["id"])
		if achievements.has(id):
			continue
		if int(provider.call(str(a["stat"]))) >= int(a["at_least"]):
			achievements[id] = day
			unlocked.append(a)
			achievement_unlocked.emit(id)
	return unlocked


func to_dict() -> Dictionary:
	return {"xp": xp, "stats": stats.duplicate(), "achievements": achievements.duplicate()}


func load_dict(d: Dictionary) -> int:
	reset()
	var issues := 0
	xp = maxi(int(d.get("xp", 0)), 0)
	level = level_for(xp)
	xp_changed.emit(xp)
	var s: Variant = d.get("stats", {})
	if typeof(s) == TYPE_DICTIONARY:
		for key in s:
			stats[str(key)] = maxi(int(s[key]), 0)
	var known := {}
	for a: Dictionary in achievement_defs():
		known[str(a["id"])] = true
	var ach: Variant = d.get("achievements", {})
	if typeof(ach) == TYPE_DICTIONARY:
		for id in ach:
			if known.has(str(id)):
				achievements[str(id)] = int(ach[id])
			else:
				issues += 1
	return issues
