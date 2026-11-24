class_name FarmController
extends Node
## Turns player input into farming actions on the cell in front of the
## player (or the adjacent cell under the mouse). FarmActionResolver decides
## what is possible; this node applies it to GameState and the world, and
## gives visual feedback (cursor, tool swing, particles, toasts).

signal action_performed(action: FarmActionResolver.Action, cell: Vector2i)

const CURSOR_TEXTURE := preload("res://assets/ui/cursor.png")
const USE_COOLDOWN := 0.25
const TOOL_LOCK := 0.18
const CURSOR_ACTIVE := Color(1, 1, 1, 0.95)
const CURSOR_IDLE := Color(1, 1, 1, 0.3)

const A := FarmActionResolver.Action

var scene: GameplayScene
var player: Player
var map: WorldMap
var hud: FarmHUD
var resolver := FarmActionResolver.new()

var _cursor: Sprite2D
var _cooldown := 0.0
var _mouse_targeting := false
var _busy := false


func setup(owner_scene: GameplayScene, p: Player, world_map: WorldMap, farm_hud: FarmHUD) -> void:
	scene = owner_scene
	player = p
	map = world_map
	hud = farm_hud
	# Soil only exists on farmable maps; elsewhere an empty grid keeps the
	# farm's cells from "appearing" at the same coordinates.
	var soil := GameState.soil_for(map.map_id)
	resolver.soil = soil if soil and WorldGraph.allows_farming(map.map_id) else SoilGrid.new()
	resolver.farming_allowed = func() -> bool: return WorldGraph.allows_farming(map.map_id)
	resolver.season = func() -> int: return int(GameState.calendar.season)
	resolver.terrain_at = func(cell: Vector2i) -> String: return map.layout.terrain_at(cell)
	resolver.object_kind_at = object_kind_at
	resolver.can_charges = func() -> int: return GameState.watering_can_charges
	resolver.can_capacity = func() -> int: return GameState.can_capacity()
	resolver.can_place = can_place
	_cursor = Sprite2D.new()
	_cursor.texture = CURSOR_TEXTURE
	map.overlay.add_child(_cursor)


func is_busy() -> bool:
	return _busy


var _ghost: Sprite2D
var _ghost_tiles: Array[Sprite2D] = []


## Translucent preview of the selected build: green = fits, red = blocked.
func _update_ghost(cell: Vector2i, item: ItemData, ok: bool) -> void:
	if _ghost == null:
		_ghost = Sprite2D.new()
		_ghost.centered = false
		_ghost.z_index = 6
		map.overlay.add_child(_ghost)
	var show := item != null and item.is_placeable() and _cursor.visible
	_ghost.visible = show and not item.place_scene.is_empty()
	for t in _ghost_tiles:
		t.visible = false
	if not show:
		return
	var tint := Color(0.6, 1.0, 0.6, 0.6) if ok else Color(1.0, 0.45, 0.45, 0.55)
	if _ghost.visible:
		var info := scene.build_view.preview_for(item)
		_ghost.texture = info.get("texture")
		_ghost.offset = info.get("offset", Vector2.ZERO)
		var region: Rect2 = info.get("region", Rect2())
		_ghost.region_enabled = region.size != Vector2.ZERO
		_ghost.region_rect = region
		_ghost.position = map.cell_anchor(cell)
		_ghost.modulate = tint
	var cells := item.footprint_cells(cell)
	while _ghost_tiles.size() < cells.size():
		var s := Sprite2D.new()
		s.texture = CURSOR_TEXTURE
		s.z_index = 5
		map.overlay.add_child(s)
		_ghost_tiles.append(s)
	for i in cells.size():
		_ghost_tiles[i].visible = true
		_ghost_tiles[i].position = map.cell_center(cells[i])
		_ghost_tiles[i].modulate = tint


## "" if `item` can be built at `cell` on this map, else a message key.
func can_place(cell: Vector2i, item: ItemData) -> String:
	var blocked: Dictionary = scene.protected_cells().duplicate() if scene else {}
	blocked[player.feet_cell(WorldMap.TILE_SIZE)] = true
	var occupied := func(c: Vector2i) -> bool: return object_kind_at(c) != FarmActionResolver.KIND_NONE
	var soil := GameState.soil_for(map.map_id)
	return Placement.validate(item, map.map_id, cell, map.layout, occupied, soil, blocked)


