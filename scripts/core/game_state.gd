extends Node
## Autoload "GameState": the current session — profile and world state.
##
## Owns long-lived data objects (calendar, clock, wallet, inventory, soil,
## chests) so they survive scene changes. Their instances are never replaced
## (only reset/loaded), which keeps every UI connection valid.
## Serialises everything through to_save_data()/apply_save_data(), which
## SaveSystem writes to disk.

signal profile_changed
signal day_started(stats: Dictionary)
signal selected_slot_changed(index: int)
signal tool_state_changed
signal weather_changed(kind: Weather.Kind)
signal game_saved(slot: int)
signal discovery_made(landmark_id: String)
## Quest finished (id "request" for daily requests) and its applied reward.
signal quest_rewarded(quest_id: String, reward: Dictionary)
signal leveled_up(level: int, reward: Dictionary)
signal achievement_earned(definition: Dictionary)

const DEFAULT_PLAYER_NAME := "Flora"
const DEFAULT_FARM_NAME := "Florence"
const HOTBAR_SIZE := 12
const WATERING_CAN_CAPACITY := 20
const FARM_MAP_ID := &"farm"
const FLORIST_MAP_ID := &"florist_shop"
const GREENHOUSE_MAP_ID := &"greenhouse"
const GREENHOUSE_COST := {"money": 1500, "items": [["stone", 30], ["fiber", 20], ["forage_amethyst", 3]]}
const STARTING_MONEY := 500
const CHEST_SIZE := 24

## Items given when a new game starts.
const STARTER_ITEMS: Array = [
	[&"hoe", 1], [&"watering_can", 1], [&"scythe", 1], [&"pickaxe", 1],
	[&"seed_daisy", 12], [&"seed_tulip", 8], [&"seed_rose", 5], [&"seed_lavender", 6],
	[&"seed_lily", 5], [&"seed_sunflower", 5], [&"fertilizer", 10],
]

var player_name: String = ""
var farm_name: String = ""
var outfit_index: int = 0

var calendar := Calendar.new()
var clock := GameClock.new()
var wallet := Wallet.new()
var inventory := Inventory.new()
var farm_soil := SoilGrid.new()
var greenhouse_soil := _make_greenhouse_soil()
var greenhouse_restored := false
## Player builds: {map_id (String): {"x,y": item_id}}
var placed: Dictionary = {}
var florist := FloristShop.new()
var relationships := Relationships.new()
var quests := QuestLog.new()
var progression := Progression.new()
## Wallet increases during reset/load are not "earnings".
var _suspend_money_stats := false
var weather: Weather.Kind = Weather.Kind.SUNNY
## Forces the weather of new days (tests / debugging). -1 = normal rolls.
var weather_override := -1
var world_seed := 0
var watering_can_charges := WATERING_CAN_CAPACITY
var selected_slot := 0
## map id -> Array[Vector2i] of layout objects the player removed (rocks, weeds…)
var removed_objects: Dictionary = {}
## chest id -> Inventory
var chests: Dictionary = {}
var playtime_seconds := 0.0
## Save slot of this session (1..3), 0 = not tied to a slot (no autosave).
var current_slot := 0
## Where the player should appear when a gameplay scene loads (from a save).
var pending_player_position: Variant = null
## Map the player is on, and the named spawn to use when its scene loads.
var current_map: StringName = &"farm"
var pending_spawn := "default"
## Landmark ids the player has discovered / maps visited at least once.
var discoveries: Dictionary = {}
var visited_maps: Dictionary = {}
## "map:x,y" -> day number on which that forage spot was picked.
var forage_picked: Dictionary = {}
## Night summary to show when the next scene loads (woke up after travelling).
var pending_day_stats: Variant = null

var settings: GameSettings

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	InputBindings.register_defaults()
	settings = GameSettings.load_or_default()
	settings.apply()
	DebugCapture.install_if_requested(self)
	_rng.randomize()
	clock.time_changed.connect(_on_clock_tick)
	quests.quest_completed.connect(_on_quest_completed)
	wallet.changed.connect(_on_wallet_changed)
	florist.sale_completed.connect(_on_florist_sale)


func has_profile() -> bool:
	return not player_name.is_empty()


