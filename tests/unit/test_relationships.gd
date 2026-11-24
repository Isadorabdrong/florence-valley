extends TestCase

var rel: Relationships


func before_each() -> void:
	rel = Relationships.new()


func test_talk_once_per_day() -> void:
	var r := rel.talk("livia", 5)
	assert_true(r["first_meeting"])
	assert_eq(r["gained"], 20)
	assert_eq(rel.talk("livia", 5)["gained"], 0, "same day")
	assert_false(rel.talk("livia", 6)["first_meeting"])
	assert_eq(rel.points("livia"), 40)


func test_gifts_once_per_day_with_reactions() -> void:
	var r := rel.gift("celeste", &"flower_lavender", 3, 1, 10)
	assert_true(r["ok"])
	assert_eq(r["reaction"], "loved")
	assert_eq(rel.points("celeste"), 80)
	assert_false(rel.gift("celeste", &"flower_daisy", 3, 1, 10)["ok"], "one gift a day")
	var bad := rel.gift("celeste", &"stone", 4, 1, 10)
	assert_eq(bad["gained"], -20)
	assert_eq(rel.points("celeste"), 60)
	assert_eq(rel.known_tastes("celeste")["stone"], "disliked")


func test_birthday_triples_gift() -> void:
	var r := rel.gift("celeste", &"flower_lavender", 1, 0, 14)
	assert_true(r["birthday"])
	assert_eq(r["gained"], 240)
	assert_eq(rel.hearts("celeste"), 2)


func test_points_clamped() -> void:
	rel.add("bento", 5000)
	assert_eq(rel.points("bento"), 1000)
	assert_eq(rel.hearts("bento"), 10)
	rel.add("bento", -9999)
	assert_eq(rel.points("bento"), 0)


func test_dict_roundtrip() -> void:
	rel.talk("tomas", 2)
	rel.gift("tomas", &"forage_glow_moss", 2, 0, 2)
	rel.mark_event("tomas", "heart_4")
	var data: Dictionary = JSON.parse_string(JSON.stringify(rel.to_dict()))
	var other := Relationships.new()
	assert_eq(other.load_dict(data), 0)
	assert_eq(other.points("tomas"), rel.points("tomas"))
	assert_true(other.event_seen("tomas", "heart_4"))
	assert_true(other.has_met("tomas"))
	data["ghost"] = {"points": 5}
	assert_eq(other.load_dict(data), 1)
