extends TestCase


func test_default_actions_registered() -> void:
	InputBindings.register_defaults()
	for action in InputBindings.ALL_ACTIONS:
		assert_true(InputMap.has_action(action), "missing action %s" % action)
		assert_false(InputMap.action_get_events(action).is_empty(), "no events for %s" % action)


func test_register_is_idempotent() -> void:
	InputBindings.register_defaults()
	var before := InputMap.action_get_events(InputBindings.MOVE_UP).size()
	InputBindings.register_defaults()
	assert_eq(InputMap.action_get_events(InputBindings.MOVE_UP).size(), before)


func test_outfits_load_and_make_materials() -> void:
	assert_gt(OutfitPalette.count(), 1, "at least two outfits")
	for i in OutfitPalette.count():
		var outfit := OutfitPalette.outfit(i)
		assert_true(outfit.has("id") and outfit.has("main") and outfit.has("shade"), "outfit %d fields" % i)
		assert_ne(OutfitPalette.make_material(i), null)
	assert_eq(OutfitPalette.outfit(999), OutfitPalette.outfit(OutfitPalette.count() - 1), "index is clamped")


func test_character_sprite_frames() -> void:
	var sheet := load("res://assets/characters/player_sheet.png") as Texture2D
	var frames := CharacterSpriteFrames.build(sheet, Vector2i(16, 24))
	for facing in ["down", "up", "right"]:
		assert_true(frames.has_animation("walk_" + facing), "walk_" + facing)
		assert_true(frames.has_animation("idle_" + facing), "idle_" + facing)
		assert_eq(frames.get_frame_count("walk_" + facing), 4)


func test_demo_tours_use_real_actions() -> void:
	for tour: String in DemoTour.TOURS:
		for step: Array in DemoTour.TOURS[tour]:
			var action: String = step[0]
			if action == "wait":
				continue
			action = "move_" + action.trim_prefix("run_") if action.begins_with("run_") else action
			assert_true(InputMap.has_action(StringName(action)), "%s: %s is an input action" % [tour, action])
			assert_gt(float(step[1]), 0.0)
