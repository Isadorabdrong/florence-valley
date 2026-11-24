extends TestCase
## Villagers in the real world: routines, talking, gifts, quests, the
## journal and grandma's diary.

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
	GameState.clock.reset_day()


func _open(map_id: StringName, minutes: int, spawn_name: String = "default") -> void:
	if is_instance_valid(scene):
		scene.free()
	GameState.clock.set_minutes(minutes)
	GameState.travel(map_id, spawn_name)
	scene = (load(MAP_SCENE) as PackedScene).instantiate()
	scene.allow_scene_changes = false
	tree.root.add_child(scene)
	await wait_physics_frames(2)


func _face_npc(npc: VillagerNPC) -> void:
	var cell := scene.map.world_to_cell(npc.position + Vector2(0, -3))
	scene.player.position = scene.map.cell_anchor(cell + Vector2i.DOWN) + Vector2(0, -1)
	scene.player.face(Vector2.UP)
	scene.controller.set("_cooldown", 0.0)


func _finish_dialogue() -> void:
	var box := scene.hud.dialogue_box()
	for i in 20:
		if not box.visible:
			return
		box.advance()
		await tree.process_frame


func test_celeste_in_village_at_8_then_market() -> void:
	await _open(&"village", 480)
	var celeste := scene.npc_director.villager("celeste")
	assert_ne(celeste, null, "Celeste in the plaza at 08:00 (Monday)")
	assert_eq(celeste.target_cell, Vector2i(24, 24))
	GameState.clock.set_minutes(540)
	await tree.process_frame
	assert_eq(scene.npc_director.villager("celeste"), null, "left for the market")
	await _open(&"market", 600, "entrance")
	assert_ne(scene.npc_director.villager("celeste"), null, "behind the market counter")


func test_talk_meets_and_advances_story() -> void:
	await _open(&"village", 480)
	GameState.quests.notify("read_diary")
	GameState.quests.notify("harvest", "daisy", 5)
	assert_true(GameState.quests.is_active("main_meet"))
	var celeste := scene.npc_director.villager("celeste")
	_face_npc(celeste)
	assert_eq(scene.controller.interact(), A.TALK)
	await tree.process_frame
	assert_true(scene.hud.dialogue_box().visible)
	await _finish_dialogue()
	assert_true(GameState.relationships.has_met("celeste"))
	assert_eq(GameState.relationships.points("celeste"), 20)
	assert_eq(GameState.quests.active["main_meet"][0], 1)


func test_gift_with_use_item() -> void:
	await _open(&"village", 480)
	GameState.inventory.add_item(&"flower_lavender", 2)
	GameState.select_slot(GameState.inventory.first_slot_of(&"flower_lavender"))
	_face_npc(scene.npc_director.villager("celeste"))
	assert_eq(scene.controller.use_selected_item(), A.GIFT)
	await tree.process_frame
	await _finish_dialogue()
	assert_eq(GameState.relationships.points("celeste"), 80, "loved gift")
	assert_eq(GameState.inventory.count_of(&"flower_lavender"), 1)


func test_marker_for_first_meeting() -> void:
	await _open(&"village", 480)
	var celeste := scene.npc_director.villager("celeste")
	assert_true(celeste.get_node("Bubble").visible, "! before meeting")
	GameState.relationships.talk("celeste", GameState.today())
	scene.npc_director.refresh_markers()
	assert_false(celeste.get_node("Bubble").visible)


func test_npc_blocks_and_is_targetable() -> void:
	await _open(&"village", 480)
	var celeste := scene.npc_director.villager("celeste")
	assert_eq(scene.controller.object_kind_at(Vector2i(24, 24)), FarmActionResolver.KIND_NPC)
	assert_true(celeste.get_node("Body") is StaticBody2D)


func test_diary_shelf_completes_first_quest() -> void:
	await _open(&"house", 600, "entrance")
	scene.player.position = scene.map.cell_anchor(Vector2i(11, 3)) + Vector2(0, -1)
	scene.player.face(Vector2.UP)
	scene.controller.set("_cooldown", 0.0)
	assert_eq(scene.controller.interact(), A.INTERACT)
	assert_true(GameState.quests.is_completed("main_diary"))
	assert_true(scene.hud.journal_panel().visible)
	assert_eq(scene.hud.journal_panel().current_tab(), JournalPanel.Tab.DIARY)
	scene.hud.close_all()


func test_heart_event_gives_reward() -> void:
	await _open(&"village", 480)
	GameState.relationships.talk("celeste", 1)
	GameState.relationships.add("celeste", 400)
	_face_npc(scene.npc_director.villager("celeste"))
	scene.controller.interact()
	await tree.process_frame
	await _finish_dialogue()
	await tree.process_frame
	assert_true(GameState.relationships.event_seen("celeste", "heart_4"))
	assert_eq(GameState.inventory.count_of(&"seed_lily"), 5 + 4)


func test_journal_opens_with_l() -> void:
	await _open(&"village", 480)
	var ev := InputEventAction.new()
	ev.action = InputBindings.JOURNAL
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.flush_buffered_events()
	await tree.process_frame
	assert_true(scene.hud.journal_panel().visible)
	for tab in [JournalPanel.Tab.DIARY, JournalPanel.Tab.VILLAGERS, JournalPanel.Tab.QUESTS]:
		scene.hud.journal_panel().call("_set_tab", tab)
	scene.hud.close_all()


func test_relationships_and_quests_saved() -> void:
	GameState.relationships.talk("aurora", 1)
	GameState.relationships.add("aurora", 150)
	GameState.quests.notify("read_diary")
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_save_data()))
	GameState.start_new_profile("Outra", "Lua", 0)
	assert_true(GameState.apply_save_data(data).is_empty())
	assert_eq(GameState.relationships.points("aurora"), 170)
	assert_true(GameState.quests.is_completed("main_diary"))


func test_schema_3_migration() -> void:
	var v3 := GameState.to_save_data()
	v3.erase("relationships")
	v3.erase("quests")
	var migrated := SaveSystem.migrate(v3, 3)
	assert_true(migrated.has("relationships") and migrated.has("quests"))
	assert_true(GameState.apply_save_data(migrated).is_empty())
	assert_true(GameState.quests.is_active("main_diary"), "story starts fresh")
