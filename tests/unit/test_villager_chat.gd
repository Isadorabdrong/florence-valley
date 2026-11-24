extends TestCase

var rel: Relationships
var log: QuestLog
var inv: Inventory


func before_each() -> void:
	rel = Relationships.new()
	log = QuestLog.new()
	log.reset()
	inv = Inventory.new(36)


func _chat(id: String, day: int = 10, season: int = 1, dos: int = 20, rain: bool = false) -> Dictionary:
	return VillagerChat.compose(id, rel, log, inv, day, season, dos, rain)


func test_first_meeting_is_intro() -> void:
	assert_eq(_chat("tomas")["kind"], "intro")
	rel.talk("tomas", 1)
	assert_eq(_chat("tomas")["kind"], "line")


func test_birthday_line() -> void:
	rel.talk("celeste", 1)
	assert_eq(_chat("celeste", 10, 0, 14)["kind"], "birthday")


func test_heart_event_once() -> void:
	rel.talk("bento", 1)
	rel.add("bento", 400)
	var c := _chat("bento")
	assert_eq(c["kind"], "event")
	assert_gt((c["pages"] as Array).size(), 1)
	assert_false((c["reward"] as Array).is_empty())
	rel.mark_event("bento", c["event"])
	assert_ne(_chat("bento")["kind"], "event")


func test_quest_offer_and_delivery() -> void:
	rel.talk("livia", 1)
	rel.add("livia", 200)
	var offer := _chat("livia")
	assert_eq(offer["kind"], "offer")
	assert_eq((offer["choices"] as Array).size(), 2)
	log.start(offer["offer"])
	assert_eq(_chat("livia")["kind"], "line", "progress line while waiting")
	inv.add_item(&"flower_rose", 3)
	assert_eq(_chat("livia")["kind"], "delivery")


func test_daily_line_stable_and_rain_aware() -> void:
	rel.talk("aurora", 1)
	assert_eq(_chat("aurora", 10)["pages"], _chat("aurora", 10)["pages"], "same line all day")
	var rain_line := Loc.text(Villagers.dialogue("aurora")["rain"])
	assert_eq(_chat("aurora", 11, 1, 20, true)["pages"][0], rain_line)
