extends TestCase


func before_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)


func after_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 0)


func test_levels_from_xp() -> void:
	assert_eq(Progression.level_for(0), 1)
	assert_eq(Progression.level_for(99), 1)
	assert_eq(Progression.level_for(100), 2)
	assert_eq(Progression.level_for(99999), Progression.max_level())
	var p := Progression.new()
	assert_eq(p.add_xp(260), [2, 3] as Array[int])
	assert_eq(p.level, 3)
	assert_almost(p.level_progress(), 10.0 / 200.0, 0.001)


func test_level_rewards_applied() -> void:
	var before := GameState.inventory.count_of(&"fertilizer")
	GameState._gain_xp(100)
	assert_eq(GameState.progression.level, 2)
	assert_eq(GameState.inventory.count_of(&"fertilizer"), before + 10)


func test_record_harvest_counts_and_gives_xp() -> void:
	GameState.record("harvest", "rose", 2)
	var p := GameState.progression
	assert_eq(p.stat("harvested_total"), 2)
	assert_eq(p.stat("harvested:rose"), 2)
	assert_eq(p.xp, 2 * ItemRegistry.flower(&"rose").total_growth_days() * 2)
	assert_true(p.achievements.has("first_harvest"))


func test_achievement_reward_and_once() -> void:
	var money := GameState.wallet.amount
	GameState.record("craft", "bouquet_simple")
	assert_true(GameState.progression.achievements.has("first_bouquet"))
	assert_eq(GameState.wallet.amount, money + 100)
	GameState.record("craft", "bouquet_simple")
	assert_eq(GameState.wallet.amount, money + 100, "rewarded only once")


func test_money_earned_ignores_reset_and_counts_income() -> void:
	assert_eq(GameState.progression.stat("money_earned"), 0, "starting money isn't income")
	GameState.wallet.add(250)
	assert_eq(GameState.progression.stat("money_earned"), 250)
	GameState.wallet.spend(100)
	assert_eq(GameState.progression.stat("money_earned"), 250)


func test_rare_harvest_stat() -> void:
	GameState.record("harvest", "golden_rose", 1)
	assert_eq(GameState.progression.stat("rare_harvested"), 1)
	assert_true(GameState.progression.achievements.has("rare_bloom"))


func test_all_achievements_have_texts_and_icons() -> void:
	for a: Dictionary in Progression.achievement_defs():
		assert_ne(ItemRegistry.item(StringName(str(a["icon"]))), null, "icon %s" % a["id"])
		for lang in ["pt_BR", "en"]:
			assert_false(str(a["title"].get(lang, "")).is_empty())
		assert_ne(GameState.stat_value(str(a["stat"])), -1)


func test_dict_roundtrip() -> void:
	GameState.record("harvest", "daisy", 3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.progression.to_dict()))
	var other := Progression.new()
	assert_eq(other.load_dict(data), 0)
	assert_eq(other.xp, GameState.progression.xp)
	assert_eq(other.stat("harvested:daisy"), 3)
	assert_true(other.achievements.has("first_harvest"))
