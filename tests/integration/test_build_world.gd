extends TestCase
## Building, the greenhouse and upgraded tools in the real scenes.

const A := FarmActionResolver.Action
const MAP_SCENE := "res://scenes/world/map_scene.tscn"

var scene: GameplayScene


func before_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)
	GameState.weather_override = Weather.Kind.SUNNY
	GameState._set_weather(Weather.Kind.SUNNY)


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


## Stands below `cell`, facing up at it, holding `item`.
func _aim(cell: Vector2i, item: StringName) -> void:
	scene.player.position = scene.map.cell_anchor(cell + Vector2i.DOWN) + Vector2(0, -1)
	scene.player.face(Vector2.UP)
	var slot := GameState.inventory.first_slot_of(item)
	if slot >= GameState.HOTBAR_SIZE:
		GameState.inventory.move_slot(slot, GameState.HOTBAR_SIZE - 1) # as a player would
		slot = GameState.HOTBAR_SIZE - 1
	GameState.select_slot(slot)
	scene.controller.set("_cooldown", 0.0)


func test_place_bench_blocks_and_pick_up() -> void:
	await _open(&"farm")
	GameState.inventory.add_item(&"build_bench", 1)
	var cell := Vector2i(50, 15)
	_aim(cell, &"build_bench")
	assert_eq(scene.controller.use_selected_item(), A.PLACE)
	assert_ne(scene.map.get_object_at(cell), null)
	assert_ne(scene.map.get_object_at(cell + Vector2i.LEFT), null, "2-wide footprint")
	assert_eq(scene.controller.object_kind_at(cell), FarmActionResolver.KIND_PLACED)
	_aim(cell, &"pickaxe")
	assert_eq(scene.controller.use_selected_item(), A.PICK_UP)
	await tree.process_frame
	assert_eq(scene.map.get_object_at(cell), null)
	assert_eq(GameState.inventory.count_of(&"build_bench"), 1)


func test_path_and_pond_tiles() -> void:
	await _open(&"farm")
	GameState.inventory.add_item(&"build_path", 2)
	GameState.inventory.add_item(&"build_pond", 1)
	_aim(Vector2i(50, 15), &"build_path")
	scene.controller.use_selected_item()
	_aim(Vector2i(51, 15), &"build_path")
	scene.controller.use_selected_item()
	assert_eq(scene.map.built_floor.get_cell_atlas_coords(Vector2i(50, 15)), Vector2i(MapLayout.EAST, 4), "connects east")
	_aim(Vector2i(53, 15), &"build_pond")
	assert_eq(scene.controller.use_selected_item(), A.PLACE)
	assert_eq(scene.map.built_water.get_cell_source_id(Vector2i(54, 14)), 0, "2x2 water")
	assert_true(GameState.farm_soil.water_cells.has(Vector2i(53, 15)), "counts as water for flowers")


func test_cannot_build_on_exit_or_village() -> void:
	await _open(&"farm")
	GameState.inventory.add_item(&"build_lamp", 1)
	assert_ne(scene.controller.can_place(Vector2i(31, 38), ItemRegistry.item(&"build_lamp")), "", "near exit")
	await _open(&"village")
	_aim(Vector2i(30, 24), &"build_lamp")
	assert_eq(scene.controller.use_selected_item(), A.NONE)


func test_builds_persist_after_reload() -> void:
	await _open(&"farm")
	GameState.inventory.add_item(&"build_cherry_tree", 1)
	_aim(Vector2i(50, 15), &"build_cherry_tree")
	scene.controller.use_selected_item()
	await _open(&"farm")
	assert_ne(scene.map.get_object_at(Vector2i(50, 15)), null, "tree still there")


func test_placed_fence_connects_to_neighbour() -> void:
	await _open(&"farm")
	GameState.inventory.add_item(&"build_fence", 2)
	_aim(Vector2i(50, 15), &"build_fence")
	scene.controller.use_selected_item()
	_aim(Vector2i(51, 15), &"build_fence")
	scene.controller.use_selected_item()
	var fence := scene.map.get_object_at(Vector2i(50, 15)) as FencePiece
	assert_eq(fence.neighbor_mask & MapLayout.EAST, MapLayout.EAST)


func test_greenhouse_restore_enter_and_plant_in_winter() -> void:
	await _open(&"farm")
	GameState.wallet.set_amount(2000)
	for entry: Array in GameState.GREENHOUSE_COST["items"]:
		GameState.inventory.add_item(StringName(entry[0]), int(entry[1]))
	_aim(Vector2i(45, 11), &"hoe")
	scene.controller.interact()
	await tree.process_frame
	scene.hud.dialog().call("_answer", true)
	await tree.process_frame
	assert_true(GameState.greenhouse_restored)
	assert_eq((scene.map.get_object_at(Vector2i(45, 11)) as GreenhouseBuilding).get_node("Sprite").texture,
		GreenhouseBuilding.RESTORED)
	scene.hud.close_all()
	_aim(Vector2i(45, 11), &"hoe")
	scene.controller.interact()
	assert_eq(GameState.current_map, &"greenhouse")
	GameState.calendar.load_dict({"day": 3, "season": 3, "year": 1})
	await _open(&"greenhouse", "entrance")
	var bed := Vector2i(8, 5)
	_aim(bed, &"hoe")
	assert_eq(scene.controller.use_selected_item(), A.TILL)
	GameState.inventory.add_item(&"seed_orchid", 1)
	_aim(bed, &"seed_orchid")
	assert_eq(scene.controller.use_selected_item(), A.PLANT, "orchid in winter, indoors")
	assert_true(GameState.greenhouse_soil.has_crop(bed))
	assert_false(GameState.farm_soil.has_crop(bed), "separate soil")


func test_upgraded_tools_work_three_cells() -> void:
	await _open(&"farm")
	var slot := GameState.inventory.first_slot_of(&"hoe")
	GameState.inventory.take_slot(slot)
	GameState.inventory.put_in_slot(slot, &"hoe_steel", 1)
	var cell := Vector2i(50, 15)
	_aim(cell, &"hoe_steel")
	assert_eq(scene.controller.use_selected_item(), A.TILL)
	for k in 3:
		assert_true(GameState.farm_soil.is_tilled(cell + Vector2i.UP * k), "tilled %d" % k)
	slot = GameState.inventory.first_slot_of(&"watering_can")
	GameState.inventory.take_slot(slot)
	GameState.inventory.put_in_slot(slot, &"watering_can_copper", 1)
	GameState.refill_watering_can()
	assert_eq(GameState.watering_can_charges, 40)
	_aim(cell, &"watering_can_copper")
	assert_eq(scene.controller.use_selected_item(), A.WATER)
	for k in 3:
		assert_true(GameState.farm_soil.is_watered(cell + Vector2i.UP * k))
	assert_eq(GameState.watering_can_charges, 37)


func test_workshop_door_opens_shop() -> void:
	await _open(&"village")
	scene.player.position = scene.map.cell_anchor(Vector2i(42, 35)) + Vector2(0, -1)
	scene.player.face(Vector2.UP)
	scene.controller.set("_cooldown", 0.0)
	scene.controller.interact()
	assert_eq(scene.hud.shop_panel().shop.id, "workshop")
	scene.hud.close_all()
