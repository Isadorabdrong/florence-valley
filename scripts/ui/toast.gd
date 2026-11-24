class_name Toast
extends PanelContainer
## Short feedback message above the hotbar.

const HOLD := 1.6
const WARN_COLOR := Color("b0465f")
const INFO_COLOR := Color("5b3a4f")

var _tween: Tween
var _last_text := ""
var _last_time := 0

@onready var _label: Label = $Label


func _ready() -> void:
	modulate.a = 0.0


func show_message(text: String, warn: bool = false) -> void:
	var now := Time.get_ticks_msec()
	if text == _last_text and now - _last_time < 400:
		return
	_last_text = text
	_last_time = now
	_label.text = text
	_label.add_theme_color_override(&"font_color", WARN_COLOR if warn else INFO_COLOR)
	if _tween:
		_tween.kill()
	modulate.a = 1.0
	_tween = create_tween()
	_tween.tween_interval(HOLD)
	_tween.tween_property(self, "modulate:a", 0.0, 0.4)


func current_text() -> String:
	return _label.text if modulate.a > 0.0 else ""
