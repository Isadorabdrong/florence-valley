class_name ConfirmDialog
extends Control
## Modal yes/no question. Usage: `var ok: bool = await dialog.ask("…")`.

signal answered(yes: bool)

@onready var _message: Label = %Message
@onready var _yes: Button = %YesButton
@onready var _no: Button = %NoButton


func _ready() -> void:
	visible = false
	_yes.pressed.connect(_answer.bind(true))
	_no.pressed.connect(_answer.bind(false))


func ask(text: String) -> bool:
	_message.text = text
	visible = true
	UiKit.pop_in(self)
	_yes.grab_focus()
	var result: bool = await answered
	return result


func _input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(InputBindings.PAUSE)):
		_answer(false)
		get_viewport().set_input_as_handled()


func _answer(yes: bool) -> void:
	if not visible:
		return
	visible = false
	answered.emit(yes)
