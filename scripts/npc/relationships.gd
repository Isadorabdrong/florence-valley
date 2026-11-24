class_name Relationships
extends RefCounted
## Friendship with each villager: points (100 = one heart), daily talk and
## gift limits, birthday bonus, seen heart events and known gift tastes.

signal friendship_changed(npc_id: String, value: int)

## npc id -> {"points", "met", "talked_day", "gifted_day", "events", "tastes"}
var state: Dictionary = {}


func reset() -> void:
	state.clear()


func _s(id: String) -> Dictionary:
	if not state.has(id):
		state[id] = {"points": 0, "met": false, "talked_day": -1, "gifted_day": -1, "events": [], "tastes": {}}
	return state[id]


func points(id: String) -> int:
	return int(_s(id)["points"])


func hearts(id: String) -> int:
	return points(id) / int(Villagers.config().get("per_heart", 100))


func has_met(id: String) -> bool:
	return bool(_s(id)["met"])


func met_count() -> int:
	var n := 0
	for id: String in state:
		if state[id]["met"]:
			n += 1
	return n


func add(id: String, delta: int) -> void:
	var s := _s(id)
	var before := int(s["points"])
	s["points"] = clampi(before + delta, 0, int(Villagers.config().get("max", 1000)))
	if int(s["points"]) != before:
		friendship_changed.emit(id, int(s["points"]))


## First conversation of the day gives friendship. Returns
## {"first_meeting": bool, "gained": int}.
func talk(id: String, day: int) -> Dictionary:
	var s := _s(id)
	var first := not bool(s["met"])
	s["met"] = true
	var gained := 0
	if int(s["talked_day"]) != day:
		s["talked_day"] = day
		gained = int(Villagers.config().get("talk", 20))
		add(id, gained)
	return {"first_meeting": first, "gained": gained}


func talked_today(id: String, day: int) -> bool:
	return int(_s(id)["talked_day"]) == day


func can_gift(id: String, day: int) -> bool:
	return int(_s(id)["gifted_day"]) != day


## One gift per villager per day; birthdays multiply the effect.
## Returns {"ok", "reaction", "gained", "birthday"}.
func gift(id: String, item_id: StringName, day: int, season: int, day_of_season: int) -> Dictionary:
	if not can_gift(id, day) or not Villagers.can_gift(item_id):
		return {"ok": false, "reaction": "already" if not can_gift(id, day) else "neutral", "gained": 0, "birthday": false}
	var reaction := Villagers.gift_reaction(id, item_id)
	var gained := int((Villagers.config().get("gift", {}) as Dictionary).get(reaction, 20))
	var birthday := Villagers.is_birthday(id, season, day_of_season)
	if birthday:
		gained *= int(Villagers.config().get("birthday_multiplier", 3))
	var s := _s(id)
	s["gifted_day"] = day
	s["met"] = true
	(s["tastes"] as Dictionary)[String(item_id)] = reaction
	add(id, gained)
	return {"ok": true, "reaction": reaction, "gained": gained, "birthday": birthday}


func known_tastes(id: String) -> Dictionary:
	return _s(id)["tastes"]


func event_seen(id: String, event_id: String) -> bool:
	return (_s(id)["events"] as Array).has(event_id)


func mark_event(id: String, event_id: String) -> void:
	if not event_seen(id, event_id):
		(_s(id)["events"] as Array).append(event_id)


func to_dict() -> Dictionary:
	return state.duplicate(true)


func load_dict(data: Dictionary) -> int:
	state.clear()
	var issues := 0
	for id in data:
		if Villagers.npc(str(id)).is_empty() or typeof(data[id]) != TYPE_DICTIONARY:
			issues += 1
			continue
		var d: Dictionary = data[id]
		var s := _s(str(id))
		s["points"] = clampi(int(d.get("points", 0)), 0, int(Villagers.config().get("max", 1000)))
		s["met"] = bool(d.get("met", false))
		s["talked_day"] = int(d.get("talked_day", -1))
		s["gifted_day"] = int(d.get("gifted_day", -1))
		s["events"] = (d.get("events", []) as Array).map(func(e: Variant) -> String: return str(e))
		var tastes: Variant = d.get("tastes", {})
		s["tastes"] = tastes if typeof(tastes) == TYPE_DICTIONARY else {}
	return issues