## Starts a fresh profile and world. Returns false (and changes nothing) if invalid.
func start_new_profile(new_player_name: String, new_farm_name: String, new_outfit: int) -> bool:
	if ProfileRules.validate_name(new_player_name) != ProfileRules.NameError.NONE:
		return false
	if ProfileRules.validate_name(new_farm_name) != ProfileRules.NameError.NONE:
		return false
	player_name = ProfileRules.sanitize_name(new_player_name)
	farm_name = ProfileRules.sanitize_name(new_farm_name)
	outfit_index = clampi(new_outfit, 0, OutfitPalette.count() - 1)
	current_slot = 0
	reset_world()
	profile_changed.emit()
	return true


## Used when a gameplay scene is launched directly (editor F6 / debugging).
func ensure_profile() -> void:
	if not has_profile():
		start_new_profile(DEFAULT_PLAYER_NAME, DEFAULT_FARM_NAME, 0)


func reset_world() -> void:
	calendar.reset()
	clock.reset_day()
	inventory.clear()
	farm_soil.clear()
	greenhouse_soil.clear()
	greenhouse_restored = false
	placed.clear()
	removed_objects.clear()
	chests.clear()
	florist.reset()
	relationships.reset()
	progression.reset()
	_suspend_money_stats = true
	wallet.set_amount(STARTING_MONEY)
	_suspend_money_stats = false
	quests.reset()
	watering_can_charges = WATERING_CAN_CAPACITY
	playtime_seconds = 0.0
	pending_player_position = null
	current_map = WorldGraph.start_map()
	pending_spawn = "default"
	discoveries.clear()
	visited_maps.clear()
	forage_picked.clear()
	world_seed = _rng.randi()
	for entry: Array in STARTER_ITEMS:
		inventory.add_item(entry[0], entry[1])
	_set_weather(Weather.Kind.SUNNY)
	select_slot(0)
	tool_state_changed.emit()


# ------------------------------------------------------------- hotbar ---

func select_slot(index: int) -> void:
	selected_slot = posmod(index, HOTBAR_SIZE)
	selected_slot_changed.emit(selected_slot)


func selected_item_id() -> StringName:
	return inventory.item_at(selected_slot)


func selected_item() -> ItemData:
	var id := selected_item_id()
	return ItemRegistry.item(id) if id != &"" else null


# -------------------------------------------------------------- tools ---

func use_watering_can() -> bool:
	if watering_can_charges <= 0:
		return false
	watering_can_charges -= 1
	tool_state_changed.emit()
	return true


func refill_watering_can() -> void:
	watering_can_charges = can_capacity()
	tool_state_changed.emit()


# -------------------------------------------------------------- world ---

func mark_object_removed(map_id: StringName, cell: Vector2i) -> void:
	var cells: Array = removed_objects.get(map_id, [])
	if not cells.has(cell):
		cells.append(cell)
	removed_objects[map_id] = cells


func removed_objects_for(map_id: StringName) -> Array:
	return removed_objects.get(map_id, [])


## Inventory of a chest, created on first access.
func chest(chest_id: String) -> Inventory:
	if not chests.has(chest_id):
		chests[chest_id] = Inventory.new(CHEST_SIZE)
	return chests[chest_id]


## Ends the day: advances calendar and clock, simulates the night, rolls
## the new day's weather (rain waters the crops) and autosaves.
func advance_day() -> Dictionary:
	calendar.advance_day()
	clock.reset_day()
	var stats := farm_soil.advance_day(calendar.season)
	var indoor := greenhouse_soil.advance_day(calendar.season)
	for key in ["grew", "bloomed", "withered"]:
		stats[key] = int(stats[key]) + int(indoor[key])
	var kind: Weather.Kind = weather_override if weather_override >= 0 \
		else Weather.for_day(world_seed, calendar.total_days(), calendar.season)
	_set_weather(kind)
	if Weather.waters_crops(kind):
		farm_soil.water_all()
	var florist_rng := RandomNumberGenerator.new()
	florist_rng.seed = hash([world_seed, calendar.total_days(), "orders"])
	stats["florist"] = florist.end_day(wallet, calendar.total_days(), calendar.weekday(), calendar.season, florist_rng)
	var quest_rng := RandomNumberGenerator.new()
	quest_rng.seed = hash([world_seed, calendar.total_days(), "requests"])
	var met: Array = Villagers.ids().filter(func(id: String) -> bool: return relationships.has_met(id))
	stats["quests"] = quests.new_day(calendar.total_days(), quest_rng, met)
	stats["birthdays"] = Villagers.ids().filter(func(id: String) -> bool:
		return Villagers.is_birthday(id, calendar.season, calendar.day))
	day_started.emit(stats)
	autosave()
	return stats


