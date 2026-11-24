extends TestCase
## Loads every map of the world and checks travel, doors, interiors,
## signs, landmarks, foraging and the map screen.

const A := FarmActionResolver.Action
const MAP_SCENE := "res://scenes/world/map_scene.tscn"

var scene: GameplayScene


func before_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)
	GameState.weather_override = Weather.Kind.SUNNY


func after_each() -> void:
	GameState.weather_override = -1
	if is_instance_valid(scene):
		scene.free()
	GameState.travel(&"farm", "default")


func _open(map_id: StringName, spawn_name: String = "default") -> void:
	if is_instance_valid(scene):
		scene.free()
	GameState.travel(map_id, spawn_name)
	scene = (load(MAP_SCENE) as PackedScene).instantiate()
	scene.allow_scene_changes = false
	tree.root.add_child(scene)
	await wait_physics_frames(2)


func _stand_facing(cell: Vector2i, from: Vector2i) -> void:
	scene.player.position = scene.map.cell_anchor(cell + from) + Vector2(0, -1)
	scene.player.face(Vector2(-from))
	scene.controller.set("_cooldown", 0.0)


func test_every_map_loads_with_player_on_walkable_spawn() -> void:
	for id in WorldGraph.map_ids():
		await _open(id)
		assert_eq(scene.map_id, id)
		var cell := scene.map.world_to_cell(scene.player.position + Vector2(0, -3))
		assert_false(TerrainAtlas.is_solid(scene.map.layout.terrain_at(cell)), "%s spawn on solid tile" % id)
		assert_true(GameState.visited_maps.has(String(id)), "%s marked visited" % id)


func test_walking_into_exit_travels() -> void:
	await _open(&"village")
	scene.set("_warp_grace", 0.0)
	scene.call("_on_exit_entered", scene.player, &"clear_lake", "from_village")
	assert_eq(GameState.current_map, &"clear_lake")
	assert_eq(GameState.pending_spawn, "from_village")


func test_arriving_uses_named_spawn() -> void:
	await _open(&"clear_lake", "from_village")
	var expected := WorldGraph.spawn(&"clear_lake", "from_village")
	assert_eq(scene.map.world_to_cell(scene.player.position + Vector2(0, -3)), expected["cell"])


func test_market_door_and_shop_counter() -> void:
	await _open(&"village")
	_stand_facing(Vector2i(20, 11), Vector2i.DOWN)
	assert_eq(scene.controller.interact(), A.INTERACT)
	assert_eq(GameState.current_map, &"market")
	await _open(&"market", "entrance")
	_stand_facing(Vector2i(8, 4), Vector2i.DOWN)
	assert_eq(scene.controller.interact(), A.INTERACT)
	assert_true(scene.hud.shop_panel().visible, "market counter opens the shop")
	assert_eq(scene.hud.shop_panel().shop.id, "market")
	scene.hud.close_all()


func test_locked_door_shows_text() -> void:
	await _open(&"village")
	_stand_facing(Vector2i(34, 11), Vector2i.DOWN)
	scene.controller.interact()
	var dialog := scene.hud.message_dialog()
	assert_true(dialog.visible)
	assert_eq(GameState.current_map, &"village", "locked: no travel")
	dialog.close()


func test_landmark_discovery() -> void:
	await _open(&"butterfly_garden")
	assert_false(GameState.discoveries.has("sundial"))
	_stand_facing(Vector2i(24, 15), Vector2i.DOWN)
	assert_eq(scene.controller.interact(), A.INTERACT)
	assert_true(GameState.discoveries.has("sundial"))
	scene.hud.close_all()


func test_forage_spot_pickup() -> void:
	await _open(&"clear_lake")
	var spot: ForageSpot = null
	for node in tree.get_nodes_in_group(&"forage_spot"):
		if scene.is_ancestor_of(node) and (node as ForageSpot).item_id != &"":
			spot = node
			break
	assert_ne(spot, null, "some forage today at the lake")
	var cell := scene.map.world_to_cell(spot.position + Vector2(0, -1))
	var id := spot.item_id
	_stand_facing(cell, Vector2i.DOWN if scene.controller.object_kind_at(cell + Vector2i.DOWN) == &"" else Vector2i.UP)
	assert_eq(scene.controller.interact(), A.FORAGE)
	assert_eq(GameState.inventory.count_of(id), 1)
	assert_eq(spot.item_id, &"", "spot emptied")
	assert_false(spot.visible)


func test_no_farming_in_village() -> void:
	await _open(&"village")
	GameState.select_slot(GameState.inventory.first_slot_of(&"hoe"))
	_stand_facing(Vector2i(28, 26), Vector2i.UP)
	assert_eq(scene.controller.use_selected_item(), A.NONE)
	assert_true(GameState.farm_soil.tilled_cells().is_empty())


func test_interior_camera_centred_and_bed_sleep() -> void:
	await _open(&"house", "entrance")
	var cam: Camera2D = scene.player.get_node("Camera")
	var rect := scene.map.get_world_rect()
	assert_lt(cam.limit_left, 0, "small room is centred")
	assert_eq(cam.limit_right - cam.limit_left, 640)
	assert_false(scene.weather_view.visible, "no weather indoors")
	var day := GameState.calendar.day
	_stand_facing(Vector2i(2, 4), Vector2i.RIGHT)
	assert_eq(scene.controller.interact(), A.SLEEP)
	scene.hud.dialog().call("_answer", true)
	for i in 120:
		await tree.process_frame
		if not scene.controller.is_busy():
			break
	assert_eq(GameState.calendar.day, day + 1)
	assert_eq(GameState.current_map, &"house")
	assert_true(rect.has_point(scene.player.position))


func test_map_panel_opens_with_m() -> void:
	await _open(&"village")
	var ev := InputEventAction.new()
	ev.action = InputBindings.MAP
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await tree.process_frame
	assert_true(scene.hud.is_modal_open(), "map open")
	scene.hud.close_all()


func test_save_on_other_map_and_reload_there() -> void:
	await _open(&"lavender_mountains")
	var pos := scene.player.position
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save_data()))
	GameState.start_new_profile("Outra", "Fazenda", 0)
	GameState.apply_save_data(data)
	assert_eq(GameState.current_map, &"lavender_mountains")
	scene.free()
	scene = (load(MAP_SCENE) as PackedScene).instantiate()
	scene.allow_scene_changes = false
	tree.root.add_child(scene)
	await wait_physics_frames(2)
	assert_eq(scene.map_id, &"lavender_mountains")
	assert_true(scene.player.position.distance_to(pos) < 1.0)
