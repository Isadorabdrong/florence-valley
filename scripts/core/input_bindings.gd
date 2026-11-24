class_name InputBindings
extends RefCounted
## Registers the default input actions at startup.
##
## Bindings live in code (instead of hand-written project.godot entries) so
## they are easy to review, test, and later override from a rebinding menu.

const MOVE_UP := &"move_up"
const MOVE_DOWN := &"move_down"
const MOVE_LEFT := &"move_left"
const MOVE_RIGHT := &"move_right"
const RUN := &"run"
const INTERACT := &"interact"
const USE_ITEM := &"use_item"
const INVENTORY := &"inventory"
const MAP := &"map"
const JOURNAL := &"journal"
const PAUSE := &"pause"
const HOTBAR_NEXT := &"hotbar_next"
const HOTBAR_PREV := &"hotbar_prev"
## hotbar_1 … hotbar_12 select a hotbar slot directly.
const HOTBAR_SLOTS: Array[StringName] = [&"hotbar_1", &"hotbar_2", &"hotbar_3", &"hotbar_4",
	&"hotbar_5", &"hotbar_6", &"hotbar_7", &"hotbar_8", &"hotbar_9", &"hotbar_10",
	&"hotbar_11", &"hotbar_12"]
const HOTBAR_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8,
	KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]

const ALL_ACTIONS: Array[StringName] = [MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT, RUN,
	INTERACT, USE_ITEM, INVENTORY, MAP, JOURNAL, PAUSE, HOTBAR_NEXT, HOTBAR_PREV]

## action -> list of physical keys
const KEYS := {
	MOVE_UP: [KEY_W, KEY_UP],
	MOVE_DOWN: [KEY_S, KEY_DOWN],
	MOVE_LEFT: [KEY_A, KEY_LEFT],
	MOVE_RIGHT: [KEY_D, KEY_RIGHT],
	RUN: [KEY_SHIFT],
	INTERACT: [KEY_E],
	USE_ITEM: [KEY_SPACE, KEY_J],
	INVENTORY: [KEY_TAB, KEY_I],
	MAP: [KEY_M],
	JOURNAL: [KEY_L],
	PAUSE: [KEY_ESCAPE],
	HOTBAR_NEXT: [KEY_BRACKETRIGHT],
	HOTBAR_PREV: [KEY_BRACKETLEFT],
}

const MOUSE := {
	USE_ITEM: [MOUSE_BUTTON_LEFT],
	INTERACT: [MOUSE_BUTTON_RIGHT],
	HOTBAR_NEXT: [MOUSE_BUTTON_WHEEL_DOWN],
	HOTBAR_PREV: [MOUSE_BUTTON_WHEEL_UP],
}

## action -> [axis, direction]
const AXES := {
	MOVE_UP: [JOY_AXIS_LEFT_Y, -1.0],
	MOVE_DOWN: [JOY_AXIS_LEFT_Y, 1.0],
	MOVE_LEFT: [JOY_AXIS_LEFT_X, -1.0],
	MOVE_RIGHT: [JOY_AXIS_LEFT_X, 1.0],
}

const BUTTONS := {
	MOVE_UP: [JOY_BUTTON_DPAD_UP],
	MOVE_DOWN: [JOY_BUTTON_DPAD_DOWN],
	MOVE_LEFT: [JOY_BUTTON_DPAD_LEFT],
	MOVE_RIGHT: [JOY_BUTTON_DPAD_RIGHT],
	RUN: [JOY_BUTTON_B],
	INTERACT: [JOY_BUTTON_A],
	USE_ITEM: [JOY_BUTTON_X],
	INVENTORY: [JOY_BUTTON_Y],
	MAP: [JOY_BUTTON_BACK],
	PAUSE: [JOY_BUTTON_START],
	HOTBAR_NEXT: [JOY_BUTTON_RIGHT_SHOULDER],
	HOTBAR_PREV: [JOY_BUTTON_LEFT_SHOULDER],
}


## Adds any missing default action. Existing actions are left untouched, so
## user rebinding (future settings menu) is never overwritten.
static func register_defaults() -> void:
	for i in HOTBAR_SLOTS.size():
		if not InputMap.has_action(HOTBAR_SLOTS[i]):
			InputMap.add_action(HOTBAR_SLOTS[i])
			var key_ev := InputEventKey.new()
			key_ev.physical_keycode = HOTBAR_KEYS[i]
			InputMap.action_add_event(HOTBAR_SLOTS[i], key_ev)
	for action in ALL_ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.25)
		for key: Key in KEYS.get(action, []):
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)
		if AXES.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.axis = AXES[action][0]
			motion.axis_value = AXES[action][1]
			InputMap.action_add_event(action, motion)
		for mouse_button: MouseButton in MOUSE.get(action, []):
			var mb := InputEventMouseButton.new()
			mb.button_index = mouse_button
			InputMap.action_add_event(action, mb)
		for button: JoyButton in BUTTONS.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = button
			InputMap.action_add_event(action, jb)
