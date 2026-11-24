extends TestCase
## End-to-end farming on the real farm scene: tools, planting, growth over
## several nights, harvest, clearing objects and persistence across reloads.

const A := FarmActionResolver.Action

var farm: Node


func before_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)
	GameState.weather_override = Weather.Kind.SUNNY
	_load_farm()


func after_each() -> void:
	GameState.weather_override = -1
	GameState.travel(&"farm", "default")
	for action in InputBindings.ALL_ACTIONS:
		Input.action_release(action)
	if is_instance_valid(farm):
		farm.free()


func _load_farm() -> void:
	farm = (load("res://scenes/farm/farm.tscn") as PackedScene).instantiate()
	farm.set("allow_scene_changes", false)
	tree.root.add_child(farm)


func _map() -> WorldMap:
	return farm.get("map")


func _controller() -> FarmController:
	return farm.get("controller")


func _player() -> Player:
	return farm.get("player")


## Puts the player one tile above `target`, facing down at it.
func _stand_above(target: Vector2i) -> void:
	var p := _player()
	p.position = _map().cell_anchor(target + Vector2i.UP) + Vector2(0, -1)
	p.velocity = Vector2.ZERO
	p.face(Vector2.DOWN)


func _select(id: StringName) -> void:
	var slot := GameState.inventory.first_slot_of(id)
	assert_true(slot >= 0 and slot < GameState.HOTBAR_SIZE, "%s should be on the hotbar" % id)
	GameState.select_slot(slot)


func _use(id: StringName, target: Vector2i) -> FarmActionResolver.Action:
	_select(id)
	_stand_above(target)
	_controller().set("_cooldown", 0.0)
	return _controller().use_selected_item()


## A free grass cell in the open area east of the house, with a free cell above.
func _free_grass_cell() -> Vector2i:
	var map := _map()
	for y in range(14, 30):
		for x in range(36, 56):
			var c := Vector2i(x, y)
			var above := c + Vector2i.UP
			if map.layout.terrain_at(c) == "grass" and _controller().object_kind_at(c) == &"" \
					and map.layout.terrain_at(above) in ["grass", "grass_flowers"] \
					and _controller().object_kind_at(above) == &"":
				return c
	return Vector2i(-1, -1)


func test_target_is_cell_in_front_of_player() -> void:
	await wait_physics_frames(2)
	var c := _free_grass_cell()
	_stand_above(c)
	assert_eq(_player().feet_cell(), c + Vector2i.UP)
	assert_eq(_controller().target_cell(), c)


func test_full_growth_cycle_daisy() -> void:
	await wait_physics_frames(2)
	var c := _free_grass_cell()
	assert_ne(c, Vector2i(-1, -1), "found a test cell")
	var seeds_before := GameState.inventory.count_of(&"seed_daisy")
	assert_eq(_use(&"hoe", c), A.TILL)
	assert_true(GameState.farm_soil.is_tilled(c))
	assert_eq(_use(&"seed_daisy", c), A.PLANT)
	assert_eq(GameState.inventory.count_of(&"seed_daisy"), seeds_before - 1, "seed consumed")
	var view: SoilView = farm.get("soil_view")
	assert_ne(view.crop_sprite_at(c), null, "crop sprite shown")
	var fl := ItemRegistry.flower(&"daisy")
	for day in fl.total_growth_days():
		assert_eq(_use(&"watering_can", c), A.WATER, "watering on day %d" % day)
		GameState.advance_day()
	assert_true(GameState.farm_soil.is_harvestable(c), "daisy blooms after %d watered days" % fl.total_growth_days())
	assert_eq(view.crop_sprite_at(c).region_rect.position.x, 5 * 16.0, "bloom frame shown")
	_stand_above(c)
	_controller().set("_cooldown", 0.0)
	assert_eq(_controller().interact(), A.HARVEST)
	assert_true(GameState.inventory.count_of(&"flower_daisy") >= 1, "flower in inventory")
	assert_false(GameState.farm_soil.has_crop(c))


