extends TestCase

const LANGS := ["pt_BR", "en"]


func _texts(value: Variant, out: Array) -> void:
	if typeof(value) == TYPE_DICTIONARY and (value as Dictionary).has("pt_BR"):
		out.append(value)
	elif typeof(value) == TYPE_DICTIONARY:
		for k in value:
			_texts(value[k], out)
	elif typeof(value) == TYPE_ARRAY:
		for v in value:
			_texts(v, out)


func test_six_villagers_with_complete_profiles() -> void:
	assert_eq(Villagers.ids().size(), 6)
	var birthdays := {}
	for id in Villagers.ids():
		var npc := Villagers.npc(id)
		for key in ["name", "skin", "hair", "outfit", "birthday", "bio", "gifts", "schedule", "requests"]:
			assert_true(npc.has(key), "%s.%s" % [id, key])
		var b := str(npc["birthday"])
		assert_false(birthdays.has(b), "unique birthday %s" % b)
		birthdays[b] = true
		assert_true(ResourceLoader.exists("res://assets/characters/portraits/%s.png" % id), "portrait %s" % id)


func test_dialogue_complete_in_both_languages() -> void:
	for id in Villagers.ids():
		var d := Villagers.dialogue(id)
		for key in ["intro", "greet", "season", "rain", "birthday", "gift", "event", "quest_offer", "quest_progress", "quest_done"]:
			assert_true(d.has(key), "%s dialogue.%s" % [id, key])
		assert_eq((d.get("season", {}) as Dictionary).size(), 4, "%s seasons" % id)
		for r in ["loved", "liked", "neutral", "disliked", "already"]:
			assert_true((d.get("gift", {}) as Dictionary).has(r), "%s gift.%s" % [id, r])
		var texts: Array = []
		_texts(d, texts)
		for tx: Dictionary in texts:
			for lang in LANGS:
				assert_false(str(tx.get(lang, "")).is_empty(), "%s missing %s text" % [id, lang])


func test_schedule_spots_are_walkable() -> void:
	var layouts := {}
	for id in Villagers.ids():
		for variant: Dictionary in Villagers.npc(id)["schedule"]:
			var last := -1
			for entry: Array in variant["entries"]:
				assert_gt(int(entry[0]), last, "%s times ascending" % id)
				last = int(entry[0])
				if entry[1] == null:
					continue
				var map_id := str(entry[1])
				assert_true(WorldGraph.has_map(StringName(map_id)), "%s → %s" % [id, map_id])
				if not layouts.has(map_id):
					layouts[map_id] = MapLayout.load_from_files(str(WorldGraph.map_def(StringName(map_id))["layout"]), WorldGraph.LEGEND_PATH)
				var layout: MapLayout = layouts[map_id]
				var cell := Vector2i(int(entry[2]), int(entry[3]))
				assert_true(layout.in_bounds(cell), "%s %s %s in bounds" % [id, map_id, cell])
				assert_false(TerrainAtlas.is_solid(layout.terrain_at(cell)), "%s %s %s not solid" % [id, map_id, cell])
				assert_true(layout.object_at(cell).is_empty(), "%s %s %s free of objects" % [id, map_id, cell])


func test_where_follows_time_weekday_season_weather() -> void:
	assert_eq(Villagers.where("celeste", 600, 0, 0, false)["map"], &"market")
	assert_eq(Villagers.where("celeste", 500, 0, 0, false)["map"], &"village")
	assert_true(Villagers.where("celeste", 1300, 0, 0, false).is_empty(), "at home at night")
	assert_true(Villagers.where("celeste", 300, 0, 0, false).is_empty(), "at home before dawn")
	assert_eq(Villagers.where("celeste", 700, 6, 0, false)["map"], &"butterfly_garden", "Sunday")
	assert_eq(Villagers.where("benicio", 600, 2, 1, false)["map"], &"clear_lake")
	assert_eq(Villagers.where("benicio", 600, 2, 1, true)["map"], &"cafe", "rain")
	assert_eq(Villagers.where("benicio", 600, 2, 3, false)["map"], &"cafe", "winter")
	assert_eq(Villagers.where("aurora", 600, 2, 0, true)["map"], &"library")


func test_gift_reactions() -> void:
	assert_eq(Villagers.gift_reaction("celeste", &"flower_lavender"), "loved")
	assert_eq(Villagers.gift_reaction("celeste", &"flower_daisy"), "liked", "tag:flower")
	assert_eq(Villagers.gift_reaction("celeste", &"stone"), "disliked")
	assert_eq(Villagers.gift_reaction("celeste", &"seed_daisy"), "neutral")
	assert_eq(Villagers.gift_reaction("bento", &"flower_rose"), "disliked", "explicit dislike beats tag like")
	assert_false(Villagers.can_gift(&"hoe"))


func test_loc_picks_language() -> void:
	var text := {"pt_BR": "Olá", "en": "Hello"}
	TranslationServer.set_locale("en")
	assert_eq(Loc.text(text), "Hello")
	TranslationServer.set_locale("pt_BR")
	assert_eq(Loc.text(text), "Olá")
	assert_eq(Loc.text("plain"), "plain")
