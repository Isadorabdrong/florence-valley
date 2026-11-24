extends TestCase
## The flower shop in the real world: restoration at the village door,
## the interior, the counter, the workbench and customers on screen.

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
	GameState.florist.reset()


func _open(map_id: StringName, spawn_name: String = "default") -> void:
	if is_instance_valid(scene):
		scene.free()
	GameState.travel(map_id, spawn_name)
	scene = (load(MAP_SCENE) as PackedScene).instantiate()
	scene.allow_scene_changes = false
	tree.root.add_child(scene)
	await wait_physics_frames(2)


func _face(cell: Vector2i, from: Vector2i) -> void:
	scene.player.position = scene.map.cell_anchor(cell + from) + Vector2(0, -1)
	scene.player.face(Vector2(-from))
	scene.controller.set("_cooldown", 0.0)


func test_ruined_shop_explains_what_is_missing() -> void:
	await _open(&"village")
	_face(Vector2i(34, 11), Vector2i.DOWN)
	scene.controller.interact()
	assert_true(scene.hud.message_dialog().visible, "explains the restoration cost")
	assert_false(GameState.florist.restored)
	assert_eq(GameState.current_map, &"village")
	scene.hud.close_all()


func test_restore_then_enter() -> void:
	await _open(&"village")
	GameState.inventory.add_item(&"stone", 10)
	GameState.inventory.add_item(&"fiber", 10)
	GameState.wallet.set_amount(1000)
	_face(Vector2i(34, 11), Vector2i.DOWN)
	scene.controller.interact()
	await tree.process_frame
	assert_true(scene.hud.dialog().visible, "asks for confirmation")
	scene.hud.dialog().call("_answer", true)
	await tree.process_frame
	assert_true(GameState.florist.restored)
	assert_eq(GameState.wallet.amount, 200)
	var building := scene.map.get_object_at(Vector2i(34, 11)) as FloristBuilding
	assert_eq(building.get_node("Sprite").texture, FloristBuilding.RESTORED)
	scene.hud.close_all()
	_face(Vector2i(34, 11), Vector2i.DOWN)
	scene.controller.interact()
	assert_eq(GameState.current_map, &"florist_shop")


func _restored_shop() -> void:
	GameState.florist.restored = true
	GameState.florist.call("_ensure_slots")
	await _open(&"florist_shop", "entrance")


func test_interior_furniture_works() -> void:
	await _restored_shop()
	assert_ne(scene.florist_view, null)
	var stands := 0
	for node in scene.map.entities.get_children():
		if node is DisplayStand and node.visible:
			stands += 1
	assert_eq(stands, 2, "4 slots = 2 stands")
	_face(Vector2i(11, 6), Vector2i.DOWN)
	scene.controller.interact()
	assert_true(scene.hud.florist_panel().visible, "counter opens management")
	scene.hud.close_all()
	_face(Vector2i(12, 2), Vector2i.DOWN)
	scene.controller.interact()
	assert_true(scene.hud.workbench_panel().visible, "workbench opens")
	scene.hud.close_all()
	_face(Vector2i(4, 2), Vector2i.DOWN)
	scene.controller.interact()
	assert_eq(scene.hud.florist_panel().current_tab(), FloristPanel.Tab.ORDERS, "board opens orders")
	scene.hud.close_all()


func test_workbench_crafts() -> void:
	await _restored_shop()
	GameState.inventory.add_item(&"flower_daisy", 3)
	scene.hud.open_workbench()
	var panel := scene.hud.workbench_panel()
	for i in 3:
		panel.pick(&"flower_daisy")
	assert_eq(panel.preview()["id"], "bouquet_daisy")
	var result := panel.craft()
	assert_false(result.is_empty())
	assert_eq(GameState.inventory.count_of(&"bouquet_daisy"), 1)
	assert_true(GameState.florist.known_recipes.has("bouquet_daisy"))
	scene.hud.close_all()


func test_customers_walk_in_and_are_served() -> void:
	await _restored_shop()
	var shop := GameState.florist
	GameState.inventory.add_item(&"flower_lily", 10)
	shop.stock_slot(0, &"flower_lily", 10, GameState.inventory)
	shop.is_open = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 300:
		shop.tick(600, 2, 0, 0, true, GameState.wallet, rng)
		if shop.has_waiting():
			break
	await tree.process_frame
	assert_true(shop.has_waiting())
	assert_gt(scene.florist_view.customer_count(), 0, "customers visible in the shop")
	_face(Vector2i(11, 6), Vector2i.UP)
	var before := GameState.wallet.amount
	scene.controller.interact()
	assert_gt(GameState.wallet.amount, before, "served at the counter")
	assert_false(scene.hud.florist_panel().visible, "serving doesn't open the panel")


func test_stand_shows_stock() -> void:
	await _restored_shop()
	GameState.inventory.add_item(&"bouquet_simple", 2)
	GameState.florist.stock_slot(0, &"bouquet_simple", 2, GameState.inventory)
	var stand := scene.map.get_object_at(Vector2i(3, 5)) as DisplayStand
	var icons := stand.get_children().filter(func(n: Node) -> bool: return n is Sprite2D and n.name != "Sprite")
	assert_eq(icons.size(), 2)


func test_shop_state_saved() -> void:
	GameState.florist.restored = true
	GameState.florist.reputation = 77
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save_data()))
	GameState.start_new_profile("Outra", "Lua", 0)
	assert_false(GameState.florist.restored)
	assert_true(GameState.apply_save_data(data).is_empty())
	assert_true(GameState.florist.restored)
	assert_eq(GameState.florist.reputation, 77)


func test_day_summary_includes_shop() -> void:
	GameState.florist.restored = true
	GameState.florist.call("_ensure_slots")
	var stats := GameState.advance_day()
	assert_true(stats.has("florist"))
