extends TestCase

const F := MovementLogic.Facing


func test_accelerates_towards_input() -> void:
	var v := MovementLogic.step_velocity(Vector2.ZERO, Vector2.RIGHT, 80.0, 400.0, 400.0, 0.1)
	assert_almost(v.x, 40.0, 0.001, "after 0.1s at 400 px/s²")
	assert_almost(v.y, 0.0)


func test_never_exceeds_max_speed() -> void:
	var v := Vector2.ZERO
	for i in 100:
		v = MovementLogic.step_velocity(v, Vector2.DOWN, 80.0, 1000.0, 1000.0, 0.016)
	assert_almost(v.length(), 80.0, 0.001)


func test_diagonal_is_not_faster() -> void:
	var v := Vector2.ZERO
	for i in 100:
		v = MovementLogic.step_velocity(v, Vector2(1, 1), 80.0, 1000.0, 1000.0, 0.016)
	assert_almost(v.length(), 80.0, 0.001, "raw (1,1) input must be normalised")


func test_friction_stops_character() -> void:
	var v := Vector2(80, 0)
	for i in 30:
		v = MovementLogic.step_velocity(v, Vector2.ZERO, 80.0, 1000.0, 1000.0, 0.016)
	assert_true(v.is_zero_approx(), "should come to rest")


func test_facing_cardinal_directions() -> void:
	assert_eq(MovementLogic.facing_from_direction(Vector2.UP, F.DOWN), F.UP)
	assert_eq(MovementLogic.facing_from_direction(Vector2.DOWN, F.UP), F.DOWN)
	assert_eq(MovementLogic.facing_from_direction(Vector2.LEFT, F.DOWN), F.LEFT)
	assert_eq(MovementLogic.facing_from_direction(Vector2.RIGHT, F.DOWN), F.RIGHT)


func test_facing_keeps_previous_when_idle() -> void:
	assert_eq(MovementLogic.facing_from_direction(Vector2.ZERO, F.LEFT), F.LEFT)


func test_facing_diagonal_keeps_matching_component() -> void:
	var diag := Vector2(1, -1).normalized()
	assert_eq(MovementLogic.facing_from_direction(diag, F.UP), F.UP, "up+right while facing up")
	assert_eq(MovementLogic.facing_from_direction(diag, F.RIGHT), F.RIGHT, "up+right while facing right")
	assert_eq(MovementLogic.facing_from_direction(diag, F.DOWN), F.RIGHT, "falls back to horizontal")


func test_facing_dominant_axis() -> void:
	assert_eq(MovementLogic.facing_from_direction(Vector2(0.9, 0.3), F.UP), F.RIGHT)
	assert_eq(MovementLogic.facing_from_direction(Vector2(-0.2, 0.8), F.UP), F.DOWN)
