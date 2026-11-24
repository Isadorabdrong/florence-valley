class_name VillagerChat
extends RefCounted
## Decides what a villager says when you talk to them. Pure: returns a
## "conversation" dictionary the dialogue box plays and the controller acts on:
##   {"kind", "pages": Array[String], "choices": Array[String],
##    "delivery": {...}, "offer": quest, "event": id, "reward": items}
## Priority: first meeting > birthday > heart event > delivery > quest offer
## > ordinary line (chosen by hearts, season and weather, stable per day).


static func compose(npc_id: String, rel: Relationships, quests: QuestLog, inventory: Inventory,
		day: int, season: int, day_of_season: int, raining: bool) -> Dictionary:
	var d := Villagers.dialogue(npc_id)
	var hearts := rel.hearts(npc_id)
	if not rel.has_met(npc_id):
		return {"kind": "intro", "pages": [Loc.text(d.get("intro"))]}
	if Villagers.is_birthday(npc_id, season, day_of_season) and not rel.talked_today(npc_id, day):
		return {"kind": "birthday", "pages": [Loc.text(d.get("birthday"))]}
	var event_hearts := int(Villagers.config().get("event_hearts", 4))
	if hearts >= event_hearts and not rel.event_seen(npc_id, "heart_%d" % event_hearts):
		var pages: Array[String] = []
		for p in d.get("event", []):
			pages.append(Loc.text(p))
		return {"kind": "event", "pages": pages, "event": "heart_%d" % event_hearts,
			"reward": Villagers.npc(npc_id).get("event_reward", []) if not d.has("event_reward") else d["event_reward"]}
	var deliveries := quests.deliveries_for(npc_id, inventory)
	if not deliveries.is_empty():
		var delivery: Dictionary = deliveries[0]
		return {"kind": "delivery", "delivery": delivery,
			"pages": [TranslationServer.translate("CHAT_DELIVERY_ASK") % _items_text(delivery["items"])],
			"choices": [TranslationServer.translate("CHAT_GIVE"), TranslationServer.translate("CHAT_NOT_NOW")]}
	var offer := quests.offer_for(npc_id, hearts)
	if not offer.is_empty():
		return {"kind": "offer", "offer": offer["id"], "pages": [Loc.text(d.get("quest_offer"))],
			"choices": [TranslationServer.translate("CHAT_ACCEPT"), TranslationServer.translate("CHAT_NOT_NOW")]}
	var side := QuestLog.side_quest_of(npc_id)
	if not side.is_empty() and quests.is_active(side["id"]) and side["objectives"][0].get("type") == "deliver":
		return {"kind": "line", "pages": [Loc.text(d.get("quest_progress"))]}
	return {"kind": "line", "pages": [_daily_line(npc_id, d, hearts, day, season, raining)]}


static func _daily_line(npc_id: String, d: Dictionary, hearts: int, day: int, season: int, raining: bool) -> String:
	var options: Array = []
	var greet: Dictionary = d.get("greet", {})
	var best_tier := "0"
	for tier: String in greet:
		if hearts >= int(tier) and int(tier) >= int(best_tier):
			best_tier = tier
	options.append_array(greet.get(best_tier, []))
	options.append((d.get("season", {}) as Dictionary).get(str(season)))
	if raining and d.has("rain"):
		options = [d["rain"]]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([npc_id, day])
	return Loc.text(options[rng.randi_range(0, options.size() - 1)])


static func gift_line(npc_id: String, result: Dictionary) -> String:
	var gifts: Dictionary = Villagers.dialogue(npc_id).get("gift", {})
	if result.get("birthday", false) and Villagers.dialogue(npc_id).has("birthday"):
		return Loc.text(gifts.get(result["reaction"])) + "\n" + Loc.text(Villagers.dialogue(npc_id)["birthday"])
	return Loc.text(gifts.get(result.get("reaction", "neutral")))


static func _items_text(items: Array) -> String:
	var parts := PackedStringArray()
	for entry: Array in items:
		parts.append("%d %s" % [int(entry[1]), ItemRegistry.item(StringName(str(entry[0]))).display_name()])
	return ", ".join(parts)
