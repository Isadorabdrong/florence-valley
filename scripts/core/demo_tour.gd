class_name DemoTour
extends Node
## Scripted walk used to record the trailer (Godot Movie Maker):
##   godot --path . res://scenes/farm/farm.tscn --write-movie out.avi
##       --fixed-fps 30 -- --demo=farming --tour=farm
## Presses the real input actions, so what is recorded is normal gameplay.
## `--tour-timelapse=<game minutes per second>` speeds the clock up.

const TOURS := {
	"farm": [["wait", 1.0], ["move_down", 0.9], ["move_right", 1.6], ["use_item", 0.4], ["move_down", 0.6],
		["use_item", 0.4], ["move_left", 1.2], ["run_down", 1.0], ["move_right", 2.0], ["wait", 1.0]],
	"dusk": [["wait", 0.8], ["move_left", 2.0], ["move_up", 1.2], ["move_right", 2.6], ["wait", 2.0]],
	"winter": [["wait", 0.6], ["run_right", 1.6], ["move_down", 1.4], ["move_left", 1.6], ["wait", 1.0]],
}

var _steps: Array = []
var _index := -1
var _left := 0.0
var _held: Array[StringName] = []
var _timelapse := 0.0
var _minutes := -1.0


func _init(tour: String, timelapse: float = 0.0) -> void:
	_steps = TOURS.get(tour, [])
	_timelapse = timelapse
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _timelapse > 0.0:
		if _minutes < 0.0: # read after the demo flags have set the time
			_minutes = GameState.clock.minutes
		_minutes += _timelapse * delta
		GameState.clock.set_minutes(int(_minutes))
	_left -= delta
	if _left > 0.0:
		return
	_release()
	_index += 1
	if _index >= _steps.size():
		set_process(false)
		return
	var step: Array = _steps[_index]
	var action: String = step[0]
	_left = float(step[1])
	if action.begins_with("run_"):
		_press(InputBindings.RUN)
		action = "move_" + action.trim_prefix("run_")
	if action != "wait":
		_press(StringName(action))


func _press(action: StringName) -> void:
	Input.action_press(action)
	_held.append(action)


func _release() -> void:
	for a in _held:
		Input.action_release(a)
	_held.clear()


func _exit_tree() -> void:
	_release()
