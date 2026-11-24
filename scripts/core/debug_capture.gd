class_name DebugCapture
extends Node
## Debug-only command-line helpers. They do nothing in normal play.
##   -- --capture=<absolute path.png> [--capture-frames=N]
##        saves a screenshot after N frames and quits (README screenshots,
##        visual regression checks)
##   -- --demo=farming
##        pre-fills flower beds next to the house with every species at every
##        growth stage (used for screenshots of the farming system)
##   -- --demo-weather=<0-5> --demo-season=<0-3> --demo-time=<minutes> --demo-ui=shop|chest|inventory
##        forces weather / time of day / an open panel on the farm

const DEMO_FARMING := "--demo=farming"

var _path := ""
var _frames_left := 90


static func install_if_requested(host: Node) -> void:
	var path := ""
	var frames := 90
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-frames="):
			frames = maxi(1, arg.trim_prefix("--capture-frames=").to_int())
	if path.is_empty():
		return
	var node := DebugCapture.new()
	node._path = path
	node._frames_left = frames
	node.process_mode = Node.PROCESS_MODE_ALWAYS
	host.add_child.call_deferred(node)


static func demo_requested(name: String) -> bool:
	return OS.get_cmdline_user_args().has(name)


static func demo_value(prefix: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(prefix + "="):
			return arg.trim_prefix(prefix + "=")
	return ""


## Applies --demo-weather / --demo-time / --demo-ui on the farm scene.
static func apply_environment_demo(farm: Node) -> void:
	var tour := demo_value("--tour")
	if not tour.is_empty():
		farm.add_child(DemoTour.new(tour, demo_value("--tour-timelapse").to_float()))
	if demo_requested("--demo=florist"):
		_florist_demo()
	if demo_requested("--demo=builds"):
		_builds_demo(farm)
	var w := demo_value("--demo-weather")
	if not w.is_empty():
		GameState._set_weather(clampi(w.to_int(), 0, Weather.Kind.size() - 1) as Weather.Kind)
	var season := demo_value("--demo-season")
	if not season.is_empty() and farm.has_method(&"apply_season_now"):
		var cal := GameState.calendar
		cal.season = clampi(season.to_int(), 0, 3) as Calendar.Season
		farm.call(&"apply_season_now")
		cal.day_changed.emit(cal.day, cal.season, cal.year) # refresh the HUD date
	var m := demo_value("--demo-time")
	if not m.is_empty():
		GameState.clock.set_minutes(m.to_int())
	var hud: FarmHUD = farm.get("hud")
	match demo_value("--demo-ui"):
		"shop":
			hud.open_shop(&"flora_cart")
		"chest":
			var chest := GameState.chest("farm:35,12")
			chest.add_item(&"stone", 14)
			chest.add_item(&"flower_rose", 6)
			GameState.inventory.add_item(&"flower_lily", 3)
			hud.open_chest("farm:35,12")
		"inventory":
			hud.open_inventory()
		"florist":
			hud.open_florist(FloristPanel.Tab.DISPLAYS)
		"progress":
			for f in ["daisy", "tulip", "rose", "lavender", "lily", "sunflower"]:
				GameState.record("harvest", f, 3)
			GameState.record("craft", "bouquet_simple")
			hud.open_journal(JournalPanel.Tab.PROGRESS)
		"workshop":
			GameState._gain_xp(500)
			hud.open_shop(&"workshop")
		"dialogue":
			var director: NpcDirector = farm.get("npc_director")
			var first := director.villagers()[0] if not director.villagers().is_empty() else null
			if first:
				hud.show_dialogue(first.npc_id, [Loc.text(Villagers.dialogue(first.npc_id)["intro"])])
		"journal", "diary":
			GameState.record("read_diary")
			GameState.record("harvest", "daisy", 5)
			for id in ["celeste", "livia", "tomas", "benicio"]:
				GameState.relationships.talk(id, 1)
				GameState.record("meet", id)
			GameState.relationships.add("celeste", 260)
			GameState.relationships.add("livia", 140)
			GameState.relationships.gift("celeste", &"flower_lavender", 2, 0, 2)
			hud.open_journal(JournalPanel.Tab.DIARY if demo_value("--demo-ui") == "diary" else JournalPanel.Tab.VILLAGERS)
		"orders":
			hud.open_florist(FloristPanel.Tab.ORDERS)
		"workbench":
			for id in [&"flower_rose", &"flower_tulip", &"flower_lily", &"flower_lavender", &"forage_violet"]:
				GameState.inventory.add_item(id, 3)
			GameState.florist.known_recipes["bouquet_simple"] = true
			GameState.florist.known_recipes["bouquet_daisy"] = true
			hud.open_workbench()
			var panel := hud.workbench_panel()
			panel.pick(&"flower_rose")
			panel.pick(&"flower_rose")
			panel.pick(&"flower_tulip")
		"map":
			for id in [&"farm", &"village", &"cherry_forest", &"clear_lake", &"butterfly_garden"]:
				GameState.visit(id)
			GameState.discover("grandma_bench")
			GameState.discover("sundial")
			hud.open_map(farm.get("map_id"))


## Plants every species in a row, one growth stage per column, beside the
## spawn point. Called by the farm scene when --demo=farming is passed.
static func apply_farming_demo(map: WorldMap) -> void:
	var soil := GameState.farm_soil
	var origin := map.layout.spawn_cell + Vector2i(3, 3)
	var flowers := ItemRegistry.all_flowers()
	for row in flowers.size():
		for stage in FlowerData.STAGE_BLOOM + 1:
			var cell := origin + Vector2i(stage, row)
			if map.get_object_at(cell) != null or map.layout.terrain_at(cell) == "water":
				continue
			soil.till(cell)
			if stage % 2 == 0:
				soil.water(cell)
			if row == 2:
				soil.fertilize(cell)
			soil.plant(cell, flowers[row].id, GameState.calendar.season)
			soil.debug_set_stage(cell, stage)


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	set_process(false)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(_path)
	print("[capture] saved %s (error %d)" % [_path, err])
	get_tree().quit()


## A restored, decorated and stocked shop with customers, for screenshots.
static func _florist_demo() -> void:
	var shop := GameState.florist
	shop.restored = true
	shop.reputation = 480
	for id in ["display_2", "display_3", "sign", "diffuser"]:
		shop.upgrades[id] = true
	for id in ["deco_vase", "deco_garland", "deco_chandelier", "deco_fountain"]:
		shop.decorations[id] = true
	shop.call("_ensure_slots")
	var stock := [&"bouquet_romantic", &"flower_rose", &"bouquet_spring", &"flower_tulip", &"bouquet_daisy", &"flower_lily"]
	for i in stock.size():
		GameState.inventory.add_item(stock[i], 6)
		shop.stock_slot(i, stock[i], 6, GameState.inventory)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	shop.generate_orders(1, 0, 0, rng)
	shop.generate_orders(2, 0, 0, rng)
	shop.is_open = true
	GameState.clock.set_minutes(600)
	for i in 400:
		shop.tick(600, 5, 0, 0, true, GameState.wallet, rng)
		if shop.pending.size() >= 2:
			break


## Builds and a restored greenhouse near the farm's east side (screenshots).
static func _builds_demo(scene: Node) -> void:
	GameState.greenhouse_restored = true
	var map: WorldMap = scene.get("map")
	var view: BuildView = scene.get("build_view")
	var builds := [[&"build_path", Vector2i(46, 16)], [&"build_path", Vector2i(47, 16)], [&"build_path", Vector2i(48, 16)],
		[&"build_path", Vector2i(49, 16)], [&"build_path", Vector2i(50, 16)], [&"build_path", Vector2i(51, 16)],
		[&"build_path", Vector2i(52, 16)], [&"build_bench", Vector2i(50, 15)], [&"build_lamp", Vector2i(47, 15)],
		[&"build_lamp", Vector2i(53, 15)], [&"build_raised_bed", Vector2i(51, 13)], [&"build_raised_bed", Vector2i(52, 13)],
		[&"build_pond", Vector2i(54, 15)], [&"build_cherry_tree", Vector2i(48, 13)], [&"build_vase", Vector2i(46, 15)],
		[&"build_fence", Vector2i(46, 13)], [&"build_fence", Vector2i(46, 14)]]
	if view == null or map.map_id != GameState.FARM_MAP_ID:
		return
	for b: Array in builds:
		GameState.placed_on(map.map_id)[Placement.key(b[1])] = String(b[0])
		view.add(b[1], b[0])
	var gh := map.get_object_at(Vector2i(45, 11)) as GreenhouseBuilding
	if gh:
		gh.refresh()
	GameState.inventory.add_item(&"build_lamp", 3)
	var player: Player = scene.get("player")
	player.position = map.cell_anchor(Vector2i(49, 18)) + Vector2(0, -1)
	player.face(Vector2.UP)
	GameState.select_slot(GameState.inventory.first_slot_of(&"build_lamp"))


## Special flowers growing in the greenhouse beds (screenshots).
static func apply_greenhouse_demo() -> void:
	var soil := GameState.greenhouse_soil
	var flowers := [&"orchid", &"blue_orchid", &"celestial_lily", &"peony", &"iris"]
	var x_starts := [2, 7, 12]
	var i := 0
	for x0 in x_starts:
		for y in range(3, 8):
			for x in range(x0, x0 + (2 if x0 == 12 else 4)):
				var cell := Vector2i(x, y)
				soil.till(cell)
				soil.water(cell)
				soil.plant(cell, flowers[i % flowers.size()], 3)
				soil.debug_set_stage(cell, 3 + (i % 3))
				i += 1
