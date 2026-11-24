class_name LocationBanner
extends Control
## Shows the current location name when entering an area, plus a one-time
## controls hint at the bottom of the screen.

@export var hold_time := 3.0
@export var hint_time := 9.0

@onready var _panel: Control = $Panel
@onready var _title: Label = $Panel/VBox/Title
@onready var _subtitle: Label = $Panel/VBox/Subtitle
@onready var _hint: Label = $Hint


func _ready() -> void:
	_panel.modulate.a = 0.0
	_hint.modulate.a = 0.0


func show_banner(title: String, subtitle: String, show_hint: bool = true) -> void:
	_title.text = title
	_subtitle.text = subtitle
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(hold_time)
	tween.tween_property(_panel, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	if show_hint:
		var hint_tween := create_tween()
		hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.8).set_delay(0.8)
		hint_tween.tween_interval(hint_time)
		hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.2)