## Kind of object occupying a cell, as understood by FarmActionResolver.
func object_kind_at(cell: Vector2i) -> StringName:
	if not map.layout.in_bounds(cell):
		return FarmActionResolver.KIND_SOLID
	if scene and scene.npc_director and scene.npc_director.npc_at(cell):
		return FarmActionResolver.KIND_NPC
	if not Placement.find_at(GameState.placed_on(map.map_id), cell).is_empty():
		return FarmActionResolver.KIND_PLACED
	var node := map.get_object_at(cell)
	if node != null:
		var kind: Variant = node.get(&"object_kind")
		if kind != null:
			return kind
		if node is CollisionObject2D:
			return FarmActionResolver.KIND_SOLID
	if _blocked_by_physics(cell):
		return FarmActionResolver.KIND_SOLID
	return FarmActionResolver.KIND_NONE


func target_cell() -> Vector2i:
	var feet := player.feet_cell(WorldMap.TILE_SIZE)
	if _mouse_targeting:
		var mouse_cell := map.world_to_cell(map.get_global_mouse_position())
		var d := mouse_cell - feet
		if absi(d.x) <= 1 and absi(d.y) <= 1 and d != Vector2i.ZERO:
			return mouse_cell
	return feet + Vector2i(MovementLogic.facing_vector(player.facing))


