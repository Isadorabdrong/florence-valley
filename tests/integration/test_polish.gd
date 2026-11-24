extends TestCase
## Phase 8 polish: music/ambience choice, footsteps by terrain, night
## lights, seasonal shader uniform, UI/feel animations and performance.

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


func _open(map_id: StringName, minutes: int = 10 * 60) -> void:
	if is_instance_valid(scene):
		scene.free()
	GameState.clock.set_minutes(minutes)
	GameState.travel(map_id, "default")
	scene = (load(MAP_SCENE) as PackedScene).instantiate()
	scene.allow_scene_changes = false
	tree.root.add_child(scene)
	await wait_physics_frames(2)


# ------------------------------------------------------------------ audio ---

func test_music_follows_season_and_title() -> void:
	await _open(&"village")
	assert_eq(AudioManager.current_music(), "spring")
	GameState.calendar.season = Calendar.Season.WINTER
	scene.apply_season_now()
	assert_eq(AudioManager.current_music(), "winter")
	for track in ["spring", "summer", "autumn", "winter", "title"]:
		assert_true(ResourceLoader.exists(AudioManager.MUSIC_DIR + track + ".wav"), "music %s exists" % track)


func test_ambience_by_place_time_and_weather() -> void:
	await _open(&"village")
	assert_eq(scene.ambience_track(), "birds", "calm spring morning")
	GameState.clock.set_minutes(22 * 60)
	assert_eq(scene.ambience_track(), "", "no birds at night")
	GameState.clock.set_minutes(10 * 60)
	GameState.weather_override = Weather.Kind.RAIN
	GameState._set_weather(Weather.Kind.RAIN)
	assert_eq(scene.ambience_track(), "", "no birds in the rain")
	await _open(&"clear_lake")
	assert_eq(scene.ambience_track(), "water")
	await _open(&"house")
	assert_eq(scene.ambience_track(), "", "quiet indoors")


func test_footstep_sound_matches_ground() -> void:
	await _open(&"house")
	assert_eq(scene.step_sound(), &"step_wood", "wooden floor inside")
	await _open(&"village")
	var cobble := scene.map.cells_with_terrain("cobble")
	assert_false(cobble.is_empty(), "village has cobblestone")
	scene.player.position = scene.map.cell_anchor(cobble[0]) + Vector2(0, -1)
	assert_eq(scene.step_sound(), &"step_stone")
	var grass := scene.map.cells_with_terrain("grass")
	scene.player.position = scene.map.cell_anchor(grass[0]) + Vector2(0, -1)
	assert_eq(scene.step_sound(), &"step_grass")


func test_walking_emits_steps() -> void:
	await _open(&"village")
	var count := [0]
	var on_step := func() -> void: count[0] += 1
	scene.player.stepped.connect(on_step)
	Input.action_press(InputBindings.MOVE_RIGHT)
	await wait_physics_frames(40)
	Input.action_release(InputBindings.MOVE_RIGHT)
	scene.player.stepped.disconnect(on_step)
	assert_gt(count[0], 0, "feet touched the ground while walking")


# ----------------------------------------------------------------- lights ---

func test_night_light_curve() -> void:
	assert_eq(NightLight.level_for(12 * 60), 0.0, "noon off")
	assert_eq(NightLight.level_for(22 * 60), 1.0, "night on")
	assert_eq(NightLight.level_for(2 * 60), 1.0, "after midnight on")
	var dusk := NightLight.level_for(18 * 60 + 30)
	assert_gt(dusk, 0.0)
	assert_lt(dusk, 1.0)
	var dawn := NightLight.level_for(5 * 60 + 45)
	assert_gt(dawn, 0.0)
	assert_lt(dawn, 1.0)


func test_lamps_turn_on_at_night() -> void:
	await _open(&"village", 12 * 60)
	var lights := tree.get_nodes_in_group(NightLight.GROUP)
	assert_gt(lights.size(), 0, "village has lamps and windows")
	for l: NightLight in lights:
		assert_false(l.visible, "off at noon")
	GameState.clock.set_minutes(22 * 60)
	for l: NightLight in lights:
		assert_true(l.visible and l.energy > 0.3, "on at night")


# ----------------------------------------------------------------- season ---

func test_season_visuals_publish_shader_global() -> void:
	SeasonVisuals.set_shader_season(3)
	var v: Variant = RenderingServer.global_shader_parameter_get(SeasonVisuals.GLOBAL_SEASON)
	# The headless dummy renderer may not store globals; check when it does.
	if v != null:
		assert_almost(float(v), 3.0)
	SeasonVisuals.set_shader_season(0)
	var foliage := load("res://shaders/wind_sway.gdshader") as Shader
	assert_true(foliage.code.contains("global uniform float season"))
	var crops := load("res://resources/materials/crop_sway.tres") as ShaderMaterial
	assert_eq(crops.get_shader_parameter("seasonal"), false, "crops keep their colours")


# ------------------------------------------------------------- feel / perf ---

func test_tool_squash_settles() -> void:
	await _open(&"farm")
	scene.player.squash()
	var sprite := scene.player.get_node("Sprite") as Node2D
	assert_ne(sprite.scale, Vector2.ONE)
	await tree.create_timer(0.3).timeout
	assert_almost(sprite.scale.x, 1.0, 0.01)


func test_panel_fade_in_finishes() -> void:
	await _open(&"farm")
	var hud := scene.hud
	hud.open_journal()
	var panel := hud.journal_panel()
	await tree.create_timer(0.3).timeout
	assert_almost(panel.modulate.a, 1.0, 0.01)
	panel.visible = false


func test_xp_signal_updates_without_polling() -> void:
	var seen := [-1]
	var cb := func(x: int) -> void: seen[0] = x
	GameState.progression.xp_changed.connect(cb)
	GameState.progression.add_xp(15)
	GameState.progression.xp_changed.disconnect(cb)
	assert_eq(seen[0], GameState.progression.xp)


func test_protected_cells_cached_and_not_mutated() -> void:
	await _open(&"farm")
	var a := scene.protected_cells()
	var size := a.size()
	scene.controller.can_place(Vector2i(50, 15), ItemRegistry.item(&"build_path"))
	assert_true(is_same(a, scene.protected_cells()), "same cached dictionary")
	assert_eq(scene.protected_cells().size(), size, "can_place does not mutate it")


func test_scene_load_and_frame_time_budget() -> void:
	var t0 := Time.get_ticks_usec()
	await _open(&"village")
	var load_ms := (Time.get_ticks_usec() - t0) / 1000.0
	assert_lt(load_ms, 2500.0, "village loads in %.0f ms" % load_ms)
	var t1 := Time.get_ticks_usec()
	await wait_physics_frames(60)
	var frame_ms := (Time.get_ticks_usec() - t1) / 1000.0 / 60.0
	print("    [perf] village load %.0f ms, %.2f ms/frame (headless)" % [load_ms, frame_ms])
	assert_lt(frame_ms, 40.0, "average frame under 40 ms")
