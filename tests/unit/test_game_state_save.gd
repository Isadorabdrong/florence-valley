extends TestCase
## GameState <-> save payload: everything the spec lists must survive a
## round trip, and bad data must be corrected instead of crashing.


func before_each() -> void:
	GameState.start_new_profile("Ana Clara", "Jardim", 2)


func after_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)


func test_full_state_roundtrip() -> void:
	GameState.wallet.set_amount(4321)
	GameState.calendar.load_dict({"day": 9, "season": 1, "year": 2})
	GameState.clock.set_minutes(14 * 60 + 30)
	GameState.inventory.add_item(&"flower_rose", 7)
	GameState.chest("farm:1,1").add_item(&"stone", 12)
	GameState.farm_soil.till(Vector2i(3, 4))
	GameState.farm_soil.plant(Vector2i(3, 4), &"daisy", 1)
	GameState.mark_object_removed(&"farm", Vector2i(10, 11))
	GameState.watering_can_charges = 3
	GameState.select_slot(5)
	GameState.pending_player_position = Vector2(100, 200)
	var data := GameState.to_save_data()
	# simulate the disk round trip (ints become floats in JSON)
	data = JSON.parse_string(JSON.stringify(data))
	GameState.start_new_profile("Outra", "Fazenda", 0)
	var issues := GameState.apply_save_data(data)
	assert_true(issues.is_empty(), "issues: %s" % [issues])
	assert_eq(GameState.player_name, "Ana Clara")
	assert_eq(GameState.farm_name, "Jardim")
	assert_eq(GameState.outfit_index, 2)
	assert_eq(GameState.wallet.amount, 4321)
	assert_eq(GameState.calendar.to_dict(), {"day": 9, "season": 1, "year": 2})
	assert_eq(GameState.clock.format(), "14:30")
	assert_eq(GameState.inventory.count_of(&"flower_rose"), 7)
	assert_eq(GameState.chest("farm:1,1").count_of(&"stone"), 12)
	assert_true(GameState.farm_soil.has_crop(Vector2i(3, 4)))
	assert_true(GameState.removed_objects_for(&"farm").has(Vector2i(10, 11)))
	assert_eq(GameState.watering_can_charges, 3)
	assert_eq(GameState.selected_slot, 5)
	assert_eq(GameState.pending_player_position, Vector2(100, 200))


func test_invalid_profile_rejected() -> void:
	var data := GameState.to_save_data()
	data["profile"]["name"] = ""
	assert_true(GameState.apply_save_data(data).has("profile"))


func test_bad_values_are_corrected() -> void:
	var data := GameState.to_save_data()
	data["money"] = -100
	data["calendar"] = {"day": 77, "season": 1, "year": 1}
	data["tools"] = {"watering_can": 9999}
	data["inventory"]["slots"][0] = {"id": "ghost_item", "count": 1}
	var issues := GameState.apply_save_data(data)
	assert_true(issues.has("money"))
	assert_true(issues.has("calendar"))
	assert_true(issues.has("inventory"))
	assert_eq(GameState.wallet.amount, 0)
	assert_eq(GameState.calendar.day, Calendar.DAYS_PER_SEASON)
	assert_eq(GameState.watering_can_charges, GameState.WATERING_CAN_CAPACITY)


func test_rainy_day_waters_crops() -> void:
	var c := Vector2i(1, 1)
	GameState.farm_soil.till(c)
	GameState.weather_override = Weather.Kind.RAIN
	GameState.advance_day()
	GameState.weather_override = -1
	assert_eq(GameState.weather, Weather.Kind.RAIN)
	assert_true(GameState.farm_soil.is_watered(c), "rain waters tilled soil")
	assert_eq(GameState.clock.minutes, GameClock.DAY_START)


func test_new_game_starts_with_money() -> void:
	assert_eq(GameState.wallet.amount, GameState.STARTING_MONEY)


func test_settings_roundtrip() -> void:
	var path := "user://test_settings.cfg"
	var s := GameSettings.new()
	s.sfx_volume = 0.25
	s.fullscreen = true
	s.locale = "en"
	assert_eq(s.save(path), OK)
	var loaded := GameSettings.load_or_default(path)
	assert_almost(loaded.sfx_volume, 0.25)
	assert_true(loaded.fullscreen)
	assert_eq(loaded.locale, "en")
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", "klingon")
	cfg.set_value("audio", "sfx", 7.0)
	cfg.save(path)
	loaded = GameSettings.load_or_default(path)
	assert_eq(loaded.locale, "pt_BR", "unknown locale falls back")
	assert_almost(loaded.sfx_volume, 1.0, 0.001, "clamped")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