func _process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if player == null or _cursor == null:
		return
	var cell := target_cell()
	_cursor.position = map.cell_center(cell)
	var item := GameState.selected_item()
	var plan := resolver.resolve_use(cell, item)
	_cursor.modulate = CURSOR_ACTIVE if plan["action"] != A.NONE else CURSOR_IDLE
	_cursor.visible = not _busy and not hud.is_modal_open()
	_update_ghost(cell, item, plan["action"] == A.PLACE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_targeting = true
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_mouse_targeting = false
	if _busy or hud.is_modal_open() or get_tree().paused or player == null:
		return
	for i in InputBindings.HOTBAR_SLOTS.size():
		if event.is_action_pressed(InputBindings.HOTBAR_SLOTS[i]):
			GameState.select_slot(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(InputBindings.HOTBAR_NEXT):
		GameState.select_slot(GameState.selected_slot + 1)
	elif event.is_action_pressed(InputBindings.HOTBAR_PREV):
		GameState.select_slot(GameState.selected_slot - 1)
	elif event.is_action_pressed(InputBindings.INVENTORY):
		hud.open_inventory()
	elif event.is_action_pressed(InputBindings.MAP):
		hud.open_map(map.map_id)
	elif event.is_action_pressed(InputBindings.JOURNAL):
		hud.open_journal()
	elif event.is_action_pressed(InputBindings.USE_ITEM):
		use_selected_item()
	elif event.is_action_pressed(InputBindings.INTERACT):
		interact()
	else:
		return
	get_viewport().set_input_as_handled()


## Uses the selected hotbar item on the target cell. Returns the action done.
func use_selected_item() -> FarmActionResolver.Action:
	if _cooldown > 0.0 or _busy:
		return A.NONE
	var cell := target_cell()
	_face(cell)
	var item := GameState.selected_item()
	return _execute(resolver.resolve_use(cell, item), cell, item)


## Context action on the target cell (harvest, sleep, refill).
func interact() -> FarmActionResolver.Action:
	if _cooldown > 0.0 or _busy:
		return A.NONE
	var cell := target_cell()
	_face(cell)
	return _execute(resolver.resolve_interact(cell), cell, null)


func _execute(plan: Dictionary, cell: Vector2i, item: ItemData) -> FarmActionResolver.Action:
	var action: FarmActionResolver.Action = plan["action"]
	var soil := resolver.soil
	var pos := map.cell_center(cell)
	match action:
		A.NONE:
			if not String(plan["reason"]).is_empty():
				hud.toast(tr(plan["reason"]), true)
				AudioManager.play(&"error", -10.0)
			return A.NONE
		A.TILL:
			for c in _area_cells(cell, item, A.TILL):
				soil.till(c)
				FarmEffects.burst(map.overlay, map.cell_center(c), &"dust", 12)
			AudioManager.play(&"till")
		A.UNTILL:
			soil.untill(cell)
			FarmEffects.burst(map.overlay, pos, &"dust", 8)
			AudioManager.play(&"rock", -4.0)
		A.WATER:
			for c in _area_cells(cell, item, A.WATER):
				if not GameState.use_watering_can():
					break
				soil.water(c)
				FarmEffects.burst(map.overlay, map.cell_center(c), &"water", 12)
			AudioManager.play(&"water")
		A.PLACE:
			if not GameState.place_build(map.map_id, item.id, cell):
				return A.NONE
			scene.build_view.add(cell, item.id)
			_refresh_water()
			FarmEffects.burst(map.overlay, pos, &"dust", 10)
			AudioManager.play(&"plant")
		A.PICK_UP:
			var found := GameState.pick_up_build(map.map_id, cell)
			if found.is_empty():
				hud.toast(tr("MSG_INVENTORY_FULL"), true)
				return A.NONE
			scene.build_view.remove(found["origin"], found["item"])
			_refresh_water()
			FarmEffects.burst(map.overlay, pos, &"dust", 10)
			AudioManager.play(&"rock", -4.0)
		A.REFILL:
			GameState.refill_watering_can()
			FarmEffects.burst(map.overlay, pos, &"water", 16)
			hud.toast(tr("MSG_CAN_REFILLED"))
			AudioManager.play(&"water", 2.0, 0.0)
		A.PLANT:
			if not GameState.inventory.remove_item(item.id, 1):
				return A.NONE
			soil.plant(cell, item.flower_id, int(GameState.calendar.season))
			FarmEffects.burst(map.overlay, pos, &"sparkle", 6)
			AudioManager.play(&"plant")
		A.FERTILIZE:
			if not GameState.inventory.remove_item(item.id, 1):
				return A.NONE
			soil.fertilize(cell)
			FarmEffects.burst(map.overlay, pos, &"sparkle", 10)
			AudioManager.play(&"plant", -2.0)
		A.OPEN_SHOP:
			hud.open_shop(&"flora_cart")
			return action
		A.INTERACT:
			_interact_with(cell)
			action_performed.emit(action, cell)
			return action
		A.FORAGE:
			if not _forage(cell):
				return A.NONE
		A.TALK:
			_talk(scene.npc_director.npc_at(cell))
			action_performed.emit(action, cell)
			return action
		A.GIFT:
			_gift(scene.npc_director.npc_at(cell), item)
			action_performed.emit(action, cell)
			return action
		A.OPEN_CHEST:
			hud.open_chest(chest_id(cell))
			return action
		A.HARVEST:
			if not _harvest(cell):
				return A.NONE
		A.CLEAR_WEED, A.BREAK_ROCK:
			_hit_object(cell, action)
		A.CLEAR_CROP:
			soil.clear_crop(cell)
			FarmEffects.burst(map.overlay, pos, &"leaf", 10)
			AudioManager.play(&"weed")
		A.SLEEP:
			_sleep()
			action_performed.emit(action, cell)
			return action
	if item != null and item.is_tool():
		FarmEffects.tool_swing(map.overlay, pos, ItemRegistry.icon(item.id), player.facing != MovementLogic.Facing.LEFT)
	_cooldown = USE_COOLDOWN
	if item != null and item.is_tool():
		player.squash()
	player.lock_movement(TOOL_LOCK)
	action_performed.emit(action, cell)
	return action


func _harvest(cell: Vector2i) -> bool:
	var soil := resolver.soil
	var crop := soil.get_crop(cell)
	var flower_item := ItemRegistry.flower_item_id(crop.flower_id)
	if not GameState.inventory.can_add(flower_item, soil.harvest_yield(cell)):
		hud.toast(tr("MSG_INVENTORY_FULL"), true)
		return false
	var result := soil.harvest(cell, GameState.rng())
	GameState.inventory.add_item(flower_item, result["flowers"])
	GameState.record("harvest", String(result["flower_id"]), int(result["flowers"]))
	var text: String = tr("MSG_HARVESTED") % [result["flowers"], ItemRegistry.item(flower_item).display_name()]
	if int(result["seeds"]) > 0:
		var seed_item := ItemRegistry.seed_id(result["flower_id"])
		if GameState.inventory.add_item(seed_item, result["seeds"]) == 0:
			text += "  " + tr("MSG_GOT_SEED")
	hud.toast(text)
	FarmEffects.burst(map.overlay, map.cell_center(cell), &"petal", 12)
	AudioManager.play(&"harvest")
	return true


func _hit_object(cell: Vector2i, action: FarmActionResolver.Action) -> void:
	var prop := map.get_object_at(cell) as ClearableProp
	if prop == null:
		return
	var pos := map.cell_center(cell)
	FarmEffects.burst(map.overlay, pos, &"dust" if action == A.BREAK_ROCK else &"leaf", 10)
	AudioManager.play(&"rock" if action == A.BREAK_ROCK else &"weed")
	if not prop.hit():
		return
	var drop := prop.drop_item
	var count := prop.drop_count
	map.remove_object_at(cell)
	GameState.mark_object_removed(map.map_id, cell)
	if drop != &"" and count > 0:
		var left := GameState.inventory.add_item(drop, count)
		if left < count:
			hud.toast(tr("MSG_GOT_ITEM") % [count - left, ItemRegistry.item(drop).display_name()])
		else:
			hud.toast(tr("MSG_INVENTORY_FULL"), true)


## Cells an (upgraded) tool affects: the target plus more in a line.
func _area_cells(cell: Vector2i, item: ItemData, action: FarmActionResolver.Action) -> Array[Vector2i]:
	var out: Array[Vector2i] = [cell]
	if item == null or item.area <= 1:
		return out
	var step := Vector2i(MovementLogic.facing_vector(player.facing))
	for k in range(1, item.area):
		var c := cell + step * k
		if resolver.resolve_use(c, item)["action"] == action:
			out.append(c)
	return out


func _refresh_water() -> void:
	var soil := GameState.soil_for(map.map_id)
	if soil == null:
		return
	for c in scene.build_view.water_cells():
		soil.water_cells[c] = true


## Runs the world.json interaction of the object at a cell.
func _interact_with(cell: Vector2i) -> void:
	var data := WorldGraph.interaction(map.map_id, cell)
	match str(data.get("type", "")):
		"door":
			AudioManager.play(&"open", -4.0)
			scene.travel_to(StringName(str(data["to"])), str(data.get("spawn", "default")))
		"sign", "locked":
			hud.show_text(tr(str(data["text"])))
		"landmark":
			var first := GameState.discover(str(data.get("id", "")))
			if first:
				AudioManager.play(&"harvest")
				hud.toast(tr("MSG_DISCOVERY"))
			hud.show_text(tr(str(data["text"])), tr("LANDMARK_TITLE"))
		"shop":
			hud.open_shop(StringName(str(data["shop"])))
		"florist_door":
			_florist_door(data)
		"greenhouse_door":
			_greenhouse_door(data)
		"florist_counter":
			var shop := GameState.florist
			if shop.has_waiting():
				var sale := shop.serve_next(GameState.wallet)
				AudioManager.play(&"coin")
				hud.toast(tr("FLORIST_SERVED") % [ItemRegistry.item(sale["item"]).display_name(),
					Wallet.format(int(sale["price"])), Wallet.format(int(sale["tip"]))])
			else:
				hud.open_florist(FloristPanel.Tab.DISPLAYS)
		"florist_board":
			hud.open_florist(FloristPanel.Tab.ORDERS)
		"florist_stand":
			hud.open_florist(FloristPanel.Tab.DISPLAYS)
		"florist_workbench":
			hud.open_workbench()
		"diary":
			GameState.record("read_diary")
			if GameState.quests.diary_pages.is_empty():
				hud.show_text(tr(str(data.get("text", "TXT_GRANDMA_SHELF"))))
			else:
				hud.open_journal(JournalPanel.Tab.DIARY)


## The village flower shop door: restore it first, then it leads inside.
func _florist_door(data: Dictionary) -> void:
	var shop := GameState.florist
	if shop.restored:
		AudioManager.play(&"open", -4.0)
		scene.travel_to(StringName(str(data["to"])), str(data.get("spawn", "default")))
		return
	var cost := shop.restoration_cost()
	var parts := PackedStringArray([tr("FLORIST_COST_MONEY") % Wallet.format(int(cost.get("money", 0)))])
	for entry: Array in cost.get("items", []):
		parts.append("%d %s (%d)" % [int(entry[1]), ItemRegistry.item(StringName(str(entry[0]))).display_name(),
			GameState.inventory.count_of(StringName(str(entry[0])))])
	var question: String = tr("FLORIST_RESTORE_QUESTION") % "\n".join(parts)
	if not shop.can_afford(int(cost.get("money", 0)), cost.get("items", []), GameState.wallet, GameState.inventory):
		hud.show_text(question + "\n\n" + tr("FLORIST_RESTORE_MISSING"), tr("FLORIST_RESTORE_TITLE"))
		return
	_busy = true
	var yes: bool = await hud.ask(question)
	_busy = false
	if yes and shop.restore(GameState.wallet, GameState.inventory):
		GameState.record("restore_florist")
		AudioManager.play(&"harvest")
		hud.show_text(tr("FLORIST_RESTORED_TEXT"), tr("FLORIST_RESTORE_TITLE"))


# ------------------------------------------------------------ villagers ---

func _talk(npc: VillagerNPC) -> void:
	if npc == null:
		return
	var id := npc.npc_id
	var rel := GameState.relationships
	var cal := GameState.calendar
	var conv := VillagerChat.compose(id, rel, GameState.quests, GameState.inventory,
		GameState.today(), int(cal.season), cal.day, GameState.is_raining())
	var talk := rel.talk(id, GameState.today())
	if talk["first_meeting"]:
		GameState.record("meet", id)
	npc.face(player.position - npc.position)
	_busy = true
	var choice: int = await hud.show_dialogue(id, conv["pages"], conv.get("choices", []))
	_busy = false
	match str(conv["kind"]):
		"event":
			rel.mark_event(id, str(conv["event"]))
			for entry: Array in conv.get("reward", []):
				GameState.inventory.add_item(StringName(str(entry[0])), int(entry[1]))
			AudioManager.play(&"harvest")
			hud.toast(tr("CHAT_EVENT_DONE") % Villagers.display_name(id))
		"offer":
			if choice == 0 and GameState.quests.start(str(conv["offer"])):
				AudioManager.play(&"open")
		"delivery":
			if choice == 0:
				_deliver(npc, conv["delivery"])
	scene.npc_director.refresh_markers()


func _deliver(npc: VillagerNPC, delivery: Dictionary) -> void:
	var reward := GameState.quests.deliver(delivery, GameState.inventory)
	if reward.is_empty():
		return
	AudioManager.play(&"coin")
	var side := QuestLog.side_quest_of(npc.npc_id)
	var line := tr("CHAT_THANKS")
	if delivery.has("quest") and not side.is_empty() and side["id"] == delivery["quest"]:
		line = Loc.text(Villagers.dialogue(npc.npc_id).get("quest_done"))
	_busy = true
	await hud.show_dialogue(npc.npc_id, [line], [])
	_busy = false


func _gift(npc: VillagerNPC, item: ItemData) -> void:
	if npc == null or item == null:
		return
	var cal := GameState.calendar
	var result := GameState.relationships.gift(npc.npc_id, item.id, GameState.today(), int(cal.season), cal.day)
	var line: String
	if result["ok"]:
		GameState.inventory.remove_item(item.id, 1)
		GameState.record("gift", npc.npc_id)
		AudioManager.play(&"pickup" if result["reaction"] != "disliked" else &"error")
		line = VillagerChat.gift_line(npc.npc_id, result)
	else:
		line = Loc.text((Villagers.dialogue(npc.npc_id).get("gift", {}) as Dictionary).get("already"))
	npc.face(player.position - npc.position)
	_busy = true
	await hud.show_dialogue(npc.npc_id, [line], [])
	_busy = false
	scene.npc_director.refresh_markers()


func _greenhouse_door(data: Dictionary) -> void:
	if GameState.greenhouse_restored:
		AudioManager.play(&"open", -4.0)
		scene.travel_to(StringName(str(data["to"])), str(data.get("spawn", "default")))
		return
	var cost: Dictionary = GameState.GREENHOUSE_COST
	var question: String = tr("GREENHOUSE_RESTORE_QUESTION") % UiKit.cost_text(int(cost["money"]), cost["items"])
	if not GameState.can_restore_greenhouse():
		hud.show_text(question + "\n\n" + tr("GREENHOUSE_RESTORE_MISSING"), tr("GREENHOUSE_TITLE"))
		return
	_busy = true
	var yes: bool = await hud.ask(question)
	_busy = false
	if yes and GameState.restore_greenhouse():
		var building := map.get_object_at(_cell_of(data)) as GreenhouseBuilding
		if building:
			building.refresh()
		AudioManager.play(&"harvest")
		hud.show_text(tr("GREENHOUSE_RESTORED_TEXT"), tr("GREENHOUSE_TITLE"))


func _cell_of(_data: Dictionary) -> Vector2i:
	return target_cell()


func _forage(cell: Vector2i) -> bool:
	var id := GameState.forage_item_at(map.map_id, cell)
	if id == &"":
		return false
	if not GameState.inventory.can_add(id, 1):
		hud.toast(tr("MSG_INVENTORY_FULL"), true)
		return false
	GameState.pick_forage(map.map_id, cell)
	GameState.inventory.add_item(id, 1)
	GameState.record("forage", String(id))
	var spot := map.get_object_at(cell) as ForageSpot
	if spot:
		spot.set_item(&"")
	hud.toast(tr("MSG_GOT_ITEM") % [1, ItemRegistry.item(id).display_name()])
	FarmEffects.burst(map.overlay, map.cell_center(cell), &"leaf", 8)
	AudioManager.play(&"pickup")
	return true


## Stable id of the chest anchored at a cell, e.g. "farm:35,12".
func chest_id(cell: Vector2i) -> String:
	return "%s:%d,%d" % [map.map_id, cell.x, cell.y]


func _sleep() -> void:
	_busy = true
	var yes: bool = await hud.ask(tr("SLEEP_QUESTION"))
	if not yes:
		_busy = false
		return
	await _go_to_next_day()


## Called when the clock reaches 02:00: the player faints and wakes at home.
func pass_out() -> void:
	if _busy:
		return
	_busy = true
	hud.close_all()
	hud.toast(tr("MSG_PASSED_OUT"), true)
	await get_tree().create_timer(0.8).timeout
	await _go_to_next_day()


func _go_to_next_day() -> void:
	player.set_input_enabled(false)
	AudioManager.play(&"sleep")
	await SceneManager.fade_out()
	var stats := GameState.advance_day()
	var home := WorldGraph.home_map()
	if map.map_id != home:
		# Wake up at home: the scene change fades back in and the new scene
		# shows the day banner.
		GameState.pending_day_stats = stats
		_busy = false
		scene.travel_to(home, WorldGraph.home_spawn())
		if not scene.allow_scene_changes:
			await SceneManager.fade_in()
			player.set_input_enabled(true)
		return
	var bed := WorldGraph.spawn(home, WorldGraph.home_spawn())
	player.position = map.cell_anchor(bed["cell"]) + Vector2(0, -2)
	player.face(bed["facing"])
	player.snap_camera()
	await SceneManager.fade_in()
	player.set_input_enabled(true)
	_busy = false
	hud.show_day_banner(stats)


func _face(cell: Vector2i) -> void:
	var d := cell - player.feet_cell(WorldMap.TILE_SIZE)
	if d != Vector2i.ZERO:
		player.face(Vector2(d))


func _blocked_by_physics(cell: Vector2i) -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = map.to_global(map.cell_center(cell))
	params.collision_mask = 1
	params.collide_with_bodies = true
	params.collide_with_areas = false
	return not map.get_world_2d().direct_space_state.intersect_point(params, 1).is_empty()
