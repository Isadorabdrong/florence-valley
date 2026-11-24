class_name GameplayScene
extends Node2D
## Plays any map of the world registry (WorldGraph): builds the layout,
## places the player at a named spawn (or a saved position), wires the
## controller/HUD, creates edge exits, runs the clock and applies light,
## weather, season and ambience. The farm additionally shows its soil.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const SPARKLE := preload("res://assets/effects/sparkle.png")
const VIEW_SIZE := Vector2(640, 360)
const WARP_GRACE := 0.5

## Fixed map for this scene file (farm.tscn); empty = GameState.current_map.
@export var default_map_id: StringName = &""

## Tests turn this off: travelling then only updates GameState.
var _protected_cache: Dictionary = {}
var allow_scene_changes := true
var map_id: StringName
var player: Player
var _warp_grace := WARP_GRACE
var _traveling := false
var _fireflies: CPUParticles2D
var florist_view: FloristView
var npc_director: NpcDirector
var build_view: BuildView

@onready var map: WorldMap = $Map
@onready var soil_view: SoilView = $SoilView
@onready var controller: FarmController = $FarmController
@onready var hud: FarmHUD = $HUD
@onready var daylight: CanvasModulate = $DayLight
@onready var weather_view: WeatherView = $WeatherView
@onready var petals: CanvasLayer = $PetalAmbience
@onready var pause_menu: Node = $PauseMenu


func _ready() -> void:
	add_to_group(GameState.GAMEPLAY_GROUP)
	GameState.ensure_profile()
	if default_map_id != &"":
		if GameState.current_map != default_map_id:
			GameState.travel(default_map_id, GameState.pending_spawn)
	else:
		var demo_map := StringName(DebugCapture.demo_value("--demo-map"))
		if demo_map != &"" and WorldGraph.has_map(demo_map) and not GameState.visited_maps.has(String(demo_map)):
			GameState.travel(demo_map, "default")
	map_id = GameState.current_map if WorldGraph.has_map(GameState.current_map) else WorldGraph.start_map()
	var def := WorldGraph.map_def(map_id)
	map.map_id = map_id
	map.layout_path = str(def.get("layout", ""))
	map.build()
	for cell: Vector2i in GameState.removed_objects_for(map_id):
		map.remove_object_at(cell)
	build_view = BuildView.new()
	build_view.name = "BuildView"
	add_child(build_view)
	build_view.setup(map, GameState.placed_on(map_id))

	player = PLAYER_SCENE.instantiate() as Player
	var start := _start_transform()
	player.position = start["position"]
	map.entities.add_child(player)
	player.face(start["facing"])
	player.stepped.connect(_on_player_step)
	player.set_camera_limits(_camera_rect())

	var soil := GameState.soil_for(map_id)
	if soil:
		var water := {}
		for cell in map.cells_with_terrain(TerrainAtlas.WATER):
			water[cell] = true
		for cell in build_view.water_cells():
			water[cell] = true
		soil.water_cells = water
		if map_id == GameState.FARM_MAP_ID and DebugCapture.demo_requested(DebugCapture.DEMO_FARMING):
			DebugCapture.apply_farming_demo(map)
		if map_id == GameState.GREENHOUSE_MAP_ID and DebugCapture.demo_requested("--demo=greenhouse"):
			DebugCapture.apply_greenhouse_demo()
		soil_view.setup(soil, map.soil_layer, map.soil_decor_layer, map.entities)
	npc_director = NpcDirector.new()
	npc_director.name = "NpcDirector"
	add_child(npc_director)
	npc_director.setup(map)
	controller.setup(self, player, map, hud)
	hud.modal_changed.connect(_on_modal_changed)
	_setup_forage()
	_setup_exits()
	_setup_ambience(str(def.get("ambience", "")))
	if map_id == GameState.FLORIST_MAP_ID:
		florist_view = FloristView.new()
		florist_view.name = "FloristView"
		add_child(florist_view)
		florist_view.setup(map, GameState.florist)

	GameState.clock.time_changed.connect(_on_time_changed)
	GameState.clock.late_night.connect(_on_late_night)
	GameState.clock.passed_out.connect(controller.pass_out)
	GameState.weather_changed.connect(_on_weather_changed)
	GameState.day_started.connect(_on_day_started)
	_apply_environment()
	DebugCapture.apply_environment_demo(self)
	var first_visit := GameState.visit(map_id)
	_show_banner(first_visit)


## The farm itself (the greenhouse also allows farming but isn't "the farm").
func is_farm() -> bool:
	return map_id == GameState.FARM_MAP_ID