# -------------------------------------------------------- exploration ---

## Prepares a move to another map; the gameplay scene performs the scene change.
func travel(map_id: StringName, spawn_name: String) -> void:
	if not WorldGraph.has_map(map_id):
		push_error("GameState: unknown map %s" % map_id)
		return
	current_map = map_id
	pending_spawn = spawn_name
	pending_player_position = null


func visit(map_id: StringName) -> bool:
	if visited_maps.has(String(map_id)):
		return false
	visited_maps[String(map_id)] = true
	record("visit", String(map_id))
	return true


func discover(landmark_id: String) -> bool:
	if discoveries.has(landmark_id):
		return false
	discoveries[landmark_id] = true
	discovery_made.emit(landmark_id)
	record("discover", landmark_id)
	return true


## Applies a quest reward: money, items, diary page, friendship ("*" = all).
func _on_quest_completed(quest_id: String, reward: Dictionary) -> void:
	if int(reward.get("money", 0)) > 0:
		wallet.add(int(reward["money"]))
	for entry: Array in reward.get("items", []):
		inventory.add_item(StringName(str(entry[0])), int(entry[1]))
	var friendship: Dictionary = reward.get("friendship", {})
	for npc_id: String in friendship:
		for id in (Villagers.ids() if npc_id == "*" else [npc_id]):
			relationships.add(id, int(friendship[npc_id]))
	quest_rewarded.emit(quest_id, reward)
	_gain_xp(Progression.xp_for("quest"))


# ------------------------------------------------------- progression ---

## The single entry point for gameplay events: advances quests, statistics,
## XP and achievements. Events: harvest, craft, forage, discover, sale,
## order, place, meet, gift, visit, read_diary, restore_florist,
## restore_greenhouse.
func record(event: String, target: String = "", amount: int = 1) -> void:
	quests.notify(event, target, amount)
	var p := progression
	match event:
		"harvest":
			p.add_stat("harvested_total", amount)
			p.add_stat("harvested:" + target, amount)
			var fl := ItemRegistry.flower(StringName(target))
			if fl:
				if fl.rarity == FlowerData.Rarity.RARE:
					p.add_stat("rare_harvested", amount)
				_gain_xp(Progression.xp_for("harvest_per_growth_day") * fl.total_growth_days() * amount)
		"craft":
			p.add_stat("crafted_total", amount)
			_gain_xp(Progression.xp_for("craft"))
		"forage":
			p.add_stat("foraged_total", amount)
			_gain_xp(Progression.xp_for("forage"))
		"discover":
			_gain_xp(Progression.xp_for("discover"))
		"sale":
			p.add_stat("sales_total", amount)
			_gain_xp(Progression.xp_for("sale"))
		"order":
			_gain_xp(Progression.xp_for("order"))
		"place":
			p.add_stat("placed_total", amount)
			_gain_xp(Progression.xp_for("place"))
		"restore_greenhouse":
			p.add_stat("greenhouse_restored")
		"restore_florist":
			p.add_stat("florist_restored")
	check_achievements()


## A statistic for achievements: counters plus values computed from state.
func stat_value(key: String) -> int:
	match key:
		"species_harvested":
			return progression.count_prefix("harvested:")
		"recipes_known":
			return florist.known_recipes.size()
		"florist_stars":
			return florist.stars()
		"max_hearts":
			var best := 0
			for id in Villagers.ids():
				best = maxi(best, relationships.hearts(id))
			return best
		"met_count":
			return relationships.met_count()
		"maps_visited":
			return WorldGraph.map_ids().filter(func(id: StringName) -> bool:
				return WorldGraph.is_outdoor(id) and visited_maps.has(String(id))).size()
		"landmarks":
			return discoveries.size()
		"diary_pages":
			return quests.diary_pages.size()
		"level":
			return progression.level
	return progression.stat(key)


func check_achievements() -> void:
	for a in progression.check_achievements(stat_value, today()):
		var money := int((a.get("reward", {}) as Dictionary).get("money", 0))
		if money > 0:
			wallet.add(money)
		achievement_earned.emit(a)


