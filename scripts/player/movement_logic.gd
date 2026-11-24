class_name MovementLogic
extends RefCounted
## Pure, engine-independent movement maths for top-down characters.
## Kept separate from the Player node so it can be unit tested and reused
## by NPCs later.

enum Facing { DOWN, UP, LEFT, RIGHT }

const FACING_NAMES: Array[String] = ["down", "up", "left", "right"]


## Accelerates towards input_dir * max_speed, or decelerates with friction
## when there is no input. Input longer than 1 is normalised so diagonals are
## never faster than straight movement.
static func step_velocity(current: Vector2, input_dir: Vector2, max_speed: float,
		acceleration: float, friction: float, delta: float) -> Vector2:
	if input_dir.length_squared() > 1.0:
		input_dir = input_dir.normalized()
	if input_dir.is_zero_approx():
		return current.move_toward(Vector2.ZERO, friction * delta)
	return current.move_toward(input_dir * max_speed, acceleration * delta)


## Maps an 8-direction input to one of 4 sprite facings.
## On a perfect diagonal the previous facing is kept when it matches one of
## the two components, which avoids sprite flicker when pressing two keys.
static func facing_from_direction(dir: Vector2, previous: Facing) -> Facing:
	if dir.length_squared() < 0.0001:
		return previous
	var ax := absf(dir.x)
	var ay := absf(dir.y)
	var horizontal := Facing.RIGHT if dir.x > 0.0 else Facing.LEFT
	var vertical := Facing.DOWN if dir.y > 0.0 else Facing.UP
	if is_equal_approx(ax, ay):
		if previous == horizontal or previous == vertical:
			return previous
		return horizontal
	return horizontal if ax > ay else vertical


static func facing_name(facing: Facing) -> String:
	return FACING_NAMES[facing]


static func facing_vector(facing: Facing) -> Vector2:
	match facing:
		Facing.UP:
			return Vector2.UP
		Facing.LEFT:
			return Vector2.LEFT
		Facing.RIGHT:
			return Vector2.RIGHT
	return Vector2.DOWN
