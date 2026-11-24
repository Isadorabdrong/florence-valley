extends TestCase

var log: QuestLog
var inv: Inventory


func before_each() -> void:
	log = QuestLog.new()
	log.reset()
	inv = Inventory.new(36)


func test_quests_data_valid() -> void:
	var ids := {}
	for q: Dictionary in QuestLog.all_quests():
		assert_false(ids.has(q["id"]), "unique %s" % q["id"])
		ids[q["id"]] = true
		for lang in ["pt_BR", "en"]:
			assert_false(str(q["title"].get(lang, "")).is_empty(), "%s title %s" % [q["id"], lang])
		for o: Dictionary in q["objectives"]:
			if o["type"] == "deliver":
				assert_false(Villagers.npc(str(o["npc"])).is_empty(), "%s npc" % q["id"])
				for entry: Array in o["items"]:
					assert_true(ItemRegistry.has_item(StringName(str(entry[0]))), "%s item %s" % [q["id"], entry[0]])
		var next := str(q.get("next", ""))
		if not next.is_empty():
			assert_false(QuestLog.quest(next).is_empty(), "%s next %s" % [q["id"], next])
	for id in Villagers.ids():
		assert_false(QuestLog.side_quest_of(id).is_empty(), "personal quest for %s" % id)


func test_story_starts_with_the_diary() -> void:
	assert_true(log.is_active("main_diary"))
	var rewards: Array = []
	log.quest_completed.connect(func(id: String, r: Dictionary) -> void: rewards.append(id))
	log.notify("read_diary")
	assert_true(log.is_completed("main_diary"))
	assert_eq(log.diary_pages, [1] as Array[int])
	assert_true(log.is_active("main_first_flowers"), "chain continues")
	assert_eq(rewards, ["main_diary"])


func test_targeted_events_only_count_matches() -> void:
	log.start("main_roses")
	log.notify("harvest", "daisy", 5)
	assert_eq(log.active["main_roses"][0], 0)
	log.notify("harvest", "rose", 7)
	log.notify("harvest", "rose", 7)
	assert_true(log.is_completed("main_roses"), "capped and completed")


func test_delivery_to_villager() -> void:
	log.start("main_celeste")
	assert_true(log.deliveries_for("celeste", inv).is_empty(), "no bouquet yet")
	inv.add_item(&"bouquet_romantic", 1)
	assert_true(log.deliveries_for("livia", inv).is_empty(), "wrong villager")
	var d: Dictionary = log.deliveries_for("celeste", inv)[0]
	var reward := log.deliver(d, inv)
	assert_eq(int(reward["money"]), 200)
	assert_eq(inv.count_of(&"bouquet_romantic"), 0)
	assert_true(log.is_completed("main_celeste"))


func test_personal_quest_needs_hearts() -> void:
	assert_true(log.offer_for("livia", 1).is_empty())
	var q := log.offer_for("livia", 2)
	assert_eq(q["id"], "side_livia_cake")
	log.start(q["id"])
	assert_true(log.offer_for("livia", 5).is_empty(), "already started")


func test_daily_requests() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var made := 0
	for day in 20:
		if not str(log.new_day(day + 1, rng, ["livia", "bento"])["new_request"]).is_empty():
			made += 1
	assert_gt(made, 0)
	assert_lt(log.requests.size(), 4)
	var r: Dictionary = log.requests[0]
	inv.add_item(StringName(str(r["item"])), int(r["count"]))
	var d: Dictionary = log.deliveries_for(str(r["npc"]), inv).filter(func(x: Dictionary) -> bool: return x.has("request"))[0]
	var reward := log.deliver(d, inv)
	assert_eq(int(reward["money"]), int(r["reward"]))
	var summary := log.new_day(999, rng, [])
	assert_eq(log.requests.size(), 0, "old requests expire")
	assert_gt(int(summary["expired"]) + 1, 0)


func test_dict_roundtrip() -> void:
	log.notify("read_diary")
	log.notify("harvest", "daisy", 2)
	var data: Dictionary = JSON.parse_string(JSON.stringify(log.to_dict()))
	var other := QuestLog.new()
	assert_eq(other.load_dict(data), 0)
	assert_eq(other.active["main_first_flowers"][0], 2)
	assert_true(other.is_completed("main_diary"))
	assert_eq(other.diary_pages, [1] as Array[int])
