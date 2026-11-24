class_name QuestLog
extends RefCounted
## Main story quests, villagers' personal quests and daily requests.
## Progress comes from game events via notify(); deliveries happen by
## talking to the villager. Rewards are applied by GameState (quest_completed).

signal quest_started(quest_id: String)
signal quest_completed(quest_id: String, reward: Dictionary)
signal changed

const PATH := "res://data/quests/quests.json"

static var _data: Dictionary = {}

## quest id -> Array of progress ints (one per objective)
var active: Dictionary = {}
var completed: Dictionary = {}
## Daily requests: {"id", "npc", "item", "count", "deadline", "reward", "friendship"}
var requests: Array[Dictionary] = []
var diary_pages: Array[int] = []
var _next_request := 1


static func data() -> Dictionary:
	if _data.is_empty():
		var file := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) if file else null
		_data = parsed if typeof(parsed) == TYPE_DICTIONARY else {}
	return _data


static func clear_cache() -> void:
	_data = {}


static func quest(id: String) -> Dictionary:
	for q: Dictionary in data().get("quests", []):
		if q["id"] == id:
			return q
	return {}


static func all_quests() -> Array:
	return data().get("quests", [])


## The personal quest a villager can offer.
static func side_quest_of(npc_id: String) -> Dictionary:
	for q: Dictionary in all_quests():
		if q.get("kind") == "side" and q.get("giver") == npc_id:
			return q
	return {}


func reset() -> void:
	active.clear()
	completed.clear()
	requests.clear()
	diary_pages.clear()
	_next_request = 1
	start(str(data().get("start", "")))


func start(id: String) -> bool:
	var q := quest(id)
	if q.is_empty() or active.has(id) or completed.has(id):
		return false
	var progress: Array = []
	for o in q.get("objectives", []):
		progress.append(0)
	active[id] = progress
	quest_started.emit(id)
	changed.emit()
	return true


func is_active(id: String) -> bool:
	return active.has(id)


func is_completed(id: String) -> bool:
	return completed.has(id)


static func objective_goal(o: Dictionary) -> int:
	return 1 if o.get("type") == "deliver" else int(o.get("count", 1))


## Records a game event ("harvest", "craft", "discover", "meet",
## "restore_florist", "read_diary", "visit"…). `target` is the flower,
## recipe, landmark… involved; objectives without a target accept any.
func notify(event: String, target: String = "", amount: int = 1) -> void:
	for id: String in active.keys():
		var q := quest(id)
		var objectives: Array = q.get("objectives", [])
		var progress: Array = active[id]
		var touched := false
		for i in objectives.size():
			var o: Dictionary = objectives[i]
			if o.get("type") != "event" or o.get("event") != event:
				continue
			if o.has("target") and str(o["target"]) != target:
				continue
			var goal := objective_goal(o)
			if int(progress[i]) < goal:
				progress[i] = mini(int(progress[i]) + amount, goal)
				touched = true
		if touched:
			changed.emit()
			_check_complete(id)


func progress_text(id: String) -> PackedStringArray:
	var out := PackedStringArray()
	var q := quest(id)
	var progress: Array = active.get(id, [])
	var objectives: Array = q.get("objectives", [])
	for i in objectives.size():
		var o: Dictionary = objectives[i]
		var p := int(progress[i]) if i < progress.size() else objective_goal(o)
		out.append("%d/%d" % [p, objective_goal(o)])
	return out


func _check_complete(id: String) -> void:
	var q := quest(id)
	var objectives: Array = q.get("objectives", [])
	var progress: Array = active.get(id, [])
	for i in objectives.size():
		if int(progress[i]) < objective_goal(objectives[i]):
			return
	active.erase(id)
	completed[id] = true
	var reward: Dictionary = q.get("reward", {})
	if reward.has("diary") and not diary_pages.has(int(reward["diary"])):
		diary_pages.append(int(reward["diary"]))
		diary_pages.sort()
	quest_completed.emit(id, reward)
	changed.emit()
	var next := str(q.get("next", ""))
	if not next.is_empty():
		start(next)


## Active deliveries a villager can receive now: [{"quest" | "request", ...}].
func deliveries_for(npc_id: String, inventory: Inventory) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in active:
		var q := quest(id)
		var objectives: Array = q.get("objectives", [])
		for i in objectives.size():
			var o: Dictionary = objectives[i]
			if o.get("type") == "deliver" and o.get("npc") == npc_id and int(active[id][i]) == 0 \
					and _has_items(o.get("items", []), inventory):
				out.append({"quest": id, "objective": i, "items": o["items"]})
	for r in requests:
		if r["npc"] == npc_id and inventory.count_of(StringName(str(r["item"]))) >= int(r["count"]):
			out.append({"request": int(r["id"]), "items": [[r["item"], r["count"]]]})
	return out