func is_outdoor() -> bool:
	return WorldGraph.is_outdoor(map_id)


func _process(delta: float) -> void:
	_warp_grace = maxf(_warp_grace - delta, 0.0)
	if get_tree().paused or hud.is_modal_open() or controller.is_busy():
		return
	GameState.clock.advance(delta)
	GameState.playtime_seconds += delta


## Moves to another map. In tests (allow_scene_changes = false) only the
## GameState side happens.
func travel_to(target: StringName, spawn_name: String) -> void:
	if _traveling:
		return
	_traveling = true
	GameState.travel(target, spawn_name)
	if allow_scene_changes:
		SceneManager.change_scene(GameState.MAP_SCENE)


# ------------------------------------------------------------------ setup ---

func _start_transform() -> Dictionary:
	var pending: Variant = GameState.pending_player_position
	GameState.pending_player_position = null
	if pending is Vector2 and map.get_world_rect().grow(-8).has_point(pending):
		return {"position": pending, "facing": Vector2.DOWN}
	var s := WorldGraph.spawn(map_id, GameState.pending_spawn)
	GameState.pending_spawn = "default"
	if s.is_empty():
		return {"position": map.spawn_position, "facing": Vector2.DOWN}
	return {"position": map.cell_anchor(s["cell"]) + Vector2(0, -2), "facing": s["facing"]}


## Cells that builds must keep free: exits and arrival points.
## Computed once per map (the ghost preview asks every frame); read-only.
func protected_cells() -> Dictionary:
	if _protected_cache.is_empty():
		_protected_cache = _compute_protected_cells()
	return _protected_cache


func _compute_protected_cells() -> Dictionary:
	var out := {}
	for e in WorldGraph.exits(map_id):
		for c: Vector2i in e["cells"]:
			out[c] = true
			for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				out[c + d] = true
	var spawns: Dictionary = (WorldGraph.data().get("spawns", {}) as Dictionary).get(String(map_id), {})
	for sp: String in spawns:
		out[WorldGraph.spawn(map_id, sp)["cell"]] = true
	return out


## Small interiors are centred on screen (the rest stays dark).
func _camera_rect() -> Rect2:
	var rect := map.get_world_rect()
	var grow := (VIEW_SIZE - rect.size).max(Vector2.ZERO) / 2.0
	return Rect2(rect.position - grow, rect.size + grow * 2.0)


func _setup_forage() -> void:
	for node in get_tree().get_nodes_in_group(&"forage_spot"):
		if not map.is_ancestor_of(node):
			continue
		var spot := node as ForageSpot
		spot.set_item(GameState.forage_item_at(map_id, map.world_to_cell(spot.position + Vector2(0, -1))))


func refresh_forage() -> void:
	_setup_forage()


func _setup_exits() -> void:
	for e in WorldGraph.exits(map_id):
		var area := Area2D.new()
		area.name = "Exit_%s" % e["to"]
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitorable = false
		for cell: Vector2i in e["cells"]:
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(WorldMap.TILE_SIZE, WorldMap.TILE_SIZE)
			shape.shape = rect
			shape.position = map.cell_center(cell)
			area.add_child(shape)
		area.body_entered.connect(_on_exit_entered.bind(e["to"], e["spawn"]))
		map.add_child(area)


func _on_exit_entered(body: Node2D, target: StringName, spawn_name: String) -> void:
	if body != player or _warp_grace > 0.0 or controller.is_busy():
		return
	travel_to(target, spawn_name)


func _setup_ambience(kind: String) -> void:
	if kind != "fireflies":
		return
	_fireflies = CPUParticles2D.new()
	var rect := map.get_world_rect()
	_fireflies.position = rect.get_center()
	_fireflies.texture = SPARKLE
	_fireflies.amount = 45
	_fireflies.lifetime = 5.0
	_fireflies.preprocess = 5.0
	_fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_fireflies.emission_rect_extents = rect.size / 2.0
	_fireflies.gravity = Vector2.ZERO
	_fireflies.direction = Vector2.UP
	_fireflies.spread = 180.0
	_fireflies.initial_velocity_min = 3.0
	_fireflies.initial_velocity_max = 10.0
	_fireflies.tangential_accel_min = -6.0
	_fireflies.tangential_accel_max = 6.0
	# Values above 1 survive the night CanvasModulate so they still glow.
	_fireflies.color = Color(2.4, 2.4, 1.3, 0.9)
	_fireflies.z_index = 4
	map.add_child(_fireflies)


# ------------------------------------------------------------ environment ---

