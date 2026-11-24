extends TestCase
## Shop, chest, clock and save/load on the real farm scene.

const A := FarmActionResolver.Action
const TEST_DIR := "user://test_saves"

var farm: Node


func before_each() -> void:
	SaveSystem.save_dir = TEST_DIR
	for slot in range(1, 4):
		SaveSystem.delete(slot)
	GameState.start_new_profile("Teste", "Florence", 0)
	GameState.weather_override = Weather.Kind.SUNNY
	_load_farm()


func after_each() -> void:
	GameState.weather_override = -1
	for slot in range(1, 4):
		SaveSystem.delete(slot)
	SaveSystem.save_dir = SaveSystem.DEFAULT_DIR
	if is_instance_valid(farm):
		farm.free()
	get_tree_paused(false)


func get_tree_paused(value: bool) -> void:
	tree.paused = value


func _load_farm() -> void:
	farm = (load("res://scenes/farm/farm.tscn") as PackedScene).instantiate()
	farm.set("allow_scene_changes", false)
	tree.root.add_child(farm)


func _map() -> WorldMap:
	return farm.get("map")


func _ctrl() -> FarmController:
	return farm.get("controller")


func _hud() -> FarmHUD:
	return farm.get("hud")


func _face_object(kind: StringName) -> Vector2i:
	var map := _map()
	for y in map.layout.height:
		for x in map.layout.width:
			var c := Vector2i(x, y)
			var node := map.get_object_at(c)
			if node and node.get(&"object_kind") == kind:
				var p: Player = farm.get("player")
				p.position = map.cell_anchor(c + Vector2i.DOWN) + Vector2(0, -1)
				p.face(Vector2.UP)
				return c
	return Vector2i(-1, -1)


func test_shop_opens_and_trades() -> void:
	await wait_physics_frames(2)
	var cart := _face_object(&"shop")
	assert_ne(cart, Vector2i(-1, -1), "market cart on the map")
	assert_eq(_ctrl().interact(), A.OPEN_SHOP)
	var panel := _hud().shop_panel()
	assert_true(panel.visible)
	assert_true(_hud().is_modal_open(), "player frozen while shopping")
	var before := GameState.wallet.amount
	panel.call("_buy", &"seed_lily", 2)
	assert_eq(GameState.wallet.amount, before - 2 * ItemRegistry.item(&"seed_lily").buy_price)
	GameState.inventory.add_item(&"flower_daisy", 4)
	panel.call("_sell", &"flower_daisy", 4)
	assert_eq(GameState.inventory.count_of(&"flower_daisy"), 0)
	panel.close()
	assert_false(_hud().is_modal_open())


func test_chest_stores_items_across_reload() -> void:
	await wait_physics_frames(2)
	var chest_cell := _face_object(&"chest")
	assert_ne(chest_cell, Vector2i(-1, -1), "chest on the map")
	assert_eq(_ctrl().interact(), A.OPEN_CHEST)
	assert_true(_hud().inventory_panel().is_chest_open())
	var chest := GameState.chest(_ctrl().chest_id(chest_cell))
	var slot := GameState.inventory.first_slot_of(&"fertilizer")
	assert_true(Inventory.transfer(GameState.inventory, slot, chest, 0))
	_hud().close_all()
	farm.free()
	_load_farm()
	await wait_physics_frames(2)
	assert_eq(GameState.chest(_ctrl().chest_id(chest_cell)).count_of(&"fertilizer"), 10)


func test_clock_runs_only_outside_menus() -> void:
	await wait_physics_frames(2)
	GameState.clock.reset_day()
	farm.call("_process", GameClock.SECONDS_PER_TICK)
	assert_eq(GameState.clock.minutes, GameClock.DAY_START + 10)
	_hud().open_inventory()
	farm.call("_process", GameClock.SECONDS_PER_TICK * 5)
	assert_eq(GameState.clock.minutes, GameClock.DAY_START + 10, "time stops in menus")
	_hud().close_all()


func test_passing_out_starts_next_day() -> void:
	await wait_physics_frames(2)
	var day := GameState.calendar.day
	GameState.clock.set_minutes(GameClock.DAY_END - 10)
	GameState.clock.advance(GameClock.SECONDS_PER_TICK)
	for i in 180:
		await tree.process_frame
		if not _ctrl().is_busy():
			break
	assert_eq(GameState.calendar.day, day + 1)
	assert_eq(GameState.clock.minutes, GameClock.DAY_START)
	assert_eq(GameState.current_map, WorldGraph.home_map(), "wakes up at home")
	GameState.travel(&"farm", "default")


func test_daylight_follows_clock() -> void:
	await wait_physics_frames(2)
	var light: CanvasModulate = farm.get("daylight")
	GameState.clock.set_minutes(12 * 60)
	var noon := light.color
	GameState.clock.set_minutes(23 * 60)
	assert_lt(light.color.v, noon.v, "night is darker")


func test_save_and_load_restores_world() -> void:
	await wait_physics_frames(2)
	var player: Player = farm.get("player")
	player.position = _map().cell_center(Vector2i(50, 14))
	GameState.farm_soil.till(Vector2i(51, 14))
	GameState.wallet.set_amount(777)
	assert_eq(GameState.save_game(2), OK)
	assert_eq(GameState.current_slot, 2)
	GameState.start_new_profile("Outra", "Pessoa", 1)
	farm.free()
	var result := GameState.load_game(2)
	assert_eq(result["error"], SaveSystem.LoadError.NONE)
	assert_eq(GameState.player_name, "Teste")
	_load_farm()
	await wait_physics_frames(2)
	assert_eq(GameState.wallet.amount, 777)
	assert_true(GameState.farm_soil.is_tilled(Vector2i(51, 14)))
	var p: Player = farm.get("player")
	assert_true(p.position.distance_to(_map().cell_center(Vector2i(50, 14))) < 1.0, "position restored")


func test_sleeping_autosaves() -> void:
	await wait_physics_frames(2)
	GameState.current_slot = 3
	GameState.advance_day()
	var r := SaveSystem.load_slot(3)
	assert_eq(r["error"], SaveSystem.LoadError.NONE)
	assert_eq(int(r["data"]["calendar"]["day"]), 2)
	GameState.current_slot = 0


func test_pause_menu_save_button() -> void:
	await wait_physics_frames(2)
	var pause := farm.get_node("PauseMenu")
	pause.call("set_open", true)
	assert_true(pause.call("save_now"))
	assert_true(SaveSystem.exists(1), "first free slot used")
	pause.call("set_open", false)