static func _has_items(items: Array, inventory: Inventory) -> bool:
	for entry: Array in items:
		if inventory.count_of(StringName(str(entry[0]))) < int(entry[1]):
			return false
	return true


## Hands over the items of a delivery. Returns the reward ({} if failed).
func deliver(delivery: Dictionary, inventory: Inventory) -> Dictionary:
	var items: Array = delivery.get("items", [])
	if not _has_items(items, inventory):
		return {}
	for entry: Array in items:
		inventory.remove_item(StringName(str(entry[0])), int(entry[1]))
	if delivery.has("quest"):
		var id: String = delivery["quest"]
		if not active.has(id):
			return {}
		active[id][int(delivery["objective"])] = 1
		changed.emit()
		var reward: Dictionary = quest(id).get("reward", {})
		_check_complete(id)
		return reward
	for r in requests:
		if int(r["id"]) == int(delivery["request"]):
			requests.erase(r)
			changed.emit()
			var reward := {"money": int(r["reward"]), "friendship": {str(r["npc"]): int(r["friendship"])}}
			quest_completed.emit("request", reward)
			return reward
	return {}


## Personal quest a villager would offer now (hearts reached, not started).
func offer_for(npc_id: String, hearts: int) -> Dictionary:
	var q := side_quest_of(npc_id)
	if q.is_empty() or active.has(q["id"]) or completed.has(q["id"]):
		return {}
	if hearts < int(q.get("requires_hearts", 0)):
		return {}
	return q


## Morning bookkeeping: expire and create daily requests.
func new_day(total_day: int, rng: RandomNumberGenerator, met: Array) -> Dictionary:
	var cfg: Dictionary = data().get("requests", {})
	var expired := 0
	for r in requests.duplicate():
		if int(r["deadline"]) < total_day:
			requests.erase(r)
			expired += 1
	var created := ""
	if not met.is_empty() and requests.size() < int(cfg.get("max_active", 3)) and rng.randf() < float(cfg.get("chance", 0.4)):
		var npc_id: String = met[rng.randi_range(0, met.size() - 1)]
		var pool: Array = Villagers.npc(npc_id).get("requests", [])
		if not pool.is_empty():
			var pick: Array = pool[rng.randi_range(0, pool.size() - 1)]
			var item := StringName(str(pick[0]))
			var value := ItemRegistry.item(item).sell_price if ItemRegistry.item(item) else 10
			requests.append({"id": _next_request, "npc": npc_id, "item": String(item), "count": int(pick[1]),
				"deadline": total_day + int(cfg.get("days", 2)),
				"reward": int(round(value * int(pick[1]) * float(cfg.get("reward_multiplier", 2.0)))),
				"friendship": int(cfg.get("friendship", 40))})
			_next_request += 1
			created = npc_id
	if expired > 0 or not created.is_empty():
		changed.emit()
	return {"expired": expired, "new_request": created}


func to_dict() -> Dictionary:
	var reqs: Array = []
	for r in requests:
		reqs.append(r.duplicate())
	return {"active": active.duplicate(true), "completed": completed.keys(), "requests": reqs,
		"diary": diary_pages.duplicate(), "next_request": _next_request}


func load_dict(d: Dictionary) -> int:
	active.clear()
	completed.clear()
	requests.clear()
	diary_pages.clear()
	var issues := 0
	var saved_active: Variant = d.get("active", {})
	if typeof(saved_active) == TYPE_DICTIONARY:
		for id in saved_active:
			var q := quest(str(id))
			if q.is_empty():
				issues += 1
				continue
			var p: Array = []
			var raw: Array = saved_active[id] if typeof(saved_active[id]) == TYPE_ARRAY else []
			for i in (q.get("objectives", []) as Array).size():
				p.append(clampi(int(raw[i]) if i < raw.size() else 0, 0, objective_goal(q["objectives"][i])))
			active[str(id)] = p
	for id in d.get("completed", []):
		if quest(str(id)).is_empty():
			issues += 1
		else:
			completed[str(id)] = true
	for r in d.get("requests", []):
		if typeof(r) != TYPE_DICTIONARY or Villagers.npc(str(r.get("npc", ""))).is_empty() \
				or not ItemRegistry.has_item(StringName(str(r.get("item", "")))):
			issues += 1
			continue
		var req: Dictionary = (r as Dictionary).duplicate()
		for key in ["id", "count", "deadline", "reward", "friendship"]:
			req[key] = int(req.get(key, 0))
		requests.append(req)
	for page in d.get("diary", []):
		diary_pages.append(int(page))
	diary_pages.sort()
	_next_request = maxi(int(d.get("next_request", 1)), 1)
	if active.is_empty() and completed.is_empty():
		start(str(data().get("start", "")))
	changed.emit()
	return issues
