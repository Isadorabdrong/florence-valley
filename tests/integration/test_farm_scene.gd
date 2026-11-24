extends TestCase
## Loads the real farm scene and drives the player with simulated input.

var _farm: Node


func before_each() -> void:
	GameState.start_new_profile("Teste", "Florence", 1)
	_farm = (load("res://scenes/farm/farm.tscn") as PackedScene).instantiate()
	_farm.set("allow_scene_changes", false)
	tree.root.add_child(_farm)


func after_each() -> void:
	for action in InputBindings.ALL_ACTIONS:
		Input.action_release(action)
	_farm.free()


func _player() -> Player:
	return _farm.get("player")


func test_player_spawns_at_map_spawn() -> void:
	await wait_physics_frames(2)
	var map: WorldMap = _farm.get_node("Map")
	var spawn := WorldGraph.spawn(&"farm", "default")
	assert_eq(_player().position, map.cell_anchor(spawn["cell"]) + Vector2(0, -2))
	assert_eq(_player().get_parent(), map.entities, "player is y-sorted with objects")


func test_player_moves_right_and_faces_right() -> void:
	await wait_physics_frames(2)
	var start := _player().position
	Input.action_press(InputBindings.MOVE_RIGHT)
	await wait_physics_frames(30)
	Input.action_release(InputBindings.MOVE_RIGHT)
	assert_gt(_player().position.x - start.x, 10.0, "moved right")
	assert_almost(_player().position.y, start.y, 0.5, "no vertical drift")
	assert_eq(_player().facing, MovementLogic.Facing.RIGHT)


func test_running_is_faster_than_walking() -> void:
	await wait_physics_frames(2)
	var start := _player().position
	Input.action_press(InputBindings.MOVE_DOWN)
	await wait_physics_frames(20)
	var walked := _player().position.y - start.y
	_player().position = start
	_player().velocity = Vector2.ZERO
	Input.action_press(InputBindings.RUN)
	await wait_physics_frames(20)
	var ran := _player().position.y - start.y
	assert_gt(ran, walked * 1.2, "run (%f) vs walk (%f)" % [ran, walked])


func test_diagonal_moves_both_axes() -> void:
	await wait_physics_frames(2)
	var start := _player().position
	Input.action_press(InputBindings.MOVE_DOWN)
	Input.action_press(InputBindings.MOVE_RIGHT)
	await wait_physics_frames(30)
	var delta := _player().position - start
	assert_gt(delta.x, 5.0)
	assert_gt(delta.y, 5.0)
	assert_almost(delta.x, delta.y, 1.0, "45 degrees")


func test_world_edge_blocks_player() -> void:
	await wait_physics_frames(2)
	_player().position = Vector2(8, 300)
	Input.action_press(InputBindings.MOVE_LEFT)
	await wait_physics_frames(40)
	assert_gt(_player().position.x, 0.0, "cannot leave the map (x=%f)" % _player().position.x)


func test_house_blocks_player() -> void:
	await wait_physics_frames(2)
	var map: WorldMap = _farm.get_node("Map")
	# Spawn is just below the house; walk straight up into it.
	var start := _player().position
	Input.action_press(InputBindings.MOVE_UP)
	await wait_physics_frames(90)
	var house_bottom := map.cell_anchor(Vector2i(31, 12)).y
	assert_gt(_player().position.y, house_bottom - 6.0, "stopped at the house wall (y=%f)" % _player().position.y)
	assert_lt(_player().position.y, start.y, "but did move up")


func test_water_blocks_player() -> void:
	await wait_physics_frames(2)
	var map: WorldMap = _farm.get_node("Map")
	# Stand west of the pond (row 25) and walk east into it.
	var pond_left_cell := Vector2i(42, 25)
	_player().position = map.cell_center(Vector2i(38, 25))
	Input.action_press(InputBindings.MOVE_RIGHT)
	await wait_physics_frames(120)
	assert_lt(_player().position.x, map.cell_center(pond_left_cell).x, "stopped at the shore (x=%f)" % _player().position.x)


func test_camera_limits_match_map() -> void:
	await wait_physics_frames(2)
	var cam: Camera2D = _player().get_node("Camera")
	var rect: Rect2 = (_farm.get_node("Map") as WorldMap).get_world_rect()
	assert_eq(cam.limit_right, int(rect.end.x))
	assert_eq(cam.limit_bottom, int(rect.end.y))
	assert_eq(cam.limit_left, 0)
	assert_eq(cam.limit_top, 0)
