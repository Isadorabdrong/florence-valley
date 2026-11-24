class_name NpcDirector
extends Node
## Puts villagers on the current map according to their schedules and
## moves them when the clock says they go somewhere else.

const VILLAGER_SCENE := preload("res://scenes/npc/villager.tscn")
const FADE := 0.4

var map: WorldMap
var _npcs: Dictionary = {} # id -> VillagerNPC


func setup(world_map: WorldMap) -> void:
	map = world_map
	GameState.clock.time_changed.connect(_on_time_changed)
	GameState.day_started.connect(_on_day_started)
	GameState.quests.changed.connect(refresh_markers)
	GameState.inventory.changed.connect(_on_inventory_changed)
	refresh(true)


func _on_day_started(_stats: Dictionary) -> void:
	refresh(true)


func _on_inventory_changed(_index: int) -> void:
	refresh_markers()


func villager(id: String) -> VillagerNPC:
	return _npcs.get(id)


func villagers() -> Array[VillagerNPC]:
	var out: Array[VillagerNPC] = []
	for n: VillagerNPC in _npcs.values():
		out.append(n)
	return out


func npc_at(cell: Vector2i) -> VillagerNPC:
	for n: VillagerNPC in _npcs.values():
		if not is_instance_valid(n):
			continue
		if map.world_to_cell(n.position + Vector2(0, -3)) == cell or (not n.is_walking() and n.target_cell == cell):
			return n
	return null


func _on_time_changed(_minutes: int) -> void:
	refresh(false)


## Places/moves everyone. `instant` = no walking (scene load, new day).
func refresh(instant: bool) -> void:
	var cal := GameState.calendar
	for id in Villagers.ids():
		var spot := Villagers.where(id, GameState.clock.minutes, cal.weekday(), int(cal.season), GameState.is_raining())
		var here: bool = not spot.is_empty() and spot["map"] == map.map_id
		var npc: VillagerNPC = _npcs.get(id)
		if not here:
			if npc:
				_npcs.erase(id)
				_leave(npc, instant)
			continue
		var pos := map.cell_anchor(spot["cell"]) + Vector2(0, -2)
		if npc == null:
			npc = VILLAGER_SCENE.instantiate() as VillagerNPC
			map.entities.add_child(npc)
			npc.setup(id)
			npc.place(pos, spot["cell"], spot["facing"])
			_npcs[id] = npc
			if not instant:
				npc.modulate.a = 0.0
				npc.create_tween().tween_property(npc, "modulate:a", 1.0, FADE)
		elif npc.target_cell != spot["cell"]:
			if instant:
				npc.place(pos, spot["cell"], spot["facing"])
			else:
				npc.walk_to(pos, spot["cell"], spot["facing"])
	refresh_markers()


func _leave(npc: VillagerNPC, instant: bool) -> void:
	if instant:
		npc.queue_free()
		return
	var tween := npc.create_tween()
	tween.tween_property(npc, "modulate:a", 0.0, FADE)
	tween.tween_callback(npc.queue_free)


## "!" over villagers who have something special to say.
func refresh_markers() -> void:
	var cal := GameState.calendar
	for id: String in _npcs:
		var npc: VillagerNPC = _npcs[id]
		if not is_instance_valid(npc):
			continue
		var conv := VillagerChat.compose(id, GameState.relationships, GameState.quests, GameState.inventory,
			GameState.today(), int(cal.season), cal.day, GameState.is_raining())
		npc.set_marker(conv["kind"] in ["intro", "birthday", "event", "delivery", "offer"])