func _gain_xp(amount: int) -> void:
	for lv in progression.add_xp(amount):
		var reward := Progression.level_reward(lv)
		if int(reward.get("money", 0)) > 0:
			wallet.add(int(reward["money"]))
		for entry: Array in reward.get("items", []):
			inventory.add_item(StringName(str(entry[0])), int(entry[1]))
		leveled_up.emit(lv, reward)


func _on_wallet_changed(_amount: int, delta: int) -> void:
	if delta > 0 and not _suspend_money_stats:
		progression.add_stat("money_earned", delta)


func _on_florist_sale(sale: Dictionary) -> void:
	record("sale", String(sale.get("item", "")))


## The day number used for daily talk/gift limits.
func today() -> int:
	return calendar.total_days()


func is_raining() -> bool:
	return Weather.waters_crops(weather)


static func _forage_key(map_id: StringName, cell: Vector2i) -> String:
	return "%s:%d,%d" % [map_id, cell.x, cell.y]


## Item lying on a forage spot today ("" if none or already picked).
func forage_item_at(map_id: StringName, cell: Vector2i) -> StringName:
	if int(forage_picked.get(_forage_key(map_id, cell), -1)) == calendar.total_days():
		return &""
	return WorldGraph.roll_forage(map_id, cell, calendar.total_days(), calendar.season, world_seed)


func pick_forage(map_id: StringName, cell: Vector2i) -> StringName:
	var id := forage_item_at(map_id, cell)
	if id != &"":
		forage_picked[_forage_key(map_id, cell)] = calendar.total_days()
	return id


## The flower shop sells on every clock tick, wherever the player is.
## Customers wait at the counter only while the player is inside.
func _on_clock_tick(minutes: int) -> void:
	if not florist.restored:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, calendar.total_days(), minutes])
	florist.tick(minutes, calendar.weekday(), int(weather), int(calendar.season),
		current_map == FLORIST_MAP_ID, wallet, rng)


func _set_weather(kind: Weather.Kind) -> void:
	weather = kind
	weather_changed.emit(kind)


func rng() -> RandomNumberGenerator:
	return _rng


# ------------------------------------------------------------ builds ---

## The build registry of a map (created on demand).
func placed_on(map_id: StringName) -> Dictionary:
	if not placed.has(String(map_id)):
		placed[String(map_id)] = {}
	return placed[String(map_id)]


## Registers a build and takes it from the inventory.
func place_build(map_id: StringName, item_id: StringName, cell: Vector2i) -> bool:
	if not inventory.remove_item(item_id, 1):
		return false
	placed_on(map_id)[Placement.key(cell)] = String(item_id)
	record("place", String(item_id))
	return true


## Removes the build covering `cell` and gives it back. Returns
## {"origin", "item"} or {} if nothing (or no room in the inventory).
func pick_up_build(map_id: StringName, cell: Vector2i) -> Dictionary:
	var registry := placed_on(map_id)
	var found := Placement.find_at(registry, cell)
	if found.is_empty() or not inventory.can_add(found["item"], 1):
		return {}
	registry.erase(Placement.key(found["origin"]))
	inventory.add_item(found["item"], 1)
	return found


## Watering can capacity of the best can the player owns.
func can_capacity() -> int:
	var best := WATERING_CAN_CAPACITY
	for id: StringName in [&"watering_can_copper"]:
		if inventory.count_of(id) > 0:
			best = maxi(best, ItemRegistry.item(id).capacity)
	return best


# --------------------------------------------------------- greenhouse ---

static func _make_greenhouse_soil() -> SoilGrid:
	var soil := SoilGrid.new()
	soil.all_seasons = true
	return soil


## The soil of a map (farm or greenhouse), or null where nothing grows.
func soil_for(map_id: StringName) -> SoilGrid:
	match map_id:
		FARM_MAP_ID:
			return farm_soil
		GREENHOUSE_MAP_ID:
			return greenhouse_soil
	return null


func can_restore_greenhouse() -> bool:
	if not wallet.can_afford(int(GREENHOUSE_COST["money"])):
		return false
	for entry: Array in GREENHOUSE_COST["items"]:
		if inventory.count_of(StringName(entry[0])) < int(entry[1]):
			return false
	return true


func restore_greenhouse() -> bool:
	if greenhouse_restored or not can_restore_greenhouse():
		return false
	wallet.spend(int(GREENHOUSE_COST["money"]))
	for entry: Array in GREENHOUSE_COST["items"]:
		inventory.remove_item(StringName(entry[0]), int(entry[1]))
	greenhouse_restored = true
	record("restore_greenhouse")
	return true