## Re-applies season visuals and audio (used by the --demo-season capture flag).
func apply_season_now() -> void:
	_apply_environment()


func _apply_environment() -> void:
	if is_outdoor():
		map.apply_season(GameState.calendar.season)
		weather_view.visible = true
		weather_view.set_weather(GameState.weather)
	else:
		weather_view.set_weather(Weather.Kind.SUNNY)
		weather_view.visible = false
	_update_light()
	_update_ambience()
	_update_audio()


func _update_light() -> void:
	var minutes := GameState.clock.minutes
	if is_outdoor():
		daylight.color = GameClock.light_color(minutes) * Weather.light_factor(GameState.weather)
	else:
		var night := clampf(float(minutes - 19 * 60) / 180.0, 0.0, 1.0)
		daylight.color = Color(1.0, 0.97, 0.92).lerp(Color(0.8, 0.74, 0.72), night)
	var level := NightLight.level_for(minutes) if is_outdoor() else 0.0
	for node in get_tree().get_nodes_in_group(NightLight.GROUP):
		(node as NightLight).set_level(level)


## Music by season (softer indoors) and background ambience.
func _update_audio() -> void:
	var season: String = ["spring", "summer", "autumn", "winter"][int(GameState.calendar.season)]
	AudioManager.play_music(season, 0.0 if is_outdoor() else AudioManager.MUSIC_INDOOR_DB)
	AudioManager.play_ambience(ambience_track())


## "water" at the lake, "birds" on calm spring/summer days outdoors, else "".
func ambience_track() -> String:
	if not is_outdoor():
		return ""
	if map_id == &"clear_lake":
		return "water"
	var m := GameState.clock.minutes
	var calm := GameState.weather == Weather.Kind.SUNNY or GameState.weather == Weather.Kind.WIND
	if calm and m >= 6 * 60 and m < 19 * 60 and int(GameState.calendar.season) <= 1:
		return "birds"
	return ""


## Footstep sound for the ground under the player.
func step_sound() -> StringName:
	var cell := player.feet_cell(WorldMap.TILE_SIZE)
	var terrain := map.layout.terrain_at(cell)
	if terrain in ["wood", "rug", "doormat"]:
		return &"step_wood"
	if terrain == "cobble" or map.built_floor.get_cell_source_id(cell) != -1:
		return &"step_stone"
	return &"step_grass"


func _on_player_step() -> void:
	var sound := step_sound()
	AudioManager.play(sound, -14.0, 0.12)
	if player.is_running() and sound != &"step_wood":
		var dust := FarmEffects.burst(map.overlay, player.position + Vector2(0, -1), &"dust", 3)
		dust.initial_velocity_max = 18.0
		dust.scale_amount_max = 0.8


func _update_ambience() -> void:
	var w := GameState.weather
	var calm := w == Weather.Kind.SUNNY or w == Weather.Kind.WIND
	var night := GameState.clock.minutes >= 19 * 60
	petals.visible = is_outdoor() and GameState.calendar.season == Calendar.Season.SPRING and calm
	for node in get_tree().get_nodes_in_group(&"butterflies"):
		if map.is_ancestor_of(node):
			(node as CanvasItem).visible = is_outdoor() and calm and not night \
				and GameState.calendar.season != Calendar.Season.WINTER
	if _fireflies:
		_fireflies.emitting = night and w != Weather.Kind.RAIN and w != Weather.Kind.STORM
		_fireflies.visible = _fireflies.emitting


func _show_banner(first_visit: bool) -> void:
	if GameState.pending_day_stats is Dictionary:
		hud.show_day_banner(GameState.pending_day_stats)
		GameState.pending_day_stats = null
		return
	var def := WorldGraph.map_def(map_id)
	var title: String = tr("LOCATION_FARM") % GameState.farm_name if is_farm() else tr(str(def.get("name_key", "")))
	var subtitle: String = tr("LOCATION_SUBTITLE") % tr(GameState.calendar.season_key())
	if first_visit and not is_farm():
		subtitle = tr("MAP_FIRST_VISIT")
	hud.banner.show_banner(title, subtitle, is_farm())


func _on_time_changed(_minutes: int) -> void:
	_update_light()
	_update_ambience()
	AudioManager.play_ambience(ambience_track())


func _on_late_night() -> void:
	hud.toast(tr("MSG_LATE_NIGHT"), true)


func _on_weather_changed(_kind: Weather.Kind) -> void:
	_apply_environment()


func _on_day_started(_stats: Dictionary) -> void:
	_apply_environment()
	_setup_forage()


func _on_modal_changed(open: bool) -> void:
	player.set_input_enabled(not open)
