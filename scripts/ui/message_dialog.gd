class_name MessageDialog
extends Control
## Modal text window for signs, books, locked doors and landmarks.

signal closed

@onready var _title: Label = %MessageTitle
@onready var _text: Label = %MessageText
@onready var _ok: Button = %OkButton


func _ready() -> void:
	visible = false
	_ok.pressed.connect(close)


func show_text(text: String, title: String = "") -> void:
	_title.text = title
	_title.visible = not title.is_empty()
	_text.text = text
	visible = true
	UiKit.pop_in(self)
	_ok.grab_focus()
	AudioManager.play(&"open", -8.0)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE) \
			or event.is_action_pressed(InputBindings.INTERACT) or event.is_action_pressed(InputBindings.USE_ITEM):
		close()
		get_viewport().set_input_as_handled()