# --------------------------------------------------------------- save ---

func autosave() -> bool:
	if current_slot <= 0:
		return false
	return save_game(current_slot) == OK


## Saves to a slot (defaults to the session slot). The player's position is
## taken from the current gameplay scene, if any.
func save_game(slot: int = current_slot) -> Error:
	if not SaveSystem.is_valid_slot(slot):
		return ERR_INVALID_PARAMETER
	current_slot = slot
	var err := SaveSystem.save(slot, to_save_data(), save_summary())
	if err == OK:
		game_saved.emit(slot)
	else:
		push_error("GameState: save to slot %d failed (%s)" % [slot, error_string(err)])
	return err


## Loads a slot into the session. Returns the SaveSystem result dictionary
## plus "issues" (PackedStringArray of corrected/discarded data).
func load_game(slot: int) -> Dictionary:
	var result := SaveSystem.load_slot(slot)
	if result["error"] != SaveSystem.LoadError.NONE:
		return result
	var issues := apply_save_data(result["data"])
	result["issues"] = issues
	if issues.has("profile"):
		result["error"] = SaveSystem.LoadError.INVALID
		return result
	current_slot = slot
	return result


func save_summary() -> Dictionary:
	return {
		"player": player_name, "farm": farm_name, "day": calendar.day,
		"season": int(calendar.season), "year": calendar.year, "money": wallet.amount,
		"playtime": int(playtime_seconds),
	}


func to_save_data() -> Dictionary:
	var chest_data := {}
	for id: String in chests:
		chest_data[id] = (chests[id] as Inventory).to_dict()
	var removed := {}
	for map_id: StringName in removed_objects:
		var cells: Array = []
		for c: Vector2i in removed_objects[map_id]:
			cells.append([c.x, c.y])
		removed[String(map_id)] = cells
	var player_pos: Variant = _current_player_position()
	return {
		"profile": {"name": player_name, "farm": farm_name, "outfit": outfit_index},
		"world": {
			"seed": world_seed, "map": String(current_map),
			"player": [player_pos.x, player_pos.y] if player_pos != null else null,
			"weather": int(weather), "removed_objects": removed,
		},
		"calendar": calendar.to_dict(),
		"clock": clock.to_dict(),
		"money": wallet.amount,
		"inventory": inventory.to_dict(),
		"hotbar_selected": selected_slot,
		"chests": chest_data,
		"farm_soil": farm_soil.to_dict(),
		"greenhouse": {"restored": greenhouse_restored, "soil": greenhouse_soil.to_dict()},
		"placed": placed.duplicate(true),
		"tools": {"watering_can": watering_can_charges},
		"stats": {"playtime": playtime_seconds},
		"florist": florist.to_dict(),
		"relationships": relationships.to_dict(),
		"quests": quests.to_dict(),
		"progression": progression.to_dict(),
		"exploration": {"discoveries": discoveries.keys(), "visited": visited_maps.keys(),
			"forage_picked": forage_picked.duplicate()},
	}