func test_watering_uses_charges_and_refills_at_pond() -> void:
	await wait_physics_frames(2)
	var c := _free_grass_cell()
	_use(&"hoe", c)
	var before := GameState.watering_can_charges
	_use(&"watering_can", c)
	assert_eq(GameState.watering_can_charges, before - 1)
	var pond := Vector2i(42, 25)
	assert_eq(_map().layout.terrain_at(pond), "water")
	_select(&"watering_can")
	_player().position = _map().cell_anchor(pond + Vector2i.LEFT) + Vector2(0, -1)
	_player().face(Vector2.RIGHT)
	_controller().set("_cooldown", 0.0)
	assert_eq(_controller().use_selected_item(), A.REFILL)
	assert_eq(GameState.watering_can_charges, GameState.WATERING_CAN_CAPACITY)


func test_cannot_till_path_or_plant_untilled() -> void:
	await wait_physics_frames(2)
	var path := Vector2i(31, 20)
	assert_eq(_map().layout.terrain_at(path), "path")
	assert_eq(_use(&"hoe", path), A.NONE)
	assert_eq(_use(&"seed_daisy", _free_grass_cell()), A.NONE)
	assert_eq(_farm_hud().last_toast(), tr("MSG_NEEDS_TILLED"))


func test_rock_takes_two_hits_and_stays_removed_after_reload() -> void:
	await wait_physics_frames(2)
	var rock := _find_object(&"rock")
	assert_ne(rock, Vector2i(-1, -1))
	assert_eq(_use(&"pickaxe", rock), A.BREAK_ROCK)
	assert_ne(_map().get_object_at(rock), null, "first hit only cracks it")
	_controller().set("_cooldown", 0.0)
	assert_eq(_controller().use_selected_item(), A.BREAK_ROCK)
	await tree.process_frame
	assert_eq(_map().get_object_at(rock), null, "second hit breaks it")
	assert_eq(GameState.inventory.count_of(&"stone"), 2)
	farm.free()
	_load_farm()
	await wait_physics_frames(2)
	assert_eq(_map().get_object_at(rock), null, "still gone after reloading the farm")


func test_weed_cleared_with_scythe_then_tillable() -> void:
	await wait_physics_frames(2)
	var weed := _find_object(&"weed")
	assert_eq(_use(&"hoe", weed), A.NONE, "must clear first")
	assert_eq(_use(&"scythe", weed), A.CLEAR_WEED)
	await tree.process_frame
	assert_eq(GameState.inventory.count_of(&"fiber"), 1)
	assert_eq(_use(&"hoe", weed), A.TILL)


func test_soil_survives_scene_reload() -> void:
	await wait_physics_frames(2)
	var c := _free_grass_cell()
	_use(&"hoe", c)
	_use(&"seed_tulip", c)
	farm.free()
	_load_farm()
	await wait_physics_frames(2)
	assert_true(GameState.farm_soil.has_crop(c))
	assert_ne((farm.get("soil_view") as SoilView).crop_sprite_at(c), null, "crop redrawn")
	assert_eq(_map().soil_layer.get_cell_source_id(c), 0, "tilled tile redrawn")


func test_house_door_leads_inside() -> void:
	await wait_physics_frames(2)
	var house := Vector2i(31, 12)
	_player().position = _map().cell_anchor(house + Vector2i.DOWN) + Vector2(0, -1)
	_player().face(Vector2.UP)
	_controller().set("_cooldown", 0.0)
	assert_eq(_controller().interact(), A.INTERACT)
	assert_eq(GameState.current_map, &"house", "door travels into the house")
	GameState.travel(&"farm", "default")


func test_hotbar_keys_select_slots() -> void:
	await wait_physics_frames(1)
	var ev := InputEventAction.new()
	ev.action = InputBindings.HOTBAR_SLOTS[3]
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await tree.process_frame
	assert_eq(GameState.selected_slot, 3)
	assert_eq(GameState.selected_item_id(), &"pickaxe")


func _farm_hud() -> FarmHUD:
	return farm.get("hud")


func _find_object(kind: StringName) -> Vector2i:
	var map := _map()
	for y in map.layout.height:
		for x in map.layout.width:
			var c := Vector2i(x, y)
			var node := map.get_object_at(c)
			if node and node.get(&"object_kind") == kind:
				# needs a free, walkable cell above to stand on
				if _controller().object_kind_at(c + Vector2i.UP) == &"" and map.layout.terrain_at(c + Vector2i.UP) != "water":
					return c
	return Vector2i(-1, -1)