## Applies saved data. Invalid parts are corrected or dropped and listed in
## the returned issues ("profile" means the save is unusable).
func apply_save_data(data: Dictionary) -> PackedStringArray:
	var issues := PackedStringArray()
	var profile: Dictionary = data.get("profile", {}) if typeof(data.get("profile")) == TYPE_DICTIONARY else {}
	var name := str(profile.get("name", ""))
	var farm := str(profile.get("farm", ""))
	if ProfileRules.validate_name(name) != ProfileRules.NameError.NONE \
			or ProfileRules.validate_name(farm) != ProfileRules.NameError.NONE:
		issues.append("profile")
		return issues
	player_name = ProfileRules.sanitize_name(name)
	farm_name = ProfileRules.sanitize_name(farm)
	outfit_index = clampi(int(profile.get("outfit", 0)), 0, OutfitPalette.count() - 1)

	var world: Dictionary = _dict(data, "world")
	world_seed = int(world.get("seed", 0))
	if not calendar.load_dict(_dict(data, "calendar")):
		issues.append("calendar")
	if not clock.load_dict(_dict(data, "clock")):
		issues.append("clock")
	var money := int(data.get("money", STARTING_MONEY))
	if money < 0:
		issues.append("money")
	_suspend_money_stats = true
	wallet.set_amount(money)
	_suspend_money_stats = false
	if inventory.load_dict(_dict(data, "inventory")) > 0:
		issues.append("inventory")
	chests.clear()
	var chest_data := _dict(data, "chests")
	for id in chest_data:
		var inv := chest(str(id))
		if typeof(chest_data[id]) != TYPE_DICTIONARY or inv.load_dict(chest_data[id]) > 0:
			issues.append("chests")
	if farm_soil.load_dict(_dict(data, "farm_soil")) > 0:
		issues.append("farm_soil")
	var gh := _dict(data, "greenhouse")
	greenhouse_restored = bool(gh.get("restored", false))
	placed.clear()
	var saved_builds := _dict(data, "placed")
	for map_id in saved_builds:
		var entries: Variant = saved_builds[map_id]
		if typeof(entries) != TYPE_DICTIONARY:
			issues.append("placed")
			continue
		for k in entries:
			var item := ItemRegistry.item(StringName(str(entries[k])))
			if item == null or not item.is_placeable() or not WorldGraph.has_map(StringName(str(map_id))):
				issues.append("placed")
				continue
			placed_on(StringName(str(map_id)))[str(k)] = str(entries[k])
	if greenhouse_soil.load_dict(_dict(gh, "soil")) > 0:
		issues.append("greenhouse")
	if florist.load_dict(_dict(data, "florist")) > 0:
		issues.append("florist")
	if relationships.load_dict(_dict(data, "relationships")) > 0:
		issues.append("relationships")
	if quests.load_dict(_dict(data, "quests")) > 0:
		issues.append("quests")
	if progression.load_dict(_dict(data, "progression")) > 0:
		issues.append("progression")
	removed_objects.clear()
	var removed := _dict(world, "removed_objects")
	for map_id in removed:
		for c in removed[map_id]:
			if typeof(c) == TYPE_ARRAY and (c as Array).size() == 2:
				mark_object_removed(StringName(str(map_id)), Vector2i(int(c[0]), int(c[1])))
	watering_can_charges = clampi(int(_dict(data, "tools").get("watering_can", WATERING_CAN_CAPACITY)), 0,
		can_capacity())
	playtime_seconds = maxf(float(_dict(data, "stats").get("playtime", 0.0)), 0.0)
	var w := int(world.get("weather", 0))
	_set_weather(clampi(w, 0, Weather.Kind.size() - 1) as Weather.Kind)
	var map_id := StringName(str(world.get("map", WorldGraph.start_map())))
	var p: Variant = world.get("player")
	if WorldGraph.has_map(map_id):
		current_map = map_id
		pending_player_position = Vector2(float(p[0]), float(p[1])) \
			if typeof(p) == TYPE_ARRAY and (p as Array).size() == 2 else null
	else:
		issues.append("map")
		current_map = WorldGraph.start_map()
		pending_player_position = null
	pending_spawn = "default"
	var exploration := _dict(data, "exploration")
	discoveries.clear()
	for id in exploration.get("discoveries", []):
		discoveries[str(id)] = true
	visited_maps.clear()
	for id in exploration.get("visited", []):
		visited_maps[str(id)] = true
	forage_picked.clear()
	var picked: Variant = exploration.get("forage_picked", {})
	if typeof(picked) == TYPE_DICTIONARY:
		for key in picked:
			forage_picked[str(key)] = int(picked[key])
	select_slot(int(data.get("hotbar_selected", 0)))
	tool_state_changed.emit()
	profile_changed.emit()
	return issues


## Gameplay scenes join this group and expose a `player` property.
const GAMEPLAY_GROUP := &"gameplay_scene"
## Scene used for every map (the map to show comes from current_map).
const MAP_SCENE := "res://scenes/world/map_scene.tscn"


func _current_player_position() -> Variant:
	if is_inside_tree():
		for scene in get_tree().get_nodes_in_group(GAMEPLAY_GROUP):
			var p: Variant = scene.get(&"player")
			if p is Player and is_instance_valid(p):
				return (p as Player).position
	return pending_player_position


static func _dict(data: Dictionary, key: String) -> Dictionary:
	var v: Variant = data.get(key, {})
	return v if typeof(v) == TYPE_DICTIONARY else {}


func save_settings() -> void:
	settings.apply()
	settings.save()
